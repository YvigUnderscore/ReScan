// SettingsView.swift
// ReScan
//
// Global app settings for export formats, resolution, defaults.

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Resolution", selection: $settings.videoResolution) {
                        ForEach(AppSettings.VideoResolution.allCases) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    
                    Picker("Framerate", selection: $settings.videoFramerate) {
                        ForEach(AppSettings.VideoFramerate.allCases) { fps in
                            Text(fps.rawValue).tag(fps)
                        }
                    }
                } header: {
                    Text("Video Recording")
                } footer: {
                    Text("ARKit selects the closest supported format. 4K is only available on Pro iPhones. The actual format depends on device capabilities.")
                }
                
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
                
                Section {
                    HStack {
                        Text("Format")
                        Spacer()
                        Text("Stray Scanner")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Directory Structure")
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• rgb.mp4").font(.caption).foregroundStyle(.secondary)
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
        }
        .preferredColorScheme(.dark)
    }
}
