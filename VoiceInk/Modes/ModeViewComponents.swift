import SwiftUI

struct VoiceInkButton: View {
    let title: LocalizedStringKey
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isDisabled ? AppTheme.Accent.disabled : AppTheme.Accent.primary)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct ModeEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Modes")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add customized modes for different contexts")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VoiceInkButton(
                title: "Add New Mode",
                action: action
            )
            .frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ModeConfigurationsGrid: View {
    @ObservedObject var modeManager: ModeManager
    let onEditConfig: (ModeConfig) -> Void
    @EnvironmentObject var enhancementService: AIEnhancementService

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach($modeManager.configurations) { $config in
                ConfigurationRow(
                    config: $config,
                    isEditing: false,
                    modeManager: modeManager,
                    onEditConfig: onEditConfig
                )
            }
        }
    }
}

struct DefaultModeIndicator: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)

            Text("Default")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.leading, 7)
        .padding(.trailing, 9)
        .frame(height: 24)
        .background {
            Capsule()
                .fill(AppTheme.Surface.card)
        }
        .overlay {
            Capsule()
                .strokeBorder(AppTheme.Border.control, lineWidth: 0.5)
        }
        .contentShape(Capsule())
        .help("Default mode is used when no app or website matches")
    }
}

/// One metadata chip on a mode card (model, language, prompt, output mode).
/// Extracted because the same capsule was written out six times inline, which
/// is how the chips drifted out of alignment with each other.
struct ModeMetadataChip: View {
    let systemImage: String
    let text: String
    var isWarning: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
            Text(text)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(isWarning ? Color.white : Color.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(isWarning ? Color.red.opacity(0.80) : AppTheme.Surface.control)
        )
        .overlay(
            Capsule()
                .stroke(
                    isWarning ? Color.red.opacity(0.80) : AppTheme.Border.control,
                    lineWidth: 0.5
                )
        )
    }
}

struct ConfigurationRow: View {
    private struct TranscriptionModelMetadata {
        let label: String
        let isWarning: Bool
        /// Where the user goes to resolve the warning. Nil when nothing is
        /// wrong, or when the fix is to edit the mode itself.
        var fixDestination: FixDestination?

        enum FixDestination {
            case models
            case mode

            var hint: String {
                switch self {
                case .models:
                    return String(localized: "Open AI Models to download or pick another model.")
                case .mode:
                    return String(localized: "Edit this mode to choose a transcription model.")
                }
            }
        }
    }

    @Binding var config: ModeConfig
    let isEditing: Bool
    let modeManager: ModeManager
    let onEditConfig: (ModeConfig) -> Void
    @EnvironmentObject var enhancementService: AIEnhancementService
    @EnvironmentObject var transcriptionModelManager: TranscriptionModelManager
    @State private var isHovering = false

    private let maxAppIconsToShow = 5

    private var selectedPrompt: CustomPrompt? {
        guard let promptId = config.selectedPrompt,
            let uuid = UUID(uuidString: promptId)
        else { return nil }
        return enhancementService.allPrompts.first { $0.id == uuid }
    }

    private var transcriptionModelMetadata: TranscriptionModelMetadata {
        switch ModeRuntimeResolver.transcriptionModelResolution(
            mode: config,
            transcriptionModelManager: transcriptionModelManager
        ) {
        case .available(_, let model):
            return TranscriptionModelMetadata(
                label: model.displayName,
                isWarning: false
            )
        // Each of these needs a different fix, so each says which one it is
        // rather than collapsing into an unexplained "Unavailable".
        case .noSelection:
            return TranscriptionModelMetadata(
                label: String(localized: "No model selected"),
                isWarning: true,
                fixDestination: .mode
            )
        case .modelNotFound:
            return TranscriptionModelMetadata(
                label: String(localized: "Model removed"),
                isWarning: true,
                fixDestination: .models
            )
        case .unavailable(_, let model):
            return TranscriptionModelMetadata(
                label: String(localized: "\(model.displayName): not downloaded"),
                isWarning: true,
                fixDestination: .models
            )
        case .noMode:
            return TranscriptionModelMetadata(
                label: String(localized: "No mode selected"),
                isWarning: true,
                fixDestination: .mode
            )
        }
    }

    private var selectedLanguage: String? {
        if let langCode = config.selectedLanguage {
            if langCode == "auto" { return String(localized: "Auto") }
            if langCode == "en" { return String(localized: "English") }

            if let modelName = config.selectedTranscriptionModelName,
                let model = transcriptionModelManager.allAvailableModels.first(where: { $0.name == modelName }),
                let langName = TranscriptionLanguageSupport.languages(
                    for: model, realtimeEnabled: config.isRealtimeTranscriptionEnabled)[langCode]
            {
                return langName
            }
            return langCode.uppercased()
        }
        return "Default"
    }

    private var appCount: Int { return config.allAppConfigs.count }
    private var websiteCount: Int { return config.allURLConfigs.count }

