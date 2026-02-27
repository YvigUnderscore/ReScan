// AppLogger.swift
// ReScan
//
// Centralized logger that writes to both the system console (os.log) and a
// timestamped log file stored in the app's Documents/Logs directory.
// The Documents directory is user-accessible via the Files app and iTunes
// file sharing (UIFileSharingEnabled is set in Info.plist).

import Foundation
import OSLog

final class AppLogger {

    static let shared = AppLogger()

    // MARK: - Private

    private var fileHandle: FileHandle?
    private var logURL: URL?
    private var didSetupFile = false
    private let subsystem = "com.rescan.app"
    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    // MARK: - Init

    private init() {
        // Defer file creation to first write to avoid filesystem access
        // before the app sandbox is fully ready.
    }

    deinit {
        try? fileHandle?.close()
    }

    // MARK: - Lazy File Setup

    private func setupFileIfNeeded() {
        guard !didSetupFile else { return }
        didSetupFile = true

        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let logsDir = docs.appendingPathComponent("Logs")
        try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let sessionFormatter = DateFormatter()
        sessionFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "ReScan_\(sessionFormatter.string(from: Date())).log"
        let url = logsDir.appendingPathComponent(filename)

        fm.createFile(atPath: url.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: url)
        logURL = url
    }

    // MARK: - Public API

    func info(_ message: String, category: String = "App") {
        write(level: "INFO", message: message, category: category)
        Logger(subsystem: subsystem, category: category).info("\(message, privacy: .public)")
    }

    func warning(_ message: String, category: String = "App") {
        write(level: "WARNING", message: message, category: category)
        Logger(subsystem: subsystem, category: category).warning("\(message, privacy: .public)")
    }

    func error(_ message: String, category: String = "App") {
        write(level: "ERROR", message: message, category: category)
        Logger(subsystem: subsystem, category: category).error("\(message, privacy: .public)")
    }

    // MARK: - Private

    private func write(level: String, message: String, category: String) {
        setupFileIfNeeded()
        let timestamp = timestampFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] [\(category)] \(message)\n"
        guard let data = line.data(using: .utf8), let handle = fileHandle else { return }
        handle.write(data)
        // Synchronize after every write so logs survive a crash
        try? handle.synchronize()
    }
}
