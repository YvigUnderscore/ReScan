// ExposureControlsView.swift
// DIETCapture
//
// Shutter speed, ISO, EV sliders and exposure mode selector.

import SwiftUI

struct ExposureControlsView: View {
    @Bindable var viewModel: CameraViewModel
    
    @State private var isExpanded = true
    
    var body: some View {
        ControlPanelView(title: "Exposition", icon: "sun.max.fill", isExpanded: $isExpanded) {
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
                
                // Shutter Speed
                ParameterSliderView(
                    label: "Shutter",
                    value: Binding(
                        get: { viewModel.shutterSliderValue },
                        set: { viewModel.updateShutterSpeed(sliderValue: $0) }
                    ),
                    displayValue: viewModel.shutterSpeedDisplay,
                    isEnabled: viewModel.settings.exposureMode == .manual
                )
                
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
    
    @State private var isExpanded = true
    
    var body: some View {
        ControlPanelView(title: "Focus", icon: "scope", isExpanded: $isExpanded) {
            VStack(spacing: 12) {
                // Focus Mode
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
                
                // Manual Focus Slider
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
    
    @State private var isExpanded = true
    
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
                
                // Confidence Threshold
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
                
                // Smooth Depth Toggle
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
                
                // Overlay Mode
                HStack {
                    Text("Overlay")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Overlay", selection: Binding(
                        get: { viewModel.settings.overlayMode },
                        set: { viewModel.setOverlayMode($0) }
                    )) {
                        ForEach(DepthOverlayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 250)
                }
                
                // Overlay Opacity (only if overlay is active)
                if viewModel.settings.overlayMode != .none {
                    HStack {
                        Text("Opacity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Slider(
                            value: Binding(
                                get: { viewModel.settings.overlayOpacity },
                                set: { viewModel.setOverlayOpacity($0) }
                            ),
                            in: 0...1,
                            step: 0.05
                        )
                        .tint(.cyan)
                        
                        Text("\(Int(viewModel.settings.overlayOpacity * 100))%")
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                
                // Depth Info
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

// MARK: - Lens Selector

struct LensSelectorView: View {
    @Bindable var viewModel: CameraViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.capabilities.availableLenses) { lens in
                Button {
                    viewModel.selectLens(lens)
                } label: {
                    Text(lens.rawValue)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.settings.selectedLens == lens
                            ? AnyShapeStyle(.white)
                            : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .foregroundStyle(
                            viewModel.settings.selectedLens == lens ? .black : .white
                        )
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            // Zoom indicator
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.caption2)
                Text(viewModel.zoomDisplay)
                    .font(.system(.caption, design: .monospaced))
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}

// MARK: - Reusable Components

struct ControlPanelView<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
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
            
            // Content
            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

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
