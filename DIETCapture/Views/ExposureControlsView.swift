// ExposureControlsView.swift
// ReScan
//
// Frosted glass settings panels — Exposure, Focus, LiDAR controls.

import SwiftUI

// MARK: - Glass Settings Sheet

struct GlassSettingsSheet: View {
    @Bindable var cameraVM: CameraViewModel
    @Bindable var lidarVM: LiDARViewModel
    
    @State private var activeSection: SettingsSection = .exposure
    
    enum SettingsSection: String, CaseIterable {
        case exposure = "Exposure"
        case focus = "Focus"
        case lidar = "LiDAR"
        
        var icon: String {
            switch self {
            case .exposure: return "sun.max.fill"
            case .focus: return "scope"
            case .lidar: return "sensor.tag.radiowaves.forward.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)
            
            // Section picker
            HStack(spacing: 4) {
                ForEach(SettingsSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            activeSection = section
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: section.icon)
                                .font(.system(size: 10))
                            Text(section.rawValue)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            activeSection == section
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [.cyan.opacity(0.5), .blue.opacity(0.4)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                  ))
                                : AnyShapeStyle(Color.white.opacity(0.05))
                        )
                        .foregroundStyle(activeSection == section ? .white : .secondary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 14)
            
            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    switch activeSection {
                    case .exposure:
                        ExposureControlsView(viewModel: cameraVM)
                    case .focus:
                        FocusControlsView(viewModel: cameraVM)
                    case .lidar:
                        LiDARControlsView(viewModel: lidarVM)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 36) // Increased bottom padding to prevent overflow
            }
        }
        .background(
            ZStack {
                // Glass effect background
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.clear,
                                Color.cyan.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Subtle border
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .white.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .preferredColorScheme(.dark)
    }
}

// MARK: - Exposure Controls

struct ExposureControlsView: View {
    @Bindable var viewModel: CameraViewModel
    
    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                // Mode Toggle
                HStack {
                    Text("Mode")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Mode", selection: Binding(
                        get: { viewModel.settings.exposureMode },
                        set: { viewModel.setExposureMode($0) }
                    )) {
                        ForEach(ExposureMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
                
                // Shutter Presets (Manual only)
                if viewModel.settings.exposureMode == .manual {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Shutter", systemImage: "timer")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(viewModel.shutterSpeedDisplay)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.cyan)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(ShutterSpeedPreset.presets) { preset in
                                    GlassPill(
                                        label: preset.label,
                                        isSelected: viewModel.selectedShutterPreset?.id == preset.id
                                    ) {
                                        viewModel.setShutterPreset(preset)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ISO
                GlassSlider(
                    label: "ISO",
                    icon: "camera.aperture",
                    value: Binding(
                        get: { viewModel.isoSliderValue },
                        set: { viewModel.updateISO(sliderValue: $0) }
                    ),
                    displayValue: viewModel.isoDisplay,
                    isEnabled: viewModel.settings.exposureMode == .manual
                )
                
                // EV
                GlassSlider(
                    label: "EV",
                    icon: "plusminus",
                    value: Binding(
                        get: { viewModel.evSliderValue },
                        set: { viewModel.updateEV(sliderValue: $0) }
                    ),
                    displayValue: viewModel.evDisplay,
                    isEnabled: viewModel.settings.exposureMode == .auto
                )
            }
        }
    }
}

// MARK: - Focus Controls

struct FocusControlsView: View {
    @Bindable var viewModel: CameraViewModel
    
    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack {
                    Text("Mode")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Mode", selection: Binding(
                        get: { viewModel.settings.focusMode },
                        set: { viewModel.setFocusMode($0) }
                    )) {
                        ForEach(FocusMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
                
                GlassSlider(
                    label: "Position",
                    icon: "target",
                    value: Binding(
                        get: { viewModel.focusSliderValue },
                        set: { viewModel.updateFocus(sliderValue: $0) }
                    ),
                    displayValue: viewModel.focusDisplay,
                    isEnabled: viewModel.settings.focusMode == .manual
                )
            }
        }
    }
}

// MARK: - LiDAR Controls

struct LiDARControlsView: View {
    @Bindable var viewModel: LiDARViewModel
    
    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                // Max Distance
                GlassSlider(
                    label: "Max Dist",
                    icon: "ruler",
                    value: Binding(
                        get: {
                            let range = LiDARSettings.distanceRange
                            return Float((viewModel.settings.maxDistance - range.lowerBound) / (range.upperBound - range.lowerBound))
                        },
                        set: {
                            let range = LiDARSettings.distanceRange
                            let dist = range.lowerBound + Float($0) * (range.upperBound - range.lowerBound)
                            viewModel.updateMaxDistance(dist)
                        }
                    ),
                    displayValue: "\(viewModel.settings.maxDistance.formatted(decimals: 1))m",
                    isEnabled: true
                )
                
                // Confidence
                HStack {
                    Text("Confidence")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Confidence", selection: Binding(
                        get: { viewModel.settings.confidenceThreshold },
                        set: { viewModel.updateConfidenceThreshold($0) }
                    )) {
                        ForEach(ConfidenceThreshold.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
                
                // Smoothing
                HStack {
                    Label("Smoothing", systemImage: "waveform.path")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { viewModel.settings.smoothingEnabled },
                        set: { viewModel.toggleSmoothing($0) }
                    ))
                    .labelsHidden()
                    .tint(.cyan)
                }
                
                // Resolution
                HStack {
                    Label("Depth Res", systemImage: "square.resize")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.7))
                    Spacer()
                    Text(viewModel.depthResolution)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
        }
    }
}

// MARK: - Glass Components

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.04))
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.1), .white.opacity(0.03)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
    }
}

struct GlassPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(minWidth: 44) // Improve tap target
                .contentShape(Rectangle()) // Ensure entire area is clickable
                .background(
                    isSelected
                        ? AnyShapeStyle(LinearGradient(
                            colors: [.cyan.opacity(0.6), .blue.opacity(0.5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                          ))
                        : AnyShapeStyle(Color.white.opacity(0.06))
                )
                .foregroundStyle(isSelected ? .white : .secondary)
                .clipShape(Capsule())
                .overlay(
                    isSelected
                        ? Capsule().strokeBorder(.cyan.opacity(0.3), lineWidth: 0.5)
                        : Capsule().strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain) // Prevent ScrollView from eating touches
    }
}

struct GlassSlider: View {
    let label: String
    let icon: String
    @Binding var value: Float
    let displayValue: String
    var isEnabled: Bool = true
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isEnabled ? Color.secondary : Color.secondary.opacity(0.4))
                Spacer()
                Text(displayValue)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isEnabled ? Color.cyan : Color.secondary.opacity(0.4))
            }
            
            Slider(value: $value, in: 0...1)
                .tint(
                    LinearGradient(
                        colors: [.cyan.opacity(0.8), .blue.opacity(0.6)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.35)
        }
    }
}
