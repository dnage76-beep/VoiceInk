import SwiftUI

struct ModeConfigFormView: View {
    let mode: ConfigurationMode
    let modeManager: ModeManager
    @Binding var draft: ModeConfigDraft
    @Binding var validationErrors: [ModeValidationError]
    @Binding var showValidationAlert: Bool
    let onDismiss: () -> Void
    let onSave: () -> Void
    let onDelete: () -> ModeRemovalResult
    let openPromptEditor: (PromptEditorView.Mode) -> Void

    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var modeWarmupStore: ModeFormWarmupStore
    @FocusState private var isNameFieldFocused: Bool

    @State private var isShowingIconPicker = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDefaultModeDeleteAlert = false
    @State private var isContextAwarenessExpanded = false
    @State private var isScreenRecordingGranted = CGPreflightScreenCaptureAccess()

    private var isDeletingDefaultMode: Bool {
        modeManager.getConfiguration(with: draft.id)?.isDefault == true
    }

    private var effectiveModelName: String? {
        draft.selectedTranscriptionModelName
    }

    private var warmupSnapshot: ModeFormWarmupSnapshot {
        modeWarmupStore.snapshot
    }

    private var selectedTranscriptionModel: (any TranscriptionModel)? {
        warmupSnapshot.transcriptionModel(named: effectiveModelName)
    }

    private var selectedPrompt: CustomPrompt? {
        guard let selectedPromptId = draft.selectedPromptId else { return nil }
        return warmupSnapshot.prompts.first { $0.id == selectedPromptId }
    }

    private var aiProviderOptions: [AIProvider] {
        warmupSnapshot.connectedAIProviders
    }

