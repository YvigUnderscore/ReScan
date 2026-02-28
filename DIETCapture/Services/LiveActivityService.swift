// LiveActivityService.swift
// ReScan
//
// Manages the lifecycle of Dynamic Island / Lock Screen Live Activities
// that track ReMap job progress in real time.

import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private init() {}

    private var currentActivity: Activity<ReMapActivityAttributes>?

    // MARK: - Availability

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Start

    func startActivity(jobId: String, datasetName: String, step: String = "Starting…") {
        guard isAvailable else { return }

        // End any previous activity first
        Task { await endAllActivities() }

        let attributes = ReMapActivityAttributes(jobId: jobId, datasetName: datasetName)
        let state = ReMapActivityAttributes.ContentState(
            status: "uploading",
            progress: 0.0,
            step: step
        )

        do {
            let activity = try Activity<ReMapActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("[LiveActivity] Started: \(activity.id)")
        } catch {
            print("[LiveActivity] Start failed: \(error)")
        }
    }

    // MARK: - Update

    func updateActivity(status: String, progress: Double, step: String, eta: String? = nil) async {
        guard let activity = currentActivity else { return }

        let newState = ReMapActivityAttributes.ContentState(
            status: status,
            progress: max(0, min(1, progress)),
            step: step,
            eta: eta
        )

        await activity.update(.init(state: newState, staleDate: nil))
    }

    // MARK: - End

    func endActivity(success: Bool, step: String) async {
        guard let activity = currentActivity else { return }

        let finalState = ReMapActivityAttributes.ContentState(
            status: success ? "completed" : "failed",
            progress: success ? 1.0 : activity.content.state.progress,
            step: step
        )

        // Keep the Live Activity visible for 30 seconds after completion
        await activity.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .after(Date.now.addingTimeInterval(30))
        )
        currentActivity = nil
    }

    // MARK: - Cleanup

    func endAllActivities() async {
        for activity in Activity<ReMapActivityAttributes>.activities {
            let state = ReMapActivityAttributes.ContentState(
                status: "cancelled",
                progress: 0,
                step: "Cancelled"
            )
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
