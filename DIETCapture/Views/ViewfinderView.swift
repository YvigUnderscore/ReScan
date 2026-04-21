// ViewfinderView.swift
// ReScan
//
// Main capture screen: ARKit preview, pass viewer, collapsible controls, record button.

import SwiftUI
import simd

struct ViewfinderView: View {
    @Bindable var viewModel: CaptureViewModel
    
    // Shared CIContext for efficient rendering
    private static let ciContext = CIContext()

    @State private var showControls = false
    @State private var previewImage: UIImage?
    @State private var refreshTimer: Timer?
    @State private var depthHistogramBins: [Float] = []
    @State private var coveragePathPoints: [SIMD2<Float>] = []
    @State private var coverageMeshPoints: [SIMD2<Float>] = []
    @State private var coverageCurrentPoint: SIMD2<Float>?
    @State private var meshUpdateTick: Int = 0
    
    private var shouldShowCoverageMap: Bool {
        AppSettings.shared.lidarEnabled &&
        AppSettings.shared.showRealtimeCoverageMap &&
        (viewModel.isRecording || viewModel.isWaitingForMesh)
    }

    private var coverageDensity: AppSettings.CoverageMapDensity {
        AppSettings.shared.coverageMapDensity
    }
    
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
                .padding(.top, 8)
                
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
                            if shouldShowCoverageMap {
                                CoverageMapOverlayView(
                                    trajectory: coveragePathPoints,
                                    meshPoints: coverageMeshPoints,
                                    currentPoint: coverageCurrentPoint,
                                    mode: AppSettings.shared.coverageMapMode,
                                    density: coverageDensity
                                )
                            }
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
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxHeight: .infinity)
                
                // MARK: - Bottom Bar
                captureControls
                    .padding(.bottom, 12)
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
        let lidarEnabled = AppSettings.shared.lidarEnabled
        let availableModes = lidarEnabled ? ViewMode.allCases : [ViewMode.rgb]
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(availableModes) { mode in
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
                
                // Ghost Mesh toggle (only meaningful in RGB mode with LiDAR enabled)
                if viewModel.lidar.viewMode == .rgb && lidarEnabled {
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
        
        updateCoverageMapData()
    }
    
    private func imageFromPixelBuffer(_ buffer: CVPixelBuffer, orientation: UIImage.Orientation = .right) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        // Reuse shared CIContext to avoid expensive initialization
        guard let cgImage = Self.ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
    
    private func updateCoverageMapData() {
        guard shouldShowCoverageMap else {
            resetCoverageMap()
            return
        }
        let density = coverageDensity
        
        let pose = viewModel.lidar.currentPose
        let translation = pose.columns.3
        let current = SIMD2<Float>(translation.x, translation.z)
        
        if let last = coveragePathPoints.last {
            // Require minimum movement before appending to reduce AR pose jitter,
            // with sensitivity tuned by the selected density.
            if simd_distance(last, current) >= density.pathStepDistance {
                coveragePathPoints.append(current)
            }
        } else {
            coveragePathPoints.append(current)
        }
        
        // Cap trajectory history to keep memory bounded while preserving recent
        // coverage context in the overlay during a recording.
        if coveragePathPoints.count > density.maxTrajectoryPoints {
            coveragePathPoints.removeFirst(coveragePathPoints.count - density.maxTrajectoryPoints)
        }
        
        meshUpdateTick += 1
        // Refresh mesh points at an interval tuned by selected density to balance
        // overlay responsiveness and rendering cost.
        if meshUpdateTick % density.meshRefreshTickInterval == 0 {
            coverageMeshPoints = viewModel.lidar.meshAnchors.prefix(density.maxVisibleMeshAnchors).map { anchor in
                let p = anchor.transform.columns.3
                return SIMD2<Float>(p.x, p.z)
            }
        }
        coverageCurrentPoint = current
    }
    
    private func resetCoverageMap() {
        coveragePathPoints.removeAll(keepingCapacity: true)
        coverageMeshPoints.removeAll(keepingCapacity: true)
        coverageCurrentPoint = nil
        meshUpdateTick = 0
    }
    
    // MARK: - Haptic
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Depth Histogram Overlay

struct CoverageMapOverlayView: View {
    // Prevents divide-by-zero when bounds collapse (all points identical),
    // and avoids extreme scale spikes for near-zero extents.
    private let minimumAxisSpan: Float = 0.001
    private let heatmapMinimumOpacity: Double = 0.12
    private let heatmapOpacityRange: Double = 0.78
    // Keep mesh surface below full opacity so trajectory/current marker remain readable.
    private let meshSurfaceMinimumOpacity: Double = 0.2
    private let meshSurfaceOpacityRange: Double = 0.55
    private let meshSurfaceGridScale: CGFloat = 0.75
    private let meshSurfaceCellCornerRadiusRatio: CGFloat = 0.22
    private let meshSurfaceMinimumGridSize: Int = 8
    
    let trajectory: [SIMD2<Float>]
    let meshPoints: [SIMD2<Float>]
    let currentPoint: SIMD2<Float>?
    let mode: AppSettings.CoverageMapMode
    let density: AppSettings.CoverageMapDensity
    
    var body: some View {
        let bounds = mapBounds(trajectory: trajectory, meshPoints: meshPoints, currentPoint: currentPoint)
        
        VStack(alignment: .leading, spacing: 6) {
            Text("Coverage")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            
            Canvas { context, size in
                guard let bounds else { return }

                switch mode {
                case .trajectoryMesh:
                    if !meshPoints.isEmpty {
                        drawMeshSurface(context: context, size: size, bounds: bounds)
                    }

                    if trajectory.count >= 2 {
                        var path = Path()
                        path.move(to: mapPoint(trajectory[0], bounds: bounds, size: size))
                        for point in trajectory.dropFirst() {
                            path.addLine(to: mapPoint(point, bounds: bounds, size: size))
                        }
                        context.stroke(path, with: .color(.green), lineWidth: 2)
                    }

                    if let current = currentPoint {
                        let mapped = mapPoint(current, bounds: bounds, size: size)
                        let currentRect = CGRect(x: mapped.x - 3, y: mapped.y - 3, width: 6, height: 6)
                        context.fill(Path(ellipseIn: currentRect), with: .color(.white))
                    }

                case .gridHeatmap:
                    drawGridHeatmap(context: context, size: size, bounds: bounds)
                }
            }
            .frame(width: 110, height: 110)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func drawGridHeatmap(
        context: GraphicsContext,
        size: CGSize,
        bounds: (minX: Float, maxX: Float, minY: Float, maxY: Float)
    ) {
        let allPoints = trajectory + meshPoints + (currentPoint.map { [$0] } ?? [])
        guard !allPoints.isEmpty else { return }

        let gridSize = density.heatmapGridSize

        let spanX = max(minimumAxisSpan, bounds.maxX - bounds.minX)
        let spanY = max(minimumAxisSpan, bounds.maxY - bounds.minY)
        let cellW = size.width / CGFloat(gridSize)
        let cellH = size.height / CGFloat(gridSize)
        var counts: [Int: Int] = [:]

        for point in allPoints {
            let normalizedX = (point.x - bounds.minX) / spanX
            let normalizedY = (point.y - bounds.minY) / spanY
            let clampedX = max(0, min(0.999, normalizedX))
            let clampedY = max(0, min(0.999, normalizedY))
            let x = Int(clampedX * Float(gridSize))
            let y = Int(clampedY * Float(gridSize))
            let key = (y * gridSize) + x
            counts[key, default: 0] += 1
        }

        let maxCount = max(1, counts.values.max() ?? 1)
        for (key, count) in counts {
            let x = key % gridSize
            let y = key / gridSize
            let intensity = CGFloat(count) / CGFloat(maxCount)
            let rect = CGRect(
                x: CGFloat(x) * cellW,
                y: CGFloat(y) * cellH,
                width: cellW,
                height: cellH
            )
            context.fill(
                Path(rect),
                with: .color(Color.cyan.opacity(heatmapMinimumOpacity + (heatmapOpacityRange * intensity)))
            )
        }
    }

    private func drawMeshSurface(
        context: GraphicsContext,
        size: CGSize,
        bounds: (minX: Float, maxX: Float, minY: Float, maxY: Float)
    ) {
        let scaledGridSize = Int(Double(density.heatmapGridSize) * Double(meshSurfaceGridScale))
        let gridSize = max(meshSurfaceMinimumGridSize, scaledGridSize)
        let spanX = max(minimumAxisSpan, bounds.maxX - bounds.minX)
        let spanY = max(minimumAxisSpan, bounds.maxY - bounds.minY)
        let cellW = size.width / CGFloat(gridSize)
        let cellH = size.height / CGFloat(gridSize)
        let cornerRadius = min(cellW, cellH) * meshSurfaceCellCornerRadiusRatio
        var counts = Array(repeating: 0, count: gridSize * gridSize)
        var maxCount = 1

        for point in meshPoints {
            let normalizedX = (point.x - bounds.minX) / spanX
            let normalizedY = (point.y - bounds.minY) / spanY
            // Clamp due to ARKit pose jitter at bounds edges that can otherwise
            // create out-of-range indices when mapping into grid cells.
            let clampedX = clampToGrid(normalizedX)
            let clampedY = clampToGrid(normalizedY)
            let x = Int(clampedX * Float(gridSize))
            let y = Int(clampedY * Float(gridSize))
            let cellIndex = (y * gridSize) + x
            counts[cellIndex] += 1
            maxCount = max(maxCount, counts[cellIndex])
        }
        
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let cellIndex = (y * gridSize) + x
                let count = counts[cellIndex]
                guard count > 0 else { continue }

                let intensity = CGFloat(count) / CGFloat(maxCount)
                let rect = CGRect(
                    x: CGFloat(x) * cellW,
                    y: CGFloat(y) * cellH,
                    width: cellW,
                    height: cellH
                )
                let opacity = meshSurfaceOpacity(for: intensity)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: cornerRadius),
                    with: .color(Color.cyan.opacity(opacity))
                )
            }
        }
    }

    private func clampToGrid(_ value: Float) -> Float {
        // Use nextDown(1.0) so exact-bound values stay inside the final grid cell.
        max(0, min(Float(1).nextDown, value))
    }

    private func meshSurfaceOpacity(for intensity: CGFloat) -> Double {
        meshSurfaceMinimumOpacity + (meshSurfaceOpacityRange * intensity)
    }
    
    private func mapBounds(
        trajectory: [SIMD2<Float>],
        meshPoints: [SIMD2<Float>],
        currentPoint: SIMD2<Float>?
    ) -> (minX: Float, maxX: Float, minY: Float, maxY: Float)? {
        let firstPoint = trajectory.first ?? meshPoints.first ?? currentPoint
        guard let first = firstPoint else { return nil }
        
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        
        for point in trajectory {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        for point in meshPoints {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        if let point = currentPoint {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return (minX, maxX, minY, maxY)
    }
    
    private func mapPoint(
        _ point: SIMD2<Float>,
        bounds: (minX: Float, maxX: Float, minY: Float, maxY: Float),
        size: CGSize
    ) -> CGPoint {
        let padding: CGFloat = 8
        let spanX = max(minimumAxisSpan, bounds.maxX - bounds.minX)
        let spanY = max(minimumAxisSpan, bounds.maxY - bounds.minY)
        let scaleX = (size.width - 2 * padding) / CGFloat(spanX)
        let scaleY = (size.height - 2 * padding) / CGFloat(spanY)
        let scale = min(scaleX, scaleY)
        
        let centerX = (bounds.minX + bounds.maxX) * 0.5
        let centerY = (bounds.minY + bounds.maxY) * 0.5
        
        let x = CGFloat(point.x - centerX) * scale + size.width * 0.5
        let y = CGFloat(point.y - centerY) * scale + size.height * 0.5
        
        return CGPoint(x: x, y: y)
    }
}

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
