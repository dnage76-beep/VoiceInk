import SwiftUI

/// The "Your voice" tab: what VoiceInk can say about how you speak, derived
/// entirely from transcripts already on this Mac.
struct InsightVoiceTab: View {
    let summary: VoiceInsightSummary
    let peakHours: DashboardPeakHoursSummary
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardLayout.columnSpacing) {
            if isLoading {
                InsightVoicePlaceholder()
            } else if summary.hasData {
                HStack(alignment: .top, spacing: DashboardLayout.columnSpacing) {
                    InsightWordCard(
                        title: String(localized: "Most used word"),
                        caption: String(localized: "excluding everyday filler"),
                        word: summary.mostUsedWord,
                        emptyMessage: String(localized: "Not enough dictation yet.")
                    )

                    InsightWordCard(
                        title: String(localized: "Most corrected word"),
                        caption: String(localized: "what AI cleanup fixes most"),
                        word: summary.mostCorrectedWord,
                        emptyMessage: String(localized: "AI cleanup hasn't changed much yet.")
                    )
                }

                InsightVocabularyCard(words: summary.mostUsedWords)

                DashboardPeakHoursCard(summary: peakHours, isLocked: false)
                    .frame(height: 196)
            } else {
                InsightVoiceEmptyState()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// A single headline word with its count.
struct InsightWordCard: View {
    let title: String
    let caption: String
    let word: VoiceInsightAnalysis.WordCount?
    let emptyMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Text.primary)

                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Text.muted)
            }

            Spacer(minLength: 4)

            if let word {
                Text(word.word)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(AppTheme.Text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(
                    String(
                        format: String(localized: "%d times"),
                        word.count
                    )
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.Text.secondary)
            } else {
                Text(emptyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(DashboardInsightCardBackground(cornerRadius: 16))
    }
}

/// The runner-up words, as a ranked list. Gives the tab substance beyond two
/// single-word headlines.
struct InsightVocabularyCard: View {
    let words: [VoiceInsightAnalysis.WordCount]

    private var maxCount: Int {
        words.first?.count ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your vocabulary")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Text.primary)

                Text("The words you reach for most, everyday filler aside.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Text.secondary)
            }

            VStack(spacing: 8) {
                ForEach(words) { entry in
                    HStack(spacing: 12) {
                        Text(entry.word)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.Text.primary)
                            .lineLimit(1)
                            .frame(width: 130, alignment: .leading)

                        GeometryReader { proxy in
                            Capsule()
                                .fill(AppTheme.Accent.primary.opacity(0.80))
                                .frame(
                                    width: max(
                                        proxy.size.width * (Double(entry.count) / Double(maxCount)),
                                        3
                                    )
                                )
                        }
                        .frame(height: 14)

                        Text(String(entry.count))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.Text.secondary)
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DashboardInsightCardBackground(cornerRadius: 16))
    }
}

struct InsightVoicePlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("Reading your transcripts...")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Text.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(DashboardInsightCardBackground(cornerRadius: 16))
    }
}

struct InsightVoiceEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing to read yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Text.primary)

            Text(
                "Once you have dictated a few times, this tab shows the words you use most and what AI cleanup tends to fix. It is all worked out on this Mac from transcripts you already have."
            )
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.Text.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DashboardInsightCardBackground(cornerRadius: 16))
    }
}
