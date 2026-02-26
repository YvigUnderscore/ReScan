// MediaLibraryView.swift
// ReScan
//
// Browse recorded scan sessions, preview passes, delete scans.

import SwiftUI
import AVKit
import AVFoundation

struct MediaLibraryView: View {
    @State private var sessions: [RecordedSession] = []
    @State private var selectedSession: RecordedSession?
    @State private var sessionToDelete: RecordedSession?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if sessions.isEmpty {
                            emptyState
                        } else {
                            ForEach(sessions) { session in
                                SessionCardView(session: session, onTap: {
                                    selectedSession = session
                                }, onDelete: {
                                    sessionToDelete = session
                                    showDeleteConfirmation = true
                                })
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session, onDelete: {
                    deleteSession(session)
                    selectedSession = nil
                })
            }
            .alert("Delete Scan?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        deleteSession(session)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all data for \"\(sessionToDelete?.name ?? "")\".")
            }
        }
        .onAppear {
            refreshSessions()
        }
    }
    
    // MARK: - Methods
    
    private func refreshSessions() {
        sessions = CaptureSession.listSessions()
    }
    
    private func deleteSession(_ session: RecordedSession) {
        CaptureSession.deleteSession(session)
        withAnimation(.easeInOut(duration: 0.3)) {
            sessions.removeAll { $0.id == session.id }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 80)
            
            Image(systemName: "tray")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                )
            
            Text("No scans yet")
                .font(.title3).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Text("Captured scans will appear here.\nSwitch to the Capture tab to start scanning.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Session Card

struct SessionCardView: View {
    let session: RecordedSession
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Thumbnail from first video frame
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [Color(white: 0.12), Color(white: 0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 64, height: 64)
                    
                    if let thumb = thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "cube.transparent.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 10) {
                        Label("\(session.frameCount)", systemImage: "photo.stack")
                        if session.hasVideo { Label("Video", systemImage: "video.fill") }
                        if session.hasDepth { Label("Depth", systemImage: "cube.fill") }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    
                    Text(session.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .task {
            thumbnail = await generateThumbnail(for: session)
        }
    }
    
    // MARK: - Thumbnail Generation
    
    private func generateThumbnail(for session: RecordedSession) async -> UIImage? {
        guard let videoURL = session.videoURL else { return nil }
        
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 128, height: 128)
        
        do {
            let (image, _) = try await generator.image(at: .zero)
            return UIImage(cgImage: image)
        } catch {
            return nil
        }
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    let session: RecordedSession
    let onDelete: () -> Void
    
    @State private var activePass: ViewMode = .rgb
    @State private var currentFrameIndex: Int = 0
    @State private var currentImage: UIImage?
    @State private var player: AVPlayer?
    @State private var showDeleteAlert = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 12) {
                    // Pass Toggle
                    passToggle
                    
                    // Content
                    ZStack {
                        if activePass == .rgb && session.hasVideo {
                            videoPlayerView
                        } else if let image = currentImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(white: 0.08))
                                .overlay {
                                    Text("No data")
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal)
                    
                    // Frame Scrubber (for non-video passes)
                    if activePass != .rgb && session.frameCount > 0 {
                        VStack(spacing: 6) {
                            Slider(
                                value: Binding(
                                    get: { Double(currentFrameIndex) },
                                    set: { currentFrameIndex = Int($0); loadFrame() }
                                ),
                                in: 0...Double(max(0, session.frameCount - 1)),
                                step: 1
                            )
                            .tint(.cyan)
                            
                            HStack {
                                Text("Frame \(currentFrameIndex)")
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                                Text("\(session.frameCount) total")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Session Info
                    sessionInfoBar
                }
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            shareSession()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Delete Scan?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete \"\(session.name)\" and all its data.")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadFrame()
            setupVideoPlayer()
        }
    }
    
    // MARK: - Pass Toggle
    
    private var passToggle: some View {
        HStack(spacing: 6) {
            ForEach(ViewMode.allCases) { mode in
                let isAvailable = passAvailable(mode)
                Button {
                    guard isAvailable else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activePass = mode
                        currentFrameIndex = 0
                        loadFrame()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.caption2)
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        activePass == mode
                            ? AnyShapeStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.white.opacity(isAvailable ? 0.08 : 0.03))
                    )
                    .foregroundStyle(
                        activePass == mode ? .white : (isAvailable ? .secondary : .secondary.opacity(0.3))
                    )
                    .clipShape(Capsule())
                }
                .disabled(!isAvailable)
            }
        }
        .padding(.top, 8)
    }
    
    private func passAvailable(_ mode: ViewMode) -> Bool {
        switch mode {
        case .rgb: return session.hasVideo
        case .depth: return session.hasDepth
        case .confidence: return session.hasConfidence
        case .mesh: return false
        }
    }
    
    // MARK: - Video Player
    
    private var videoPlayerView: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Session Info Bar
    
    private var sessionInfoBar: some View {
        HStack(spacing: 16) {
            Label("\(session.frameCount) frames", systemImage: "photo.stack")
            if session.hasVideo { Label("RGB", systemImage: "video.fill") }
            if session.hasDepth { Label("Depth", systemImage: "cube.fill") }
            if session.hasConfidence { Label("Conf.", systemImage: "checkmark.shield.fill") }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.bottom, 16)
    }
    
    // MARK: - Data Loading
    
    private func loadFrame() {
        let fm = FileManager.default
        let frameName = String(format: "%06d", currentFrameIndex)
        
        switch activePass {
        case .rgb, .mesh:
            break
            
        case .depth:
            let depthURL = session.directory.appendingPathComponent("depth/\(frameName).png")
            if fm.fileExists(atPath: depthURL.path),
               let image = UIImage(contentsOfFile: depthURL.path) {
                currentImage = image
            } else {
                currentImage = nil
            }
            
        case .confidence:
            let confURL = session.directory.appendingPathComponent("confidence/\(frameName).png")
            if fm.fileExists(atPath: confURL.path),
               let image = UIImage(contentsOfFile: confURL.path) {
                currentImage = image
            } else {
                currentImage = nil
            }
        }
    }
    
    private func setupVideoPlayer() {
        if let videoURL = session.videoURL {
            player = AVPlayer(url: videoURL)
        }
    }
    
    // MARK: - Share
    
    private func shareSession() {
        let activityVC = UIActivityViewController(activityItems: [session.directory], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
