import SwiftUI

/// What AI cleanup changed, counted by diffing the raw transcript against the
/// text that actually got pasted.
struct InsightFixesCard: View {
    let corrections: VoiceInsightAnalysis.CorrectionSummary
    let enhancedSessionCount: Int
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headlineValue)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(AppTheme.Text.primary)
                    .contentTransition(.numericText())
                    .monospacedDigit()

                HStack(spacing: 5) {
                    Text("FIXES MADE BY AI")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.Text.secondary)

                    InfoTip(
                        "Words AI cleanup removed or replaced, found by comparing what VoiceInk heard against the text it pasted. Filler like \"um\" counts here."
                    )
                }
            }

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 7) {
                detailRow(
                    value: corrections.wordsCorrected,
                    label: String(localized: "words corrected")
                )
                detailRow(
                    value: corrections.sessionsTouched,
                    label: String(localized: "sessions cleaned up")
                )
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DashboardInsightCardBackground(cornerRadius: 16))
    }

    private var headlineValue: String {
        if isLoading { return "--" }
        return String(corrections.totalFixes)
    }

    private func detailRow(value: Int, label: String) -> some View {
        HStack(spacing: 6) {
            Text(String(value))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Text.primary)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Text.secondary)
        }
    }
}

/// Total words dictated, with the book-length equivalence the dashboard already
/// computes elsewhere.
struct InsightTotalWordsCard: View {
    let wordCount: Int
    let sessionCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Formatters.formattedCompactNumber(wordCount))
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(AppTheme.Text.primary)
                    .contentTransition(.numericText())
                    .monospacedDigit()

                Text("TOTAL WORDS DICTATED")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.Text.secondary)
            }

            Divider().opacity(0.4)

            Text(equivalenceText)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DashboardInsightCardBackground(cornerRadius: 16))
    }

    private var equivalenceText: String {
        switch DashboardProgressBenchmark.equivalence(for: wordCount) {
        case .matched(let title):
            return String(format: String(localized: "That's %@, start to finish."), title)
        case .repeated(let title, let count):
            return String(format: String(localized: "That's %@, %d times over."), title, count)
        case .remaining(let words, let title):
            return String(
                format: String(localized: "%@ more words and you'll have written %@."),
                Formatters.formattedCompactNumber(words), title
            )
        }
    }
}