    private var websiteText: String {
        if websiteCount == 0 { return "" }
        return String(localized: "\(websiteCount) Websites")
    }

    private var appText: String {
        if appCount == 0 { return "" }
        return String(localized: "\(appCount) Apps")
    }

    private var extraAppsCount: Int {
        return max(0, appCount - maxAppIconsToShow)
    }

    private var visibleAppConfigs: [AppConfig] {
        return Array(config.allAppConfigs.prefix(maxAppIconsToShow))
    }

    private var editModeButton: some View {
        Button {
            onEditConfig(config)
        } label: {
            Text("Edit")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(AppTheme.Surface.control)
                )
                .overlay(
                    Capsule()
                        .stroke(AppTheme.Border.control, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help("Edit mode")
        .accessibilityLabel("Edit mode")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        ModeIconView(icon: config.icon, size: config.icon.kind == .emoji ? 20 : 16)
                    }
                    .frame(width: 40, height: 40)
                    .background(
                        AppCardBackground(isSelected: false, cornerRadius: AppTheme.Radius.pill)
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(config.name)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        HStack(spacing: 12) {
                            if appCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 10))
                                    Text(appText)
                                        .font(.caption2)
                                }
                            }

                            if websiteCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 10))
                                    Text(websiteText)
                                        .font(.caption2)
                                }
                            }
                        }
                        .padding(.top, 2)
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    if config.isDefault {
                        DefaultModeIndicator()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onEditConfig(config)
                }

                if !config.isDefault {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { config.isEnabled },
                            set: { newValue in
                                if newValue {
                                    modeManager.enableConfiguration(with: config.id)
                                } else {
                                    modeManager.disableConfiguration(with: config.id)
                                }
                            }
                        )
                    )
                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.Accent.primary))
                    .labelsHidden()
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppMaterialCardBackground.fill)

            Divider()

            HStack(spacing: 8) {
                let modelMetadata = transcriptionModelMetadata
                let modelBadge = ModeMetadataChip(
                    systemImage: modelMetadata.isWarning ? "exclamationmark.triangle.fill" : "waveform",
                    text: modelMetadata.label,
                    isWarning: modelMetadata.isWarning
                )

                // A warning badge is a way out, not just a label.
                if let destination = modelMetadata.fixDestination {
                    Button {
                        switch destination {
                        case .models:
                            ModeSetupNavigator.openModelsSettings()
                        case .mode:
                            onEditConfig(config)
                        }
                    } label: {
                        modelBadge
                    }
                    .buttonStyle(.plain)
                    .help(destination.hint)
                    .accessibilityLabel(Text("\(modelMetadata.label). \(destination.hint)"))
                } else {
                    modelBadge
                }

                if let language = selectedLanguage, language != "Default" {
                    ModeMetadataChip(systemImage: "globe", text: language)
                }

                if config.isAIEnhancementEnabled,
                    config.selectedAIProvider != AIProvider.localCLI.rawValue,
                    let modelName = config.selectedAIModel,
                    !modelName.isEmpty
                {
                    ModeMetadataChip(
                        systemImage: "cpu",
                        text: modelName.count > 20 ? String(modelName.prefix(18)) + "..." : modelName
                    )
                }

                if config.outputMode != .paste {
                    ModeMetadataChip(
                        systemImage: config.outputMode.iconName,
                        text: config.outputMode.displayName
                    )
                }

                if config.outputMode == .paste && config.autoSendKey.isEnabled {
                    ModeMetadataChip(
                        systemImage: "keyboard",
                        text: config.autoSendKey.displayName
                    )
                }

                if config.isAIEnhancementEnabled {
                    ModeMetadataChip(
                        systemImage: "sparkles",
                        text: selectedPrompt?.title ?? String(localized: "AI")
                    )
                }

                Spacer()

                if isHovering {
                    editModeButton
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onEditConfig(config)
            }
            // The chips are ~20pt capsules, so 6pt of padding left them
            // crowding the card's rounded bottom corners and getting clipped.
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Surface.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    AppMaterialCardBackground.border(for: isEditing),
                    lineWidth: AppMaterialCardBackground.lineWidth(for: isEditing)
                )
        }
        .opacity(config.isEnabled ? 1.0 : 0.70)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

}

struct ModeAppIcon: View {
    let bundleId: String

    var body: some View {
        if let icon = TriggerAppIconCache.shared.icon(for: bundleId) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
        }
    }
}

struct AppGridItem: View {
    let app: (url: URL, name: String, bundleId: String, icon: NSImage)
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                    .shadow(color: Color(NSColor.shadowColor).opacity(0.1), radius: 2, x: 0, y: 1)
                Text(app.name)
                    .font(.system(size: 10))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
            }
            .frame(width: 80, height: 80)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppTheme.Accent.fillSubtle : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppTheme.Accent.primary : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
