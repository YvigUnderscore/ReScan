// ReMapLiveActivityView.swift
// ReScanWidget
//
// Live Activity UI for Dynamic Island and Lock Screen — shows ReMap job progress.

import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Widget Bundle

@main
struct ReScanWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReMapLiveActivityWidget()
    }
}

// MARK: - Live Activity Widget

struct ReMapLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReMapActivityAttributes.self) { context in
            // Lock Screen / Notification Banner
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view (long press)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: context.state.statusIcon)
                            .font(.title3)
                            .foregroundStyle(statusColor(context.state.status))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.datasetName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(context.state.step)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.progressPercent)%")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(statusColor(context.state.status))
                            .monospacedDigit()
                        if let eta = context.state.eta {
                            Text(eta)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .tint(statusColor(context.state.status))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.statusIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(context.state.status))
            } compactTrailing: {
                Text("\(context.state.progressPercent)%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(statusColor(context.state.status))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.state.isTerminal ? context.state.statusIcon : "gearshape.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(context.state.status))
            }
            .widgetURL(URL(string: "rescan://remap"))
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "uploading":  return .cyan
        case "processing": return .blue
        case "completed":  return .green
        case "failed":     return .red
        case "cancelled":  return .orange
        default:           return .gray
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<ReMapActivityAttributes>

    private var statusColor: Color {
        switch context.state.status {
        case "uploading":  return .cyan
        case "processing": return .blue
        case "completed":  return .green
        case "failed":     return .red
        case "cancelled":  return .orange
        default:           return .gray
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "viewfinder")
                    .font(.headline)
                    .foregroundStyle(.cyan)
                Text("ReScan ReMap")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if context.state.isTerminal {
                    Image(systemName: context.state.statusIcon)
                        .font(.headline)
                        .foregroundStyle(statusColor)
                } else {
                    Text("\(context.state.progressPercent)%")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(statusColor)
                        .monospacedDigit()
                }
            }

            // Progress bar
            if !context.state.isTerminal {
                ProgressView(value: context.state.progress)
                    .tint(statusColor)
            }

            // Footer
            HStack {
                Text(context.attributes.datasetName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                Spacer()
                Text(context.state.step)
                    .font(.caption)
                    .foregroundStyle(statusColor.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(.black.opacity(0.85))
    }
}
