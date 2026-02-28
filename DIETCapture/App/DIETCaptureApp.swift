// ReScanApp.swift
// ReScan
//
// App entry point with AppDelegate for background tasks and notifications.

import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct ReScanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register BGTaskScheduler tasks before the first suspended state
        BackgroundTaskService.shared.registerTasks()

        // Request notification permission
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }

        // Become delegate for foreground notification display
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background refresh whenever we enter background
        BackgroundTaskService.shared.scheduleAppRefresh()
        BackgroundTaskService.shared.scheduleProcessingTask()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification taps
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
