import Foundation
import OSLog
import SwiftData

enum SessionMetricRecorder {
    private static let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "SessionMetricRecorder")
    private static let source = "recorder"

    /// The app the dictated text was headed for. Captured at recording start by
    /// ActiveWindowService, so it is the app the user was actually typing into
    /// rather than VoiceInk itself.
    struct TargetApp {
        let bundleID: String?
        let name: String?
    }

    @discardableResult
    static func recordRecorderSession(
        transcription: Transcription,
        model: (any TranscriptionModel)?,
        in modelContext: ModelContext,
        timestamp: Date = Date(),
        targetApp: TargetApp? = nil
    ) throws -> Bool {
        guard transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue else {
            return false
        }

        let transcriptionId = transcription.id
        let descriptor = FetchDescriptor<SessionMetric>(
            predicate: #Predicate<SessionMetric> { metric in
                metric.transcriptionId == transcriptionId
            }
        )

        if try modelContext.fetchCount(descriptor) > 0 {
            return false
        }

        let textForCounting = finalTextForCounting(from: transcription)
        let wordCount = WordCounter.count(in: textForCounting)
        let audioDuration = max(transcription.duration, 0)
        let transcriptionDuration = transcription.transcriptionDuration.flatMap { $0 > 0 ? $0 : nil }
        let speedFactor = transcriptionDuration.flatMap { duration in
            audioDuration > 0 ? audioDuration / duration : nil
        }

        let enhancementDuration = transcription.enhancementDuration.flatMap { $0 > 0 ? $0 : nil }
        let enhancementTokenEstimate = EnhancementTokenEstimate.estimate(from: transcription)

        let metric = SessionMetric(
            transcriptionId: transcription.id,
            timestamp: timestamp,
            source: source,
            wordCount: wordCount,
            audioDuration: audioDuration,
            transcriptionModelName: transcription.transcriptionModelName ?? model?.displayName,
            transcriptionDuration: transcriptionDuration,
            speedFactor: speedFactor,
            modeName: transcription.modeName,
            aiEnhancementModelName: transcription.aiEnhancementModelName,
            enhancementDuration: enhancementDuration,
            enhancementEstimatedTokenCount: enhancementTokenEstimate?.tokenCount,
            targetAppBundleID: targetApp?.bundleID,
            targetAppName: targetApp?.name
        )

        modelContext.insert(metric)
        logger.notice("Recorded session metric for transcription \(transcriptionId.uuidString, privacy: .public)")
        return true
    }

    /// Reads the app that was frontmost when this recording began. Returns nil
    /// when that app was VoiceInk, since dictating into our own window is not a
    /// usage pattern worth charting.
    @MainActor
    static func currentTargetApp() -> TargetApp? {
        guard let app = ActiveWindowService.shared.currentApplication else { return nil }

        let ownBundleID = Bundle.main.bundleIdentifier
        if let bundleID = app.bundleIdentifier, bundleID == ownBundleID {
            return nil
        }

        return TargetApp(bundleID: app.bundleIdentifier, name: app.localizedName)
    }

    private static func finalTextForCounting(from transcription: Transcription) -> String {
        if let enhancedText = transcription.enhancedText,
            transcription.enhancementDuration != nil,
            !enhancedText.isEmpty
        {
            return enhancedText
        }

        return transcription.text
    }
}
