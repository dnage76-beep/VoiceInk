import SwiftUI

/// Where your dictation actually goes, by app category.
///
/// This is the one card whose data started being recorded only recently, so it
/// says so plainly while history is thin rather than implying the missing
/// sessions never happened.
struct InsightAppUsageCard: View {
    let summary: DashboardAppUsageSummary
    var playsEntrance: Bool = false

    @State private var hasAppeared = false

    /// Categories worth a row: every one that saw activity, plus nothing else.
    /// Showing six zeroes to make the card look full is padding, not insight.
    private var rows: [CategoryDictationUsage] {
        summary.categories
            .filter { $0.wordCount > 0 }
            .sorted { $0.wordCount > $1.wordCount }
    }

    private var topShare: Double {
        Double(rows.first?.wordCount ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if summary.hasData {
                VStack(spacing: 9) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        categoryRow(row, order: index)
                    }
                }

                if summary.unattributedSessionCount > 0 {
                    Text(
                        String(
                            format: String(
                                localized:
                                    "%d earlier sessions aren't included: VoiceInk only started noting the destination app recently."
                            ),
                            summary.unattributedSessionCount
                        )
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Text.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                emptyState
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DashboardInsightCardBackground(cornerRadius: 16))
        .onAppear { hasAppeared = true }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Where you dictate")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Text.primary)

            Spacer(minLength: 8)

            if summary.hasData {
                Text(
                    String(
                        format: String(localized: "APPS USED | %d"),
                        summary.distinctAppCount
                    )
                )
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(AppTheme.Text.secondary)
                .lineLimit(1)
            }
        }
    }

    private func categoryRow(_ row: CategoryDictationUsage, order: Int) -> some View {
        let share = topShare > 0 ? Double(row.wordCount) / topShare : 0
        let percent = summary.share(of: row.category)

        return HStack(spacing: 11) {
            Image(systemName: row.category.symbolName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.Text.secondary)
                .frame(width: 18)

            // Bar length is relative to the busiest category so the differences
            // stay visible; the number beside it is the true share of the whole.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.Accent.primary.opacity(0.08))

                    Capsule()
                        .fill(AppTheme.Accent.primary.opacity(0.85))
                        .frame(
                            width: max(
                                proxy.size.width * (hasAppeared || !playsEntrance ? share : 0), 3
                            )
                        )
                        .animation(
                            playsEntrance
                                ? .spring(response: 0.65, dampingFraction: 0.85)
                                    .delay(Double(order) * 0.06) : nil,
                            value: hasAppeared
                        )
                }
            }
            .frame(height: 18)

            Text(row.category.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.Text.primary)
                .lineLimit(1)
                .frame(width: 108, alignment: .leading)

            Text(percent.formatted(.percent.precision(.fractionLength(0))))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Text.secondary)
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: String(localized: "%@, %d percent of your words"),
                row.category.localizedTitle,
                Int((percent * 100).rounded())
            )
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing to show yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Text.primary)

            Text(
                "VoiceInk notes which app your text lands in, so this fills in as you dictate. It never leaves your Mac."
            )
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.Text.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}
