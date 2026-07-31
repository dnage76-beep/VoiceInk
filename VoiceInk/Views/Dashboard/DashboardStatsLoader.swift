import Foundation
import SwiftData

enum DashboardStatsLoader {
    static func load(from modelContainer: ModelContainer) async throws -> DashboardStatsSummary {
        let task = Task.detached(priority: .utility) {
            try Task.checkCancellation()

            let backgroundContext = ModelContext(modelContainer)
            let count = try backgroundContext.fetchCount(FetchDescriptor<SessionMetric>())

            try Task.checkCancellation()

            var words = 0
            var duration: TimeInterval = 0
            var todayCount = 0
            var todayWords = 0
            var todayDuration: TimeInterval = 0
            var recentSevenDayCount = 0
            var recentSevenDayWords = 0
            var recentSevenDayDuration: TimeInterval = 0
            var previousSevenDayCount = 0
            var previousSevenDayWords = 0
            var previousSevenDayDuration: TimeInterval = 0
            var lastThirtyDayCount = 0
            var lastThirtyDayWords = 0
            var lastThirtyDayDuration: TimeInterval = 0
            var thisYearCount = 0
            var thisYearWords = 0
            var thisYearDuration: TimeInterval = 0
            var lastSevenDayTranscriptionPerformance: [String: ModelPerformanceAccumulator] = [:]
            var lastSevenDayEnhancementPerformance: [String: ModelPerformanceAccumulator] = [:]
            var lastThirtyDayTranscriptionPerformance: [String: ModelPerformanceAccumulator] = [:]
            var lastThirtyDayEnhancementPerformance: [String: ModelPerformanceAccumulator] = [:]
            var thisYearTranscriptionPerformance: [String: ModelPerformanceAccumulator] = [:]
            var thisYearEnhancementPerformance: [String: ModelPerformanceAccumulator] = [:]
            var allTimeTranscriptionPerformance: [String: ModelPerformanceAccumulator] = [:]
            var allTimeEnhancementPerformance: [String: ModelPerformanceAccumulator] = [:]
            var todayTranscriptionPerformance: [String: ModelPerformanceAccumulator] = [:]
            var todayEnhancementPerformance: [String: ModelPerformanceAccumulator] = [:]
            var lastSevenDayTranscriptionAudioUsage: [String: TranscriptionAudioUsageAccumulator] = [:]
            var lastSevenDayEnhancementTokenUsage: [String: EnhancementTokenUsageAccumulator] = [:]
            var lastThirtyDayTranscriptionAudioUsage: [String: TranscriptionAudioUsageAccumulator] = [:]
            var lastThirtyDayEnhancementTokenUsage: [String: EnhancementTokenUsageAccumulator] = [:]
            var thisYearTranscriptionAudioUsage: [String: TranscriptionAudioUsageAccumulator] = [:]
            var thisYearEnhancementTokenUsage: [String: EnhancementTokenUsageAccumulator] = [:]
            var allTimeTranscriptionAudioUsage: [String: TranscriptionAudioUsageAccumulator] = [:]
            var allTimeEnhancementTokenUsage: [String: EnhancementTokenUsageAccumulator] = [:]
            var todayTranscriptionAudioUsage: [String: TranscriptionAudioUsageAccumulator] = [:]
            var todayEnhancementTokenUsage: [String: EnhancementTokenUsageAccumulator] = [:]
            var todayPeakHours: [Int: DashboardPeakHourAccumulator] = [:]
            var lastSevenDayPeakHours: [Int: DashboardPeakHourAccumulator] = [:]
            var lastThirtyDayPeakHours: [Int: DashboardPeakHourAccumulator] = [:]
            var thisYearPeakHours: [Int: DashboardPeakHourAccumulator] = [:]
            var allTimePeakHours: [Int: DashboardPeakHourAccumulator] = [:]
            var allTimeMonthWords: [Date: Int] = [:]
            var firstMetricDate: Date?
            // Every day that saw at least one session, for the streak.
            var activeDays: Set<Date> = []
            var todayEnhancedCount = 0
            var recentSevenDayEnhancedCount = 0
            var lastThirtyDayEnhancedCount = 0
            var thisYearEnhancedCount = 0
            var totalEnhancedCount = 0
            // Which apps the dictated text was headed for. Only sessions
            // recorded after app capture shipped carry this, so the unattributed
            // tally is kept to explain a partial picture rather than hide one.
            var appUsage: [String: DashboardAppUsageAccumulator] = [:]
            var unattributedSessionCount = 0
            // One entry per active day, for the contribution-style grid.
            var wordsByDay: [Date: Int] = [:]
            // Recording time per day, paired with wordsByDay to find the best
            // speaking rate the user has ever sustained over a full day.
            var durationByDay: [Date: TimeInterval] = [:]
            let windows = DashboardPeriodWindows()
            let now = windows.now
            let calendar = windows.calendar
            var todayProductivity = Self.hourlyProductivityPoints(now: now, calendar: calendar)
            var lastSevenDayProductivity = Self.productivityPoints(
                dayCount: 7, now: now, calendar: calendar, labelStyle: .weekday)
            var lastThirtyDayProductivity = Self.productivityPoints(
                dayCount: 30, now: now, calendar: calendar, labelStyle: .dayOfMonth)
            var thisYearProductivity = Self.monthlyProductivityPoints(
                from: windows.thisYearStart, through: now, calendar: calendar)
            let todayHourIndices = Dictionary(
                uniqueKeysWithValues: todayProductivity.enumerated().map { index, point in
                    (startOfHour(for: point.date, calendar: calendar), index)
                })
            let sevenDayIndices = Dictionary(
                uniqueKeysWithValues: lastSevenDayProductivity.enumerated().map { index, point in
                    (calendar.startOfDay(for: point.date), index)
                })
            let thirtyDayIndices = Dictionary(
                uniqueKeysWithValues: lastThirtyDayProductivity.enumerated().map { index, point in
                    (calendar.startOfDay(for: point.date), index)
                })
            let thisYearMonthIndices = Dictionary(
                uniqueKeysWithValues: thisYearProductivity.enumerated().map { index, point in
                    (startOfMonth(for: point.date, calendar: calendar), index)
                })
            var offset = 0

            while offset < count {
                try Task.checkCancellation()

                var descriptor = FetchDescriptor<SessionMetric>(
                    sortBy: [SortDescriptor(\SessionMetric.timestamp, order: .forward)]
                )
                descriptor.fetchLimit = 5_000
                descriptor.fetchOffset = offset

                let records = try backgroundContext.fetch(descriptor)
                if records.isEmpty {
                    break
                }

                if firstMetricDate == nil {
                    firstMetricDate = records.first?.timestamp
                }

                for metric in records {
                    words += metric.wordCount
                    duration += metric.audioDuration

                    // A session counts as enhanced when a model actually ran on
                    // it, which is what naming a model records.
                    let wasEnhanced = sanitizedModelName(metric.aiEnhancementModelName) != nil
                    if wasEnhanced {
                        totalEnhancedCount += 1
                    }

                    if windows.todayInterval.contains(metric.timestamp) {
                        todayCount += 1
                        todayWords += metric.wordCount
                        todayDuration += metric.audioDuration
                        if wasEnhanced { todayEnhancedCount += 1 }
                    }

                    if windows.recentSevenDayInterval.contains(metric.timestamp) {
                        recentSevenDayCount += 1
                        recentSevenDayWords += metric.wordCount
                        recentSevenDayDuration += metric.audioDuration
                        if wasEnhanced { recentSevenDayEnhancedCount += 1 }
                    } else if windows.previousSevenDayInterval.contains(metric.timestamp) {
                        previousSevenDayCount += 1
                        previousSevenDayWords += metric.wordCount
                        previousSevenDayDuration += metric.audioDuration
                    }

                    if windows.recentThirtyDayInterval.contains(metric.timestamp) {
                        lastThirtyDayCount += 1
                        lastThirtyDayWords += metric.wordCount
                        lastThirtyDayDuration += metric.audioDuration
                        if wasEnhanced { lastThirtyDayEnhancedCount += 1 }
                    }

                    if windows.thisYearInterval.contains(metric.timestamp) {
                        thisYearCount += 1
                        thisYearWords += metric.wordCount
                        thisYearDuration += metric.audioDuration
                        if wasEnhanced { thisYearEnhancedCount += 1 }
                    }

                    let metricHourStart = startOfHour(for: metric.timestamp, calendar: calendar)
                    if let todayHourIndex = todayHourIndices[metricHourStart] {
                        todayProductivity[todayHourIndex].words += metric.wordCount
                    }

                    let metricDay = calendar.startOfDay(for: metric.timestamp)
                    activeDays.insert(metricDay)
                    wordsByDay[metricDay, default: 0] += metric.wordCount
                    durationByDay[metricDay, default: 0] += metric.audioDuration
                    accumulateAppUsage(for: metric, into: &appUsage, unattributed: &unattributedSessionCount)
                    if let weekIndex = sevenDayIndices[metricDay] {
                        lastSevenDayProductivity[weekIndex].words += metric.wordCount
                    }
                    if let monthIndex = thirtyDayIndices[metricDay] {
                        lastThirtyDayProductivity[monthIndex].words += metric.wordCount
                    }
                    if windows.thisYearInterval.contains(metric.timestamp) {
                        let metricMonth = startOfMonth(for: metric.timestamp, calendar: calendar)
                        if let thisYearIndex = thisYearMonthIndices[metricMonth] {
                            thisYearProductivity[thisYearIndex].words += metric.wordCount
                        }
                    }
                    allTimeMonthWords[startOfMonth(for: metric.timestamp, calendar: calendar), default: 0] +=
                        metric.wordCount

                    let metricHour = calendar.component(.hour, from: metric.timestamp)

                    if windows.todayInterval.contains(metric.timestamp) {
                        addModelPerformance(
                            for: metric,
                            transcriptionPerformance: &todayTranscriptionPerformance,
                            enhancementPerformance: &todayEnhancementPerformance
                        )
                        addModelUsage(
                            for: metric,
                            transcriptionAudioUsage: &todayTranscriptionAudioUsage,
                            enhancementTokenUsage: &todayEnhancementTokenUsage
                        )
                        addPeakHour(for: metric, hour: metricHour, day: metricDay, to: &todayPeakHours)
                    }
                    if windows.recentSevenDayInterval.contains(metric.timestamp) {
                        addModelPerformance(
                            for: metric,
                            transcriptionPerformance: &lastSevenDayTranscriptionPerformance,
                            enhancementPerformance: &lastSevenDayEnhancementPerformance
                        )
                        addModelUsage(
                            for: metric,
                            transcriptionAudioUsage: &lastSevenDayTranscriptionAudioUsage,
                            enhancementTokenUsage: &lastSevenDayEnhancementTokenUsage
                        )
                        addPeakHour(for: metric, hour: metricHour, day: metricDay, to: &lastSevenDayPeakHours)
                    }
                    if windows.recentThirtyDayInterval.contains(metric.timestamp) {
                        addModelPerformance(
                            for: metric,
                            transcriptionPerformance: &lastThirtyDayTranscriptionPerformance,
                            enhancementPerformance: &lastThirtyDayEnhancementPerformance
                        )
                        addModelUsage(
                            for: metric,
                            transcriptionAudioUsage: &lastThirtyDayTranscriptionAudioUsage,
                            enhancementTokenUsage: &lastThirtyDayEnhancementTokenUsage
                        )
                        addPeakHour(for: metric, hour: metricHour, day: metricDay, to: &lastThirtyDayPeakHours)
                    }
                    if windows.thisYearInterval.contains(metric.timestamp) {
                        addModelPerformance(
                            for: metric,
                            transcriptionPerformance: &thisYearTranscriptionPerformance,
                            enhancementPerformance: &thisYearEnhancementPerformance
                        )
                        addModelUsage(
                            for: metric,
                            transcriptionAudioUsage: &thisYearTranscriptionAudioUsage,
                            enhancementTokenUsage: &thisYearEnhancementTokenUsage
                        )
                        addPeakHour(for: metric, hour: metricHour, day: metricDay, to: &thisYearPeakHours)
                    }
                    addModelPerformance(
                        for: metric,
                        transcriptionPerformance: &allTimeTranscriptionPerformance,
                        enhancementPerformance: &allTimeEnhancementPerformance
                    )
                    addModelUsage(
                        for: metric,
                        transcriptionAudioUsage: &allTimeTranscriptionAudioUsage,
                        enhancementTokenUsage: &allTimeEnhancementTokenUsage
                    )
                    addPeakHour(for: metric, hour: metricHour, day: metricDay, to: &allTimePeakHours)
                }

                offset += records.count
            }

            try Task.checkCancellation()

            let streaks = Self.dayStreaks(activeDays: activeDays, now: now, calendar: calendar)

            let allTimeProductivity: [DashboardProductivityPoint] = {
                guard let firstMetricDate else { return [] }
                return Self.monthlyProductivityPoints(
                    from: firstMetricDate,
                    through: now,
                    calendar: calendar,
                    wordsByMonth: allTimeMonthWords
                )
            }()

            return DashboardStatsSummary(
                totalCount: count,
                totalWords: words,
                totalDuration: duration,
                todayCount: todayCount,
                todayWords: todayWords,
                todayDuration: todayDuration,
                recentSevenDayCount: recentSevenDayCount,
                recentSevenDayWords: recentSevenDayWords,
                recentSevenDayDuration: recentSevenDayDuration,
                previousSevenDayCount: previousSevenDayCount,
                previousSevenDayWords: previousSevenDayWords,
                previousSevenDayDuration: previousSevenDayDuration,
                lastThirtyDayCount: lastThirtyDayCount,
                lastThirtyDayWords: lastThirtyDayWords,
                lastThirtyDayDuration: lastThirtyDayDuration,
                thisYearCount: thisYearCount,
                thisYearWords: thisYearWords,
                thisYearDuration: thisYearDuration,
                todayProductivity: todayProductivity,
                lastSevenDayProductivity: lastSevenDayProductivity,
                lastThirtyDayProductivity: lastThirtyDayProductivity,
                thisYearProductivity: thisYearProductivity,
                allTimeProductivity: allTimeProductivity,
                todayModelPerformance: Self.modelPerformance(
                    transcription: todayTranscriptionPerformance,
                    enhancement: todayEnhancementPerformance
                ),
                lastSevenDayModelPerformance: Self.modelPerformance(
                    transcription: lastSevenDayTranscriptionPerformance,
                    enhancement: lastSevenDayEnhancementPerformance
                ),
                lastThirtyDayModelPerformance: Self.modelPerformance(
                    transcription: lastThirtyDayTranscriptionPerformance,
                    enhancement: lastThirtyDayEnhancementPerformance
                ),
                thisYearModelPerformance: Self.modelPerformance(
                    transcription: thisYearTranscriptionPerformance,
                    enhancement: thisYearEnhancementPerformance
                ),
                allTimeModelPerformance: Self.modelPerformance(
                    transcription: allTimeTranscriptionPerformance,
                    enhancement: allTimeEnhancementPerformance
                ),
                todayModelUsage: Self.modelUsage(
                    transcriptionAudio: todayTranscriptionAudioUsage,
                    enhancementTokens: todayEnhancementTokenUsage
                ),
                lastSevenDayModelUsage: Self.modelUsage(
                    transcriptionAudio: lastSevenDayTranscriptionAudioUsage,
                    enhancementTokens: lastSevenDayEnhancementTokenUsage
                ),
                lastThirtyDayModelUsage: Self.modelUsage(
                    transcriptionAudio: lastThirtyDayTranscriptionAudioUsage,
                    enhancementTokens: lastThirtyDayEnhancementTokenUsage
                ),
                thisYearModelUsage: Self.modelUsage(
                    transcriptionAudio: thisYearTranscriptionAudioUsage,
                    enhancementTokens: thisYearEnhancementTokenUsage
                ),
                allTimeModelUsage: Self.modelUsage(
                    transcriptionAudio: allTimeTranscriptionAudioUsage,
                    enhancementTokens: allTimeEnhancementTokenUsage
                ),
                todayPeakHours: Self.peakHoursSummary(from: todayPeakHours),
                lastSevenDayPeakHours: Self.peakHoursSummary(from: lastSevenDayPeakHours),
                lastThirtyDayPeakHours: Self.peakHoursSummary(from: lastThirtyDayPeakHours),
                thisYearPeakHours: Self.peakHoursSummary(from: thisYearPeakHours),
                allTimePeakHours: Self.peakHoursSummary(from: allTimePeakHours),
                currentDayStreak: streaks.current,
                longestDayStreak: streaks.longest,
                todayEnhancedCount: todayEnhancedCount,
                recentSevenDayEnhancedCount: recentSevenDayEnhancedCount,
                lastThirtyDayEnhancedCount: lastThirtyDayEnhancedCount,
                thisYearEnhancedCount: thisYearEnhancedCount,
                totalEnhancedCount: totalEnhancedCount,
                appUsage: Self.appUsageSummary(
                    from: appUsage,
                    unattributedSessionCount: unattributedSessionCount
                ),
                wordsByDay: wordsByDay,
                bestDayWordCount: wordsByDay.values.max() ?? 0,
                bestWordsPerMinute: Self.bestWordsPerMinute(
                    wordsByDay: wordsByDay,
                    durationByDay: durationByDay
                )
            )
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Current and longest runs of consecutive days with at least one session.
    ///
    /// The current streak is allowed to end yesterday rather than today: it is
    /// still an unbroken run until today is actually missed, and showing it
    /// collapse to zero every midnight would be wrong.
    static func dayStreaks(
        activeDays: Set<Date>,
        now: Date,
        calendar: Calendar
    ) -> (current: Int, longest: Int) {
        guard !activeDays.isEmpty else { return (0, 0) }

        let sortedDays = activeDays.sorted()

        var longest = 1
        var run = 1
        for index in 1..<max(sortedDays.count, 1) {
            let previous = sortedDays[index - 1]
            let day = sortedDays[index]
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? 0

            if gap == 1 {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }

        let today = calendar.startOfDay(for: now)
        guard let mostRecent = sortedDays.last,
            let daysSinceMostRecent = calendar.dateComponents([.day], from: mostRecent, to: today).day,
            daysSinceMostRecent <= 1
        else {
            return (0, longest)
        }

        // Walk back from the most recent active day while days stay contiguous.
        var current = 1
        var cursor = mostRecent
        while let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor),
            activeDays.contains(previousDay)
        {
            current += 1
            cursor = previousDay
        }

        return (current, max(longest, current))
    }

    private static func monthlyProductivityPoints(
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar,
        wordsByMonth: [Date: Int] = [:]
    ) -> [DashboardProductivityPoint] {
        let startMonth = startOfMonth(for: startDate, calendar: calendar)
        let endMonth = startOfMonth(for: endDate, calendar: calendar)
        guard let monthCount = calendar.dateComponents([.month], from: startMonth, to: endMonth).month else {
            return []
        }

        let labelFormatter = DateFormatter()
        labelFormatter.calendar = calendar
        labelFormatter.locale = .current
        labelFormatter.dateFormat = "MMM"

        let accessibilityFormatter = DateFormatter()
        accessibilityFormatter.calendar = calendar
        accessibilityFormatter.locale = .current
        accessibilityFormatter.dateFormat = "MMMM yyyy"

        return (0...max(monthCount, 0)).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: offset, to: startMonth) else {
                return nil
            }

            return DashboardProductivityPoint(
                date: startOfMonth(for: date, calendar: calendar),
                label: labelFormatter.string(from: date),
                accessibilityLabel: accessibilityFormatter.string(from: date),
                words: wordsByMonth[startOfMonth(for: date, calendar: calendar), default: 0]
            )
        }
    }

