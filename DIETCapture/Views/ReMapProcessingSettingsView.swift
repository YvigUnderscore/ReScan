// ReMapProcessingSettingsView.swift
// ReScan
//
// Advanced processing settings for ReMap with tooltips, presets, and all
// documented parameters (fps, feature_type, matcher_type, etc.).

import SwiftUI

struct ReMapProcessingSettingsView: View {
    @Binding var settings: ReMapProcessingSettings
    /// Optional source duration in seconds (video length or EXR sequence duration).
    /// When provided, the Performance section displays the estimated extracted frame count.
    var sourceDuration: TimeInterval?
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSection: SettingsSection? = .pipeline
    @State private var showSavedFeedback = false
    
    private enum SettingsSection: String, CaseIterable {
        case pipeline = "Pipeline"
        case camera = "Camera & LiDAR"
        case performance = "Performance"
        case colorspace = "Colorspace"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // MARK: - Presets
                        presetsSection
                        
                        // MARK: - Collapsible Sections
                        pipelineSection
                        cameraLidarSection
                        performanceSection
                        colorspaceSection
                        
                        // MARK: - Actions
                        actionsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Processing")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.cyan)
                }
            }
            .overlay(alignment: .bottom) {
                if showSavedFeedback {
                    savedBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Presets Section
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Presets", systemImage: "wand.and.stars")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 10) {
                presetCard(
                    label: "Indoor",
                    icon: "house.fill",
                    description: "3 fps · SuperPoint",
                    gradient: [.blue.opacity(0.5), .cyan.opacity(0.3)],
                    preset: .presetIndoor
                )
                presetCard(
                    label: "Outdoor",
                    icon: "sun.max.fill",
                    description: "2 fps · SP Max",
                    gradient: [.orange.opacity(0.5), .yellow.opacity(0.3)],
                    preset: .presetOutdoor
                )
                presetCard(
                    label: "Turntable",
                    icon: "rotate.3d",
                    description: "5 fps · Full SfM",
                    gradient: [.purple.opacity(0.5), .pink.opacity(0.3)],
                    preset: .presetTurntable
                )
            }
        }
    }
    
    private func presetCard(label: String, icon: String, description: String, gradient: [Color], preset: ReMapProcessingSettings) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                settings = preset
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                
                Text(label)
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Pipeline Section
    
    private var pipelineSection: some View {
        settingsCard(
            section: .pipeline,
            icon: "cpu",
            iconColor: .cyan,
            title: "Pipeline",
            subtitle: "\(settings.featureType) · \(settings.matcherType)"
        ) {
            VStack(spacing: 14) {
                // Approach
                pickerRow(
                    icon: "arrow.triangle.branch",
                    title: "Approach",
                    tooltip: "stray_approach",
                    selection: $settings.strayApproach,
                    options: ReMapProcessingSettings.strayApproachOptions
                )
                
                rowDivider
                
                // Feature Type
                pickerRow(
                    icon: "sparkle.magnifyingglass",
                    title: "Feature Type",
                    tooltip: "feature_type",
                    selection: $settings.featureType,
                    options: ReMapProcessingSettings.featureTypeOptions
                )
                
                rowDivider
                
                // Matcher Type
                pickerRow(
                    icon: "arrow.left.arrow.right",
                    title: "Matcher",
                    tooltip: "matcher_type",
                    selection: $settings.matcherType,
                    options: ReMapProcessingSettings.matcherTypeOptions
                )
                
                rowDivider
                
                // Max Keypoints
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "dot.squareshape.split.2x2")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                            .frame(width: 20)
                        Text("Max Keypoints")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(settings.maxKeypoints)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.cyan.opacity(0.1), in: Capsule())
                    }
                    Slider(value: Binding(
                        get: { Double(settings.maxKeypoints) },
                        set: { settings.maxKeypoints = Int($0) }
                    ), in: 1024...16384, step: 1024)
                        .tint(.cyan)
                    Text(ReMapProcessingSettings.tooltip(for: "max_keypoints"))
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                
                rowDivider
                
                // Pairing Mode
                pickerRow(
                    icon: "link",
                    title: "Pairing",
                    tooltip: "pairing_mode",
                    selection: $settings.pairingMode,
                    options: ReMapProcessingSettings.pairingModeOptions
                )
            }
        }
    }
    
    // MARK: - Camera & LiDAR Section
    
    private var cameraLidarSection: some View {
        settingsCard(
            section: .camera,
            icon: "camera.aperture",
            iconColor: .green,
            title: "Camera & LiDAR",
            subtitle: "\(settings.cameraModel) · Confidence \(settings.strayConfidence)"
        ) {
            VStack(spacing: 14) {
                // Camera Model
                pickerRow(
                    icon: "camera",
                    title: "Camera Model",
                    tooltip: "camera_model",
                    selection: $settings.cameraModel,
                    options: ReMapProcessingSettings.cameraModelOptions
                )
                
                rowDivider
                
                // Depth Confidence
                HStack {
                    Image(systemName: "waveform.path")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .frame(width: 20)
                    Text("Confidence")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("", selection: $settings.strayConfidence) {
                        Text("Low").tag(0)
                        Text("Medium").tag(1)
                        Text("High").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                
                Text(ReMapProcessingSettings.tooltip(for: "stray_confidence"))
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.6))
                
                rowDivider
                
                // Depth Subsample
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "square.grid.3x3.topleft.filled")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        Text("Depth Subsample")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(settings.strayDepthSubsample)×")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.green.opacity(0.1), in: Capsule())
                    }
                    Slider(value: Binding(
                        get: { Double(settings.strayDepthSubsample) },
                        set: { settings.strayDepthSubsample = Int($0) }
                    ), in: 1...8, step: 1)
                        .tint(.green)
                    Text(ReMapProcessingSettings.tooltip(for: "stray_depth_subsample"))
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                
                rowDivider
                
                // Generate Pointcloud
                HStack {
                    Image(systemName: "cube.transparent")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generate Pointcloud")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Text(ReMapProcessingSettings.tooltip(for: "stray_gen_pointcloud"))
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    Spacer()
                    Toggle("", isOn: $settings.strayGenPointcloud)
                        .tint(.green)
                        .labelsHidden()
                }
            }
        }
    }
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        settingsCard(
            section: .performance,
            icon: "gauge.with.dots.needle.33percent",
            iconColor: .orange,
            title: "Performance",
            subtitle: "\(String(format: "%.1f", settings.fps)) fps · \(settings.mapperType)"
        ) {
            VStack(spacing: 14) {
                // FPS
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "speedometer")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        Text("Extraction FPS")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(settings.fps, specifier: "%.1f")")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.1), in: Capsule())
                    }
                    Slider(value: $settings.fps, in: 1...30, step: 0.5)
                        .tint(.orange)
                    if let duration = sourceDuration, duration > 0 {
                        let estimatedFrames = Int(ceil(duration * settings.fps))
                        HStack(spacing: 4) {
                            Image(systemName: "photo.stack")
                                .font(.caption2)
                                .foregroundStyle(.orange.opacity(0.8))
                            Text("≈ \(estimatedFrames) frames extracted")
                                .font(.caption2).fontWeight(.medium)
                                .foregroundStyle(.orange.opacity(0.8))
                        }
                    }
                    Text(ReMapProcessingSettings.tooltip(for: "fps"))
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                
                rowDivider
                
                // Mapper Type
                pickerRowColored(
                    icon: "map",
                    title: "Mapper",
                    tooltip: "mapper_type",
                    color: .orange,
                    selection: $settings.mapperType,
                    options: ReMapProcessingSettings.mapperTypeOptions
                )
                
                rowDivider
                
                // CPU Threads
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "cpu")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        Text("CPU Threads")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(settings.numThreads.map { "\($0)" } ?? "Auto")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.1), in: Capsule())
                    }
                    Slider(value: Binding(
                        get: { Double(settings.numThreads ?? 0) },
                        set: { settings.numThreads = Int($0) == 0 ? nil : Int($0) }
                    ), in: 0...32, step: 1)
                        .tint(.orange)
                    Text(ReMapProcessingSettings.tooltip(for: "num_threads"))
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
        }
    }
    
    // MARK: - Colorspace Section
    
    private var colorspaceSection: some View {
        settingsCard(
            section: .colorspace,
            icon: "paintpalette",
            iconColor: .purple,
            title: "Colorspace",
            subtitle: settings.colorspaceEnabled
                ? "\(settings.inputColorspace.label) → \(settings.outputColorspace.label)"
                : "Disabled"
        ) {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.purple)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Conversion")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Text("Convert images between colorspaces during processing.")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    Spacer()
                    Toggle("", isOn: $settings.colorspaceEnabled)
                        .tint(.purple)
                        .labelsHidden()
                }
                
                if settings.colorspaceEnabled {
                    rowDivider
                    
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.caption)
                            .foregroundStyle(.purple)
                            .frame(width: 20)
                        Text("Input")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("", selection: $settings.inputColorspace) {
                            ForEach(ReMapColorspace.allCases) { cs in
                                Text(cs.label).tag(cs)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.purple)
                    }
                    
                    rowDivider
                    
                    HStack {
                        Image(systemName: "circle.righthalf.filled")
                            .font(.caption)
                            .foregroundStyle(.purple)
                            .frame(width: 20)
                        Text("Output")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("", selection: $settings.outputColorspace) {
                            ForEach(ReMapColorspace.allCases) { cs in
                                Text(cs.label).tag(cs)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.purple)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    settings = ReMapProcessingSettings()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                }
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
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
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showSavedFeedback = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showSavedFeedback = false
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save Defaults")
                }
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [.cyan.opacity(0.8), .blue.opacity(0.6)], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Saved Banner
    
    private var savedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Defaults saved")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 16)
    }
    
    // MARK: - Settings Card
    
    private func settingsCard<Content: View>(
        section: SettingsSection,
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    expandedSection = expandedSection == section ? nil : section
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(iconColor)
                        .frame(width: 28, height: 28)
                        .background(iconColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expandedSection == section ? 90 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expandable content
            if expandedSection == section {
                VStack(spacing: 0) {
                    Divider().background(.white.opacity(0.08))
                    
                    content()
                        .padding(14)
                }
                .transition(.opacity)
            }
        }
        .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    expandedSection == section ? iconColor.opacity(0.25) : .white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Picker Row
    
    private func pickerRow(icon: String, title: String, tooltip: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.cyan)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Picker("", selection: selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(.cyan)
            }
            if !tooltip.isEmpty {
                Text(ReMapProcessingSettings.tooltip(for: tooltip))
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
    }
    
    private func pickerRowColored(icon: String, title: String, tooltip: String, color: Color, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Picker("", selection: selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(color)
            }
            if !tooltip.isEmpty {
                Text(ReMapProcessingSettings.tooltip(for: tooltip))
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
    }
    
    // MARK: - Divider
    
    private var rowDivider: some View {
        Divider().background(.white.opacity(0.06))
    }
}
