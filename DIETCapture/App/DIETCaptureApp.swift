// ReScanApp.swift
// ReScan
//
// App entry point.

import SwiftUI

@main
struct ReScanApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environment(EXRPostProcessingService.shared)
                .task {
                    logStartupInfo()
                }
        }
    }

    private func logStartupInfo() {
        let logger = AppLogger.shared
        let device = UIDevice.current
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build   = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        logger.info("=== ReScan launching ===", category: "Startup")
        logger.info("Version \(version) (\(build))", category: "Startup")
        logger.info("Device: \(device.name) — \(device.model) — iOS \(device.systemVersion)", category: "Startup")
        logger.info("Locale: \(Locale.current.identifier)", category: "Startup")

        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            logger.info("Documents: \(docs.path)", category: "Startup")
        }
    }
}
