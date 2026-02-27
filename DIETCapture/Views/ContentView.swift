// ContentView.swift
// ReScan
//
// Root view with tab bar: Capture and Media Library.

import SwiftUI
import ARKit
import AVFoundation

struct ContentView: View {
    @State private var viewModel = CaptureViewModel()
    @State private var showSplash = true
    @State private var hasPermissions = false
    @State private var permissionsChecked = false
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            } else if !permissionsChecked {
                loadingView
            } else if !viewModel.camera.capabilities.hasLiDAR {
                noLiDARView
            } else if !hasPermissions {
                permissionsView
            } else {
                TabView(selection: $selectedTab) {
                    ViewfinderView(viewModel: viewModel)
                        .tabItem {
                            Image(systemName: "camera.fill")
                            Text("Capture")
                        }
                        .tag(0)
                    
                    MediaLibraryView()
                        .tabItem {
                            Image(systemName: "photo.stack.fill")
                            Text("Library")
                        }
                        .tag(1)
                        
                    SettingsView()
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .tag(2)
                }
                .tint(.cyan)
                .preferredColorScheme(.dark)
            }
        }
        .task {
            // Check permissions and keep splash screen visible for at least 2.2 seconds for animation
            async let authDelay: ()? = try? Task.sleep(nanoseconds: 2_200_000_000)
            async let authCheck: Void = checkPermissions()
            
            _ = await (authDelay, authCheck)
            
            withAnimation(.easeInOut(duration: 0.4)) {
                showSplash = false
            }
        }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.12), .black],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.pulse, options: .repeating)
                
                Text("ReScan")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .cyan.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                    )
                
                ProgressView()
                    .tint(.cyan)
                    .scaleEffect(1.2)
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
                    .font(.title).fontWeight(.bold).foregroundStyle(.white)
                Text("This app requires an iPhone with LiDAR sensor.\n(iPhone 12 Pro or newer)")
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
            }
        }
    }
    
    // MARK: - Permissions
    
    private var permissionsView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 64)).foregroundStyle(.cyan)
                Text("Camera Access Required")
                    .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                Text("ReScan needs access to your camera and LiDAR sensor.")
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.headline).foregroundStyle(.black)
                        .padding(.horizontal, 32).padding(.vertical, 14)
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
