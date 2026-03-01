// SettingsView.swift
// ReScan
//
// Global app settings for export formats, resolution, capture FPS, encoding, defaults.

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var storageManager = SecurityScopedStorageManager.shared
    
    @State private var showFileImporter = false
    @State private var expandedSection: SettingsSection? = .capture
    
    private var supportsAppleLog: Bool {
        ExportService.supportsAppleLog
    }
    
    private enum SettingsSection: String, CaseIterable {
        case capture = "Capture"
        case lidar = "LiDAR"
        case encoding = "Encoding"
        case storage = "Storage"
        case remap = "ReMap"
        case export = "Export"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        captureSection
                        lidarSection
                        encodingSection
                        storageSection
                        remapSection
                        exportSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let selectedUrl = urls.first else { return }
                    storageManager.saveExternalURL(selectedUrl)
                case .failure(let error):
                    print("Error selecting folder: \(error.localizedDescription)")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Capture Section
    
    private var captureSection: some View {
        let resLabel = settings.videoResolution.rawValue
        let fpsLabel = settings.captureFPS.label
        
        return settingsCard(
            section: .capture,
            icon: "video.fill",
            iconColor: .cyan,
            title: "Capture",
            subtitle: "\(resLabel) · \(fpsLabel)"
        ) {
            VStack(spacing: 14) {
                // Resolution
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "rectangle.dashed")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                            .frame(width: 20)
                        Text("Resolution")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("", selection: $settings.videoResolution) {
                            ForEach(availableResolutions) { res in
                                Text(res.rawValue).tag(res)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.cyan)
                    }
                    if !settings.lidarEnabled {
                        Text("4K available when LiDAR is disabled.")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                }
                
                rowDivider
                
                // Capture FPS
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "speedometer")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                            .frame(width: 20)
                        Text("Capture FPS")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("", selection: $settings.captureFPS) {
                            ForEach(AppSettings.CaptureFPS.allCases) { fps in
                                Text(fps.label).tag(fps)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.cyan)
                    }
                    Text("Frames saved per second. ARKit runs at 30fps internally for tracking. Lower FPS = smaller files.")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
        }
    }
    
    private var availableResolutions: [AppSettings.VideoResolution] {
        if settings.lidarEnabled {
            return [.high]
        } else {
            return AppSettings.VideoResolution.allCases
        }
    }
    
    // MARK: - LiDAR Section
    
    private var lidarSection: some View {
        settingsCard(
            section: .lidar,
            icon: "sensor.tag.radiowaves.forward.fill",
            iconColor: .green,
            title: "LiDAR",
            subtitle: settings.lidarEnabled ? "Enabled · \(String(format: "%.1f", settings.defaultMaxDistance))m" : "Disabled"
        ) {
            VStack(spacing: 14) {
                // LiDAR Toggle
                HStack {
                    Image(systemName: "sensor.tag.radiowaves.forward")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable LiDAR")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Text("When disabled, Depth, Confidence and Mesh are not captured. 4K becomes available.")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    Spacer()
                    Toggle("", isOn: $settings.lidarEnabled)
                        .tint(.green)
                        .labelsHidden()
                }
                
                if settings.lidarEnabled {
                    rowDivider
                    
                    // Max Distance
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "ruler")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .frame(width: 20)
                            Text("Max Distance")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(settings.defaultMaxDistance, specifier: "%.1f")m")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.green.opacity(0.1), in: Capsule())
                        }
                        Slider(value: $settings.defaultMaxDistance, in: 0.5...5.0, step: 0.1)
                            .tint(.green)
                    }
                    
                    rowDivider
                    
                    // Confidence
                    HStack {
                        Image(systemName: "waveform.path")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        Text("Confidence")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("", selection: $settings.defaultConfidence) {
                            Text("Low").tag(0)
                            Text("Medium").tag(1)
                            Text("High").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                    
                    Text("Low = max coverage with noise. Medium = balanced. High = most accurate but may have gaps.")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.6))
                    
                    rowDivider
                    
                    // Smooth Depth
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smooth Depth")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Text("Temporal smoothing to reduce noise and flickering.")
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                        Spacer()
                        Toggle("", isOn: $settings.defaultSmoothing)
                            .tint(.green)
                            .labelsHidden()
                    }
                    
                    rowDivider
                    
                    // Depth Color Map
                    HStack {
                        Image(systemName: "paintpalette")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        Text("Depth Color Map")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("", selection: $settings.depthColorMap) {
                            ForEach(AppSettings.DepthColorMap.allCases) { map in
                                Text(map.rawValue).tag(map)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.green)
                    }
                    
                    rowDivider
                    
                    // Mesh Start Mode
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "play.circle")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .frame(width: 20)
                            Text("Mesh Start")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Spacer()
                            Picker("", selection: $settings.meshStartMode) {
                                ForEach(AppSettings.MeshStartMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.green)
                        }
                        Text("Wait for First Polygons ensures mesh alignment. BruteForce starts immediately.")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    
                    rowDivider
                    
                    // Adaptive Mesh Refinement
                    HStack {
                        Image(systemName: "square.grid.3x3.topleft.filled")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Adaptive Mesh Refinement")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Text("Subdivides triangles in frequently scanned regions and for large polygons.")
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                        Spacer()
                        Toggle("", isOn: $settings.adaptiveMeshRefinement)
                            .tint(.green)
                            .labelsHidden()
                    }
                    
                    if settings.adaptiveMeshRefinement {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .frame(width: 20)
                            Text("Detail Level")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Spacer()
                            Picker("", selection: $settings.meshDetailLevel) {
                                ForEach(MeshDetailLevel.allCases) { level in
                                    Text(level.label).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Encoding Section
    
    private var encodingSection: some View {
        let codecLabel = settings.useAppleLog && supportsAppleLog ? "ProRes 422 HQ" : (settings.enableHDR ? "HDR HEVC" : "HEVC")
        
        return settingsCard(
            section: .encoding,
            icon: "film",
            iconColor: .orange,
            title: "Encoding",
            subtitle: codecLabel + (settings.enableHDR ? " · HDR" : "")
        ) {
            VStack(spacing: 14) {
                // HDR
                HStack {
                    Image(systemName: "sun.max.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HDR")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Text("High Dynamic Range video capture.")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    Spacer()
                    Toggle("", isOn: $settings.enableHDR)
                        .tint(.orange)
                        .labelsHidden()
                }
                
                rowDivider
                
                // Apple Log
                HStack {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(supportsAppleLog ? .orange : .secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Log (ProRes)")
                            .font(.subheadline)
                            .foregroundStyle(supportsAppleLog ? .white : .secondary)
                        if supportsAppleLog {
                            Text("Logarithmic color space with ProRes 422 HQ. ~3.5 GB/min at 2K.")
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.6))
                        } else {
                            Text("⚠️ Requires iPhone 15 Pro or later.")
                                .font(.caption2)
                                .foregroundStyle(.orange.opacity(0.7))
                        }
                    }
                    Spacer()
                    Toggle("", isOn: $settings.useAppleLog)
                        .tint(.orange)
                        .labelsHidden()
                        .disabled(!supportsAppleLog)
                }
            }
        }
    }
    
    // MARK: - Storage Section
    
    private var storageSection: some View {
        settingsCard(
            section: .storage,
            icon: "externaldrive.fill",
            iconColor: .purple,
            title: "Storage",
            subtitle: storageManager.externalStorageURL != nil ? "External connected" : "Internal"
        ) {
            VStack(spacing: 14) {
                if let url = storageManager.externalStorageURL {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Text(url.lastPathComponent)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    
                    Button(role: .destructive) {
                        storageManager.clearExternalURL()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "eject.fill")
                            Text("Disconnect")
                        }
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        showFileImporter = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "externaldrive.badge.plus")
                            Text("Connect External Storage (SSD/USB-C)")
                        }
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.purple.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Text("Required for high-fps EXR sequences.")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
        }
    }
    
    // MARK: - ReMap Section
    
    private var remapSection: some View {
        settingsCard(
            section: .remap,
            icon: "server.rack",
            iconColor: .blue,
            title: "ReMap Server",
            subtitle: settings.remapServerURL.isEmpty ? "Not configured" : "Connected"
        ) {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text("Server URL")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(settings.remapServerURL.isEmpty ? "Not set" : settings.remapServerURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                rowDivider
                
                HStack {
                    Image(systemName: "key.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(KeychainService.shared.read(key: "remapAPIKey") != nil ? "••••••••" : "Not set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text("Configure server connection in the ReMap tab. API key stored in iOS Keychain.")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.6))
                
                rowDivider
                
                // Default Processing
                HStack {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text("Feature Type")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(settings.remapDefaultFeatureType)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
                
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text("Matcher")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(settings.remapDefaultMatcherType)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
                
                HStack {
                    Image(systemName: "speedometer")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text("Default FPS")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(settings.remapDefaultFPS, specifier: "%.1f")")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.blue)
                }
                
                Text("Default processing settings. Override per-job in the ReMap tab.")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        let codecLabel = settings.useAppleLog && supportsAppleLog ? "ProRes 422 HQ" : (settings.enableHDR ? "HDR HEVC" : "HEVC")
        let ext = (settings.useAppleLog && supportsAppleLog) ? "mov" : "mp4"
        
        return settingsCard(
            section: .export,
            icon: "square.and.arrow.up",
            iconColor: .secondary,
            title: "Export Info",
            subtitle: "Stray Scanner · \(codecLabel)"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.zipper")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("Format")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Stray Scanner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                rowDivider
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Directory Structure")
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text("• rgb.\(ext) (\(codecLabel))").font(.caption2).foregroundStyle(.secondary.opacity(0.7))
                    Text("• rgb/ (EXR — via Library)").font(.caption2).foregroundStyle(.secondary.opacity(0.7))
                    Text("• camera_matrix.csv").font(.caption2).foregroundStyle(.secondary.opacity(0.7))
                    Text("• odometry.csv").font(.caption2).foregroundStyle(.secondary.opacity(0.7))
                    if settings.lidarEnabled {
                        Text("• depth/ (16-bit PNG mm)").font(.caption2).foregroundStyle(.secondary.opacity(0.7))
                        Text("• confidence/ (8-bit PNG)").font(.caption2).foregroundStyle(.secondary.opacity(0.7))
                        Text("• mesh.obj").font(.caption2).foregroundStyle(.secondary.opacity(0.7))
                    }
                }
            }
        }
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
    
    // MARK: - Divider
    
    private var rowDivider: some View {
        Divider().background(.white.opacity(0.06))
    }
}
