// SettingsView.swift
// ReScan
//
// Global app settings for export formats, resolution, capture FPS, encoding, defaults.

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var storageManager = SecurityScopedStorageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showFileImporter = false
    
    private var supportsAppleLog: Bool {
        ExportService.supportsAppleLog
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Video Recording
                Section {
                    Picker("Resolution", selection: $settings.videoResolution) {
                        ForEach(AppSettings.VideoResolution.allCases) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    
                    Picker("Capture FPS", selection: $settings.captureFPS) {
                        ForEach(AppSettings.CaptureFPS.allCases) { fps in
                            Text(fps.label).tag(fps)
                        }
                    }
                    
                    if settings.captureEXR && settings.captureFPS.rawValue > 2 {
                        Text("⚠️ High FPS with EXR is likely to cause dropped frames or crashes due to hardware bandwidth limits. 1 FPS is recommended.")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                } header: {
                    Text("Video Recording")
                } footer: {
                    Text("The capture FPS controls how many frames are saved per second. ARKit always runs at 30fps internally for accurate LiDAR tracking. Lower FPS = smaller files, useful for photogrammetry workflows.")
                }
                
                // MARK: - Color & Encoding
                Section {
                    Toggle("HDR", isOn: $settings.enableHDR)
                        .tint(.cyan)
                    
                    Toggle("Apple Log (ProRes)", isOn: $settings.useAppleLog)
                        .tint(.orange)
                        .disabled(!supportsAppleLog || settings.captureEXR)
                        
                    Toggle("EXR Sequence", isOn: $settings.captureEXR)
                        .tint(.purple)
                    
                    Toggle("Deferred EXR Conversion", isOn: $settings.deferredEXRConversion)
                        .tint(.orange)
                        .disabled(!settings.captureEXR)
                } header: {
                    Text("Color & Encoding")
                } footer: {
                    if settings.captureEXR {
                        let base = "Captures individual EXR frames instead of a video. EXR files are saved in extended linear sRGB space using half-float precision.\n\n⚠️ EXR sequences consume extreme amounts of storage and memory (~10MB/frame). It is highly recommended to use 1 FPS to avoid hardware bottlenecks (RAM buffers, CPU processing, and storage thermal throttling)."
                        let deferred = settings.deferredEXRConversion ? "\n\nDeferred Conversion: Raw YUV frames are written to disk during capture (minimal CPU load). Convert them to EXR later from the media library." : ""
                        Text(base + deferred)
                    } else if !supportsAppleLog {
                        Text("⚠️ Apple Log requires iPhone 15 Pro or later. This device will use HDR HEVC instead.\n\nApple Log captures in a logarithmic color space with ProRes 422 HQ compression — ideal for color grading to ACEScg or other color spaces without quality loss.")
                    } else {
                        Text("Apple Log captures in a logarithmic color space with ProRes 422 HQ compression — ideal for converting to ACEScg without quality loss.\n\n⚠️ ProRes files are significantly larger (~6 GB/min at 4K).")
                    }
                }
                
                // MARK: - LiDAR Defaults
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Max Distance")
                            Spacer()
                            Text("\(settings.defaultMaxDistance, specifier: "%.1f")m")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.defaultMaxDistance, in: 0.5...5.0, step: 0.1)
                            .tint(.cyan)
                    }
                    .padding(.vertical, 4)
                    
                    Picker("Confidence", selection: $settings.defaultConfidence) {
                        Text("Low").tag(0)
                        Text("Medium").tag(1)
                        Text("High").tag(2)
                    }
                    
                    Toggle("Smooth Depth", isOn: $settings.defaultSmoothing)
                        .tint(.cyan)
                } header: {
                    Text("LiDAR Defaults")
                } footer: {
                    Text("Confidence controls the minimum quality threshold for depth measurements.\n\n• Low: Keeps all depth measurements, including uncertain ones. Maximum coverage but may include noise.\n• Medium (Recommended): Good balance between coverage and accuracy. Filters out the least reliable points.\n• High: Only keeps the most reliable depth measurements. Best accuracy but may have gaps in coverage.\n\nSmooth Depth applies temporal smoothing across frames to reduce noise and flickering in the depth map.")
                }
                
                // MARK: - External Storage
                Section {
                    if let url = storageManager.externalStorageURL {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Storage Location")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(url.lastPathComponent)
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Button(role: .destructive) {
                            storageManager.clearExternalURL()
                        } label: {
                            Text("Disconnect External Storage")
                        }
                    } else {
                        Button {
                            showFileImporter = true
                        } label: {
                            HStack {
                                Image(systemName: "externaldrive.fill")
                                Text("Select External Storage (SSD/USB-C)")
                            }
                        }
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Capture your files directly to an external USB-C drive. Required for high-fps EXR sequences.")
                }
                
                // MARK: - Export Info
                Section {
                    HStack {
                        Text("Format")
                        Spacer()
                        Text("Stray Scanner")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Video Codec")
                        Spacer()
                        Text(settings.captureEXR ? "None (EXR Sequence)" : (settings.useAppleLog && supportsAppleLog ? "ProRes 422 HQ" : (settings.enableHDR ? "HDR HEVC" : "HEVC")))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Directory Structure")
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if settings.captureEXR {
                            Text("• rgb/ (EXR 16-bit float)").font(.caption).foregroundStyle(.secondary)
                        } else {
                            let ext = (settings.useAppleLog && supportsAppleLog) ? "mov" : "mp4"
                            Text("• rgb.\(ext) (\(settings.useAppleLog && supportsAppleLog ? "ProRes 422 HQ, Apple Log" : (settings.enableHDR ? "HDR HEVC" : "HEVC")))").font(.caption).foregroundStyle(.secondary)
                        }
                        Text("• camera_matrix.csv").font(.caption).foregroundStyle(.secondary)
                        Text("• odometry.csv").font(.caption).foregroundStyle(.secondary)
                        Text("• depth/ (16-bit PNG mm)").font(.caption).foregroundStyle(.secondary)
                        Text("• confidence/ (8-bit PNG)").font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Export Options")
                } footer: {
                    Text("ReScan natively exports to the Stray Scanner format, ready for strayscanner-to-colmap processing.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.cyan)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let selectedUrl = urls.first else { return }
                    storageManager.saveExternalURL(selectedUrl)
                case .failure(let error):
                    print("Error selecting folder: \(error.localizedDescription)")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
