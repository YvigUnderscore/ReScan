// ReMapActivityAttributes.swift
// ReScanWidget
//
// Copy of the shared ActivityAttributes model for the Widget Extension target.
// Keep in sync with DIETCapture/Models/ReMapActivityAttributes.swift.

import ActivityKit
import Foundation

struct ReMapActivityAttributes: ActivityAttributes {

    // MARK: - Dynamic Content

    public struct ContentState: Codable, Hashable {
        var status: String
        var progress: Double
        var step: String
        var eta: String?
    }

    // MARK: - Static Content

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
}
