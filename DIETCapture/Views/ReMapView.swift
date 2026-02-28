// ReMapView.swift
// ReScan
//
// Main ReMap integration view: server config, dataset upload, job monitoring,
// logs viewer, result download, and processing settings.

import SwiftUI

struct ReMapView: View {
    @State private var viewModel = ReMapViewModel()
    @State private var sessions: [RecordedSession] = []
    @State private var selectedSession: RecordedSession?
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var logsJobId: String?
    @State private var showProcessingSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Server Status
                        serverStatusCard
                        
                        if viewModel.isConfigured {
                            // Active Job
                            if viewModel.activeJobId != nil {
                                activeJobCard
                            }
                            
                            // Upload Section
                            uploadSection
                            
                            // Jobs List
                            jobsSection
                        } else {
                            configurePrompt
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
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
                        Button {
                            Task { await viewModel.refreshJobs() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
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
                if let jobId = logsJobId {
                    ReMapLogsView(viewModel: viewModel, jobId: jobId)
                }
            }
            .confirmationDialog(
                "Upload Source",
                isPresented: $viewModel.showSourcePicker,
                titleVisibility: .visible
            ) {
                Button("RGB Video (smaller, faster)") {
                    viewModel.uploadSource = .video
                    if let session = selectedSession {
                        Task { await viewModel.performUpload(session: session) }
                    }
                }
                Button("EXR Sequence (higher quality)") {
                    viewModel.uploadSource = .exr
                    if let session = selectedSession {
                        Task { await viewModel.performUpload(session: session) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This dataset has both RGB video and EXR frames. Which source would you like to use for processing?")
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
            }
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
    
    // MARK: - Upload Section
    
    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.arrow.up.fill")
                    .foregroundStyle(.cyan)
                Text("Upload Dataset")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    showProcessingSettings = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Settings")
                    }
                    .font(.caption)
                    .foregroundStyle(.purple)
                }
            }
            
            if viewModel.isCreatingZIP {
                progressRow(label: "Creating ZIP…", progress: viewModel.zipProgress, color: .orange)
            } else if viewModel.isUploading {
                progressRow(label: "Uploading…", progress: viewModel.uploadProgress, color: .cyan)
            } else {
                if sessions.isEmpty {
                    Text("No datasets available. Capture a scan first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions.prefix(5)) { session in
                        datasetRow(session: session)
                    }
                    
                    if sessions.count > 5 {
                        Text("\(sessions.count - 5) more datasets available…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Process button (if dataset uploaded)
            if let datasetId = viewModel.lastDatasetId, !viewModel.isStartingProcess {
                Divider().background(.white.opacity(0.1))
                
                Button {
                    Task { await viewModel.startProcessing(datasetId: datasetId) }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Processing")
                        Spacer()
                        Text(datasetId.prefix(8) + "…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(
                        LinearGradient(colors: [.green.opacity(0.8), .cyan.opacity(0.6)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
            }
            
            if viewModel.isStartingProcess {
                HStack {
                    ProgressView().tint(.cyan)
                    Text("Starting processing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Dataset Row
    
    private func datasetRow(session: RecordedSession) -> some View {
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
            
            Button {
                selectedSession = session
                Task { await viewModel.uploadDataset(session: session) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
            }
            .disabled(viewModel.isUploading || viewModel.isCreatingZIP)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Active Job Card
    
    private var activeJobCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(.blue)
                    .symbolEffect(.rotate, isActive: viewModel.isPolling)
                
                Text("Active Job")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if let status = viewModel.activeJobStatus {
                    let jobStatus = ReMapJobStatus(rawValue: status.status) ?? .processing
                    HStack(spacing: 4) {
                        Image(systemName: jobStatus.icon)
                        Text(jobStatus.label)
                    }
                    .font(.caption)
                    .foregroundStyle(Color.fromString(jobStatus.color))
                }
            }
            
            if let status = viewModel.activeJobStatus {
                ProgressView(value: Double(status.progress) / 100.0)
                    .tint(.cyan)
                
                HStack {
                    Text("\(status.progress)%")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    if let step = status.currentStep {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(step)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    // View Logs
                    Button {
                        logsJobId = viewModel.activeJobId
                        showLogs = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text("Logs")
                        }
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    }
                    
                    let parsedStatus = ReMapJobStatus(rawValue: status.status)
                    
                    // Cancel
                    if parsedStatus == .processing || parsedStatus == .queued {
                        Button {
                            if let jobId = viewModel.activeJobId {
                                Task { await viewModel.cancelJob(jobId: jobId) }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.fill")
                                Text("Cancel")
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }
                    
                    // Download
                    if parsedStatus == .completed {
                        Button {
                            if let jobId = viewModel.activeJobId {
                                Task { await viewModel.downloadResult(jobId: jobId) }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download Result")
                            }
                            .font(.caption)
                            .foregroundStyle(.green)
                        }
                        .disabled(viewModel.isDownloading)
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
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.cyan.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Jobs Section
    
    private var jobsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.cyan)
                Text("Jobs History")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(viewModel.jobs.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if viewModel.jobs.isEmpty {
                Text("No jobs yet. Upload and process a dataset to get started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.jobs) { job in
                    jobRow(job: job)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Job Row
    
    private func jobRow(job: ReMapJobListItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: job.parsedStatus.icon)
                        .foregroundStyle(Color.fromString(job.parsedStatus.color))
                    Text(job.jobId.prefix(12) + "…")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                HStack(spacing: 8) {
                    Text(job.parsedStatus.label)
                        .foregroundStyle(Color.fromString(job.parsedStatus.color))
                    if let step = job.currentStep {
                        Text(step)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(job.progress)%")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Logs
                Button {
                    logsJobId = job.jobId
                    showLogs = true
                } label: {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
                
                // Track / Download depending on status
                if job.parsedStatus == .completed {
                    Button {
                        Task { await viewModel.downloadResult(jobId: job.jobId) }
                    } label: {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } else if !job.parsedStatus.isTerminal {
                    Button {
                        viewModel.startPolling(jobId: job.jobId)
                    } label: {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                
                // Cancel if active
                if !job.parsedStatus.isTerminal {
                    Button {
                        Task { await viewModel.cancelJob(jobId: job.jobId) }
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
            }
        }
        .padding(.vertical, 6)
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
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadLogs(jobId: jobId)
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
