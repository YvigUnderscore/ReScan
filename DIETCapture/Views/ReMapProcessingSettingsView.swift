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
                    
                    settingRow(title: "Mapper", tooltip: "mapper_type") {
                        Picker("", selection: $settings.mapperType) {
                            ForEach(ReMapProcessingSettings.mapperTypeOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    settingRow(title: "Pairing Mode", tooltip: "pairing_mode") {
                        Picker("", selection: $settings.pairingMode) {
                            ForEach(ReMapProcessingSettings.pairingModeOptions, id: \.self) { option in
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
                    
                    settingRow(title: "Max Keypoints", tooltip: "max_keypoints") {
                        HStack {
                            Slider(value: Binding(
                                get: { Double(settings.maxKeypoints) },
                                set: { settings.maxKeypoints = Int($0) }
                            ), in: 1024...16384, step: 1024)
                                .tint(.cyan)
                            Text("\(settings.maxKeypoints)")
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 50)
                        }
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
                } header: {
                    Text("Camera")
                }
                
                // MARK: - LiDAR / Stray
                Section {
                    settingRow(title: "Confidence", tooltip: "stray_confidence") {
                        Picker("", selection: $settings.strayConfidence) {
                            Text("0 (Low)").tag(0)
                            Text("1 (Medium)").tag(1)
                            Text("2 (High)").tag(2)
                        }
                        .pickerStyle(.menu)
                    }
                    
                    settingRow(title: "Depth Subsample", tooltip: "stray_depth_subsample") {
                        HStack {
                            Slider(value: Binding(
                                get: { Double(settings.strayDepthSubsample) },
                                set: { settings.strayDepthSubsample = Int($0) }
                            ), in: 1...8, step: 1)
                                .tint(.cyan)
                            Text("\(settings.strayDepthSubsample)")
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 20)
                        }
                    }
                    
                    settingRow(title: "Generate Pointcloud", tooltip: "stray_gen_pointcloud") {
                        Toggle("", isOn: $settings.strayGenPointcloud)
                            .tint(.cyan)
                    }
                } header: {
                    Text("LiDAR / Depth")
                }
                
                // MARK: - Performance
                Section {
                    settingRow(title: "CPU Threads", tooltip: "num_threads") {
                        HStack {
                            Slider(value: Binding(
                                get: { Double(settings.numThreads ?? 0) },
                                set: { settings.numThreads = Int($0) == 0 ? nil : Int($0) }
                            ), in: 0...32, step: 1)
                                .tint(.cyan)
                            Text(settings.numThreads.map { "\($0)" } ?? "Auto")
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 40)
                        }
                    }
                } header: {
                    Text("Performance")
                }
                
                // MARK: - Colorspace
                Section {
                    Toggle("Enable Colorspace Conversion", isOn: $settings.colorspaceEnabled)
                        .tint(.cyan)
                    
                    if settings.colorspaceEnabled {
                        settingRow(title: "Input Colorspace", tooltip: "") {
                            Picker("", selection: $settings.inputColorspace) {
                                ForEach(ReMapColorspace.allCases) { cs in
                                    Text(cs.label).tag(cs)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        settingRow(title: "Output Colorspace", tooltip: "") {
                            Picker("", selection: $settings.outputColorspace) {
                                ForEach(ReMapColorspace.allCases) { cs in
                                    Text(cs.label).tag(cs)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                } header: {
                    Text("Colorspace")
                } footer: {
                    Text("When enabled, the server will convert images from the input colorspace to the output colorspace during processing.")
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
                        s.remapDefaultMaxKeypoints = settings.maxKeypoints
                        s.remapDefaultMapperType = settings.mapperType
                        s.remapDefaultPairingMode = settings.pairingMode
                        s.remapDefaultNumThreads = settings.numThreads ?? 0
                        s.remapDefaultStrayConfidence = settings.strayConfidence
                        s.remapDefaultStrayDepthSubsample = settings.strayDepthSubsample
                        s.remapDefaultStrayGenPointcloud = settings.strayGenPointcloud
                        s.remapDefaultColorspaceEnabled = settings.colorspaceEnabled
                        s.remapDefaultInputColorspace = settings.inputColorspace.rawValue
                        s.remapDefaultOutputColorspace = settings.outputColorspace.rawValue
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
                
                if !tooltip.isEmpty {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                content()
            }
            
            if !tooltip.isEmpty {
                Text(ReMapProcessingSettings.tooltip(for: tooltip))
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
            }
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
