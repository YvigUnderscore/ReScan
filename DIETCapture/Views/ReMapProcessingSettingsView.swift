// ReMapProcessingSettingsView.swift
// ReScan
//
// Advanced processing settings for ReMap with tooltips, presets, and all
// documented parameters (fps, feature_type, matcher_type, etc.).

import SwiftUI

struct ReMapProcessingSettingsView: View {
    @Binding var settings: ReMapProcessingSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Presets
                Section {
                    HStack(spacing: 10) {
                        presetButton(label: "Indoor", icon: "house.fill", preset: .presetIndoor)
                        presetButton(label: "Outdoor", icon: "sun.max.fill", preset: .presetOutdoor)
                        presetButton(label: "Turntable", icon: "rotate.3d", preset: .presetTurntable)
                    }
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Quick Presets")
                } footer: {
                    Text("Preconfigured settings optimized for common scanning scenarios.")
                }
                
                // MARK: - General
                Section {
                    settingRow(title: "FPS", tooltip: "fps") {
                        HStack {
                            Slider(value: $settings.fps, in: 1...30, step: 0.5)
                                .tint(.cyan)
                            Text("\(settings.fps, specifier: "%.1f")")
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 40)
                        }
                    }
                    
                    settingRow(title: "Approach", tooltip: "stray_approach") {
                        Picker("", selection: $settings.strayApproach) {
                            ForEach(ReMapProcessingSettings.strayApproachOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("General")
                }
                
                // MARK: - Feature Extraction
                Section {
                    settingRow(title: "Feature Type", tooltip: "feature_type") {
                        Picker("", selection: $settings.featureType) {
                            ForEach(ReMapProcessingSettings.featureTypeOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Feature Extraction")
                }
                
                // MARK: - Matching
                Section {
                    settingRow(title: "Matcher Type", tooltip: "matcher_type") {
                        Picker("", selection: $settings.matcherType) {
                            ForEach(ReMapProcessingSettings.matcherTypeOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Feature Matching")
                }
                
                // MARK: - Camera
                Section {
                    settingRow(title: "Camera Model", tooltip: "camera_model") {
                        Picker("", selection: $settings.cameraModel) {
                            ForEach(ReMapProcessingSettings.cameraModelOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    settingRow(title: "Single Camera", tooltip: "single_camera") {
                        Toggle("", isOn: $settings.singleCamera)
                            .tint(.cyan)
                    }
                } header: {
                    Text("Camera")
                }
                
                // MARK: - Performance
                Section {
                    settingRow(title: "Use GPU", tooltip: "use_gpu") {
                        Toggle("", isOn: $settings.useGPU)
                            .tint(.cyan)
                    }
                } header: {
                    Text("Performance")
                }
                
                // MARK: - Reset & Save Defaults
                Section {
                    Button {
                        settings = ReMapProcessingSettings()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                    }
                    
                    Button {
                        let s = AppSettings.shared
                        s.remapDefaultFPS = settings.fps
                        s.remapDefaultApproach = settings.strayApproach
                        s.remapDefaultFeatureType = settings.featureType
                        s.remapDefaultMatcherType = settings.matcherType
                        s.remapDefaultCameraModel = settings.cameraModel
                        s.remapDefaultSingleCamera = settings.singleCamera
                        s.remapDefaultUseGPU = settings.useGPU
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save as Default Settings")
                        }
                        .foregroundStyle(.cyan)
                    }
                }
            }
            .navigationTitle("Processing Settings")
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
    
    // MARK: - Setting Row with Tooltip
    
    private func settingRow<Content: View>(title: String, tooltip: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                
                Button {
                    // Tooltip shown via popover/alert
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .help(ReMapProcessingSettings.tooltip(for: tooltip))
                
                Spacer()
                
                content()
            }
            
            Text(ReMapProcessingSettings.tooltip(for: tooltip))
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Preset Button
    
    private func presetButton(label: String, icon: String, preset: ReMapProcessingSettings) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings = preset
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.cyan)
        }
        .buttonStyle(.plain)
    }
}
