// ViewfinderView.swift
// ReScan
//
// Main capture screen: ARKit preview, pass viewer, collapsible controls, record button.

import SwiftUI

struct ViewfinderView: View {
    @Bindable var viewModel: CaptureViewModel
    
    // Shared CIContext for efficient rendering
    private static let ciContext = CIContext()

    @State private var showControls = false
    @State private var previewImage: UIImage?
    @State private var refreshTimer: Timer?
    @State private var depthHistogramBins: [Float] = []
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Status Bar
                StatusBarView(
                    trackingState: viewModel.lidar.trackingStateString,
                    trackingColor: viewModel.lidar.trackingStateColor,
                    isRecording: viewModel.isRecording,
                    elapsedTime: viewModel.elapsedTimeString,
                    frameCount: viewModel.frameCountString,
                    batteryPercent: viewModel.batteryPercentage,
                    storageMB: viewModel.storageAvailableMB,
                    thermalState: viewModel.thermalState
                )
                .padding(.top, 4)
                
                // MARK: - Viewfinder with Pass Viewer
                ZStack {
                    // Live Preview (from ARKit)
                    if let image = previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(white: 0.1))
                            .overlay {
                                ProgressView()
                                    .tint(.cyan)
                            }
                    }
                    
                    // Mesh Overlay (when viewing mesh, or ghost mesh over RGB)
                    if viewModel.lidar.viewMode == .mesh || (viewModel.lidar.viewMode == .rgb && viewModel.lidar.ghostMeshEnabled) {
                        ARMeshOverlayView(session: viewModel.lidar.arService.arSession)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .allowsHitTesting(false) // Let touches pass through
                    }
                    
                    // Pass viewer buttons (top-right)
                    VStack {
                        HStack {
                            Spacer()
                            passViewerButtons
                        }
                        .padding(12)
                        
                        Spacer()
                        
                        // Depth histogram (when viewing depth)
                        if viewModel.lidar.viewMode == .depth && !depthHistogramBins.isEmpty {
                            DepthHistogramView(bins: depthHistogramBins, maxDepth: viewModel.settings.lidar.maxDistance)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 4)
                        }
                        
                        // Depth legend (when viewing depth)
                        if viewModel.lidar.viewMode == .depth {
                            depthLegend
                                .padding(8)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxHeight: .infinity)
                
                // MARK: - Bottom Bar
                captureControls
                    .padding(.bottom, 4)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            viewModel.setup()
            startPreviewRefresh()
        }
        .onDisappear {
            viewModel.teardown()
            refreshTimer?.invalidate()
        }
        .sheet(isPresented: $showControls) {
            GlassSettingsSheet(cameraVM: viewModel.camera, lidarVM: viewModel.lidar)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
        .alert("Notice", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.showError = false }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Pass Viewer Buttons
    
    private var passViewerButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ViewMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.lidar.viewMode = mode
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.caption2)
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.lidar.viewMode == mode
                                ? AnyShapeStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .foregroundStyle(viewModel.lidar.viewMode == mode ? .white : .secondary)
                        .clipShape(Capsule())
                    }
                }
                
                // Ghost Mesh toggle (only meaningful in RGB mode)
                if viewModel.lidar.viewMode == .rgb {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.lidar.ghostMeshEnabled.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "move.3d")
                                .font(.caption2)
                            Text("Ghost")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.lidar.ghostMeshEnabled
                                ? AnyShapeStyle(LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .foregroundStyle(viewModel.lidar.ghostMeshEnabled ? .white : .secondary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - Depth Legend
    
    private var depthLegend: some View {
        HStack(spacing: 4) {
            Text("0m")
                .font(.system(size: 9, design: .monospaced))
            LinearGradient(
                colors: [.blue, .cyan, .green, .yellow, .red],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: 80, height: 6)
            .clipShape(Capsule())
            Text("\(viewModel.settings.lidar.maxDistance, specifier: "%.1f")m")
                .font(.system(size: 9, design: .monospaced))
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    // MARK: - Capture Controls
    
    private var captureControls: some View {
        HStack(spacing: 20) {
            // Controls toggle
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showControls.toggle()
                }
            } label: {
                Image(systemName: showControls ? "slider.horizontal.below.square.and.square.filled" : "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(showControls ? .cyan : .white)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            Spacer()
            
            // Record button
            Button {
                if viewModel.isRecording || viewModel.isWaitingForMesh {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
                hapticFeedback()
            } label: {
                ZStack {
                    // Outer ring
                    Circle()
                        .strokeBorder(
                            viewModel.isRecording
                                ? LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom)
                                : viewModel.isWaitingForMesh
                                    ? LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.white, .gray], startPoint: .top, endPoint: .bottom),
                            lineWidth: 4
                        )
                        .frame(width: 76, height: 76)
                    
                    // Inner shape
                    if viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom))
                            .frame(width: 30, height: 30)
                    } else if viewModel.isWaitingForMesh {
                        // Pulsing hourglass while waiting for mesh
                        Image(systemName: "hourglass")
                            .font(.title2)
                            .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                    } else {
                        Circle()
                            .fill(LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 62, height: 62)
                            .shadow(color: .red.opacity(0.4), radius: 8)
                    }
                }
            }
            
            Spacer()
            
            // Status / saving indicator
            if viewModel.isSaving {
                ProgressView()
                    .tint(.cyan)
                    .frame(width: 48, height: 48)
            } else {
                Color.clear.frame(width: 48, height: 48)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    
    // MARK: - Preview Refresh
    
    private func startPreviewRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            updatePreview()
        }
    }
    
    private func updatePreview() {
        if viewModel.lidar.viewMode == .rgb {
            // Show ARKit captured image — landscape buffer, rotate to portrait
            if let buffer = viewModel.lidar.currentCapturedImage {
                previewImage = imageFromPixelBuffer(buffer, orientation: .right)
            }
        } else {
            // Show depth/confidence overlay — also landscape buffer, same rotation
            if let buffer = viewModel.lidar.generateViewBuffer() {
                previewImage = imageFromPixelBuffer(buffer, orientation: .right)
            }
        }
        
        // Compute depth histogram for the histogram overlay
        if viewModel.lidar.viewMode == .depth, let depth = viewModel.lidar.currentDepthMap {
            let maxDist = viewModel.settings.lidar.maxDistance
            depthHistogramBins = DepthMapProcessor.depthHistogram(depth, maxDepth: maxDist, binCount: 32)
        } else if !depthHistogramBins.isEmpty {
            depthHistogramBins = []
        }
    }
    
    private func imageFromPixelBuffer(_ buffer: CVPixelBuffer, orientation: UIImage.Orientation = .right) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        // Reuse shared CIContext to avoid expensive initialization
        guard let cgImage = Self.ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
    
    // MARK: - Haptic
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Depth Histogram Overlay

struct DepthHistogramView: View {
    let bins: [Float]
    let maxDepth: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                ForEach(0..<bins.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: i))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(2, CGFloat(bins[i]) * 40))
                }
            }
            .frame(height: 44)
            .animation(.easeOut(duration: 0.15), value: bins)
            
            HStack {
                Text("0m")
                    .font(.system(size: 8, design: .monospaced))
                Spacer()
                Text("Depth Distribution")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                Spacer()
                Text(String(format: "%.1fm", maxDepth))
                    .font(.system(size: 8, design: .monospaced))
            }
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
    
    private func barColor(for index: Int) -> Color {
        let t = Double(index) / Double(max(1, bins.count - 1))
        return Color(hue: (1 - t) * 0.66, saturation: 0.9, brightness: 0.9)
    }
}
