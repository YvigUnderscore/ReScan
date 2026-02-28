// SettingsView.swift
// ReScan
//
// Global app settings for export formats, resolution, capture FPS, encoding, defaults.

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var storageManager = SecurityScopedStorageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showFileImporter = false
    
    private var supportsAppleLog: Bool {
        ExportService.supportsAppleLog
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Video Recording
                Section {
                    Picker("Resolution", selection: $settings.videoResolution) {
                        ForEach(AppSettings.VideoResolution.allCases) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }

                    Picker("Capture FPS", selection: $settings.captureFPS) {
                        ForEach(AppSettings.CaptureFPS.allCases) { fps in
                            Text(fps.label).tag(fps)
                        }
                    }
                } header: {
                    Text("Video Recording")
                } footer: {
                    Text("The capture FPS controls how many frames are saved per second. ARKit always runs at 30fps internally for accurate LiDAR tracking. Lower FPS = smaller files, useful for photogrammetry workflows.")
                }
                
                // MARK: - Color & Encoding
                Section {
                    Toggle("HDR", isOn: $settings.enableHDR)
                        .tint(.cyan)

                    Toggle("Apple Log (ProRes)", isOn: $settings.useAppleLog)
                        .tint(.orange)
                        .disabled(!supportsAppleLog)
                } header: {
                    Text("Color & Encoding")
                } footer: {
                    if !supportsAppleLog {
                        Text("⚠️ Apple Log requires iPhone 15 Pro or later. This device will use HDR HEVC instead.\n\nApple Log captures in a logarithmic color space with ProRes 422 HQ compression — ideal for color grading to ACEScg or other color spaces without quality loss.")
                    } else {
                        Text("Apple Log captures in a logarithmic color space with ProRes 422 HQ compression — ideal for converting to ACEScg without quality loss.\n\n⚠️ ProRes files are significantly larger (~6 GB/min at 4K).")
                    }
                }
                
                // MARK: - LiDAR Defaults
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
                    
                    Picker("Depth Color Map", selection: $settings.depthColorMap) {
                        ForEach(AppSettings.DepthColorMap.allCases) { map in
                            Text(map.rawValue).tag(map)
                        }
                    }
                    
                    Picker("Mesh Start", selection: $settings.meshStartMode) {
                        ForEach(AppSettings.MeshStartMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    
                    Toggle("Adaptive Mesh Refinement", isOn: $settings.adaptiveMeshRefinement)
                        .tint(.cyan)
                    
                    if settings.adaptiveMeshRefinement {
                        Picker("Mesh Detail Level", selection: $settings.meshDetailLevel) {
                            ForEach(MeshDetailLevel.allCases) { level in
                                Text(level.label).tag(level)
                            }
                        }
                    }
                } header: {
                    Text("LiDAR Defaults")
                } footer: {
                    Text("Confidence controls the minimum quality threshold for depth measurements.\n\n• Low: Keeps all depth measurements, including uncertain ones. Maximum coverage but may include noise.\n• Medium (Recommended): Good balance between coverage and accuracy. Filters out the least reliable points.\n• High: Only keeps the most reliable depth measurements. Best accuracy but may have gaps in coverage.\n\nSmooth Depth applies temporal smoothing across frames to reduce noise and flickering in the depth map.\n\nMesh Start controls when the capture begins after pressing Rec:\n• Wait for First Polygons (default): capture starts only once the ARKit mesh has produced its first geometry, ensuring LiDAR/RGB/odometry are aligned with an active mesh.\n• BruteForce (Instant): capture starts immediately when Rec is pressed.\n\nAdaptive Mesh Refinement progressively enriches the mesh during capture. Regions scanned multiple times receive higher triangle density via subdivision. Detail Level controls the voxel resolution and maximum subdivision depth.")
                }
                
                // MARK: - External Storage
                Section {
                    if let url = storageManager.externalStorageURL {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Storage Location")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(url.lastPathComponent)
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Button(role: .destructive) {
                            storageManager.clearExternalURL()
                        } label: {
                            Text("Disconnect External Storage")
                        }
                    } else {
                        Button {
                            showFileImporter = true
                        } label: {
                            HStack {
                                Image(systemName: "externaldrive.fill")
                                Text("Select External Storage (SSD/USB-C)")
                            }
                        }
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Capture your files directly to an external USB-C drive. Required for high-fps EXR sequences.")
                }
                
                // MARK: - Export Info
                Section {
                    HStack {
                        Text("Format")
                        Spacer()
                        Text("Stray Scanner")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Video Codec")
                        Spacer()
                        Text(settings.useAppleLog && supportsAppleLog ? "ProRes 422 HQ" : (settings.enableHDR ? "HDR HEVC" : "HEVC"))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Directory Structure")
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        let ext = (settings.useAppleLog && supportsAppleLog) ? "mov" : "mp4"
                        Text("• rgb.\(ext) (\(settings.useAppleLog && supportsAppleLog ? "ProRes 422 HQ, Apple Log" : (settings.enableHDR ? "HDR HEVC" : "HEVC")))").font(.caption).foregroundStyle(.secondary)
                        Text("• rgb/ (EXR linear sRGB — via Library conversion)").font(.caption).foregroundStyle(.secondary.opacity(0.7))
                        Text("• camera_matrix.csv").font(.caption).foregroundStyle(.secondary)
                        Text("• odometry.csv").font(.caption).foregroundStyle(.secondary)
                        Text("• depth/ (16-bit PNG mm)").font(.caption).foregroundStyle(.secondary)
                        Text("• confidence/ (8-bit PNG)").font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Export Options")
                } footer: {
                    Text("ReScan natively exports to the Stray Scanner format, ready for strayscanner-to-colmap processing.\n\nEXR (linear sRGB) conversion can be triggered manually from the Library tab after capture.")
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
}
