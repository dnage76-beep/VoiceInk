import Foundation
import SwiftData

/// Everything on the "Your voice" tab, computed from stored transcripts.
///
/// Kept separate from `DashboardStatsLoader` because it reads `Transcription`
/// (which holds the actual text) rather than `SessionMetric` (which holds only
/// counts), and because it is a good deal more expensive: it tokenises every
/// transcript. It runs on demand when that tab is opened, not on every refresh.
struct VoiceInsightSummary: Equatable, Sendable {
    static let empty = VoiceInsightSummary()

    var mostUsedWords: [VoiceInsightAnalysis.WordCount] = []
    var corrections: VoiceInsightAnalysis.CorrectionSummary = .init()
    /// Transcripts examined, so the UI can explain a thin result.
    var transcriptCount: Int = 0

    var hasData: Bool { transcriptCount > 0 }

    var mostUsedWord: VoiceInsightAnalysis.WordCount? { mostUsedWords.first }
    var mostCorrectedWord: VoiceInsightAnalysis.WordCount? { corrections.mostCorrected.first }
}

enum VoiceInsightLoader {
    /// Cap on how many transcripts we tokenise. Word frequency stabilises long
    /// before this, and it keeps the pass bounded for someone with years of
    /// history. Newest first, so the profile reflects how you speak now.
    private static let transcriptLimit = 2_000

    static func load(from modelContainer: ModelContainer) async throws -> VoiceInsightSummary {
        let task = Task.detached(priority: .utility) {
            try Task.checkCancellation()

            let context = ModelContext(modelContainer)
            var descriptor = FetchDescriptor<Transcription>(
                sortBy: [SortDescriptor(\Transcription.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = transcriptLimit

            let transcripts = try context.fetch(descriptor)

            try Task.checkCancellation()

            var texts: [String] = []
            var pairs: [VoiceInsightAnalysis.EnhancementPair] = []

            for transcript in transcripts {
                // Canceled and failed runs hold placeholder text, not speech.
                guard transcript.transcriptionStatus == TranscriptionStatus.completed.rawValue else {
                    continue
                }

                // The words the user actually shipped are the enhanced ones when
                // cleanup ran, so that is what the frequency card should reflect.
                let finalText = transcript.enhancedText?.isEmpty == false
                    ? transcript.enhancedText! : transcript.text
                texts.append(finalText)

                if let enhanced = transcript.enhancedText,
                    !enhanced.isEmpty,
                    transcript.enhancementDuration != nil
                {
                    pairs.append(
                        VoiceInsightAnalysis.EnhancementPair(raw: transcript.text, enhanced: enhanced)
                    )
                }
            }

            try Task.checkCancellation()

            return VoiceInsightSummary(
                mostUsedWords: VoiceInsightAnalysis.mostUsedWords(in: texts),
                corrections: VoiceInsightAnalysis.corrections(in: pairs),
                transcriptCount: texts.count
            )
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
