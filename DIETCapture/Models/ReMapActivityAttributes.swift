// ReMapActivityAttributes.swift
// ReScan
//
// Shared ActivityAttributes used by both the main app and the ReScanWidget extension
// to drive Dynamic Island and Lock Screen Live Activities for ReMap job progress.

import ActivityKit
import Foundation

struct ReMapActivityAttributes: ActivityAttributes {

    // MARK: - Dynamic Content (updates during the activity)

    public struct ContentState: Codable, Hashable {
        /// Current phase: "uploading" | "processing" | "completed" | "failed" | "cancelled"
        var status: String
        /// Overall progress (0.0 – 1.0)
        var progress: Double
        /// Human-readable current step, e.g. "Extracting features…"
        var step: String
        /// Optional ETA string
        var eta: String?
    }

    // MARK: - Static Content (set at start, never changes)

    var jobId: String
    var datasetName: String
}

// MARK: - Helpers

extension ReMapActivityAttributes.ContentState {
    var isTerminal: Bool { status == "completed" || status == "failed" || status == "cancelled" }
    var progressPercent: Int { Int((progress * 100).rounded()) }

    var statusIcon: String {
        switch status {
        case "uploading":   return "arrow.up.circle.fill"
        case "processing":  return "gearshape.2.fill"
        case "completed":   return "checkmark.circle.fill"
        case "failed":      return "xmark.circle.fill"
        case "cancelled":   return "minus.circle.fill"
        default:            return "clock.fill"
        }
    }

    var statusColor: String {
        switch status {
        case "uploading":   return "cyan"
        case "processing":  return "blue"
        case "completed":   return "green"
        case "failed":      return "red"
        case "cancelled":   return "orange"
        default:            return "gray"
        }
    }
}