    private static func hourlyProductivityPoints(
        now: Date,
        calendar: Calendar
    ) -> [DashboardProductivityPoint] {
        let todayStart = calendar.startOfDay(for: now)
        let labelFormatter = Formatters.localizedHourFormatter(calendar: calendar)
        let accessibilityFormatter = Formatters.localizedHourFormatter(calendar: calendar)

        return (0..<24).compactMap { offset in
            guard let date = calendar.date(byAdding: .hour, value: offset, to: todayStart) else {
                return nil
            }

            return DashboardProductivityPoint(
                date: startOfHour(for: date, calendar: calendar),
                label: labelFormatter.string(from: date),
                accessibilityLabel: accessibilityFormatter.string(from: date)
            )
        }
    }

    private static func productivityPoints(
        dayCount: Int,
        now: Date,
        calendar: Calendar,
        labelStyle: DashboardProductivityLabelStyle
    ) -> [DashboardProductivityPoint] {
        guard let startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: calendar.startOfDay(for: now))
        else {
            return []
        }

        let labelFormatter = DateFormatter()
        labelFormatter.calendar = calendar
        labelFormatter.locale = .current
        labelFormatter.dateFormat = labelStyle.dateFormat

        let accessibilityFormatter = DateFormatter()
        accessibilityFormatter.calendar = calendar
        accessibilityFormatter.locale = .current
        accessibilityFormatter.dateStyle = .medium