    private var configuredSelectedAIProvider: AIProvider? {
        let selectedProvider: AIProvider?
        if let providerName = draft.selectedAIProvider {
            selectedProvider = AIProvider(rawValue: providerName)
        } else {
            selectedProvider = aiProviderOptions.first
        }

        guard let selectedProvider,
            selectedProvider.supportsEnhancement,
            aiProviderOptions.contains(selectedProvider)
        else { return nil }

        return selectedProvider
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            formContent

            footer
        }
        .onAppear {
            applyOutputRules()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFieldFocused = true
            }
        }
        .onChange(of: draft.isAIEnhancementEnabled) { _, _ in
            applyOutputRules()
        }
        .onChange(of: draft.selectedPromptId) { _, _ in
            applyOutputRules()
        }
        .onChange(of: draft.selectedAIProvider) { _, _ in
            applyOutputRules()
        }
        .onChange(of: draft.selectedAIModel) { _, _ in
            applyOutputRules()
        }
        // The grant happens in System Settings, so re-check on return rather
        // than trusting the value read when the form opened.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isScreenRecordingGranted = CGPreflightScreenCaptureAccess()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                isShowingIconPicker.toggle()
            } label: {
                ModeIconView(icon: draft.icon, size: draft.icon.kind == .emoji ? 22 : 18)
                    .frame(width: 36, height: 36)
                    .background(
                        AppCardBackground(isSelected: false, cornerRadius: 18)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowingIconPicker, arrowEdge: .bottom) {
                ModeIconPickerView(
                    selectedIcon: $draft.icon,
                    isPresented: $isShowingIconPicker
                )
            }

            TextField("Mode name", text: $draft.name)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .focused($isNameFieldFocused)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(AppTheme.Surface.card)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        // The Form below scrolls, and without an opaque backing its rows show
        // through the header as they pass under it.
        .background(.regularMaterial)
        .overlay(Divider().opacity(0.5), alignment: .bottom)
        // Keeps the header above the scrolling content it overlaps.
        .zIndex(1)
    }

    private var formContent: some View {
        Form {
            ModeTriggerSection(
                appConfigs: $draft.appConfigs,
                websiteConfigs: $draft.websiteConfigs,
                triggerGroups: $draft.triggerGroups,
                triggerWords: $draft.triggerWords,
                modeId: draft.id,
                cleanURL: modeManager.cleanURL
            )
            transcriptionSection
            aiEnhancementSection
            advancedSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Delete Mode?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if case .edit = mode {
                Button("Delete", role: .destructive) {
                    if case .blockedDefault = onDelete() {
                        isShowingDefaultModeDeleteAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                String(
                    format: String(localized: "Are you sure you want to delete '%@'? This action cannot be undone."),
                    draft.name))
        }
        .alert(
            "Default Mode Can’t Be Deleted",
            isPresented: $isShowingDefaultModeDeleteAlert,
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(
                    String(
                        format: String(
                            localized: "'%@' is the default mode. Set another mode as default before deleting it."
                        ),
                        draft.name
                    )
                )
            }
        )
        .modeValidationAlert(errors: validationErrors, isPresented: $showValidationAlert)
    }

    private var transcriptionSection: some View {
        Section("Transcription") {
            if warmupSnapshot.usableTranscriptionModels.isEmpty {
                Text(
                    "No transcription models available. Please connect to a cloud service or download a local model in the AI Models tab."
                )
                .foregroundColor(.secondary)
            } else {
                let modelBinding = Binding<String?>(
                    get: { draft.selectedTranscriptionModelName },
                    set: { draft.selectedTranscriptionModelName = $0 }
                )

                Picker(selection: modelBinding) {
                    // A placeholder prompting a choice, not a state the user
                    // can pick. It disappears once a model is selected.
                    if draft.selectedTranscriptionModelName == nil {
                        Label("Choose a model", systemImage: "waveform")
                            .tag(nil as String?)
                    }

                    ForEach(warmupSnapshot.usableTranscriptionModels, id: \.name) { model in
                        Text(model.displayName).tag(model.name as String?)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Model")
                        InfoTip(
                            "Which model turns your speech into text for this mode. This is the transcription step, separate from AI Enhancement below, which cleans the text up afterwards."
                        )
                    }
                }
                .onChange(of: draft.selectedTranscriptionModelName) { _, newModelName in
                    if let modelName = newModelName,
                        let model = warmupSnapshot.transcriptionModel(named: modelName)
                    {
                        draft.isRealtimeTranscriptionEnabled = TranscriptionRealtimeSupport.isAvailable(for: model)
                        if model.provider == .gemini {
                            draft.selectedLanguage = "auto"
                        } else {
                            draft.useCompatibleLanguage(for: model)
                        }
                    }
                }

                realtimeToggle
            }

            languagePicker

            ExpandableSettingsRow(
                title: "Transcription Formatting",
                isExpanded: $draft.isTranscriptionFormattingExpanded,
                summary: draft.isTextFormattingEnabled
                    ? String(localized: "Paragraph breaks on")
                    : String(localized: "Paragraph breaks off")
            ) {
                Toggle(isOn: $draft.isTextFormattingEnabled) {
                    HStack(spacing: 4) {
                        Text("Paragraph breaks")
                        InfoTip(
                            "Splits a long dictation into paragraphs instead of returning one solid block. This runs on the transcript itself, with no AI model involved."
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var realtimeToggle: some View {
        if let model = selectedTranscriptionModel,
            TranscriptionRealtimeSupport.isAvailable(for: model)
        {
            Toggle(isOn: $draft.isRealtimeTranscriptionEnabled) {
                HStack(spacing: 4) {
                    Text("Real-time")
                    InfoTip(
                        TranscriptionRealtimeSupport.isRequired(for: model)
                            ? "Transcribes while you speak instead of after you stop. This model only works this way, so it cannot be turned off here."
                            : "Transcribes while you speak, so the text is ready the moment you stop. Turn it off to transcribe the whole recording at the end, which some models handle more accurately."
                    )
                }
            }
            .disabled(TranscriptionRealtimeSupport.isRequired(for: model))
            .onAppear {
                if TranscriptionRealtimeSupport.isRequired(for: model) {
                    draft.isRealtimeTranscriptionEnabled = true
                }
            }
            .onChange(of: draft.isRealtimeTranscriptionEnabled) { _, _ in
                draft.useCompatibleLanguage(for: model)
            }
        }
    }

    @ViewBuilder
    private var languagePicker: some View {
        if languageSelectionDisabled() {
            LabeledContent("Language") {
                Text("Autodetected")
                    .foregroundColor(.secondary)
            }
            .onAppear {
                draft.selectedLanguage = "auto"
            }
        } else if let selectedModel = effectiveModelName,
            let modelInfo = warmupSnapshot.transcriptionModel(named: selectedModel),
            modelInfo.isMultilingualModel
        {
            let languageBinding = Binding<String?>(
                get: { effectiveLanguage(for: modelInfo) },
                set: { draft.selectedLanguage = $0 }
            )

            HStack(spacing: 8) {
                Text("Language")

                Spacer(minLength: 12)

                if modelInfo.provider == .nativeApple {
                    NativeAppleLanguageAssetControl(
                        localeIdentifier: effectiveLanguage(for: modelInfo),
                        isVisible: true,
                        startsDownloadAutomatically: true
                    )
                    .layoutPriority(1)
                    .frame(width: 28, height: 24)
                }

                Picker("", selection: languageBinding) {
                    ForEach(
                        availableLanguages(for: modelInfo).sorted(by: {
                            if $0.key == "auto" { return true }
                            if $1.key == "auto" { return false }
                            return $0.value < $1.value
                        }), id: \.key
                    ) { key, value in
                        Text(value).tag(key as String?)
                    }
                }
                .labelsHidden()
            }
            .onAppear {
                draft.selectedLanguage = effectiveLanguage(for: modelInfo)
            }
        } else if let selectedModel = effectiveModelName,
            let modelInfo = warmupSnapshot.transcriptionModel(named: selectedModel),
            !modelInfo.isMultilingualModel
        {
            EmptyView()
                .onAppear {
                    if draft.selectedLanguage == nil {
                        draft.selectedLanguage = "en"
                    }
                }
        }
    }

    private var aiEnhancementSection: some View {
        Section("AI Enhancement") {
            Toggle(isOn: $draft.isAIEnhancementEnabled) {
                HStack(spacing: 4) {
                    Text("AI Enhancement")
                    InfoTip(
                        "A second pass over the transcript: an AI model removes filler words, fixes punctuation, and applies the corrections you spoke out loud. Leave it off for the fastest possible paste."
                    )
                }
            }
            .onChange(of: draft.isAIEnhancementEnabled) { _, newValue in
                if newValue {
                    if configuredSelectedAIProvider == nil {
                        draft.selectedAIProvider = aiProviderOptions.first?.rawValue
                        draft.selectedAIModel = nil
                    }
                    if draft.selectedAIModel == nil,
                        let provider = configuredSelectedAIProvider,
                        provider != .localCLI
                    {
                        draft.selectedAIModel = warmupSnapshot.selectedModel(for: provider)
                    }
                    if draft.selectedPromptId == nil {
                        draft.selectedPromptId = warmupSnapshot.firstPromptId
                    }
                    if configuredSelectedAIProvider == .ollama {
                        aiService.refreshOllamaAvailabilityInBackground()
                    }
                }
            }

            let providerBinding = Binding<AIProvider>(
                get: {
                    configuredSelectedAIProvider ?? aiProviderOptions.first ?? .gemini
                },
                set: { newValue in
                    draft.selectedAIProvider = newValue.rawValue
                    draft.selectedAIModel = nil
                }
            )

            if draft.isAIEnhancementEnabled {
                let providerOptions = aiProviderOptions

                if providerOptions.isEmpty {
                    LabeledContent("AI Provider") {
                        Text("No providers connected")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else {
                    Picker(selection: providerBinding) {
                        ForEach(providerOptions, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("AI Provider")
                            InfoTip(
                                "Which service runs the enhancement for this mode. Only providers you have already connected on the AI Enhancement page appear here."
                            )
                        }
                    }
                    .onChange(of: draft.selectedAIProvider) { _, newValue in
                        if let provider = newValue.flatMap({ AIProvider(rawValue: $0) }) {
                            switch provider {
                            case .localCLI:
                                draft.selectedAIModel = nil
                            case .ollama:
                                if draft.selectedAIModel == nil || draft.selectedAIModel?.isEmpty == true {
                                    draft.selectedAIModel = warmupSnapshot.selectedModel(for: provider)
                                }
                                aiService.refreshOllamaAvailabilityInBackground()
                            default:
                                draft.selectedAIModel = provider.defaultModel
                            }
                        }
                    }
                }

                if let provider = configuredSelectedAIProvider {
                    aiModelPicker(for: provider)
                    promptPicker
                    contextAwarenessRow
                }
            }
        }
    }

    @ViewBuilder
    private func aiModelPicker(for provider: AIProvider) -> some View {
        if provider == .localCLI {
            LabeledContent("AI Model") {
                Text("Default")
                    .foregroundColor(.secondary)
            }
            .onAppear {
                draft.selectedAIModel = nil
            }
        } else {
            let models = aiModelOptions(for: provider)
            if models.isEmpty {
                LabeledContent("AI Model") {
                    Text(
                        provider == .openRouter
                            ? LocalizedStringKey("No models loaded") : LocalizedStringKey("No models available")
                    )
                    .foregroundColor(.secondary)
                    .italic()
                }
            } else {
                let modelBinding = Binding<String>(
                    get: {
                        if let model = draft.selectedAIModel, !model.isEmpty { return model }
                        return warmupSnapshot.selectedModel(for: provider)
                    },
                    set: { newModelValue in
                        draft.selectedAIModel = newModelValue
                    }
                )

                Picker("AI Model", selection: modelBinding) {
                    ForEach(models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }

                if provider == .openRouter {
                    Button("Refresh Models") {
                        Task { await aiService.fetchOpenRouterModels() }
                    }
                    .help("Refresh models")
                }
            }
        }
    }

    private func aiModelOptions(for provider: AIProvider) -> [String] {
        var models = warmupSnapshot.availableModels(for: provider)

        if let selectedModel = draft.selectedAIModel,
            !selectedModel.isEmpty,
            !models.contains(selectedModel)
        {
            models.insert(selectedModel, at: 0)
        }

        return models
    }

    private var promptPicker: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("Prompt")
                InfoTip(
                    "The instructions the enhancement model follows: how formal to be, whether to keep slang, what formatting to use. Edit it with the pencil, or add your own with the plus."
                )
            }

            Spacer(minLength: 12)

            if warmupSnapshot.prompts.isEmpty {
                Text("No prompts available")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Picker("", selection: $draft.selectedPromptId) {
                    ForEach(warmupSnapshot.prompts) { prompt in
                        Text(prompt.title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .tag(prompt.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            if let selectedPrompt {
                Button {
                    openPromptEditor(.edit(selectedPrompt))
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 18))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit prompt")
            }

            AddIconButton(helpText: "Add prompt") {
                openPromptEditor(.add)
            }
        }
    }

    private var contextAwarenessRow: some View {
        ExpandableSettingsRow(
            title: "Context Awareness",
            isExpanded: $isContextAwarenessExpanded,
            summary: contextAwarenessSummary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    "Extra text sent to the model along with your dictation, so it can match names and spelling to what is already on screen. It never replaces what you said."
                )
                .settingsDescription()

                contextToggles
            }
        }
    }

    /// States what is actually switched on, so the collapsed row does not read
    /// as an unexplained disclosure arrow.
    private var contextAwarenessSummary: String {
        var sources: [String] = []
        if draft.useSelectedTextContext { sources.append(String(localized: "selected text")) }
        if draft.useClipboardContext { sources.append(String(localized: "clipboard")) }
        if draft.useScreenCapture { sources.append(String(localized: "screen")) }

        guard !sources.isEmpty else {
            return String(localized: "Nothing extra is sent")
        }

        return sources.joined(separator: ", ")
    }

    private var contextToggles: some View {
        Group {
            Toggle(isOn: $draft.useSelectedTextContext) {
                HStack(spacing: 4) {
                    Text("Selected Text")
                    InfoTip(
                        "Whatever text is highlighted in the app you are dictating into gets sent along with your words. Useful for rewriting: highlight a sentence, say how to change it."
                    )
                }
            }

            Toggle(isOn: $draft.useClipboardContext) {
                HStack(spacing: 4) {
                    Text("Clipboard")
                    InfoTip(
                        "Sends whatever is currently on your clipboard as reference material. Worth leaving off unless a mode really needs it, since you may not remember what you copied last."
                    )
                }
            }

            Toggle(isOn: $draft.useScreenCapture) {
                HStack(spacing: 4) {
                    Text("Screen")
                    InfoTip(
                        "Takes a picture of your screen when you start recording, reads the text out of it, and sends that too. Needs Screen Recording permission, and it is the slowest of the three."
                    )
                }
            }

            // Without the permission this toggle looks on but silently captures
            // nothing, which is the exact failure the user cannot diagnose.
            if draft.useScreenCapture && !isScreenRecordingGranted {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Status.warningStrong)

                    Text("Screen Recording permission is off, so no screen text is being sent.")
                        .settingsDescription()

                    Button("Open Settings", action: openScreenRecordingSettings)
                        .controlSize(.small)
                }
            }
        }
    }

    private func openScreenRecordingSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        {
            NSWorkspace.shared.open(url)
        }
    }

    private var outputChoices: [ModeOutputMode] {
        ModeOutputMode.choices(canRespond: canRespond)
    }

    private var canRespond: Bool {
        draft.isAIEnhancementEnabled && selectedPrompt != nil && configuredSelectedAIProvider != nil
    }

    private func applyOutputRules() {
        draft.applyOutputRules(canRespond: canRespond)
    }

    private var advancedSection: some View {
        Section("Advanced") {
            Picker(selection: $draft.outputMode) {
                ForEach(outputChoices, id: \.self) { outputMode in
                    Label(outputMode.displayName, systemImage: outputMode.iconName)
                        .tag(outputMode)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Output")
                    InfoTip(
                        "What happens with the finished text. Paste types it where your cursor is. Respond shows the model's reply in the recorder instead of pasting, for asking questions out loud. Custom Command pipes the text into a script you write.\n\nRespond needs AI Enhancement on with a prompt and provider set, so it only appears once those are in place."
                    )
                }
            }
            .onChange(of: draft.outputMode) { _, _ in
                applyOutputRules()
            }

            if draft.outputMode != .respond {
                Toggle(isOn: $draft.isDefault) {
                    HStack(spacing: 6) {
                        Text("Set as default")
                        InfoTip("Default mode is used when no specific app or website matches are found.")
                    }
                }
            }

            if draft.outputMode.usesPasteOptions {
                Picker(selection: $draft.autoSendKey) {
                    ForEach(AutoSendKey.allCases, id: \.self) { key in
                        Text(key.displayName).tag(key)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Auto Send")
                        InfoTip(
                            "Automatically presses a key combination after pasting text. Useful for chat applications or forms that use different send shortcuts."
                        )
                    }
                }
            }

            if draft.outputMode == .customCommand {
                customCommandControls
            }
        }
    }

    private var customCommandControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Command")
                InfoTip(
                    LocalizedStringKey(
                        "Runs locally with your user permissions. The final transcript is sent on stdin and exposed as VOICEINK_TRANSCRIPT."
                    ))
                Spacer()
                Menu {
                    ForEach(CustomCommandTemplate.allCases) { template in
                        Button(template.displayName) {
                            draft.customCommand = template.command
                        }
                    }
                } label: {
                    Label("Template", systemImage: "doc.on.doc")
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            TextEditor(text: $draft.customCommand)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(AppTheme.Surface.control)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppTheme.Border.control.opacity(0.4), lineWidth: 1)
                )

        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            HStack {
                if case .edit = mode {
                    Button("Delete", role: .destructive) {
                        if isDeletingDefaultMode {
                            isShowingDefaultModeDeleteAlert = true
                        } else {
                            isShowingDeleteConfirmation = true
                        }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Cancel") { onDismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    onSave()
                } label: {
                    Text("Save Changes")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.canSave)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        // Same reason as the header: the scrolling Form passes underneath.
        .background(.regularMaterial)
        .overlay(Divider().opacity(0.5), alignment: .top)
        .zIndex(1)
    }

    private func languageSelectionDisabled() -> Bool {
        guard let selectedModelName = effectiveModelName,
            let model = warmupSnapshot.transcriptionModel(named: selectedModelName)
        else { return false }
        return model.provider == .gemini
    }

    private func availableLanguages(for model: any TranscriptionModel) -> [String: String] {
        TranscriptionLanguageSupport.languages(for: model, realtimeEnabled: draft.isRealtimeTranscriptionEnabled)
    }

    private func effectiveLanguage(for model: any TranscriptionModel) -> String {
        TranscriptionLanguageSupport.validLanguageOrFallback(
            draft.selectedLanguage ?? UserDefaults.standard.string(forKey: "SelectedLanguage"),
            for: model,
            realtimeEnabled: draft.isRealtimeTranscriptionEnabled
        )
    }

}
