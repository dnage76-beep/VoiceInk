import Foundation
import Testing

@testable import VoiceInk

/// The streak is a number the user will notice being wrong, and its rules are
/// all about boundaries: midnight, a single missed day, gaps in old history.
struct DashboardStreakTests {
    private let calendar = DashboardPeriodWindows.dashboardCalendar()

    /// Fixed reference point so these never depend on the day they run.
    private var now: Date {
        DateComponents(
            calendar: calendar,
            year: 2026, month: 7, day: 30, hour: 14
        ).date!
    }

    private func days(agoFromToday offsets: [Int]) -> Set<Date> {
        let today = calendar.startOfDay(for: now)
        return Set(
            offsets.compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: today)
            }
        )
    }

    private func streaks(_ offsets: [Int]) -> (current: Int, longest: Int) {
        DashboardStatsLoader.dayStreaks(
            activeDays: days(agoFromToday: offsets),
            now: now,
            calendar: calendar
        )
    }

    @Test func noSessionsMeansNoStreak() {
        let result = DashboardStatsLoader.dayStreaks(activeDays: [], now: now, calendar: calendar)
        #expect(result.current == 0)
        #expect(result.longest == 0)
    }

    @Test func todayOnlyIsAStreakOfOne() {
        let result = streaks([0])
        #expect(result.current == 1)
        #expect(result.longest == 1)
    }

    @Test func consecutiveDaysEndingTodayCount() {
        let result = streaks([0, 1, 2, 3])
        #expect(result.current == 4)
        #expect(result.longest == 4)
    }

    /// The whole reason the current streak tolerates a one-day lag: at 9am you
    /// have not dictated yet today, and yesterday's run is still alive.
    @Test func streakSurvivesUntilTodayIsActuallyMissed() {
        let result = streaks([1, 2, 3])
        #expect(result.current == 3)
    }

    @Test func missingTwoDaysBreaksTheCurrentStreak() {
        let result = streaks([2, 3, 4])
        #expect(result.current == 0)
        #expect(result.longest == 3)
    }

    /// A long-dead run should still be reported as the best ever.
    @Test func longestStreakRemembersOlderRuns() {
        // A 5-day run two weeks ago, then a 2-day run ending today.
        let result = streaks([0, 1, 14, 15, 16, 17, 18])
        #expect(result.current == 2)
        #expect(result.longest == 5)
    }

    @Test func gapsWithinHistoryDoNotMerge() {
        // Two separate 2-day runs, nothing recent.
        let result = streaks([10, 11, 20, 21])
        #expect(result.current == 0)
        #expect(result.longest == 2)
    }

    @Test func duplicateSessionsOnOneDayCountOnce() {
        // The loader inserts start-of-day into a Set, so a busy day is one day.
        let today = calendar.startOfDay(for: now)
        let result = DashboardStatsLoader.dayStreaks(
            activeDays: [today],
            now: now,
            calendar: calendar
        )
        #expect(result.current == 1)
        #expect(result.longest == 1)
    }
}

/// Words per minute is shown as a headline number, so its guard against
/// nonsense extrapolation from very short clips matters.
struct DashboardWordsPerMinuteTests {
    @Test func computesRateOverRecordedTime() {
        let totals = DashboardMetricTotals(count: 1, words: 150, duration: 60)
        #expect(totals.wordsPerMinute == 150)
    }

    @Test func roundsToNearestWord() {
        // 100 words in 90s = 66.67 wpm.
        let totals = DashboardMetricTotals(count: 1, words: 100, duration: 90)
        #expect(totals.wordsPerMinute == 67)
    }

    @Test func tooShortToBeMeaningful() {
        // Two words in a one-second clip would extrapolate to 120 wpm.
        let totals = DashboardMetricTotals(count: 1, words: 2, duration: 1)
        #expect(totals.wordsPerMinute == nil)
    }

    @Test func noWordsMeansNoRate() {
        let totals = DashboardMetricTotals(count: 1, words: 0, duration: 30)
        #expect(totals.wordsPerMinute == nil)
    }

    @Test func emptyTotalsHaveNoRate() {
        #expect(DashboardMetricTotals().wordsPerMinute == nil)
    }
}
