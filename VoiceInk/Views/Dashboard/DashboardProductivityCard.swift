import Foundation
import SwiftUI

struct DashboardProductivityCard: View {
    @Binding var period: DashboardInsightPeriod
    let points: [DashboardProductivityPoint]
    let updatedAtText: String
    let isRefreshingStats: Bool
    let onRefreshStats: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                Text(period.chartTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Text.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.18), value: isRefreshingStats)

                    DashboardStatsRefreshButton(
                        isRefreshing: isRefreshingStats,
                        action: onRefreshStats
                    )
                }
                .frame(maxWidth: 260, alignment: .trailing)
            }

            DashboardProductivityChart(period: period, points: points)
                .frame(height: 208)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DashboardInsightCardBackground(cornerRadius: 16))
    }

    private var statusText: String {
        isRefreshingStats ? String(localized: "Updating") : updatedAtText
    }
}
struct DashboardProductivitySummaryStrip: View {
    let summary: DashboardTimeSavedSummary
    var wordsPerMinute: Int?
    var dayStreak: Int = 0
    var longestDayStreak: Int = 0
    var enhancedCount: Int = 0
    /// True on the session's first dashboard appearance: cells fade in with a
    /// short stagger and numerals count up. Later visits render settled.
    var playsEntrance: Bool = false

    var body: some View {
        // Two rows of three rather than one row of six: at six across, the
        // numerals shrink below the point where they read as the headline.
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                DashboardStatCell(
                    order: 0,
                    playsEntrance: playsEntrance,
                    icon: "clock",
                    title: "Time saved",
                    detail: String(localized: "vs typing at 40 wpm"),
                    value: summary.hasData ? summary.timeSaved : nil,
                    format: { Formatters.formattedSavedTime($0) }
                )
                DashboardStatCell(
                    order: 1,
                    playsEntrance: playsEntrance,
                    icon: "text.alignleft",
                    title: "Words dictated",
                    detail: nil,
                    value: summary.hasData ? Double(summary.wordCount) : nil,
                    format: { Formatters.formattedCompactNumber(Int($0.rounded())) }
                )
                DashboardStatCell(
                    order: 2,
                    playsEntrance: playsEntrance,
                    icon: "mic",
                    title: "Sessions",
                    detail: nil,
                    value: summary.hasData ? Double(summary.sessionCount) : nil,
                    format: { Formatters.formattedCompactNumber(Int($0.rounded())) }
                )
            }

            HStack(alignment: .top, spacing: 12) {
                DashboardStatCell(
                    order: 3,
                    playsEntrance: playsEntrance,
                    icon: "speedometer",
                    title: "Words per minute",
                    detail: wordsPerMinute == nil
                        ? String(localized: "needs a longer recording") : String(localized: "while speaking"),
                    value: wordsPerMinute.map(Double.init),
                    format: { String(Int($0.rounded())) }
                )
                DashboardStatCell(
                    order: 4,
                    playsEntrance: playsEntrance,
                    icon: "flame",
                    title: "Day streak",
                    detail: longestDayStreak > 0
                        ? String(format: String(localized: "best %d"), longestDayStreak) : nil,
                    value: dayStreak > 0 ? Double(dayStreak) : nil,
                    format: { String(Int($0.rounded())) }
                )
                DashboardStatCell(
                    order: 5,
                    playsEntrance: playsEntrance,
                    icon: "sparkles",
                    title: "Cleaned up by AI",
                    detail: enhancedShareDetail,
                    value: summary.hasData ? Double(enhancedCount) : nil,
                    format: { Formatters.formattedCompactNumber(Int($0.rounded())) }
                )
            }
        }
    }

    /// "of 120 sessions" reads more honestly than a bare count, which otherwise
    /// looks like a score without a denominator.
    private var enhancedShareDetail: String? {
        guard summary.hasData, summary.sessionCount > 0 else { return nil }
        return String(
            format: String(localized: "of %@ sessions"),
            Formatters.formattedCompactNumber(summary.sessionCount)
        )
    }
}

/// Ink style: big numeral first, quiet lowercase label under it, a small gray
/// glyph in the corner naming the metric at a glance. White card, hairline
/// border, and a border that darkens a touch on hover; nothing louder.
private struct DashboardStatCell: View {
    let order: Int
    let playsEntrance: Bool
    let icon: String
    let title: LocalizedStringKey
    let detail: String?
    /// Nil means no data yet; the cell shows "--" and skips the count-up.
    let value: Double?
    let format: (Double) -> String

    @State private var isHovering = false

