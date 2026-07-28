import SwiftUI

/// Dedicated sidebar page for AI enhancement: what it is, which provider
/// powers it, and which modes use it.
struct AIEnhancementSettingsView: View {
    @EnvironmentObject private var aiService: AIService
    @ObservedObject private var modeManager = ModeManager.shared
    @State private var isEditingProvider = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                sectionTitle("Provider")
                providerRow
                if hasSelectableModels {
                    modelRow
                }
                if isEditingProvider {
                    APIKeyManagementView()
                }

                sectionTitle("Modes using enhancement")
                modesSummaryCard
            }
            .padding(24)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Ink settings row: current value stated plainly, detail behind Change.
    private var providerRow: some View {
        settingsRow {
            VStack(alignment: .leading, spacing: 2) {
                Text("Provider")
                    .font(.system(size: 13, weight: .medium))

                Text(currentProviderSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(isEditingProvider ? "Done" : "Change") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isEditingProvider.toggle()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var modelRow: some View {
        settingsRow {
            VStack(alignment: .leading, spacing: 2) {
                Text("Model")
                    .font(.system(size: 13, weight: .medium))

                Text(aiService.currentModel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: modelSelection) {
                ForEach(aiService.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    private var settingsRowSpacing: CGFloat { 12 }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: settingsRowSpacing) {
            content()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(AppTheme.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var hasSelectableModels: Bool {
        aiService.selectedProvider != .localCLI && aiService.availableModels.count > 1
    }

    private var modelSelection: Binding<String> {
        Binding(
            get: { aiService.currentModel },
            set: { model in
                let provider = aiService.selectedProvider
                aiService.selectModel(model, for: provider)
                applyModelToModes(model, provider: provider)
            }
        )
    }

    /// Modes pin their own model, which would silently override this picker.
    /// Switching here switches every mode on the same provider; per-mode
    /// overrides can still be set afterwards in Modes.
    private func applyModelToModes(_ model: String, provider: AIProvider) {
        for config in modeManager.configurations
        where config.isAIEnhancementEnabled
            && config.selectedAIProvider == provider.rawValue
            && config.selectedAIModel != model
        {
            var updated = config
            updated.selectedAIModel = model
            modeManager.updateConfiguration(updated)
        }
    }

    private var currentProviderSummary: String {
        let provider = aiService.selectedProvider
        let model = aiService.currentModel
        if hasSelectableModels {
            return provider.rawValue
        }
        if model.isEmpty {
            return String(format: String(localized: "%@, no model selected"), provider.rawValue)
        }
        return "\(provider.rawValue): \(model)"
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("AI Enhancement")
                .font(.system(size: 26, weight: .semibold, design: .serif))

            InfoTip(
                "Turn raw dictation into clean, ready-to-send text. Transcription writes down exactly what you said; enhancement is the second pass, where an AI model removes filler words, fixes punctuation and grammar, applies your spoken self-corrections, and formats the result for where you're typing.\n\nEnhancement is set per mode: your Default mode can stay instant with no AI, while Email or Coding modes clean up with a model. Short phrases skip enhancement automatically so quick commands paste immediately."
            )
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .padding(.top, 4)
    }

    private var modesSummaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(modeManager.configurations) { mode in
                HStack(spacing: 10) {
                    Image(systemName: mode.isAIEnhancementEnabled ? "wand.and.stars" : "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(mode.isAIEnhancementEnabled ? Color.accentColor : .secondary)
                        .frame(width: 18)

                    Text(mode.name)
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    Text(mode.isAIEnhancementEnabled ? enhancementLabel(for: mode) : String(localized: "Instant, no AI"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 14)

                if mode.id != modeManager.configurations.last?.id {
                    Divider().padding(.leading, 42)
                }
            }

            Divider()

            Button {
                ModeSetupNavigator.openModesSettings()
            } label: {
                Label("Configure in Modes", systemImage: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
        }
        .background(AppTheme.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func enhancementLabel(for mode: ModeConfig) -> String {
        if let model = mode.selectedAIModel, !model.isEmpty {
            return model
        }
        return String(localized: "AI cleanup")
    }
}
