// SettingsView.swift
// ReScan
//
// Settings screen accessible from Controls panel. Simplified for Stray Scanner export.

import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: CaptureViewModel
    
    var body: some View {
        NavigationStack {
            List {
                Section("LiDAR") {
                    HStack {
                        Text("Max Distance")
                        Spacer()
                        Text("\(viewModel.settings.lidar.maxDistance, specifier: "%.1f")m")
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $viewModel.settings.lidar.maxDistance,
                        in: LiDARSettings.distanceRange,
                        step: 0.1
                    )
                    .tint(.cyan)
                    
                    Picker("Confidence", selection: $viewModel.settings.lidar.confidenceThreshold) {
                        ForEach(ConfidenceThreshold.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    
                    Toggle("Depth Smoothing", isOn: $viewModel.settings.lidar.smoothingEnabled)
                        .tint(.cyan)
                }
                
                Section("Export") {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.cyan)
                        Text("Stray Scanner Format")
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Output files:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Group {
                            Label("rgb.mp4", systemImage: "video.fill")
                            Label("camera_matrix.csv", systemImage: "camera.metering.matrix")
                            Label("odometry.csv", systemImage: "location.fill")
                            Label("depth/*.png (16-bit mm)", systemImage: "cube.fill")
                            Label("confidence/*.png", systemImage: "checkmark.shield.fill")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("ReScan")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("v1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Format")
                        Spacer()
                        Text("Stray Scanner Compatible")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}
