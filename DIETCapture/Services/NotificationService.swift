// NotificationService.swift
// ReScan
//
// Centralized service for local notifications: job completion, failure, and upload events.

import UserNotifications
import Foundation

final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()
    private init() {}

    // MARK: - Permission

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    var authorizationStatus: UNAuthorizationStatus {
        get async {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    }

    // MARK: - Job Notifications

    func sendJobStartedNotification(jobId: String, datasetName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Processing Started"
        content.body = "ReMap is processing \"\(datasetName)\" in the background."
        content.sound = nil
        content.userInfo = ["jobId": jobId, "type": "started"]
        schedule(content, identifier: "remap_\(jobId)_started")
    }

    func sendJobCompletedNotification(jobId: String, datasetName: String = "Dataset") {
        let content = UNMutableNotificationContent()
        content.title = "Processing Complete ✅"
        content.body = "\"\(datasetName)\" has been processed successfully."
        content.sound = .default
        content.userInfo = ["jobId": jobId, "type": "completed"]
        schedule(content, identifier: "remap_\(jobId)_completed")
    }

    func sendJobFailedNotification(jobId: String, datasetName: String = "Dataset", error: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "Processing Failed ❌"
        if let error {
            content.body = "\"\(datasetName)\" failed: \(error)"
        } else {
            content.body = "\"\(datasetName)\" processing failed. Tap to view details."
        }
        content.sound = .defaultCritical
        content.userInfo = ["jobId": jobId, "type": "failed"]
        schedule(content, identifier: "remap_\(jobId)_failed")
    }

    func sendUploadCompletedNotification(datasetId: String) {
        let content = UNMutableNotificationContent()
        content.title = "Upload Complete"
        content.body = "Dataset uploaded. Tap to start processing."
        content.sound = .default
        content.userInfo = ["datasetId": datasetId, "type": "upload_completed"]
        schedule(content, identifier: "remap_upload_\(datasetId)_completed")
    }

    // MARK: - Private

    private func schedule(_ content: UNMutableNotificationContent, identifier: String) {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[Notification] Failed to schedule \(identifier): \(error)")
            }
        }
    }
}
