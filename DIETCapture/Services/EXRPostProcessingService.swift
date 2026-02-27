// EXRPostProcessingService.swift
// ReScan
//
// Background service that converts deferred EXR sessions (raw YUV frames) to
// OpenEXR format after capture. Runs on a low-priority queue and respects
// device thermal state to avoid impacting performance.

import Foundation
import Observation
import CoreImage

@Observable
final class EXRPostProcessingService {

    static let shared = EXRPostProcessingService()

    // MARK: - Observable State (updated on main queue)

    /// Whether a conversion job is currently running.
    var isConverting = false

    /// ID of the session currently being converted.
    var currentSessionID: String?

    /// 0.0 – 1.0 progress for the active session.
    var sessionProgress: Double = 0

    /// Number of raw frames still waiting for conversion in the active session.
    var remainingFrames: Int = 0

    // MARK: - Private

    private let conversionQueue = DispatchQueue(label: "com.rescan.exr.postprocess", qos: .utility)
    private var isCancelled = false

    private lazy var ciContext: CIContext = {
        CIContext(options: [
            .useSoftwareRenderer: false,
            .allowLowPower: true,
            .cacheIntermediates: false
        ])
    }()

    // MARK: - Public API

    /// Convert a single pending session.  Calls `completion` on the main queue when done (or cancelled).
    func convertSession(_ session: RecordedSession, completion: @escaping () -> Void) {
        guard case .pending(let count) = session.conversionStatus, count > 0 else {
            completion()
            return
        }
        isCancelled = false
        setConverting(true, sessionID: session.id, remaining: count)

        conversionQueue.async { [weak self] in
            self?.runConversionSync(for: session)
            DispatchQueue.main.async {
                self?.setConverting(false, sessionID: nil, remaining: 0)
                completion()
            }
        }
    }

    /// Convert all pending sessions in the library.  Calls `completion` on the main queue when done.
    func convertAllPending(in sessions: [RecordedSession], completion: @escaping () -> Void) {
        let pending = sessions.filter {
            if case .pending = $0.conversionStatus { return true }
            return false
        }
        guard !pending.isEmpty else { completion(); return }

        isCancelled = false
        let total = pending.reduce(0) {
            if case .pending(let c) = $1.conversionStatus { return $0 + c }
            return $0
        }
        setConverting(true, sessionID: pending.first?.id, remaining: total)

        conversionQueue.async { [weak self] in
            for session in pending {
                guard let self, !self.isCancelled else { break }
                DispatchQueue.main.async { self.currentSessionID = session.id }
                self.runConversionSync(for: session)
            }
            DispatchQueue.main.async {
                self?.setConverting(false, sessionID: nil, remaining: 0)
                completion()
            }
        }
    }

    /// Stop an in-progress conversion at the next frame boundary.
    func cancelConversion() {
        isCancelled = true
    }

    // MARK: - Private helpers

    private func setConverting(_ converting: Bool, sessionID: String?, remaining: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.isConverting = converting
            self?.currentSessionID = sessionID
            self?.remainingFrames = remaining
            self?.sessionProgress = 0
        }
    }

    /// Synchronously converts all `.yuv` files in `session`'s `rgb/` directory to `.exr`.
    /// Runs on `conversionQueue`.
    private func runConversionSync(for session: RecordedSession) {
        let fm = FileManager.default
        let rgbDir = session.directory.appendingPathComponent("rgb")

        guard let contents = try? fm.contentsOfDirectory(atPath: rgbDir.path) else { return }
        let yuvFiles = contents.filter { $0.hasSuffix(".yuv") }.sorted()
        let total = yuvFiles.count
        guard total > 0 else { return }

        for (index, filename) in yuvFiles.enumerated() {
            guard !isCancelled else { break }

            // Respect thermal state
            switch ProcessInfo.processInfo.thermalState {
            case .critical:
                while ProcessInfo.processInfo.thermalState == .critical && !isCancelled {
                    Thread.sleep(forTimeInterval: 10)
                }
            case .serious:
                Thread.sleep(forTimeInterval: 2)
            default:
                break
            }

            let rawURL = rgbDir.appendingPathComponent(filename)
            let stem   = (filename as NSString).deletingPathExtension
            let exrURL = rgbDir.appendingPathComponent(stem + ".exr")

            if convertFrame(from: rawURL, to: exrURL) {
                try? fm.removeItem(at: rawURL)
            }

            let progress = Double(index + 1) / Double(total)
            let left = total - (index + 1)
            DispatchQueue.main.async { [weak self] in
                self?.sessionProgress = progress
                self?.remainingFrames = left
            }
        }

        // Remove the pending marker only when all frames are converted
        let leftoverYUV = (try? fm.contentsOfDirectory(atPath: rgbDir.path))?.filter { $0.hasSuffix(".yuv") } ?? []
        if leftoverYUV.isEmpty {
            let markerURL = rgbDir.appendingPathComponent(CaptureSession.pendingConversionMarker)
            try? fm.removeItem(at: markerURL)
        }
    }

    /// Converts a single raw YUV file to an OpenEXR file.  Returns `true` on success.
    private func convertFrame(from rawURL: URL, to exrURL: URL) -> Bool {
        guard let pixelBuffer = ExportService.loadRawYUVFrame(from: rawURL) else {
            print("[EXRPostProcessing] ❌ Failed to load raw YUV: \(rawURL.lastPathComponent)")
            return false
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else {
            print("[EXRPostProcessing] ❌ extendedLinearSRGB unavailable")
            return false
        }

        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent,
                                                    format: .RGBAh, colorSpace: colorSpace) else {
            print("[EXRPostProcessing] ❌ CIContext createCGImage failed")
            return false
        }

        guard let dest = CGImageDestinationCreateWithURL(exrURL as CFURL,
                                                         "com.ilm.openexr-image" as CFString, 1, nil) else {
            print("[EXRPostProcessing] ❌ Cannot create CGImageDestination")
            return false
        }

        let options: [CFString: Any] = [
            // 1 = ZIP (lossless) compression in the OpenEXR spec
            "imageCompression" as CFString: NSNumber(value: 1)
        ]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        let success = CGImageDestinationFinalize(dest)
        if success {
            print("[EXRPostProcessing] ✅ Converted \(rawURL.lastPathComponent) → \(exrURL.lastPathComponent)")
        } else {
            print("[EXRPostProcessing] ❌ CGImageDestinationFinalize failed for \(exrURL.lastPathComponent)")
        }
        return success
    }
}
