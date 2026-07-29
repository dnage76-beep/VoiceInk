import AppKit
import Foundation
import SwiftData
import os

@MainActor
final class ModelPrewarmService: ObservableObject {
    private let transcriptionModelManager: TranscriptionModelManager
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "ModelPrewarm")
    /// The engine, so prewarming loads models into the same services the
    /// dictation path uses and takes part in the same residency bookkeeping.
    private weak var engine: VoiceInkEngine?
    private let prewarmAudioURL = Bundle.main.url(forResource: "sound7", withExtension: "wav")
    private let prewarmEnabledKey = "PrewarmModelOnWake"

    init(
        transcriptionModelManager: TranscriptionModelManager,
        engine: VoiceInkEngine
    ) {
        self.transcriptionModelManager = transcriptionModelManager
        self.engine = engine
        setupNotifications()
        schedulePrewarmOnAppLaunch()
    }

    // MARK: - Notification Setup

    private func setupNotifications() {
        let center = NSWorkspace.shared.notificationCenter

        // Trigger on wake from sleep
        center.addObserver(
            self,
            selector: #selector(schedulePrewarm),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        logger.notice("ModelPrewarmService initialized - listening for wake and app launch")
    }

    // MARK: - Trigger Handlers

    /// Trigger on app launch (cold start)
    private func schedulePrewarmOnAppLaunch() {
        logger.notice("App launched, scheduling prewarm")
        Task {
            try? await Task.sleep(for: .seconds(3))
            await performPrewarm()
        }
    }

    /// Trigger on wake from sleep or screen unlock
    @objc private func schedulePrewarm() {
        logger.notice("Mac activity detected (wake/unlock), scheduling prewarm")
        Task {
            try? await Task.sleep(for: .seconds(3))
            await performPrewarm()
        }
    }

    // MARK: - Core Prewarming Logic

    private func performPrewarm() async {
        guard shouldPrewarm() else { return }

        guard let engine else { return }

        // A dictation already has the models checked out. Prewarming on top of
        // it would race the same FluidAudio instance, and there is nothing to
        // warm up anyway.
        guard !engine.isUsingModels else {
            logger.notice("Skipping prewarm, a dictation is already using the models")
            return
        }

        guard let audioURL = prewarmAudioURL else {
            logger.error("❌ Prewarm audio file (sound7.wav) not found")
            return
        }

        guard
            let transcriptionConfiguration = ModeRuntimeResolver.transcriptionConfiguration(
                transcriptionModelManager: transcriptionModelManager
            )
        else {
            logger.notice("No model selected, skipping prewarm")
            return
        }
        let currentModel = transcriptionConfiguration.model

        logger.notice("Prewarming \(currentModel.displayName, privacy: .public)")
        let startTime = Date()

        // Holds the models for the duration of the warm-up, so a release
        // triggered meanwhile waits instead of tearing down a half-built
        // manager, and marks them resident so they can be released later.
        engine.beginModelUse()
        defer { engine.endModelUse() }

        do {
            let _ = try await engine.serviceRegistry.transcribe(
                audioURL: audioURL,
                model: currentModel,
                context: transcriptionConfiguration.requestContext
            )
            let duration = Date().timeIntervalSince(startTime)

            logger.notice("Prewarm completed in \(String(format: "%.2f", duration), privacy: .public)s")

        } catch {
            logger.error("❌ Prewarm failed: \(error, privacy: .public)")
        }
    }

    // MARK: - Validation

    private func shouldPrewarm() -> Bool {
        // Check if user has enabled prewarming
        let isEnabled = UserDefaults.standard.bool(forKey: prewarmEnabledKey)
        guard isEnabled else {
            logger.notice("Prewarm disabled by user")
            return false
        }

        // Only prewarm local models (Parakeet and Whisper need ANE compilation)
        guard
            let model = ModeRuntimeResolver.transcriptionConfiguration(
                transcriptionModelManager: transcriptionModelManager
            )?.model
        else {
            return false
        }

        switch model.provider {
        case .whisper, .fluidAudio:
            return true
        default:
            logger.notice("Skipping prewarm - cloud models don't need it")
            return false
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        logger.notice("ModelPrewarmService deinitialized")
    }
}
