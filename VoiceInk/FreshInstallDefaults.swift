import AppKit
import Carbon.HIToolbox
import Foundation
import LaunchAtLogin

/// A fresh install should land where a well-configured one ends up:
/// Fn hybrid hotkey, launch at login, Claude CLI enhancement when the
/// `claude` binary is available, and the full starter mode set.
/// Existing installs are never touched.
enum FreshInstallDefaults {
    private static let appliedKey = "HasAppliedFreshInstallDefaults"

    /// Runs before RecordingShortcutManager exists, so the onboarding
    /// shortcut screen shows Fn hybrid preselected instead of empty.
    static func seedAtLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "hasCompletedOnboardingV2"),
            !defaults.bool(forKey: appliedKey)
        else { return }

        ShortcutStore.seedShortcut(
            .modifierOnly(keyCode: UInt16(kVK_Function), modifierFlags: [.function]),
            for: .primaryRecording
        )

        if defaults.string(forKey: "primaryRecordingShortcut") == nil {
            defaults.set(
                RecordingShortcutManager.ShortcutSelection.custom.rawValue,
                forKey: "primaryRecordingShortcut"
            )
        }

        if defaults.string(forKey: "primaryRecordingShortcutMode") == nil {
            defaults.set(
                RecordingShortcutManager.Mode.hybrid.rawValue,
                forKey: "primaryRecordingShortcutMode"
            )
        }

        // Greet the owner by their account name instead of "there".
        if (defaults.string(forKey: "dashboardDisplayName") ?? "").isEmpty {
            let firstName = NSFullUserName()
                .components(separatedBy: .whitespaces)
                .first { !$0.isEmpty }
            if let firstName {
                defaults.set(firstName, forKey: "dashboardDisplayName")
            }
        }
    }

    @MainActor
    static func applyAtOnboardingCompletion(
        aiService: AIService,
        enhancementService: AIEnhancementService
    ) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: appliedKey) else { return }
        defaults.set(true, forKey: appliedKey)

        // Blocking SMAppService XPC call; keep it off the main thread.
        Task.detached(priority: .utility) {
            if !LaunchAtLogin.isEnabled {
                LaunchAtLogin.isEnabled = true
            }
        }

        disableSystemFnOverrideIfNeeded()

        Task { @MainActor in
            let claudeAvailable = await Self.isClaudeCLIAvailable()

            // Onboarding normally sets this up on the Claude Code step; this
            // is the fallback for a skipped or interrupted onboarding.
            if claudeAvailable, !hasWorkingProvider(aiService) {
                aiService.loadLocalCLITemplate(.claude)
                aiService.updateLocalCLITimeoutSeconds(AppDefaults.enhancementTimeoutSeconds)
                aiService.selectedProvider = .localCLI
            }

            installStarterModes(
                aiService: aiService,
                enhancementService: enhancementService,
                enhanceByDefault: hasWorkingProvider(aiService)
            )
        }
    }

    /// True when the selected provider can actually serve requests right now.
    @MainActor
    private static func hasWorkingProvider(_ aiService: AIService) -> Bool {
        switch aiService.selectedProvider {
        case .localCLI, .ollama, .custom:
            return aiService.isAPIKeyValid
        default:
            return APIKeyManager.shared.hasAPIKey(forProvider: aiService.selectedProvider.rawValue)
        }
    }

    /// Same login shell LocalCLIService uses, so detection matches runtime.
    static func isClaudeCLIAvailable() async -> Bool {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", "command -v claude"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    @MainActor
    private static func installStarterModes(
        aiService: AIService,
        enhancementService: AIEnhancementService,
        enhanceByDefault: Bool
    ) {
        // Dictation-only lineup: no Rewrite, no Assistant. VoiceInk types what
        // you said, cleaned up; it never answers.
        let desiredKinds: [StarterModeKind] = [.clean, .email, .coding, .texting]
        let installedKinds = StarterModeCatalog.templates
            .map(\.kind)
            .filter { StarterModeFactory.isInstalled(kind: $0) }
        var seenKinds = Set<StarterModeKind>()
        let kinds = (installedKinds + desiredKinds).filter { seenKinds.insert($0).inserted }

        let seedResult = StarterModePromptSeeder.ensurePrompts(
            for: kinds,
            in: enhancementService.customPrompts
        )
        if seedResult.didChange {
            enhancementService.customPrompts = seedResult.prompts
        }

        StarterModeFactory.install(
            kinds: kinds,
            provider: aiService.selectedProvider,
            modelName: aiService.currentModel,
            transcriptionModelName: UserDefaults.standard.string(forKey: "CurrentTranscriptionModel")
                ?? StarterModeFactory.defaultTranscriptionModelName
        )

        guard enhanceByDefault,
            let cleanTemplate = StarterModeCatalog.templates.first(where: { $0.kind == .clean }),
            var defaultConfig = ModeManager.shared.getConfiguration(with: cleanTemplate.id)
        else { return }

        defaultConfig.isAIEnhancementEnabled = true
        defaultConfig.selectedPrompt = PromptTemplates.defaultPromptId.uuidString
        defaultConfig.selectedAIProvider = aiService.selectedProvider.rawValue
        defaultConfig.selectedAIModel = aiService.currentModel
        ModeManager.shared.updateConfiguration(defaultConfig)
        ModeManager.shared.setActiveConfiguration(defaultConfig)
    }

    /// With Fn as the recording key, the system's own Fn action (emoji
    /// picker, input-source switch, dictation) fights every activation.
    private static func disableSystemFnOverrideIfNeeded() {
        guard let shortcut = ShortcutStore.shortcut(for: .primaryRecording),
            shortcut.isModifierOnly,
            shortcut.keyCode == UInt16(kVK_Function)
        else { return }

        let domain = "com.apple.HIToolbox" as CFString
        CFPreferencesSetValue(
            "AppleFnUsageType" as CFString,
            0 as CFNumber,
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
}
