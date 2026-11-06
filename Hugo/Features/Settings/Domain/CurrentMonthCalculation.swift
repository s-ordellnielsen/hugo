import Foundation

nonisolated struct CurrentMonthCalculation: Sendable {
    struct Option: Sendable {
        let pacing: YearlyGoalPacing
        let fraction: Double
        let contributionSeconds: TimeInterval
        let expectedSeconds: TimeInterval
    }

    let firstDayLabel: String
    let lastDayLabel: String
    let todayLabel: String
    let todayFraction: Double
    let monthlyGoalSeconds: TimeInterval
    let options: [Option]

    static func make(
        status: PublisherStatus?,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> CurrentMonthCalculation? {
        guard let status, let rule = status.yearlyGoalRule else { return nil }
        let month = now.yearMonth(using: calendar)
        let firstDay = month.date(calendar: calendar)
        guard let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) else { return nil }
        let currentFraction = YearlyGoalPacing.proRated.currentMonthFraction(now: now, calendar: calendar)

        var dateStyle = Date.FormatStyle().month(.wide).day()
        dateStyle.calendar = calendar
        dateStyle.timeZone = calendar.timeZone
        dateStyle.locale = locale
        let todayStyle = Date.FormatStyle().month(.wide).day().weekday(.wide)
        var localizedTodayStyle = todayStyle
        localizedTodayStyle.calendar = calendar
        localizedTodayStyle.timeZone = calendar.timeZone
        localizedTodayStyle.locale = locale

        let report = TheocraticYearReportBuilder.report(
            for: TheocraticYear.containing(now, calendar: calendar),
            entries: [],
            now: now,
            calendar: calendar,
            locale: locale)

        let options = YearlyGoalPacing.allCases.compactMap { pacing -> Option? in
            guard
                let progress = YearlyGoalProgress.make(
                    report: report, status: status, pacing: pacing, now: now, calendar: calendar),
                let expectedSeconds = progress.expectedSeconds
            else { return nil }
            let fraction = pacing.currentMonthFraction(now: now, calendar: calendar)
            return Option(
                pacing: pacing,
                fraction: fraction,
                contributionSeconds: rule.monthlyGoalSeconds * fraction,
                expectedSeconds: expectedSeconds)
        }

        return CurrentMonthCalculation(
            firstDayLabel: firstDay.formatted(dateStyle),
            lastDayLabel: lastDay.formatted(dateStyle),
            todayLabel: now.formatted(localizedTodayStyle),
            todayFraction: currentFraction,
            monthlyGoalSeconds: rule.monthlyGoalSeconds,
            options: options)
    }
}
