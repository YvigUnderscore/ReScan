// ViewfinderView.swift
// DIETCapture
//
// Main capture screen: camera preview, depth overlay, controls, and capture buttons.

import SwiftUI

struct ViewfinderView: View {
    @Bindable var viewModel: CaptureViewModel
    
    @State private var showSettings = false
    @State private var overlayBuffer: CVPixelBuffer?
    @State private var depthRefreshTimer: Timer?
    
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
                
                // MARK: - Viewfinder
                ZStack {
                    // Camera Preview
                    CameraPreviewView(cameraService: viewModel.camera.cameraService)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Depth/Confidence Overlay
                    if viewModel.lidar.settings.overlayMode != .none {
                        DepthOverlayImageView(pixelBuffer: overlayBuffer)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .allowsHitTesting(false)
                    }
                    
                    // Depth info overlay
                    if viewModel.lidar.settings.overlayMode != .none {
                        VStack {
                            Spacer()
                            HStack {
                                // Color bar legend
                                HStack(spacing: 2) {
                                    Text("0m")
                                        .font(.system(size: 9, design: .monospaced))
                                    LinearGradient(
                                        colors: [.blue, .cyan, .green, .yellow, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .frame(width: 80, height: 6)
                                    .clipShape(Capsule())
                                    Text("\(viewModel.lidar.settings.maxDistance, specifier: "%.1f")m")
                                        .font(.system(size: 9, design: .monospaced))
                                }
                                .padding(6)
                                .background(.ultraThinMaterial, in: Capsule())
                                Spacer()
                            }
                            .padding(8)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                
                // MARK: - Lens Selector
                LensSelectorView(viewModel: viewModel.camera)
                    .padding(.vertical, 4)
                
                // MARK: - Control Panels (Scrollable)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ExposureControlsView(viewModel: viewModel.camera)
                        FocusControlsView(viewModel: viewModel.camera)
                        LiDARControlsView(viewModel: viewModel.lidar)
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 280)
                
                Spacer(minLength: 4)
                
                // MARK: - Capture Controls
                captureControls
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            viewModel.setup()
            startOverlayRefresh()
        }
        .onDisappear {
            viewModel.teardown()
            depthRefreshTimer?.invalidate()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .alert("Notice", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.showError = false }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Capture Controls Bar
    
    private var captureControls: some View {
        HStack(spacing: 30) {
            // Settings button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            Spacer()
            
            // Photo button
            Button {
                viewModel.capturePhoto()
                hapticFeedback()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 70, height: 70)
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundStyle(.black)
                }
            }
            
            // Record button
            Button {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
                hapticFeedback()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 70, height: 70)
                    
                    if viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.red)
                            .frame(width: 28, height: 28)
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: 56, height: 56)
                    }
                }
            }
            
            Spacer()
            
            // Saving indicator or empty space
            if viewModel.isSaving {
                ProgressView()
                    .tint(.white)
                    .frame(width: 50, height: 50)
            } else {
                Color.clear
                    .frame(width: 50, height: 50)
            }
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - Depth Overlay Refresh
    
    private func startOverlayRefresh() {
        depthRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { _ in
            if viewModel.lidar.settings.overlayMode != .none {
                overlayBuffer = viewModel.lidar.generateOverlayBuffer()
            } else {
                overlayBuffer = nil
            }
        }
    }
    
    // MARK: - Haptic
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
