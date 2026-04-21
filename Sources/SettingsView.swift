import SwiftUI
import AVFoundation
import ServiceManagement

// MARK: - Shared Helpers

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(_ title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private let iso8601DayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

// MARK: - Shared Download Status Views

@MainActor
@ViewBuilder
private func whisperKitDownloadStatus(
    for variant: String,
    downloads: WhisperKitDownloadManager
) -> some View {
    let isActive = downloads.isDownloading && downloads.currentVariant == variant
    let isCached = downloads.cachedFolder(for: variant) != nil

    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Text("Model status:")
                .font(.caption)
            Spacer()
            if isActive {
                Text("\(Int(downloads.progressFraction * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if isCached {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            } else {
                Button("Download now") {
                    Task {
                        _ = try? await downloads.ensureModel(variant: variant)
                    }
                }
                .font(.caption)
            }
        }
        if isActive {
            ProgressView(value: downloads.progressFraction)
                .progressViewStyle(.linear)
        }
        if let error = downloads.errorMessage, downloads.currentVariant == variant {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

@MainActor
@ViewBuilder
private func localLLMDownloadStatus(
    for modelId: String,
    downloads: LLMDownloadManager
) -> some View {
    let isActive = downloads.isDownloading && downloads.currentModelId == modelId
    let isReady = downloads.isReady(modelId: modelId)

    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Text("Model status:")
                .font(.caption)
            Spacer()
            if isActive {
                Text("\(Int(downloads.progressFraction * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if isReady {
                Label("Loaded", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            } else {
                Button("Download & load now") {
                    Task.detached(priority: .userInitiated) {
                        _ = try? await MLXModelContainerPool.shared.loadOrReturn(modelId: modelId)
                    }
                }
                .font(.caption)
            }
        }
        if isActive {
            ProgressView(value: downloads.progressFraction)
                .progressViewStyle(.linear)
        }
        if let error = downloads.errorMessage, downloads.currentModelId == nil {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        appState.selectedSettingsTab = tab
                    } label: {
                        Label(tab.title, systemImage: tab.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(appState.selectedSettingsTab == tab
                                          ? Color.accentColor.opacity(0.15)
                                          : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(10)
            .frame(width: 180)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            Group {
                switch appState.selectedSettingsTab {
                case .general, .none:
                    GeneralSettingsView()
                case .prompts:
                    PromptsSettingsView()
                case .macros:
                    VoiceMacrosSettingsView()
                case .runLog:
                    RunLogView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    @AppStorage("show_menu_bar_icon") private var showMenuBarIcon = true
    @State private var customVocabularyInput: String = ""
    @State private var micPermissionGranted = false
    @State private var whisperKitChoice: WhisperKitModelChoice = .default
    @State private var localLLMChoice: LocalLLMModelChoice = .default
    @State private var transcriptionLanguage: TranscriptionLanguage = .auto
    @State private var pendingWhisperSwitch: WhisperKitModelChoice?
    @State private var pendingLLMSwitch: LocalLLMModelChoice?
    @State private var currentWhisperOnScreen: WhisperKitModelChoice = .default
    @State private var currentLLMOnScreen: LocalLLMModelChoice = .default
    @ObservedObject private var whisperKitDownloads = WhisperKitDownloadManager.shared
    @ObservedObject private var llmDownloads = LLMDownloadManager.shared
    @StateObject private var githubCache = GitHubMetadataCache.shared
    @ObservedObject private var updateManager = UpdateManager.shared
    private let freeflowRepoURL = URL(string: "https://github.com/verdana86/geMMaFloW")!

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // App branding header
                VStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)

                    Text("geMMaFloW")
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // GitHub card
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            AsyncImage(url: URL(string: "https://github.com/verdana86.png")) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Color.gray.opacity(0.2)
                                }
                            }
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())

                            Button {
                                openURL(freeflowRepoURL)
                            } label: {
                                Text("verdana86/geMMaFloW")
                                    .font(.system(.caption, design: .monospaced).weight(.medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption2)
                                if githubCache.isLoading {
                                    ProgressView().scaleEffect(0.5)
                                } else if let count = githubCache.starCount {
                                    Text("\(count.formatted()) \(count == 1 ? "star" : "stars")")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.yellow.opacity(0.14)))

                            Button {
                                openURL(freeflowRepoURL)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "star")
                                    Text("Star")
                                }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.yellow.opacity(0.18)))
                            }
                            .buttonStyle(.plain)
                        }

                        if !githubCache.recentStargazers.isEmpty {
                            Divider()
                            HStack(spacing: 8) {
                                HStack(spacing: -6) {
                                    ForEach(githubCache.recentStargazers) { star in
                                        Button {
                                            openURL(star.user.htmlUrl)
                                        } label: {
                                            AsyncImage(url: star.user.avatarThumbnailUrl) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                default:
                                                    Color.gray.opacity(0.2)
                                                }
                                            }
                                            .frame(width: 22, height: 22)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .clipped()
                                Text("recently starred")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .fixedSize()
                                Spacer()
                            }
                            .clipped()
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 4)

                SettingsCard("App", icon: "power") {
                    startupSection
                }
                SettingsCard("Updates", icon: "arrow.triangle.2.circlepath") {
                    updatesSection
                }
                SettingsCard("Transcription Model", icon: "waveform") {
                    transcriptionModelSection
                }
                SettingsCard("Post-Processing Model", icon: "sparkles") {
                    postProcessingModelSection
                }
                SettingsCard("Dictation Shortcuts", icon: "keyboard.fill") {
                    hotkeySection
                }
                SettingsCard("Edit Mode", icon: "pencil") {
                    commandModeSection
                }
                SettingsCard("Microphone", icon: "mic.fill") {
                    microphoneSection
                }
                SettingsCard("Alert Sounds", icon: "speaker.wave.2.fill") {
                    alertSoundsSection
                }
                if appState.postProcessingEnabled {
                    SettingsCard("Custom Vocabulary", icon: "text.book.closed.fill") {
                        vocabularySection
                    }
                }
                SettingsCard("Permissions", icon: "lock.shield.fill") {
                    permissionsSection
                }
            }
            .padding(24)
        }
        .onAppear {
            customVocabularyInput = appState.customVocabulary
            let initialWhisper = WhisperKitModelChoice.fromSentinelBaseURL(appState.transcriptionBaseURL) ?? .default
            let initialLLM = LocalLLMModelChoice.fromSentinelBaseURL(appState.llmBaseURL) ?? .default
            whisperKitChoice = initialWhisper
            localLLMChoice = initialLLM
            currentWhisperOnScreen = initialWhisper
            currentLLMOnScreen = initialLLM
            transcriptionLanguage = TranscriptionLanguage.fromISO(appState.transcriptionLanguage)
            checkMicPermission()
            appState.refreshLaunchAtLoginStatus()
            Task { await githubCache.fetchIfNeeded() }
        }
        .onChange(of: appState.transcriptionBaseURL) { value in
            if let choice = WhisperKitModelChoice.fromSentinelBaseURL(value) {
                whisperKitChoice = choice
                currentWhisperOnScreen = choice
            }
        }
        .onChange(of: appState.llmBaseURL) { value in
            if let choice = LocalLLMModelChoice.fromSentinelBaseURL(value) {
                localLLMChoice = choice
                currentLLMOnScreen = choice
            }
        }
        .alert(
            pendingWhisperSwitch.map { "Switch transcription model to \($0.displayName)?" } ?? "",
            isPresented: Binding(
                get: { pendingWhisperSwitch != nil },
                set: { if !$0 { cancelWhisperSwitch() } }
            ),
            presenting: pendingWhisperSwitch
        ) { newChoice in
            Button("Download & switch") { confirmWhisperSwitch(to: newChoice) }
            Button("Cancel", role: .cancel) { cancelWhisperSwitch() }
        } message: { newChoice in
            Text(whisperSwitchMessage(to: newChoice))
        }
        .alert(
            pendingLLMSwitch.map { "Switch post-processing model to \($0.displayName)?" } ?? "",
            isPresented: Binding(
                get: { pendingLLMSwitch != nil },
                set: { if !$0 { cancelLLMSwitch() } }
            ),
            presenting: pendingLLMSwitch
        ) { newChoice in
            Button("Download & switch") { confirmLLMSwitch(to: newChoice) }
            Button("Cancel", role: .cancel) { cancelLLMSwitch() }
        } message: { newChoice in
            Text(llmSwitchMessage(to: newChoice))
        }
    }

    // MARK: Model switch helpers

    private static let megabyte: Double = 1024 * 1024

    private func whisperSwitchMessage(to newChoice: WhisperKitModelChoice) -> String {
        let oldBytes = ModelCacheCleaner.whisperKitVariantSizeBytes(variant: currentWhisperOnScreen.whisperKitIdentifier)
        let existingBytes = ModelCacheCleaner.whisperKitVariantSizeBytes(variant: newChoice.whisperKitIdentifier)
        var lines: [String] = []
        if existingBytes > 0 {
            lines.append("\(newChoice.displayName) is already on disk — no download needed.")
        } else {
            lines.append("Will download \(newChoice.displayName) now.")
        }
        if oldBytes > 0 {
            let freed = String(format: "%.0f MB", Double(oldBytes) / Self.megabyte)
            lines.append("The current model (\(currentWhisperOnScreen.displayName)) will be removed from disk — frees about \(freed).")
        }
        return lines.joined(separator: "\n\n")
    }

    private func llmSwitchMessage(to newChoice: LocalLLMModelChoice) -> String {
        let oldBytes = ModelCacheCleaner.gemmaCacheSizeBytes(modelId: currentLLMOnScreen.mlxModelId)
        let existingBytes = ModelCacheCleaner.gemmaCacheSizeBytes(modelId: newChoice.mlxModelId)
        var lines: [String] = []
        if existingBytes > 0 {
            lines.append("\(newChoice.displayName) is already on disk — no download needed.")
        } else {
            lines.append("Will download \(newChoice.displayName) now.")
        }
        if oldBytes > 0 {
            let freed = String(format: "%.1f GB", Double(oldBytes) / (Self.megabyte * 1024))
            lines.append("The current model (\(currentLLMOnScreen.displayName)) will be removed from disk — frees about \(freed).")
        }
        return lines.joined(separator: "\n\n")
    }

    private func cancelWhisperSwitch() {
        // Picker is bound to whisperKitChoice; revert it back to what
        // appState actually has, so the UI doesn't display a staged value.
        whisperKitChoice = currentWhisperOnScreen
        pendingWhisperSwitch = nil
    }

    private func cancelLLMSwitch() {
        localLLMChoice = currentLLMOnScreen
        pendingLLMSwitch = nil
    }

    private func confirmWhisperSwitch(to newChoice: WhisperKitModelChoice) {
        let old = currentWhisperOnScreen
        pendingWhisperSwitch = nil
        // Update sentinel + screen state first so all pickers/bindings stay
        // in sync while the async cleanup + download runs in the background.
        appState.transcriptionBaseURL = newChoice.sentinelBaseURL
        currentWhisperOnScreen = newChoice
        let oldVariant = old.whisperKitIdentifier
        let newVariant = newChoice.whisperKitIdentifier
        Task.detached(priority: .userInitiated) {
            await WhisperKitInstancePool.shared.evict(modelVariant: oldVariant)
            await WhisperKitDownloadManager.shared.evict(variant: oldVariant)
            ModelCacheCleaner.deleteWhisperKitVariant(variant: oldVariant)
            _ = try? await WhisperKitInstancePool.shared.loadOrReturn(modelVariant: newVariant)
        }
    }

    private func confirmLLMSwitch(to newChoice: LocalLLMModelChoice) {
        let old = currentLLMOnScreen
        pendingLLMSwitch = nil
        appState.llmBaseURL = newChoice.sentinelBaseURL
        currentLLMOnScreen = newChoice
        let oldModelId = old.mlxModelId
        let newModelId = newChoice.mlxModelId
        let wantsWarmup = appState.postProcessingEnabled
        Task.detached(priority: .userInitiated) {
            await MLXModelContainerPool.shared.evict(modelId: oldModelId)
            ModelCacheCleaner.deleteGemmaCache(modelId: oldModelId)
            if wantsWarmup {
                _ = try? await MLXModelContainerPool.shared.loadOrReturnWithPrimedCache(
                    modelId: newModelId,
                    systemPrompt: PostProcessingService.localDictationSystemPrompt
                )
            } else {
                _ = try? await MLXModelContainerPool.shared.loadOrReturn(modelId: newModelId)
            }
        }
    }

    // MARK: Startup

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Launch geMMaFloW at login", isOn: $appState.launchAtLogin)
            Toggle("Show menu bar icon", isOn: $showMenuBarIcon)

            if SMAppService.mainApp.status == .requiresApproval {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Login item requires approval in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Login Items Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: Updates

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Automatically check for updates", isOn: Binding(
                get: { updateManager.autoCheckEnabled },
                set: { updateManager.autoCheckEnabled = $0 }
            ))

            HStack(spacing: 10) {
                Button {
                    Task {
                        await updateManager.checkForUpdates(userInitiated: true)
                    }
                } label: {
                    if updateManager.isChecking {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Checking...")
                        }
                    } else {
                        Text("Check for Updates Now")
                    }
                }
                .disabled(updateManager.isChecking || updateManager.updateStatus != .idle)

                if let lastCheck = updateManager.lastCheckDate {
                    Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if updateManager.updateAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    switch updateManager.updateStatus {
                    case .downloading:
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Downloading update...")
                                    .font(.caption.weight(.semibold))
                                ProgressView(value: updateManager.downloadProgress ?? 0)
                                    .progressViewStyle(.linear)
                                if let progress = updateManager.downloadProgress {
                                    Text("\(Int(progress * 100))%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Cancel") {
                                updateManager.cancelDownload()
                            }
                            .font(.caption)
                        }

                    case .installing:
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Installing update...")
                                .font(.caption.weight(.semibold))
                        }

                    case .readyToRelaunch:
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Relaunching...")
                                .font(.caption.weight(.semibold))
                        }

                    case .error(let message):
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                            Spacer()
                            Button("Retry") {
                                updateManager.updateStatus = .idle
                                if let release = updateManager.latestRelease {
                                    updateManager.downloadAndInstall(release: release)
                                }
                            }
                            .font(.caption)
                        }

                    case .idle:
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.blue)
                            Text("A new version of geMMaFloW is available!")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Button("Update Now") {
                                if let release = updateManager.latestRelease {
                                    updateManager.downloadAndInstall(release: release)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    // MARK: Transcription Model

    private var transcriptionModelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Model")
                    .font(.caption.weight(.semibold))
                Picker("Model", selection: $whisperKitChoice) {
                    ForEach(WhisperKitModelChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                .labelsHidden()
                .onChange(of: whisperKitChoice) { newValue in
                    guard newValue != currentWhisperOnScreen else { return }
                    pendingWhisperSwitch = newValue
                }
                whisperKitDownloadStatus(for: whisperKitChoice.whisperKitIdentifier, downloads: whisperKitDownloads)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Language")
                    .font(.caption.weight(.semibold))
                Picker("Language", selection: $transcriptionLanguage) {
                    ForEach(TranscriptionLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .onChange(of: transcriptionLanguage) { newValue in
                    guard appState.transcriptionLanguage != newValue.isoCode else { return }
                    appState.transcriptionLanguage = newValue.isoCode
                }
                Text("Auto-detect works but can be unreliable on short clips — pick a specific language to lock it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Post-Processing Model

    private var postProcessingModelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Clean up transcript with Gemma", isOn: $appState.postProcessingEnabled)
                .toggleStyle(.switch)

            Text("When off, dictation pastes the raw Whisper transcript — faster (no 1–2s LLM pass) but with less punctuation and filler cleanup. Edit Mode still uses Gemma on demand.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if appState.postProcessingEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Model")
                        .font(.caption.weight(.semibold))
                    Picker("Model", selection: $localLLMChoice) {
                        ForEach(LocalLLMModelChoice.allCases) { choice in
                            Text(choice.displayName).tag(choice)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: localLLMChoice) { newValue in
                        guard newValue != currentLLMOnScreen else { return }
                        pendingLLMSwitch = newValue
                    }
                    localLLMDownloadStatus(for: localLLMChoice.mlxModelId, downloads: llmDownloads)
                }
            }
        }
    }

    // MARK: Dictation Shortcuts

    private var hotkeySection: some View {
        DictationShortcutEditor { isCapturing in
            if isCapturing {
                appState.suspendHotkeyMonitoringForShortcutCapture()
            } else {
                appState.resumeHotkeyMonitoringAfterShortcutCapture()
            }
        }
    }

    private var commandModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable Edit Mode", isOn: Binding(
                get: { appState.isCommandModeEnabled },
                set: { newValue in
                    _ = appState.setCommandModeEnabled(newValue)
                }
            ))

            Text("Transform highlighted text with a spoken instruction instead of dictating over it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Invocation Style", selection: Binding(
                get: { appState.commandModeStyle },
                set: { newValue in
                    _ = appState.setCommandModeStyle(newValue)
                }
            )) {
                ForEach(CommandModeStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!appState.isCommandModeEnabled)

            Group {
                switch appState.commandModeStyle {
                case .automatic:
                    Text("If text is selected, your normal dictation shortcut transforms the selection instead of dictating over it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .manual:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hold the extra modifier together with your normal dictation shortcut to transform selected text.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Extra Modifier", selection: Binding(
                            get: { appState.commandModeManualModifier },
                            set: { newValue in
                                _ = appState.setCommandModeManualModifier(newValue)
                            }
                        )) {
                            ForEach(CommandModeManualModifier.allCases) { modifier in
                                Text(modifier.title).tag(modifier)
                            }
                        }
                        .disabled(!appState.isCommandModeEnabled || appState.commandModeStyle != .manual)
                    }
                }
            }
            .opacity(appState.isCommandModeEnabled ? 1 : 0.5)

            if let validationMessage = appState.commandModeManualModifierValidationMessage {
                Label(validationMessage, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: Clipboard

    // MARK: Microphone

    private var microphoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select which microphone to use for recording.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                MicrophoneOptionRow(
                    name: "System Default",
                    isSelected: appState.selectedMicrophoneID == "default" || appState.selectedMicrophoneID.isEmpty,
                    action: { appState.selectedMicrophoneID = "default" }
                )
                ForEach(appState.availableMicrophones) { device in
                    MicrophoneOptionRow(
                        name: device.name,
                        isSelected: appState.selectedMicrophoneID == device.uid,
                        action: { appState.selectedMicrophoneID = device.uid }
                    )
                }
            }
        }
        .onAppear {
            appState.refreshAvailableMicrophones()
        }
    }

    // MARK: Alert Sounds

    private var alertSoundsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Play alert sounds on record start and stop", isOn: $appState.alertSoundsEnabled)
        }
    }

    // MARK: Custom Vocabulary

    private var vocabularySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Words and phrases to preserve during post-processing.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $customVocabularyInput)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: customVocabularyInput) { newValue in
                    appState.customVocabulary = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }

            Text("Separate entries with commas, new lines, or semicolons.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Permissions

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            permissionRow(
                title: "Microphone",
                icon: "mic.fill",
                granted: micPermissionGranted,
                action: {
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        DispatchQueue.main.async {
                            micPermissionGranted = granted
                        }
                    }
                }
            )

            permissionRow(
                title: "Accessibility",
                icon: "hand.raised.fill",
                granted: appState.hasAccessibility,
                action: {
                    appState.openAccessibilitySettings()
                }
            )

            permissionRow(
                title: "Screen Recording",
                icon: "camera.viewfinder",
                granted: appState.hasScreenRecordingPermission,
                action: {
                    appState.requestScreenCapturePermission()
                }
            )
        }
    }

    private func permissionRow(title: String, icon: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.blue)
            Text(title)
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Granted")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button("Grant Access") {
                    action()
                }
                .font(.caption)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private func checkMicPermission() {
        micPermissionGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

}

