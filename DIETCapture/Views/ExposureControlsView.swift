// ExposureControlsView.swift
// ReScan
//
// Shutter presets, ISO slider, EV slider, focus, LiDAR controls.

import SwiftUI

struct ExposureControlsView: View {
    @Bindable var viewModel: CameraViewModel
    
    @State private var isExpanded = true
    
    var body: some View {
        ControlPanelView(title: "Exposure", icon: "sun.max.fill", isExpanded: $isExpanded) {
            VStack(spacing: 12) {
                // Exposure Mode
                HStack {
                    Text("Mode")
                        .font(.caption)
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
                    .frame(maxWidth: 220)
                }
                
                // Shutter Speed Presets
                if viewModel.settings.exposureMode == .manual {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Shutter")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(viewModel.shutterSpeedDisplay)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.cyan)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(ShutterSpeedPreset.presets) { preset in
                                    Button {
                                        viewModel.setShutterPreset(preset)
                                    } label: {
                                        Text(preset.label)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                viewModel.selectedShutterPreset?.id == preset.id
                                                    ? AnyShapeStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                                                    : AnyShapeStyle(Color.white.opacity(0.08))
                                            )
                                            .foregroundStyle(
                                                viewModel.selectedShutterPreset?.id == preset.id ? .white : .secondary
                                            )
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ISO
                ParameterSliderView(
                    label: "ISO",
                    value: Binding(
                        get: { viewModel.isoSliderValue },
                        set: { viewModel.updateISO(sliderValue: $0) }
                    ),
                    displayValue: viewModel.isoDisplay,
                    isEnabled: viewModel.settings.exposureMode == .manual
                )
                
                // EV Compensation
                ParameterSliderView(
                    label: "EV",
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
    @State private var isExpanded = false
    
    var body: some View {
        ControlPanelView(title: "Focus", icon: "scope", isExpanded: $isExpanded) {
            VStack(spacing: 12) {
                HStack {
                    Picker("Focus", selection: Binding(
                        get: { viewModel.settings.focusMode },
                        set: { viewModel.setFocusMode($0) }
                    )) {
                        ForEach(FocusMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                ParameterSliderView(
                    label: "Position",
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
    @State private var isExpanded = false
    
    var body: some View {
        ControlPanelView(title: "LiDAR", icon: "sensor.tag.radiowaves.forward.fill", isExpanded: $isExpanded) {
            VStack(spacing: 12) {
                // Max Distance
                HStack {
                    Text("Max Dist")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { viewModel.settings.maxDistance },
                            set: { viewModel.updateMaxDistance($0) }
                        ),
                        in: LiDARSettings.distanceRange,
                        step: 0.1
                    )
                    .tint(.cyan)
                    Text("\(viewModel.settings.maxDistance, specifier: "%.1f")m")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 45, alignment: .trailing)
                }
                
                // Confidence
                HStack {
                    Text("Confid.")
                        .font(.caption)
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
                
                // Smooth
                HStack {
                    Text("Smooth")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { viewModel.settings.smoothingEnabled },
                        set: { viewModel.toggleSmoothing($0) }
                    ))
                    .labelsHidden()
                    .tint(.cyan)
                }
                
                // Resolution info
                HStack {
                    Text("Resolution: \(viewModel.depthResolution)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Reusable ControlPanel

struct ControlPanelView<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Parameter Slider

struct ParameterSliderView: View {
    let label: String
    @Binding var value: Float
    let displayValue: String
    var isEnabled: Bool = true
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .leading)
            Slider(value: $value, in: 0...1)
                .tint(.cyan)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.4)
            Text(displayValue)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(isEnabled ? .primary : .secondary)
        }
    }
}
