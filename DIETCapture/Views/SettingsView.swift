// SettingsView.swift
// DIETCapture
//
// Settings screen: resolution, framerate, format, white balance, export options, presets.

import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: CaptureViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Capture Format
                Section("Capture Format") {
                    // Photo Format
                    Picker("Photo Format", selection: $viewModel.settings.camera.photoFormat) {
                        ForEach(PhotoFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    
                    // Video Codec
                    Picker("Video Codec", selection: $viewModel.settings.camera.videoCodec) {
                        ForEach(VideoCodec.allCases) { codec in
                            Text(codec.rawValue).tag(codec)
                        }
                    }
                    
                    // Depth Export Format
                    Picker("Depth Format", selection: $viewModel.settings.camera.depthExportFormat) {
                        ForEach(DepthExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                }
                
                // MARK: - Framerate
                Section("Framerate") {
                    Picker("Target FPS", selection: Binding(
                        get: { viewModel.settings.camera.targetFramerate },
                        set: { viewModel.camera.setFrameRate($0) }
                    )) {
                        ForEach(FrameratePreset.common) { preset in
                            Text(preset.label).tag(preset.fps)
                        }
                    }
                }
                
                // MARK: - White Balance
                Section("White Balance") {
                    Picker("Mode", selection: Binding(
                        get: { viewModel.camera.settings.whiteBalanceMode },
                        set: { viewModel.camera.setWhiteBalanceMode($0) }
                    )) {
                        ForAll(WhiteBalanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if viewModel.camera.settings.whiteBalanceMode == .manual {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Temperature")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(viewModel.camera.settings.whiteBalance.temperature))K")
                                    .font(.system(.caption, design: .monospaced))
                            }
                            Slider(
                                value: $viewModel.camera.settings.whiteBalance.temperature,
                                in: WhiteBalanceValues.temperatureRange,
                                step: 100
                            ) {
                                Text("Temperature")
                            }
                            .tint(
                                LinearGradient(
                                    colors: [.blue, .white, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .onChange(of: viewModel.camera.settings.whiteBalance.temperature) { _, newValue in
                                viewModel.camera.updateWhiteBalance(
                                    temperature: newValue,
                                    tint: viewModel.camera.settings.whiteBalance.tint
                                )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Tint")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(viewModel.camera.settings.whiteBalance.tint))")
                                    .font(.system(.caption, design: .monospaced))
                            }
                            Slider(
                                value: $viewModel.camera.settings.whiteBalance.tint,
                                in: WhiteBalanceValues.tintRange,
                                step: 1
                            ) {
                                Text("Tint")
                            }
                            .tint(
                                LinearGradient(
                                    colors: [.green, .gray, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .onChange(of: viewModel.camera.settings.whiteBalance.tint) { _, newValue in
                                viewModel.camera.updateWhiteBalance(
                                    temperature: viewModel.camera.settings.whiteBalance.temperature,
                                    tint: newValue
                                )
                            }
                        }
                    }
                }
                
                // MARK: - LiDAR Export
                Section("LiDAR Export") {
                    Toggle("Export Point Clouds", isOn: $viewModel.settings.lidar.exportPointClouds)
                    Toggle("Export Mesh (OBJ)", isOn: $viewModel.settings.lidar.exportMesh)
                }
                
                // MARK: - Metadata
                Section("Metadata Export") {
                    Toggle("Camera Poses", isOn: $viewModel.settings.exportPoses)
                    Toggle("Camera Intrinsics", isOn: $viewModel.settings.exportIntrinsics)
                    Toggle("COLMAP Format", isOn: $viewModel.settings.exportCOLMAP)
                    Toggle("Geotagging", isOn: $viewModel.settings.geotagging)
                }
                
                // MARK: - Device Info
                Section("Device Capabilities") {
                    LabeledContent("Device", value: viewModel.camera.capabilities.deviceName)
                    LabeledContent("LiDAR", value: viewModel.camera.capabilities.hasLiDAR ? "✅" : "❌")
                    LabeledContent("ProRAW", value: viewModel.camera.capabilities.hasProRAW ? "✅" : "❌")
                    LabeledContent("Available Lenses") {
                        Text(viewModel.camera.capabilities.availableLenses.map(\.rawValue).joined(separator: ", "))
                            .font(.caption)
                    }
                    LabeledContent("Depth Resolution") {
                        Text(viewModel.lidar.depthResolution)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                
                // MARK: - Presets
                Section("Presets") {
                    Button {
                        applyPreset(.highQuality)
                    } label: {
                        Label("High Quality (Slow)", systemImage: "star.fill")
                    }
                    
                    Button {
                        applyPreset(.balanced)
                    } label: {
                        Label("Balanced", systemImage: "star.leadinghalf.filled")
                    }
                    
                    Button {
                        applyPreset(.performance)
                    } label: {
                        Label("Performance (Fast)", systemImage: "hare.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Presets
    
    enum Preset {
        case highQuality, balanced, performance
    }
    
    func applyPreset(_ preset: Preset) {
        switch preset {
        case .highQuality:
            viewModel.settings.camera.photoFormat = .proRAW
            viewModel.settings.camera.depthExportFormat = .exr
            viewModel.settings.camera.targetFramerate = 30
            viewModel.settings.lidar.confidenceThreshold = .high
            viewModel.settings.lidar.smoothingEnabled = true
            viewModel.settings.lidar.exportPointClouds = true
            viewModel.settings.lidar.exportMesh = true
            
        case .balanced:
            viewModel.settings.camera.photoFormat = .heif
            viewModel.settings.camera.depthExportFormat = .png16
            viewModel.settings.camera.targetFramerate = 30
            viewModel.settings.lidar.confidenceThreshold = .medium
            viewModel.settings.lidar.smoothingEnabled = true
            viewModel.settings.lidar.exportPointClouds = true
            viewModel.settings.lidar.exportMesh = false
            
        case .performance:
            viewModel.settings.camera.photoFormat = .jpeg
            viewModel.settings.camera.depthExportFormat = .png16
            viewModel.settings.camera.targetFramerate = 60
            viewModel.settings.lidar.confidenceThreshold = .low
            viewModel.settings.lidar.smoothingEnabled = false
            viewModel.settings.lidar.exportPointClouds = false
            viewModel.settings.lidar.exportMesh = false
        }
    }
}

// Workaround: ForAll to avoid ambiguity with SwiftUI's ForEach
struct ForAll<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        ForEach(Array(data), id: \.id) { element in
            content(element)
        }
    }
}
