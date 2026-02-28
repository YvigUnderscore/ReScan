// ReMapView.swift
// ReScan
//
// Main ReMap integration view: dataset-centric workflow with step-by-step
// processing, live job monitoring, and beautiful animations.

import SwiftUI

struct ReMapView: View {
    @State private var viewModel = ReMapViewModel()
    @State private var sessions: [RecordedSession] = []
    @State private var selectedSession: RecordedSession?
    @State private var selectedSource: ReMapUploadSource?
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var logsJobId: String?
    @State private var showProcessingSettings = false
    @State private var showClearConfirmation = false
    @State private var selectedTab: ReMapTab = .newJob
    
    private enum ReMapTab: String, CaseIterable {
        case newJob = "New Job"
        case active = "Active"
        case history = "History"
        
        var icon: String {
            switch self {
            case .newJob: return "plus.circle.fill"
            case .active: return "bolt.fill"
            case .history: return "clock.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if viewModel.isConfigured {
                        // Server status bar (compact)
                        serverStatusBar
                        
                        // Tab selector
                        tabSelector
                        
                        // Tab content
                        ScrollView {
                            VStack(spacing: 16) {
                                switch selectedTab {
                                case .newJob:
                                    newJobContent
                                case .active:
                                    activeJobsContent
                                case .history:
                                    historyContent
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 32)
                        }
                    } else {
                        configurePrompt
                    }
                }
            }
            .navigationTitle("ReMap")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(.cyan)
                    }
                }
                
                if viewModel.isConfigured {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                Task { await viewModel.refreshJobs() }
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.cleanInterface()
                                    selectedSession = nil
                                    selectedSource = nil
                                }
                            } label: {
                                Label("Clean Interface", systemImage: "sparkles")
                            }
                            
                            Button(role: .destructive) {
                                showClearConfirmation = true
                            } label: {
                                Label("Clear Job History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                ReMapServerSettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showProcessingSettings) {
                ReMapProcessingSettingsView(settings: $viewModel.processingSettings, sourceDuration: selectedSession?.duration)
            }
            .sheet(isPresented: $showLogs) {
                ReMapLogsView(viewModel: viewModel, jobId: logsJobId ?? "")
            }
            .alert("Generate EXR Sequence?", isPresented: $viewModel.showEXRGenerationPrompt) {
                Button("Generate & Upload") {
                    if let session = viewModel.pendingEXRSession {
                        Task { await viewModel.generateEXRAndUpload(session: session) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.pendingEXRSession = nil
                }
            } message: {
                Text("No EXR sequence found for this dataset. Would you like to generate it automatically from the RGB video and then upload?")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {}
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .confirmationDialog(
                "Clear Job History",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.clearJobHistory()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all jobs from the local view. Jobs on the server will not be affected.")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.loadConfig()
            sessions = CaptureSession.listSessions()
            if viewModel.isConfigured {
                Task {
                    await viewModel.checkServer()
                    await viewModel.refreshJobs()
                    // Auto-select Active tab on first load if there are processing jobs
                    if !viewModel.processingJobs.isEmpty && selectedTab == .newJob {
                        selectedTab = .active
                    }
                }
                viewModel.startAutoRefresh()
            }
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedTab)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedSession?.id)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedSource)
    }
    
    // MARK: - Server Status Bar (Compact)
    
    private var serverStatusBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isServerOnline ? .green : .red)
                    .frame(width: 7, height: 7)
                
                Text(viewModel.isServerOnline ? "Connected" : "Offline")
                    .font(.caption2).fontWeight(.medium)
                    .foregroundStyle(viewModel.isServerOnline ? .green : .red)
            }
            
            if viewModel.isCheckingServer {
                ProgressView()
                    .tint(.cyan)
                    .scaleEffect(0.6)
            }
            
            Spacer()
            
            if viewModel.isConfigured {
                Text(viewModel.serverURL)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            if let version = viewModel.serverVersion {
                Text("v\(version)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.7))
            }
            
            Button {
                Task { await viewModel.checkServer() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(.cyan)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(white: 0.06))
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ReMapTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.caption).fontWeight(.semibold)
                            
                            // Badge for active jobs
                            if tab == .active && !viewModel.processingJobs.isEmpty {
                                Text("\(viewModel.processingJobs.count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.blue, in: Capsule())
                            }
                        }
                        .foregroundStyle(selectedTab == tab ? .cyan : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? .cyan : .clear)
                            .frame(height: 2)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .background(Color(white: 0.06))
    }
    
    // MARK: - Configure Prompt
    
    private var configurePrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "link.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            Text("Connect to ReMap")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("Configure your ReMap server URL and API key\nto start processing datasets remotely.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showSettings = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                    Text("Configure Server")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [.cyan, .cyan.opacity(0.8)], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - New Job Tab
    
    private var newJobContent: some View {
        VStack(spacing: 16) {
            // Upload progress states
            if viewModel.isGeneratingEXR {
                uploadProgressCard(
                    icon: "wand.and.stars",
                    label: "Generating EXR Sequence",
                    progress: viewModel.exrGenerationProgress,
                    color: .purple
                )
            } else if viewModel.isCreatingZIP {
                uploadProgressCard(
                    icon: "doc.zipper",
                    label: "Creating ZIP Archive",
                    progress: viewModel.zipProgress,
                    color: .orange
                )
            } else if viewModel.isUploading {
                uploadProgressCard(
                    icon: "arrow.up.circle.fill",
                    label: "Uploading to Server",
                    progress: viewModel.uploadProgress,
                    color: .cyan
                )
            } else if viewModel.isStartingProcess {
                HStack(spacing: 10) {
                    ProgressView().tint(.cyan).scaleEffect(0.8)
                    Text("Starting processing…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
            } else if let session = selectedSession {
                datasetWorkflow(session: session)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                // Dataset selection
                datasetSelectionGrid
            }
        }
    }
    
    // MARK: - Dataset Selection Grid
    
    private var datasetSelectionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.arrow.up.fill")
                    .foregroundStyle(.cyan)
                Text("Select a Dataset")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(sessions.count)")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(white: 0.15), in: Capsule())
            }
            
            if sessions.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(colors: [.secondary.opacity(0.5), .secondary.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                        )
                    Text("No datasets yet")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text("Capture a scan to start processing.")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(sessions) { session in
                    datasetRow(session: session)
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Dataset Row
    
    private func datasetRow(session: RecordedSession) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedSession = session
                selectedSource = nil
            }
        } label: {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "cube.fill")
                    .font(.title3)
                    .foregroundStyle(.cyan)
                    .frame(width: 36, height: 36)
                    .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        if session.hasVideo {
                            Label("Video", systemImage: "video.fill")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        if session.hasEXR {
                            Label("EXR", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        Label("\(session.frameCount)", systemImage: "photo.stack")
                        Label(sessionSizeString(session.diskSizeMB), systemImage: "internaldrive")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUploading || viewModel.isCreatingZIP || viewModel.isGeneratingEXR)
    }
    
    // MARK: - Dataset Workflow (Step-by-Step)
    
    private func datasetWorkflow(session: RecordedSession) -> some View {
        VStack(spacing: 16) {
            // Header with selected dataset
            HStack(spacing: 12) {
                Image(systemName: "cube.fill")
                    .font(.title3)
                    .foregroundStyle(.cyan)
                    .frame(width: 36, height: 36)
                    .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        Label("\(session.frameCount) frames", systemImage: "photo.stack")
                        Label(sessionSizeString(session.diskSizeMB), systemImage: "internaldrive")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedSession = nil
                        selectedSource = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
            
            // Steps with visual timeline
            VStack(spacing: 0) {
                // Step 1: Source
                stepCard(
                    number: 1,
                    title: "Source",
                    isActive: selectedSource == nil,
                    isComplete: selectedSource != nil,
                    isLast: false
                ) {
                    HStack(spacing: 10) {
                        if session.hasVideo {
                            sourceButton(
                                source: .video,
                                icon: "video.fill",
                                description: "Smaller, faster",
                                isSelected: selectedSource == .video
                            )
                        }
                        if session.hasEXR {
                            sourceButton(
                                source: .exr,
                                icon: "photo.stack.fill",
                                description: "Higher quality",
                                isSelected: selectedSource == .exr
                            )
                        } else if session.hasVideo {
                            sourceButton(
                                source: .exr,
                                icon: "wand.and.stars",
                                description: "Generate EXR",
                                isSelected: selectedSource == .exr
                            )
                        }
                    }
                }
                
                // Step 2: Settings (shown after source selection)
                if selectedSource != nil {
                    stepCard(
                        number: 2,
                        title: "Settings",
                        isActive: true,
                        isComplete: false,
                        isLast: false
                    ) {
                        VStack(spacing: 10) {
                            // Settings summary chips
                            settingsSummary
                            
                            Button {
                                showProcessingSettings = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("Configure Processing")
                                }
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.cyan)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(.cyan.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    
                    // Step 3: Launch
                    stepCard(
                        number: 3,
                        title: "Launch",
                        isActive: true,
                        isComplete: false,
                        isLast: true
                    ) {
                        Button {
                            viewModel.uploadSource = selectedSource ?? .video
                            Task {
                                await viewModel.performUpload(session: session)
                                if let datasetId = viewModel.lastDatasetId {
                                    await viewModel.startProcessing(datasetId: datasetId)
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        selectedSession = nil
                                        selectedSource = nil
                                        selectedTab = .active
                                        sessions = CaptureSession.listSessions()
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Upload & Process")
                                Spacer()
                                Image(systemName: selectedSource == .exr ? "photo.stack.fill" : "video.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(
                                LinearGradient(
                                    colors: [.cyan, .blue.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isUploading || viewModel.isCreatingZIP)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
    }
    
    // MARK: - Step Card
    
    private func stepCard<Content: View>(
        number: Int,
        title: String,
        isActive: Bool,
        isComplete: Bool,
        isLast: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                ZStack {
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.green)
                    } else {
                        Text("\(number)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(isActive ? .black : .secondary)
                            .frame(width: 24, height: 24)
                            .background(
                                isActive ? AnyShapeStyle(.cyan) : AnyShapeStyle(Color(white: 0.2)),
                                in: Circle()
                            )
                    }
                }
                
                if !isLast {
                    Rectangle()
                        .fill(isComplete ? .green.opacity(0.4) : Color(white: 0.15))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(isActive || isComplete ? .white : .secondary)
                
                content()
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }
    
    // MARK: - Source Button
    
    private func sourceButton(source: ReMapUploadSource, icon: String, description: String, isSelected: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedSource = source
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(source.rawValue)
                    .font(.caption).fontWeight(.bold)
                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color(white: 0.08)),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? .cyan : .white.opacity(0.08), lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? .cyan : .white)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Settings Summary
    
    private var settingsSummary: some View {
        let s = viewModel.processingSettings
        return FlowLayout(spacing: 6) {
            settingChip(icon: "speedometer", text: "\(String(format: "%.1f", s.fps)) fps")
            settingChip(icon: "sparkle.magnifyingglass", text: s.featureType)
            settingChip(icon: "arrow.left.arrow.right", text: s.matcherType)
            settingChip(icon: "map", text: s.mapperType)
            settingChip(icon: "camera", text: s.cameraModel)
        }
    }
    
    private func settingChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(white: 0.12), in: Capsule())
    }
    
    // MARK: - Active Jobs Tab
    
    private var activeJobsContent: some View {
        VStack(spacing: 16) {
            if viewModel.processingJobs.isEmpty {
                emptyStateCard(
                    icon: "bolt.slash",
                    title: "No Active Jobs",
                    subtitle: "Start a new job from the New Job tab."
                )
            } else {
                ForEach(viewModel.processingJobs) { job in
                    activeJobCard(job: job)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            
            if viewModel.isDownloading {
                HStack(spacing: 10) {
                    ProgressView().tint(.green).scaleEffect(0.8)
                    Text("Downloading result…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.processingJobs.count)
    }
    
    private func activeJobCard(job: ReMapJobListItem) -> some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Group {
                    if #available(iOS 18.0, *) {
                        Image(systemName: job.parsedStatus.icon)
                            .foregroundStyle(Color.fromString(job.parsedStatus.color))
                            .symbolEffect(.pulse, isActive: job.parsedStatus == .processing)
                    } else {
                        Image(systemName: job.parsedStatus.icon)
                            .foregroundStyle(Color.fromString(job.parsedStatus.color))
                    }
                }
                .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.datasetId ?? job.jobId)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(job.parsedStatus.label)
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(Color.fromString(job.parsedStatus.color))
                        
                        if let step = job.currentStep {
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(step)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption2)
                }
                
                Spacer()
                
                Text("\(job.progress)%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fromString(job.parsedStatus.color))
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.15))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.fromString(job.parsedStatus.color), Color.fromString(job.parsedStatus.color).opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(job.progress) / 100.0)
                        .animation(.easeInOut(duration: 0.5), value: job.progress)
                }
            }
            .frame(height: 6)
            
            // Actions
            HStack(spacing: 8) {
                actionButton(icon: "doc.text", label: "Logs", color: .cyan) {
                    logsJobId = job.jobId
                    showLogs = true
                }
                
                actionButton(icon: "eye.fill", label: "Watch", color: .blue) {
                    viewModel.startPolling(jobId: job.jobId)
                }
                
                Spacer()
                
                actionButton(icon: "xmark.circle", label: "Cancel", color: .red.opacity(0.8)) {
                    Task { await viewModel.cancelJob(jobId: job.jobId) }
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.fromString(job.parsedStatus.color).opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - History Tab
    
    private var historyContent: some View {
        VStack(spacing: 16) {
            // Completed jobs
            if !viewModel.completedJobs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Completed")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(viewModel.completedJobs.count)")
                            .font(.caption2).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.green.opacity(0.5), in: Capsule())
                    }
                    
                    ForEach(viewModel.completedJobs) { job in
                        completedJobRow(job: job)
                    }
                }
                .padding(16)
                .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.green.opacity(0.15), lineWidth: 1)
                )
            }
            
            // Failed / Cancelled jobs
            if !viewModel.failedJobs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Failed / Cancelled")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(viewModel.failedJobs.count)")
                            .font(.caption2).fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(viewModel.failedJobs) { job in
                        failedJobRow(job: job)
                    }
                }
                .padding(16)
                .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
            }
            
            // Empty state
            if viewModel.completedJobs.isEmpty && viewModel.failedJobs.isEmpty {
                emptyStateCard(
                    icon: "clock",
                    title: "No Job History",
                    subtitle: "Completed and failed jobs will appear here."
                )
            }
        }
    }
    
    private func completedJobRow(job: ReMapJobListItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(job.datasetId ?? job.jobId)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                if let createdAt = job.createdAt {
                    Text(createdAt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Button {
                    logsJobId = job.jobId
                    showLogs = true
                } label: {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                        .frame(width: 30, height: 30)
                        .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                
                Button {
                    Task { await viewModel.downloadResult(jobId: job.jobId) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download")
                    }
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.green.opacity(0.1), in: Capsule())
                }
                .disabled(viewModel.isDownloading)
            }
        }
        .padding(10)
        .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func failedJobRow(job: ReMapJobListItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: job.parsedStatus.icon)
                .foregroundStyle(Color.fromString(job.parsedStatus.color))
                .font(.body)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(job.jobId.prefix(16) + "…")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                Text(job.parsedStatus.label)
                    .font(.caption2)
                    .foregroundStyle(Color.fromString(job.parsedStatus.color))
            }
            
            Spacer()
            
            Button {
                logsJobId = job.jobId
                showLogs = true
            } label: {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.cyan)
                    .frame(width: 30, height: 30)
                    .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(10)
        .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Upload Progress Card
    
    private func uploadProgressCard(icon: String, label: String, progress: Double, color: Color) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("\(Int(progress * 100))% complete")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
    
    // MARK: - Shared Components
    
    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.caption).fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(color.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func emptyStateCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(colors: [.secondary.opacity(0.5), .secondary.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                )
            Text(title)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Helpers
    
    private func sessionSizeString(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}

// MARK: - Flow Layout (for chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        
        return CGSize(width: width, height: y + rowHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Server Settings Sheet

struct ReMapServerSettingsView: View {
    @Bindable var viewModel: ReMapViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempServerURL: String = ""
    @State private var tempAPIKey: String = ""
    @State private var showAPIKey: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("http://192.168.1.100:5000", text: $tempServerURL)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            if showAPIKey {
                                TextField("Enter API Key", text: $tempAPIKey)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("Enter API Key", text: $tempAPIKey)
                            }
                            
                            Button {
                                showAPIKey.toggle()
                            } label: {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("ReMap Server")
                } footer: {
                    Text("Enter the URL and API key for your ReMap server. The API key is securely stored in the iOS Keychain.\n\nStart the ReMap server on your computer and copy the API key displayed in the terminal or GUI.")
                }
                
                Section {
                    Button {
                        saveAndTest()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Save & Test Connection")
                        }
                    }
                    .disabled(tempServerURL.isEmpty || tempAPIKey.isEmpty)
                    
                    if viewModel.isCheckingServer {
                        HStack {
                            ProgressView().tint(.cyan).scaleEffect(0.8)
                            Text("Testing connection…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.isServerOnline ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(viewModel.isServerOnline ? "Connected" : "Not Connected")
                                .foregroundStyle(viewModel.isServerOnline ? .green : .red)
                        }
                        .font(.caption)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        tempServerURL = ""
                        tempAPIKey = ""
                        viewModel.serverURL = ""
                        viewModel.apiKey = ""
                        viewModel.saveConfig()
                        viewModel.isServerOnline = false
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Configuration")
                        }
                    }
                }
            }
            .navigationTitle("Server Settings")
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
        .onAppear {
            tempServerURL = viewModel.serverURL
            tempAPIKey = viewModel.apiKey
        }
    }
    
    private func saveAndTest() {
        viewModel.serverURL = tempServerURL
        viewModel.apiKey = tempAPIKey
        viewModel.saveConfig()
        
        Task {
            await viewModel.checkServer()
        }
    }
}

// MARK: - Logs View

struct ReMapLogsView: View {
    @Bindable var viewModel: ReMapViewModel
    let jobId: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoadingLogs {
                    ProgressView("Loading logs…")
                        .tint(.cyan)
                } else if jobId.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No job selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.jobLogs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No logs available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.jobLogs) { log in
                                logEntryView(log)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Job Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.cyan)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await viewModel.loadLogs(jobId: jobId) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.cyan)
                    }
                    .disabled(jobId.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if !jobId.isEmpty {
                await viewModel.loadLogs(jobId: jobId)
            }
        }
    }
    
    private func logEntryView(_ log: ReMapJobLogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: logIcon(for: log.level))
                .font(.caption)
                .foregroundStyle(logColor(for: log.level))
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(log.step)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                
                Text(log.message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                if let ts = log.timestamp {
                    Text(ts)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
        }
        .padding(10)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func logIcon(for level: String?) -> String {
        switch level?.lowercased() {
        case "error": return "xmark.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "info": return "info.circle.fill"
        default: return "circle.fill"
        }
    }
    
    private func logColor(for level: String?) -> Color {
        switch level?.lowercased() {
        case "error": return .red
        case "warning": return .orange
        case "info": return .cyan
        default: return .secondary
        }
    }
}
