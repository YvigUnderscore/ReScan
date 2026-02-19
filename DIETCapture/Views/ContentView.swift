// ContentView.swift
// DIETCapture
//
// Root view: checks for LiDAR availability and shows the viewfinder.

import SwiftUI
import ARKit

struct ContentView: View {
    @State private var viewModel = CaptureViewModel()
    @State private var hasPermissions = false
    @State private var permissionsChecked = false
    
    var body: some View {
        Group {
            if !permissionsChecked {
                loadingView
            } else if !viewModel.camera.capabilities.hasLiDAR {
                noLiDARView
            } else if !hasPermissions {
                permissionsView
            } else {
                ViewfinderView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
                    .statusBarHidden(true)
            }
        }
        .task {
            await checkPermissions()
        }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                Text("Initializing...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - No LiDAR
    
    private var noLiDARView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
                
                Text("LiDAR Required")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("This app requires an iPhone with LiDAR sensor.\n(iPhone 12 Pro or newer)")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    // MARK: - Permissions
    
    private var permissionsView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.cyan)
                
                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("DIET Capture needs access to your camera and LiDAR sensor to function.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.cyan, in: Capsule())
                }
            }
        }
    }
    
    // MARK: - Permission Check
    
    private func checkPermissions() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            hasPermissions = true
        case .notDetermined:
            hasPermissions = await AVCaptureDevice.requestAccess(for: .video)
        default:
            hasPermissions = false
        }
        
        permissionsChecked = true
    }
}
