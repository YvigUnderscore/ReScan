// ContentView.swift
// ReScan
//
// Root view with a modern floating tab bar and full-screen content areas.

import SwiftUI
import ARKit

// MARK: - Tab Definition

private enum AppTab: Int, CaseIterable {
    case capture = 0
    case library = 1
    case remap   = 2
    case settings = 3

    var icon: String {
        switch self {
        case .capture:  return "camera.fill"
        case .library:  return "photo.stack.fill"
        case .remap:    return "server.rack"
        case .settings: return "gearshape.fill"
        }
    }

    var label: String {
        switch self {
        case .capture:  return "Capture"
        case .library:  return "Library"
        case .remap:    return "ReMap"
        case .settings: return "Settings"
        }
    }

    var accentColor: Color {
        switch self {
        case .capture:  return .cyan
        case .library:  return .purple
        case .remap:    return .blue
        case .settings: return .gray
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var viewModel = CaptureViewModel()
    @State private var showSplash = true
    @State private var hasPermissions = false
    @State private var permissionsChecked = false
    @State private var selectedTab: AppTab = .capture

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
                mainInterface
            }
        }
        .task {
            async let authDelay: () = Task.sleep(nanoseconds: 2_200_000_000)
            async let authCheck: () = checkPermissions()
            _ = await (try? authDelay, authCheck)
            withAnimation(.easeInOut(duration: 0.4)) {
                showSplash = false
            }
        }
    }

    // MARK: - Main Interface

    private var mainInterface: some View {
        ZStack(alignment: .bottom) {
            // Full-screen content for each tab
            Group {
                switch selectedTab {
                case .capture:
                    ViewfinderView(viewModel: viewModel)
                        .ignoresSafeArea()
                        .padding(.bottom, 90) // Clear room for floating tab bar
                case .library:
                    MediaLibraryView()
                case .remap:
                    ReMapView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating pill tab bar
            floatingTabBar
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Floating Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: isSelected ? 20 : 18, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? tab.accentColor : .white.opacity(0.45))
                    .scaleEffect(isSelected ? 1.05 : 1.0)

                Text(tab.label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? tab.accentColor : .white.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(tab.accentColor.opacity(0.15))
                    }
                }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            MeshGradientBackground()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.08))
                        .frame(width: 110, height: 110)
                    Image(systemName: "viewfinder")
                        .font(.system(size: 52, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .symbolEffect(.pulse, options: .repeating)
                }

                VStack(spacing: 8) {
                    Text("ReScan")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(1.2)
                }
            }
        }
    }

    // MARK: - No LiDAR

    private var noLiDARView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.red.gradient)
                VStack(spacing: 10) {
                    Text("LiDAR Required")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("ReScan requires an iPhone with LiDAR.\n(iPhone 12 Pro or newer)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
    }

    // MARK: - Permissions

    private var permissionsView: some View {
        ZStack {
            MeshGradientBackground()

            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.cyan.gradient)
                }

                VStack(spacing: 12) {
                    Text("Camera Access Required")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("ReScan needs access to your camera and LiDAR sensor to capture 3D data.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                        Text("Open Settings")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
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

// MARK: - Mesh Gradient Background

private struct MeshGradientBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [.cyan.opacity(0.12), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [.blue.opacity(0.08), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()
        }
    }
}