    private var entranceDelay: Double { 0.08 + Double(order) * 0.05 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 8) {
                numeral

                Spacer(minLength: 6)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Text.muted)
                    .padding(.top, 5)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Text.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            if let detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.Text.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        // One fixed minimum height for every cell, so the rows line up whether
        // or not a cell carries a detail line.
        .frame(minWidth: 132, maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .background(DashboardInsightCardBackground(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(isHovering ? 0.22 : 0), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
        .entranceReveal(delay: entranceDelay, play: playsEntrance)
    }

    @ViewBuilder
    private var numeral: some View {
        Group {
            if let value {
                CountUpText(
                    target: value,
                    format: format,
                    delay: entranceDelay + 0.1,
                    play: playsEntrance
                )
            } else {
                Text(verbatim: "--")
            }
        }
        .font(.system(size: 30, weight: .semibold).monospacedDigit())
        .foregroundStyle(AppTheme.Text.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.66)
    }
}

private struct DashboardStatsRefreshButton: View {
    let isRefreshing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.Accent.primary)
                        .transition(.opacity)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.Text.primary.opacity(0.72))
                        .transition(.opacity)
                }
            }
            .frame(width: 34, height: 34)
            .background(AppCardBackground(cornerRadius: 17))
            .animation(.easeInOut(duration: 0.18), value: isRefreshing)
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
        .help(refreshHelp)
        .accessibilityLabel(Text(refreshHelp))
    }

    private var refreshHelp: String {
        isRefreshing ? String(localized: "Refreshing stats") : String(localized: "Refresh stats")
    }
}

private enum DashboardProductivityChartData {
    static func visiblePoints(
        for period: DashboardInsightPeriod,
        points: [DashboardProductivityPoint],
        now: Date = Date()
    ) -> [DashboardProductivityPoint] {
        Array(points.prefix(visiblePointCount(for: period, points: points, now: now)))
    }

    static func visiblePointCount(
        for period: DashboardInsightPeriod,
        points: [DashboardProductivityPoint],
        now: Date = Date()
    ) -> Int {
        guard period == .today, let firstPoint = points.first else {
            return points.count
        }

        let calendar = DashboardPeriodWindows.dashboardCalendar()

        guard calendar.isDate(firstPoint.date, inSameDayAs: now) else {
            return points.count
        }

        return min(points.count, calendar.component(.hour, from: now) + 1)
    }

    static func yAxisUpperBound(for value: Int) -> Int {
        guard value > 0 else {
            return 0
        }

        let paddedValue = Double(value) * 1.06
        let magnitude = pow(10, max(0, floor(log10(paddedValue)) - 1))
        let step = max(1, Int(magnitude))

        return max(value, Int(ceil(paddedValue / Double(step))) * step)
    }
}

private struct DashboardProductivityChart: View {
    let period: DashboardInsightPeriod
    let points: [DashboardProductivityPoint]

    private var yAxisUpperBound: Int {
        DashboardProductivityChartData.yAxisUpperBound(for: visiblePoints.map(\.words).max() ?? 0)
    }

    private var hasWords: Bool {
        visiblePoints.contains { $0.words > 0 }
    }

    private var visiblePoints: [DashboardProductivityPoint] {
        DashboardProductivityChartData.visiblePoints(for: period, points: points)
    }

    private var horizontalSlotCount: Int {
        period == .today ? 24 : max(visiblePoints.count, 1)
    }

    private var yAxisLabels: [Int] {
        guard hasWords else {
            return [0]
        }

        return [
            yAxisUpperBound,
            yAxisUpperBound * 3 / 4,
            yAxisUpperBound / 2,
            yAxisUpperBound / 4,
            0,
        ]
        .reduce(into: []) { labels, value in
            if !labels.contains(value) {
                labels.append(value)
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DashboardProductivityYAxis(labels: yAxisLabels)
                .accessibilityHidden(true)

            DashboardProductivityPlotArea(
                period: period,
                points: points,
                visiblePoints: visiblePoints,
                yAxisUpperBound: yAxisUpperBound,
                horizontalSlotCount: horizontalSlotCount
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dictated words chart")
        .accessibilityValue(totalWordsAccessibilityValue)
    }

    private var totalWordsAccessibilityValue: String {
        String(
            format: String(localized: "%@ words"),
            Formatters.formattedNumber(points.reduce(0) { $0 + $1.words })
        )
    }
}

private struct DashboardProductivityYAxis: View {
    let labels: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if labels.count == 1, let label = labels.first {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    yAxisLabel(label)
                }
                .frame(maxHeight: .infinity, alignment: .bottomLeading)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(labels, id: \.self) { label in
                        yAxisLabel(label)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }

            Text("Words")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.Text.secondary.opacity(0.82))
                .lineLimit(1)
                .frame(height: 30, alignment: .topLeading)
        }
        .frame(width: 42, alignment: .leading)
    }

    private func yAxisLabel(_ label: Int) -> some View {
        Text(Formatters.formattedAxisValue(label))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.Text.secondary)
            .lineLimit(1)
    }
}
