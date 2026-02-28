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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Server Status
                        serverStatusCard
                        
                        if viewModel.isConfigured {
                            // Processing Datasets
                            if !viewModel.processingJobs.isEmpty {
                                processingDatasetsSection
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                            
                            // ReMapped Datasets (completed)
                            if !viewModel.completedJobs.isEmpty {
                                remappedDatasetsSection
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                            
                            // Dataset Selection & Workflow
                            datasetSelectionSection
                            
                            // Failed/Cancelled jobs
                            if !viewModel.failedJobs.isEmpty {
                                failedJobsSection
                                    .transition(.opacity)
                            }
                        } else {
                            configurePrompt
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.processingJobs.count)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.completedJobs.count)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedSession?.id)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedSource)
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
                ReMapProcessingSettingsView(settings: $viewModel.processingSettings)
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
                }
                viewModel.startAutoRefresh()
            }
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }
    
    // MARK: - Server Status Card
    
    private var serverStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.title3)
                    .foregroundStyle(.cyan)
                
                Text("Server")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if viewModel.isCheckingServer {
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(0.8)
                } else {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isServerOnline ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isServerOnline ? "Online" : "Offline")
                            .font(.caption)
                            .foregroundStyle(viewModel.isServerOnline ? .green : .red)
                    }
                }
            }
            
            if viewModel.isConfigured {
                Text(viewModel.serverURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if let version = viewModel.serverVersion {
                    Text("API \(version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            
            Button {
                Task { await viewModel.checkServer() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Check Connection")
                }
                .font(.caption)
                .foregroundStyle(.cyan)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Configure Prompt
    
    private var configurePrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan.opacity(0.4), .blue.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                )
            
            Text("Connect to ReMap Server")
                .font(.title3).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Text("Configure your ReMap server URL and API key to start processing datasets remotely.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showSettings = true
            } label: {
                Text("Configure Server")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(.cyan, in: Capsule())
            }
        }
        .padding(.top, 40)
    }
    
    // MARK: - Processing Datasets Section
    
    private var processingDatasetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Group {
                    if #available(iOS 18.0, *) {
                        Image(systemName: "gearshape.2.fill")
                            .foregroundStyle(.blue)
                            .symbolEffect(.rotate, isActive: true)
                    } else {
                        Image(systemName: "gearshape.2.fill")
                            .foregroundStyle(.blue)
                    }
                }
                
                Text("Processing Datasets")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(viewModel.processingJobs.count)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.6), in: Capsule())
            }
            
            ForEach(viewModel.processingJobs) { job in
                processingJobRow(job: job)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func processingJobRow(job: ReMapJobListItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: job.parsedStatus.icon)
                            .foregroundStyle(Color.fromString(job.parsedStatus.color))
                        if let datasetId = job.datasetId {
                            Text(datasetId.prefix(12) + "…")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                        } else {
                            Text(job.jobId.prefix(12) + "…")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text(job.parsedStatus.label)
                            .foregroundStyle(Color.fromString(job.parsedStatus.color))
                        if let step = job.currentStep {
                            Text("· \(step)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption2)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        logsJobId = job.jobId
                        showLogs = true
                    } label: {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                    
                    Button {
                        viewModel.startPolling(jobId: job.jobId)
                    } label: {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    
                    Button {
                        Task { await viewModel.cancelJob(jobId: job.jobId) }
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
            }
            
            ProgressView(value: Double(job.progress) / 100.0)
                .tint(.blue)
                .animation(.easeInOut(duration: 0.3), value: job.progress)
            
            Text("\(job.progress)%")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - ReMapped Datasets Section (Completed)
    
    private var remappedDatasetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                
                Text("ReMapped Datasets")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(viewModel.completedJobs.count)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.6), in: Capsule())
            }
            
            ForEach(viewModel.completedJobs) { job in
                completedJobRow(job: job)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func completedJobRow(job: ReMapJobListItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    if let datasetId = job.datasetId {
                        Text(datasetId.prefix(12) + "…")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                    } else {
                        Text(job.jobId.prefix(12) + "…")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                
                if let createdAt = job.createdAt {
                    Text(createdAt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    logsJobId = job.jobId
                    showLogs = true
                } label: {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
                
                Button {
                    Task { await viewModel.downloadResult(jobId: job.jobId) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                }
                .disabled(viewModel.isDownloading)
            }
        }
        .padding(12)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Dataset Selection & Workflow
    
    private var datasetSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.arrow.up.fill")
                    .foregroundStyle(.cyan)
                Text("Select Dataset")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if selectedSession != nil {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedSession = nil
                            selectedSource = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Cancel")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Upload progress states
            if viewModel.isGeneratingEXR {
                progressRow(label: "Generating EXR…", progress: viewModel.exrGenerationProgress, color: .purple)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if viewModel.isCreatingZIP {
                progressRow(label: "Creating ZIP…", progress: viewModel.zipProgress, color: .orange)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if viewModel.isUploading {
                progressRow(label: "Uploading…", progress: viewModel.uploadProgress, color: .cyan)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if viewModel.isStartingProcess {
                HStack {
                    ProgressView().tint(.cyan).scaleEffect(0.8)
                    Text("Starting processing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else if let session = selectedSession {
                // Dataset workflow steps
                datasetWorkflow(session: session)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                // Dataset list
                if sessions.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text("No datasets available. Capture a scan first.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(sessions) { session in
                        datasetRow(session: session)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
            }
            
            if viewModel.isDownloading {
                HStack {
                    ProgressView().tint(.green).scaleEffect(0.8)
                    Text("Downloading result…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Dataset Row
    
    private func datasetRow(session: RecordedSession) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedSession = session
                selectedSource = nil
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        if session.hasVideo { Label("Video", systemImage: "video.fill") }
                        if session.hasEXR { Label("EXR", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                        Label("\(session.frameCount)", systemImage: "photo.stack")
                        Label(sessionSizeString(session.diskSizeMB), systemImage: "internaldrive")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.cyan)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUploading || viewModel.isCreatingZIP || viewModel.isGeneratingEXR)
    }
    
    // MARK: - Dataset Workflow (Step-by-Step)
    
    private func datasetWorkflow(session: RecordedSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selected dataset info
            HStack(spacing: 10) {
                Image(systemName: "doc.zipper")
                    .font(.title3)
                    .foregroundStyle(.cyan)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        Label("\(session.frameCount) frames", systemImage: "photo.stack")
                        Label(sessionSizeString(session.diskSizeMB), systemImage: "internaldrive")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 12))
            
            // Step 1: Source Selection
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    stepBadge(number: 1, isActive: selectedSource == nil, isComplete: selectedSource != nil)
                    Text("Choose Source")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(selectedSource == nil ? .white : .secondary)
                }
                
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
                        // EXR not available but can be generated
                        sourceButton(
                            source: .exr,
                            icon: "wand.and.stars",
                            description: "Generate from video",
                            isSelected: selectedSource == .exr
                        )
                    }
                }
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
            
            // Step 2 & 3: Settings & Upload (shown after source selection)
            if selectedSource != nil {
                VStack(alignment: .leading, spacing: 12) {
                    // Step 2: Settings
                    HStack(spacing: 6) {
                        stepBadge(number: 2, isActive: true, isComplete: false)
                        Text("Processing Settings")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Button {
                            showProcessingSettings = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "slider.horizontal.3")
                                Text("Configure")
                            }
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.purple.opacity(0.15), in: Capsule())
                        }
                    }
                    
                    // Quick info about current settings
                    settingsSummary
                        .transition(.opacity)
                    
                    Divider().background(.white.opacity(0.1))
                    
                    // Step 3: Upload & Process
                    HStack(spacing: 6) {
                        stepBadge(number: 3, isActive: true, isComplete: false)
                        Text("Upload & Process")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    
                    Button {
                        viewModel.uploadSource = selectedSource ?? .video
                        Task {
                            await viewModel.performUpload(session: session)
                            // After successful upload, auto-start processing
                            if let datasetId = viewModel.lastDatasetId {
                                await viewModel.startProcessing(datasetId: datasetId)
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    selectedSession = nil
                                    selectedSource = nil
                                    sessions = CaptureSession.listSessions()
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Upload & Start Processing")
                            Spacer()
                            Image(systemName: selectedSource == .exr ? "photo.stack.fill" : "video.fill")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(
                            LinearGradient(
                                colors: [.cyan.opacity(0.8), .blue.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .disabled(viewModel.isUploading || viewModel.isCreatingZIP)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }
    
    // MARK: - Source Button
    
    private func sourceButton(source: ReMapUploadSource, icon: String, description: String, isSelected: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedSource = source
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(source.rawValue)
                    .font(.caption).fontWeight(.semibold)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color(white: 0.08)),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? .cyan : .clear, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? .cyan : .white)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Step Badge
    
    private func stepBadge(number: Int, isActive: Bool, isComplete: Bool) -> some View {
        ZStack {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
            } else {
                Text("\(number)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? .black : .secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        isActive ? AnyShapeStyle(.cyan) : AnyShapeStyle(Color(white: 0.2)),
                        in: Circle()
                    )
            }
        }
    }
    
    // MARK: - Settings Summary
    
    private var settingsSummary: some View {
        let s = viewModel.processingSettings
        return HStack(spacing: 12) {
            settingChip(icon: "speedometer", text: "\(String(format: "%.1f", s.fps)) fps")
            settingChip(icon: "sparkle.magnifyingglass", text: s.featureType)
            settingChip(icon: "map", text: s.mapperType)
        }
    }
    
    private func settingChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(white: 0.1), in: Capsule())
    }
    
    // MARK: - Failed Jobs Section
    
    private var failedJobsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Failed / Cancelled")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(viewModel.failedJobs.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(viewModel.failedJobs) { job in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: job.parsedStatus.icon)
                                .foregroundStyle(Color.fromString(job.parsedStatus.color))
                            Text(job.jobId.prefix(12) + "…")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white)
                        }
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
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Progress Row
    
    private func progressRow(label: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ProgressView()
                    .tint(color)
                    .scaleEffect(0.8)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(color)
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
    
    // MARK: - Helpers
    
    private func sessionSizeString(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
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