        return (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else {
                return nil
            }

            return DashboardProductivityPoint(
                date: calendar.startOfDay(for: date),
                label: labelFormatter.string(from: date),
                accessibilityLabel: accessibilityFormatter.string(from: date)
            )
        }
    }

    private static func modelPerformance(
        transcription: [String: ModelPerformanceAccumulator],
        enhancement: [String: ModelPerformanceAccumulator]
    ) -> [ModelPerformanceSummary] {
        let transcriptionSummaries = transcription.map { name, accumulator in
            accumulator.summary(kind: .transcription, name: name)
        }
        let enhancementSummaries = enhancement.map { name, accumulator in
            accumulator.summary(kind: .enhancement, name: name)
        }

        return transcriptionSummaries.sortedForPerformanceDisplay() + enhancementSummaries.sortedForPerformanceDisplay()
    }

    private static func addModelPerformance(
        for metric: SessionMetric,
        transcriptionPerformance: inout [String: ModelPerformanceAccumulator],
        enhancementPerformance: inout [String: ModelPerformanceAccumulator]
    ) {
        if let modelName = sanitizedModelName(metric.transcriptionModelName),
            let transcriptionDuration = metric.transcriptionDuration,
            transcriptionDuration > 0
        {
            transcriptionPerformance[modelName, default: ModelPerformanceAccumulator()].add(
                processingDuration: transcriptionDuration,
                audioDuration: metric.audioDuration
            )
        }

        if let modelName = sanitizedModelName(metric.aiEnhancementModelName),
            let enhancementDuration = metric.enhancementDuration,
            enhancementDuration > 0
        {
            enhancementPerformance[modelName, default: ModelPerformanceAccumulator()].add(
                processingDuration: enhancementDuration
            )
        }
    }

    private static func modelUsage(
        transcriptionAudio: [String: TranscriptionAudioUsageAccumulator],
        enhancementTokens: [String: EnhancementTokenUsageAccumulator]
    ) -> ModelUsageSummary {
        let transcriptionSummaries =
            transcriptionAudio
            .map { name, accumulator in accumulator.summary(name: name) }
            .sorted { lhs, rhs in
                if lhs.totalAudioDuration != rhs.totalAudioDuration {
                    return lhs.totalAudioDuration > rhs.totalAudioDuration
                }

                if lhs.sessionCount != rhs.sessionCount {
                    return lhs.sessionCount > rhs.sessionCount
                }

                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        let enhancementSummaries =
            enhancementTokens
            .map { name, accumulator in accumulator.summary(name: name) }
            .sorted { lhs, rhs in
                if lhs.estimatedTokens != rhs.estimatedTokens {
                    return lhs.estimatedTokens > rhs.estimatedTokens
                }

                if lhs.sessionCount != rhs.sessionCount {
                    return lhs.sessionCount > rhs.sessionCount
                }

                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        return ModelUsageSummary(
            transcriptionModels: transcriptionSummaries,
            enhancementModels: enhancementSummaries
        )
    }

    private static func addModelUsage(
        for metric: SessionMetric,
        transcriptionAudioUsage: inout [String: TranscriptionAudioUsageAccumulator],
        enhancementTokenUsage: inout [String: EnhancementTokenUsageAccumulator]
    ) {
        if let modelName = sanitizedModelName(metric.transcriptionModelName),
            metric.audioDuration > 0
        {
            transcriptionAudioUsage[modelName, default: TranscriptionAudioUsageAccumulator()].add(
                audioDuration: metric.audioDuration
            )
        }

        if let modelName = sanitizedModelName(metric.aiEnhancementModelName) {
            let tokens = max(metric.enhancementEstimatedTokenCount ?? 0, 0)
            enhancementTokenUsage[modelName, default: EnhancementTokenUsageAccumulator()].add(
                tokens: tokens
            )
        }
    }

    private static func addPeakHour(
        for metric: SessionMetric,
        hour: Int,
        day: Date,
        to peakHours: inout [Int: DashboardPeakHourAccumulator]
    ) {
        peakHours[hour, default: DashboardPeakHourAccumulator()].add(
            words: metric.wordCount,
            audioDuration: metric.audioDuration,
            day: day
        )
    }

    /// The best speaking rate sustained across a whole day.
    ///
    /// Measured per day rather than per session on purpose: a single six-word
    /// burst can score absurdly high, and a "personal best" the user can never
    /// beat again is worse than no number. Days under a minute of total audio
    /// are ignored for the same reason.
    static func bestWordsPerMinute(
        wordsByDay: [Date: Int],
        durationByDay: [Date: TimeInterval]
    ) -> Int? {
        var best: Int?

        for (day, words) in wordsByDay {
            guard let duration = durationByDay[day], duration >= 60, words > 0 else { continue }
            let rate = Int((Double(words) / (duration / 60)).rounded())
            if rate > (best ?? 0) {
                best = rate
            }
        }

        return best
    }

    /// Files one session under the app it was dictated into. Sessions recorded
    /// before app capture shipped have no app, and are counted separately so the
    /// card can say so rather than silently under-reporting.
    private static func accumulateAppUsage(
        for metric: SessionMetric,
        into appUsage: inout [String: DashboardAppUsageAccumulator],
        unattributed: inout Int
    ) {
        // Fall back to the display name when a bundle ID is missing, so an app
        // that reports only one of the two is still charted.
        guard let key = metric.targetAppBundleID ?? metric.targetAppName, !key.isEmpty else {
            unattributed += 1
            return
        }

        let displayName = metric.targetAppName ?? metric.targetAppBundleID ?? key
        appUsage[
            key,
            default: DashboardAppUsageAccumulator(
                bundleID: metric.targetAppBundleID,
                name: displayName
            )
        ].add(words: metric.wordCount)
    }

    private static func appUsageSummary(
        from appUsage: [String: DashboardAppUsageAccumulator],
        unattributedSessionCount: Int
    ) -> DashboardAppUsageSummary {
        let apps =
            appUsage.values
            .map { $0.usage() }
            .sorted { lhs, rhs in
                if lhs.wordCount == rhs.wordCount {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.wordCount > rhs.wordCount
            }

        var byCategory: [DictationCategory: (sessions: Int, words: Int)] = [:]
        for app in apps {
            byCategory[app.category, default: (0, 0)].sessions += app.sessionCount
            byCategory[app.category, default: (0, 0)].words += app.wordCount
        }

        let categories =
            byCategory
            .map { category, totals in
                CategoryDictationUsage(
                    category: category,
                    sessionCount: totals.sessions,
                    wordCount: totals.words
                )
            }
            .sorted { $0.category.sortIndex < $1.category.sortIndex }

        return DashboardAppUsageSummary(
            apps: apps,
            categories: categories,
            unattributedSessionCount: unattributedSessionCount
        )
    }

    private static func peakHoursSummary(from peakHours: [Int: DashboardPeakHourAccumulator])
        -> DashboardPeakHoursSummary
    {
        let hourlyActivity = (0..<24).map { hour in
            peakHours[hour, default: DashboardPeakHourAccumulator()].point(hour: hour)
        }

        var bestStartHour = 0
        var bestWordCount = 0
        var bestSessionCount = 0

        for startHour in 0..<24 {
            let first = peakHours[startHour, default: DashboardPeakHourAccumulator()]
            let second = peakHours[(startHour + 1) % 24, default: DashboardPeakHourAccumulator()]
            let windowWordCount = first.wordCount + second.wordCount
            let windowSessionCount = first.sessionCount + second.sessionCount

            if windowWordCount > bestWordCount
                || (windowWordCount == bestWordCount && windowSessionCount > bestSessionCount)
            {
                bestStartHour = startHour
                bestWordCount = windowWordCount
                bestSessionCount = windowSessionCount
            }
        }

        return DashboardPeakHoursSummary(
            startHour: bestStartHour,
            endHour: (bestStartHour + 2) % 24,
            wordCount: bestWordCount,
            sessionCount: bestSessionCount,
            hourlyActivity: hourlyActivity
        )
    }
}

private func startOfMonth(for date: Date, calendar: Calendar) -> Date {
    calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
}

private func startOfHour(for date: Date, calendar: Calendar) -> Date {
    calendar.dateInterval(of: .hour, for: date)?.start ?? date
}

private enum DashboardProductivityLabelStyle {
    case weekday
    case dayOfMonth

    var dateFormat: String {
        switch self {
        case .weekday: return "E"
        case .dayOfMonth: return "d"
        }
    }
}

private struct ModelPerformanceAccumulator {
    var sessionCount = 0
    var totalProcessingDuration: TimeInterval = 0
    var totalAudioDuration: TimeInterval = 0

    mutating func add(processingDuration: TimeInterval, audioDuration: TimeInterval = 0) {
        sessionCount += 1
        totalProcessingDuration += processingDuration
        totalAudioDuration += max(audioDuration, 0)
    }

    func summary(kind: ModelInsightKind, name: String) -> ModelPerformanceSummary {
        ModelPerformanceSummary(
            kind: kind,
            name: name,
            sessionCount: sessionCount,
            averageProcessingDuration: sessionCount > 0 ? totalProcessingDuration / Double(sessionCount) : nil,
            averageSpeedFactor: totalProcessingDuration > 0 && totalAudioDuration > 0
                ? totalAudioDuration / totalProcessingDuration : nil
        )
    }
}

private struct TranscriptionAudioUsageAccumulator {
    var sessionCount = 0
    var totalAudioDuration: TimeInterval = 0

    mutating func add(audioDuration: TimeInterval) {
        sessionCount += 1
        totalAudioDuration += audioDuration
    }

    func summary(name: String) -> TranscriptionModelUsage {
        TranscriptionModelUsage(
            name: name,
            sessionCount: sessionCount,
            totalAudioDuration: totalAudioDuration
        )
    }
}

private struct EnhancementTokenUsageAccumulator {
    var sessionCount = 0
    var estimatedTokens = 0

    mutating func add(tokens: Int) {
        sessionCount += 1
        estimatedTokens += tokens
    }

    func summary(name: String) -> EnhancementTokenUsage {
        EnhancementTokenUsage(
            name: name,
            sessionCount: sessionCount,
            estimatedTokens: estimatedTokens
        )
    }
}

private struct DashboardPeakHourAccumulator {
    var wordCount = 0
    var sessionCount = 0
    var audioDuration: TimeInterval = 0
    var activeDays: Set<Date> = []

    mutating func add(words: Int, audioDuration: TimeInterval, day: Date) {
        wordCount += words
        sessionCount += 1
        self.audioDuration += audioDuration
        activeDays.insert(day)
    }

    func point(hour: Int) -> DashboardHourlyActivityPoint {
        DashboardHourlyActivityPoint(
            hour: hour,
            wordCount: wordCount,
            sessionCount: sessionCount,
            audioDuration: audioDuration,
            activeDayCount: activeDays.count
        )
    }
}

private struct DashboardAppUsageAccumulator {
    var bundleID: String?
    var name: String
    var wordCount = 0
    var sessionCount = 0

    mutating func add(words: Int) {
        wordCount += words
        sessionCount += 1
    }

    func usage() -> AppDictationUsage {
        AppDictationUsage(
            bundleID: bundleID,
            name: name,
            category: DictationCategory.category(forBundleID: bundleID),
            sessionCount: sessionCount,
            wordCount: wordCount
        )
    }
}

private func sanitizedModelName(_ name: String?) -> String? {
    guard let name else {
        return nil
    }

    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
