import SwiftUI

/// Contribution-style calendar of dictation activity.
///
/// One column per week, one row per weekday, shaded by how many words that day
/// carried. Monochrome by design: the whole dashboard is black and white, and a
/// green heatmap would be the only colour on the page.
struct InsightActivityGrid: View {
    let wordsByDay: [Date: Int]
    let bestDayWordCount: Int
    let currentStreak: Int
    let longestStreak: Int
    var playsEntrance: Bool = false

    private let calendar = DashboardPeriodWindows.dashboardCalendar()
    private let cell: CGFloat = 11
    private let gap: CGFloat = 3

    private let weeks: [[Date?]]
    private let monthLabelsByColumn: [Int: String]

    @State private var hasAppeared = false

    init(
        wordsByDay: [Date: Int],
        bestDayWordCount: Int,
        currentStreak: Int,
        longestStreak: Int,
        playsEntrance: Bool = false
    ) {
        self.wordsByDay = wordsByDay
        self.bestDayWordCount = bestDayWordCount
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.playsEntrance = playsEntrance

        let calendar = DashboardPeriodWindows.dashboardCalendar()
        let columns = Self.makeWeeks(weekCount: 18, calendar: calendar)
        self.weeks = columns
        self.monthLabelsByColumn = Self.monthLabels(for: columns, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(alignment: .top, spacing: 6) {
                weekdayLabels
                VStack(alignment: .leading, spacing: 5) {
                    monthLabels
                    grid
                }
            }

            legend
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DashboardInsightCardBackground(cornerRadius: 16))
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(streakTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            if longestStreak > 0 {
                Text(String(format: String(localized: "LONGEST STREAK | %d"), longestStreak))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.Text.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var streakTitle: String {
        switch currentStreak {
        case 0: return String(localized: "No streak yet")
        case 1: return String(localized: "1 day streak")
        default: return String(format: String(localized: "%d day streak"), currentStreak)
        }
    }

    /// Sunday/Tuesday/Thursday only. Labelling all seven crowds the rows at this
    /// cell size, and the alternating labels still orient the reader.
    private var weekdayLabels: some View {
        VStack(alignment: .trailing, spacing: gap) {
            // Pad down past the month row so weekdays line up with their cells.
            Color.clear.frame(height: 13)

            ForEach(0..<7, id: \.self) { row in
                Group {
                    if row % 2 == 0 {
                        Text(weekdaySymbol(row))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.Text.muted)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 24, height: cell, alignment: .trailing)
            }
        }
    }

    private func weekdaySymbol(_ row: Int) -> String {
        // Row 0 is the calendar's first weekday; dashboardCalendar starts Monday.
        let symbols = calendar.shortWeekdaySymbols
        let index = (calendar.firstWeekday - 1 + row) % 7
        return String(symbols[index].prefix(3))
    }

    private var monthLabels: some View {
        HStack(spacing: gap) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                Group {
                    if let label = monthLabel(forWeekAt: index, week: week) {
                        Text(label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.Text.muted)
                            .fixedSize()
                            .frame(width: cell, alignment: .leading)
                    } else {
                        Color.clear.frame(width: cell, height: 10)
                    }
                }
            }
        }
        .frame(height: 10, alignment: .leading)
    }

    private func monthLabel(forWeekAt index: Int, week: [Date?]) -> String? {
        monthLabelsByColumn[index]
    }

    /// Month name per column, computed once.
    ///
    /// A label is wider than the column it sits above, so a month starting
    /// within two columns of the previous label is skipped rather than drawn
    /// overlapping it. Column 0 is never labelled: it is usually a partial
    /// month and would collide with the next label.
    private static func monthLabels(
        for columns: [[Date?]],
        calendar: Calendar
    ) -> [Int: String] {
        let symbols = calendar.shortMonthSymbols
        var labels: [Int: String] = [:]
        var lastLabelled: Int?

        guard columns.count > 1 else { return labels }

        for index in 1..<columns.count {
            guard let firstDay = columns[index].compactMap({ $0 }).first,
                let previousDay = columns[index - 1].compactMap({ $0 }).first
            else { continue }

            let month = calendar.component(.month, from: firstDay)
            guard calendar.component(.month, from: previousDay) != month else { continue }
            if let previous = lastLabelled, index - previous < 3 { continue }

            labels[index] = symbols[month - 1]
            lastLabelled = index
        }

        return labels
    }

    private var grid: some View {
        HStack(spacing: gap) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                VStack(spacing: gap) {
                    ForEach(Array(week.enumerated()), id: \.offset) { dayIndex, day in
                        dayCell(day, weekIndex: weekIndex, dayIndex: dayIndex)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date?, weekIndex: Int, dayIndex: Int) -> some View {
        let words = day.flatMap { wordsByDay[$0] } ?? 0
        let isFuture = day.map { $0 > Date() } ?? false

        return RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(fill(words: words, isFuture: isFuture, hasDay: day != nil))
            .frame(width: cell, height: cell)
            .opacity(hasAppeared || !playsEntrance ? 1 : 0)
            .animation(
                playsEntrance
                    ? .easeOut(duration: 0.28).delay(Double(weekIndex) * 0.012) : nil,
                value: hasAppeared
            )
            .help(tooltip(day: day, words: words))
            .accessibilityHidden(day == nil)
    }

    private func fill(words: Int, isFuture: Bool, hasDay: Bool) -> Color {
        guard hasDay, !isFuture else { return .clear }
        guard words > 0 else { return AppTheme.Accent.primary.opacity(0.07) }

        // Four steps against the best day, so a normal day is still visible
        // next to an outlier.
        let ratio = bestDayWordCount > 0 ? Double(words) / Double(bestDayWordCount) : 0
        let opacity: Double
        switch ratio {
        case ..<0.25: opacity = 0.28
        case ..<0.50: opacity = 0.48
        case ..<0.75: opacity = 0.70
        default: opacity = 0.92
        }
        return AppTheme.Accent.primary.opacity(opacity)
    }

    private func tooltip(day: Date?, words: Int) -> String {
        guard let day else { return "" }
        let date = day.formatted(date: .abbreviated, time: .omitted)
        guard words > 0 else {
            return String(format: String(localized: "%@: no dictation"), date)
        }
        return String(format: String(localized: "%@: %d words"), date, words)
    }

    private var legend: some View {
        HStack(spacing: 5) {
            Text("Less")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.Text.muted)

            ForEach([0.07, 0.28, 0.48, 0.70, 0.92] as [Double], id: \.self) { opacity in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(AppTheme.Accent.primary.opacity(opacity))
                    .frame(width: cell, height: cell)
            }

            Text("More")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.Text.muted)
        }
    }

    /// Columns of seven days, oldest first, ending with the week containing
    /// today. Built once in init: SwiftUI re-evaluates body freely, and this
    /// walks 126 dates plus a month-label pass each time as a computed property.
    private static func makeWeeks(weekCount: Int, calendar: Calendar) -> [[Date?]] {
        let today = calendar.startOfDay(for: Date())

        // Walk back to the start of this week, then back weekCount-1 weeks.
        let weekday = calendar.component(.weekday, from: today)
        let offsetIntoWeek = (weekday - calendar.firstWeekday + 7) % 7
        guard let thisWeekStart = calendar.date(byAdding: .day, value: -offsetIntoWeek, to: today),
            let firstWeekStart = calendar.date(
                byAdding: .day, value: -7 * (weekCount - 1), to: thisWeekStart
            )
        else {
            return []
        }

        return (0..<weekCount).map { weekIndex in
            (0..<7).map { dayIndex -> Date? in
                calendar.date(
                    byAdding: .day, value: weekIndex * 7 + dayIndex, to: firstWeekStart
                )
            }
        }
    }
}