// MARK: - Microphone Option Row

struct MicrophoneOptionRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Prompts Settings

struct PromptsSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsCard("System Prompt", icon: "text.bubble.fill") {
                    systemPromptSection
                }
                SettingsCard("Context Prompt", icon: "eye.fill") {
                    contextPromptSection
                }
            }
            .padding(24)
        }
    }

    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Optimized for the bundled Gemma 4B model — not editable.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(PostProcessingService.localDictationSystemPrompt)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
        }
    }

    private var contextPromptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tells the context model how to summarise the frontmost app's screenshot + metadata into the activity hint passed to post-processing.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(AppContextService.defaultContextPrompt)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
        }
    }
}

// MARK: - Run Log

struct RunLogView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Run Log")
                        .font(.headline)
                    Text("Stored locally. Only the \(appState.maxPipelineHistoryCount) most recent runs are kept.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Clear History") {
                    appState.clearPipelineHistory()
                }
                .disabled(appState.pipelineHistory.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            if appState.pipelineHistory.isEmpty {
                VStack {
                    Spacer()
                    Text("No runs yet. Use dictation to populate history.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appState.pipelineHistory) { item in
                            RunLogEntryView(item: item)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

// MARK: - Run Log Entry

struct RunLogEntryView: View {
    let item: PipelineHistoryItem
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = false
    @State private var isRetrying = false
    @State private var showContextPrompt = false
    @State private var showPostProcessingPrompt = false

    private var isError: Bool {
        item.postProcessingStatus.hasPrefix("Error:")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        if isError {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.timestamp.formatted(date: .numeric, time: .standard))
                                .font(.subheadline.weight(.semibold))
                            Text(item.postProcessedTranscript.isEmpty ? "(no transcript)" : item.postProcessedTranscript)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isError && item.audioFileName != nil {
                    Button {
                        appState.retryTranscription(item: item)
                    } label: {
                        if isRetrying {
                            ProgressView()
                                .controlSize(.mini)
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isRetrying)
                    .help("Retry transcription")
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.deleteHistoryEntry(id: item.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete this run")
            }
            .padding(12)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 16) {
                    // Audio player
                    if let audioFileName = item.audioFileName {
                        let audioURL = AppState.audioStorageDirectory().appendingPathComponent(audioFileName)
                        AudioPlayerView(audioURL: audioURL)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("No audio recorded")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Custom vocabulary
                    if !item.customVocabulary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Custom Vocabulary")
                                .font(.caption.weight(.semibold))
                            FlowLayout(spacing: 4) {
                                ForEach(parseVocabulary(item.customVocabulary), id: \.self) { word in
                                    Text(word)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    // Pipeline steps
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pipeline")
                            .font(.caption.weight(.semibold))

                        // Step 1: Context Capture
                        PipelineStepView(
                            number: 1,
                            title: "Capture Context",
                            content: {
                                VStack(alignment: .leading, spacing: 6) {
                                    if let dataURL = item.contextScreenshotDataURL,
                                       let image = imageFromDataURL(dataURL) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxHeight: 120)
                                            .cornerRadius(4)
                                    }

                                    if let prompt = item.contextPrompt, !prompt.isEmpty {
                                        Button {
                                            showContextPrompt.toggle()
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(showContextPrompt ? "Hide Prompt" : "Show Prompt")
                                                    .font(.caption)
                                                Image(systemName: showContextPrompt ? "chevron.up" : "chevron.down")
                                                    .font(.caption2)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(Color.accentColor)

                                        if showContextPrompt {
                                            Text(prompt)
                                                .font(.system(.caption2, design: .monospaced))
                                                .textSelection(.enabled)
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color(nsColor: .controlBackgroundColor))
                                                .cornerRadius(4)
                                        }
                                    }

                                    if !item.contextSummary.isEmpty {
                                        Text(item.contextSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    } else {
                                        Text("No context captured")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        )

                        // Step 2: Transcribe Audio
                        PipelineStepView(
                            number: 2,
                            title: "Transcribe Audio",
                            content: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sent audio to the configured transcription model")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                    if !item.rawTranscript.isEmpty {
                                        Text(item.rawTranscript)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .cornerRadius(4)
                                    } else {
                                        Text("(empty transcript)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        )

                        // Step 3: Post-Process
                        PipelineStepView(
                            number: 3,
                            title: "Post-Process",
                            content: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.postProcessingStatus)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)

                                    if let prompt = item.postProcessingPrompt, !prompt.isEmpty {
                                        Button {
                                            showPostProcessingPrompt.toggle()
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(showPostProcessingPrompt ? "Hide Prompt" : "Show Prompt")
                                                    .font(.caption)
                                                Image(systemName: showPostProcessingPrompt ? "chevron.up" : "chevron.down")
                                                    .font(.caption2)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(Color.accentColor)

                                        if showPostProcessingPrompt {
                                            Text(prompt)
                                                .font(.system(.caption2, design: .monospaced))
                                                .textSelection(.enabled)
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color(nsColor: .controlBackgroundColor))
                                                .cornerRadius(4)
                                        }
                                    }

                                    if !item.postProcessedTranscript.isEmpty {
                                        Text(item.postProcessedTranscript)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isError ? Color.red.opacity(0.4) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .onReceive(appState.$retryingItemIDs) { ids in
            isRetrying = ids.contains(item.id)
        }
    }

    private func parseVocabulary(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Pipeline Step View

struct PipelineStepView<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Audio Player

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.onFinish?()
        }
    }
}

struct AudioPlayerView: View {
    let audioURL: URL
    @State private var player: AVAudioPlayer?
    @State private var delegate = AudioPlayerDelegate()
    @State private var isPlaying = false
    @State private var duration: TimeInterval = 0
    @State private var elapsed: TimeInterval = 0
    @State private var progressTimer: Timer?

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsed / duration, 1.0)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.body)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(0, geo.size.width * progress), height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 28)

            Text("\(formatDuration(elapsed)) / \(formatDuration(duration))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .onAppear {
            loadDuration()
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private func loadDuration() {
        guard FileManager.default.fileExists(atPath: audioURL.path) else { return }
        if let p = try? AVAudioPlayer(contentsOf: audioURL) {
            duration = p.duration
        }
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            guard FileManager.default.fileExists(atPath: audioURL.path) else { return }
            do {
                let p = try AVAudioPlayer(contentsOf: audioURL)
                delegate.onFinish = {
                    self.stopPlayback()
                }
                p.delegate = delegate
                p.play()
                player = p
                isPlaying = true
                elapsed = 0
                startProgressTimer()
            } catch {}
        }
    }

    private func stopPlayback() {
        progressTimer?.invalidate()
        progressTimer = nil
        player?.stop()
        player = nil
        isPlaying = false
        elapsed = 0
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if let p = player, p.isPlaying {
                elapsed = p.currentTime
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let pos = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Voice Macros Settings

struct VoiceMacrosSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddMacro = false
    @State private var editingMacro: VoiceMacro?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsCard("Voice Macros", icon: "music.mic") {
                    macrosSection
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingAddMacro, onDismiss: { editingMacro = nil }) {
            VoiceMacroEditorView(isPresented: $showingAddMacro, macro: $editingMacro)
        }
    }

    private var macrosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bypass post-processing and immediately paste your predefined text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { showingAddMacro = true }) {
                    Text("Add Macro")
                }
            }

            if appState.voiceMacros.isEmpty {
                VStack {
                    Image(systemName: "music.mic")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 4)
                    Text("No Voice Macros Yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Click 'Add Macro' to define your first voice macro.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 1) {
                    ForEach(Array(appState.voiceMacros.enumerated()), id: \.element.id) { index, macro in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(macro.command)
                                    .font(.headline)
                                Spacer()
                                Button("Edit") {
                                    editingMacro = macro
                                    showingAddMacro = true
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                
                                Button("Delete") {
                                    appState.voiceMacros.removeAll { $0.id == macro.id }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .foregroundStyle(.red)
                            }
                            Text(macro.payload)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    }
                }
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.06), lineWidth: 1))
            }
        }
    }
}

struct VoiceMacroEditorView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @Binding var macro: VoiceMacro?

    @State private var command: String = ""
    @State private var payload: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(macro == nil ? "Add Macro" : "Edit Macro")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Command (What you say)")
                    .font(.caption.weight(.semibold))
                TextField("e.g. debugging prompt", text: $command)
                    .textFieldStyle(.roundedBorder)

                Text("Text (What gets pasted)")
                    .font(.caption.weight(.semibold))
                    .padding(.top, 8)
                TextEditor(text: $payload)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 150)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                    macro = nil
                }
                Spacer()
                Button("Save") {
                    let newMacro = VoiceMacro(
                        id: macro?.id ?? UUID(),
                        command: command.trimmingCharacters(in: .whitespacesAndNewlines),
                        payload: payload
                    )
                    
                    if let existingIndex = appState.voiceMacros.firstIndex(where: { $0.id == newMacro.id }) {
                        appState.voiceMacros[existingIndex] = newMacro
                    } else {
                        appState.voiceMacros.append(newMacro)
                    }
                    isPresented = false
                    macro = nil
                }
                .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || payload.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            if let m = macro {
                command = m.command
                payload = m.payload
            }
        }
    }
}
