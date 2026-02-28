// BackgroundTaskService.swift
// ReScan
//
// Registers and schedules BGTaskScheduler tasks to poll ReMap job statuses
// and fire local notifications even when the app is not in the foreground.

import BackgroundTasks
import Foundation

final class BackgroundTaskService: @unchecked Sendable {
    static let shared = BackgroundTaskService()
    private init() {}

    // MARK: - Identifiers (must match Info.plist BGTaskSchedulerPermittedIdentifiers)

    static let appRefreshIdentifier = "com.rescan.app.refresh"
    static let processingIdentifier = "com.rescan.app.processing"

    // MARK: - Registration (call once at app launch, before first runloop)

    func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.appRefreshIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task { await self.handleAppRefresh(task: refreshTask) }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.processingIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            Task { await self.handleProcessingTask(task: processingTask) }
        }
    }

    // MARK: - Scheduling

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.appRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        submit(request)
    }

    func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: Self.processingIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        submit(request)
    }

    // MARK: - Active Job Tracking (persisted via UserDefaults)

    func trackJob(id: String, datasetName: String) {
        var ids = UserDefaults.standard.stringArray(forKey: "bg_activeJobIds") ?? []
        if !ids.contains(id) { ids.append(id) }
        UserDefaults.standard.set(ids, forKey: "bg_activeJobIds")

        var names = UserDefaults.standard.dictionary(forKey: "bg_jobNames") as? [String: String] ?? [:]
        names[id] = datasetName
        UserDefaults.standard.set(names, forKey: "bg_jobNames")
    }

    func untrackJob(id: String) {
        var ids = UserDefaults.standard.stringArray(forKey: "bg_activeJobIds") ?? []
        ids.removeAll { $0 == id }
        UserDefaults.standard.set(ids, forKey: "bg_activeJobIds")

        var names = UserDefaults.standard.dictionary(forKey: "bg_jobNames") as? [String: String] ?? [:]
        names.removeValue(forKey: id)
        UserDefaults.standard.set(names, forKey: "bg_jobNames")
    }

    // MARK: - Handlers

    private func handleAppRefresh(task: BGAppRefreshTask) async {
        // Reschedule immediately so the OS keeps calling us
        scheduleAppRefresh()

        let pollTask = Task { await pollActiveJobs() }

        task.expirationHandler = { pollTask.cancel() }
        await pollTask.value
        task.setTaskCompleted(success: !pollTask.isCancelled)
    }

    private func handleProcessingTask(task: BGProcessingTask) async {
        let pollTask = Task { await pollActiveJobs() }

        task.expirationHandler = { pollTask.cancel() }
        await pollTask.value
        task.setTaskCompleted(success: !pollTask.isCancelled)
    }

    // MARK: - Polling

    func pollActiveJobs() async {
        let ids = UserDefaults.standard.stringArray(forKey: "bg_activeJobIds") ?? []
        let names = UserDefaults.standard.dictionary(forKey: "bg_jobNames") as? [String: String] ?? [:]

        for jobId in ids {
            guard !Task.isCancelled else { return }
            do {
                let status = try await ReMapAPIService.shared.jobStatus(jobId: jobId)
                let parsed = ReMapJobStatus(rawValue: status.status)
                let datasetName = names[jobId] ?? "Dataset"

                if parsed?.isTerminal == true {
                    untrackJob(id: jobId)
                    if parsed == .completed {
                        NotificationService.shared.sendJobCompletedNotification(jobId: jobId, datasetName: datasetName)
                    } else if parsed == .failed {
                        NotificationService.shared.sendJobFailedNotification(jobId: jobId, datasetName: datasetName, error: status.message)
                    }
                }
            } catch {
                print("[BackgroundTask] Poll error for job \(jobId): \(error)")
            }
        }
    }

    // MARK: - Private

    private func submit(_ request: BGTaskRequest) {
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BackgroundTask] Submit failed (\(request.identifier)): \(error)")
        }
    }
}
