// SettingsView.swift
// ReScan
//
// Global app settings for export formats, resolution, capture FPS, encoding, defaults.

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    
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
                        .disabled(!supportsAppleLog || settings.captureEXR)
                        
                    Toggle("EXR Sequence", isOn: $settings.captureEXR)
                        .tint(.purple)
                } header: {
                    Text("Color & Encoding")
                } footer: {
                    if settings.captureEXR {
                        Text("Captures individual EXR frames instead of a video. EXR files are saved in extended linear sRGB space using half-float precision.\n\n⚠️ EXR sequences consume extreme amounts of storage and memory.")
                    } else if !supportsAppleLog {
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
                } header: {
                    Text("LiDAR Defaults")
                } footer: {
                    Text("Confidence controls the minimum quality threshold for depth measurements.\n\n• Low: Keeps all depth measurements, including uncertain ones. Maximum coverage but may include noise.\n• Medium (Recommended): Good balance between coverage and accuracy. Filters out the least reliable points.\n• High: Only keeps the most reliable depth measurements. Best accuracy but may have gaps in coverage.\n\nSmooth Depth applies temporal smoothing across frames to reduce noise and flickering in the depth map.")
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
                        Text(settings.captureEXR ? "None (EXR Sequence)" : (settings.useAppleLog && supportsAppleLog ? "ProRes 422 HQ" : (settings.enableHDR ? "HDR HEVC" : "HEVC")))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Directory Structure")
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if settings.captureEXR {
                            Text("• rgb/ (EXR 16-bit float)").font(.caption).foregroundStyle(.secondary)
                        } else {
                            let ext = (settings.useAppleLog && supportsAppleLog) ? "mov" : "mp4"
                            Text("• rgb.\(ext) (\(settings.useAppleLog && supportsAppleLog ? "ProRes 422 HQ, Apple Log" : (settings.enableHDR ? "HDR HEVC" : "HEVC")))").font(.caption).foregroundStyle(.secondary)
                        }
                        Text("• camera_matrix.csv").font(.caption).foregroundStyle(.secondary)
                        Text("• odometry.csv").font(.caption).foregroundStyle(.secondary)
                        Text("• depth/ (16-bit PNG mm)").font(.caption).foregroundStyle(.secondary)
                        Text("• confidence/ (8-bit PNG)").font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Export Options")
                } footer: {
                    Text("ReScan natively exports to the Stray Scanner format, ready for strayscanner-to-colmap processing.")
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
        }
        .preferredColorScheme(.dark)
    }
}
