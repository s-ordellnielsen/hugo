import Foundation

/// What the monthly target starts from before Buffer is added.
nonisolated enum PlannerTargetBase: String, CaseIterable, Sendable {
    /// The publisher status's monthly goal.
    case monthlyGoal
    /// What is left of the yearly goal, shared evenly over the months left in
    /// the theocratic year. Only statuses with a yearly goal offer it.
    case yearlyGoalShare
}

nonisolated extension PlannerTargetBase {
    var label: LocalizedStringResource {
        switch self {
        case .monthlyGoal: "planner.target.base.monthlyGoal"
        case .yearlyGoalShare: "planner.target.base.yearlyGoalShare"
        }
    }
}

nonisolated enum PlannerTarget {
    static func settingSummary(
        base: PlannerTargetBase,
        extraHours: Int,
        status: PublisherStatus?,
        locale: Locale = .current
    ) -> String {
        let baseText: String?
        if let status, status.yearlyGoalRule != nil {
            switch base {
            case .monthlyGoal:
                baseText = String(localized: "planner.target.base.monthlyGoal", locale: locale)
            case .yearlyGoalShare:
                baseText = String(localized: "planner.target.base.yearlyGoalShare", locale: locale)
            }
        } else if (status?.monthlyGoal ?? 0) > 0 {
            baseText = String(localized: "planner.target.base.monthlyGoal", locale: locale)
        } else {
            baseText = nil
        }

        let extra = ServiceDurationFormatter.hoursString(from: TimeInterval(max(0, extraHours)) * 3_600, locale: locale)
        guard let baseText else {
            return extraHours > 0
                ? extra
                : String(localized: LocalizedStringResource("planner.target.none", locale: locale))
        }
        guard extraHours > 0 else { return baseText }
        let summary = LocalizedStringResource(
            "planner.target.summary.withExtra", defaultValue: "\(baseText) + \(extra)", locale: locale,
            comment: "A monthly target summary followed by extra hours. Both arguments are localized text.")
        return String(localized: summary)
    }

    /// The monthly target for `month` in seconds, or nil when it would be zero.
    /// `extraHours` is the nonnegative Buffer added to the base. Without a
    /// status goal, that Buffer is the whole personal monthly target.
    /// `creditedBeforeCurrentMonth` is the credited time of the current
    /// theocratic year's months before the current month; it is read only for
    /// `.yearlyGoalShare`.
    static func seconds(
        for month: YearMonth,
        base: PlannerTargetBase,
        extraHours: Int,
        status: PublisherStatus?,
        creditedBeforeCurrentMonth: TimeInterval,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TimeInterval? {
        var baseSeconds = TimeInterval(status?.monthlyGoal ?? 0) * 3_600

        if base == .yearlyGoalShare, let status, status.yearlyGoalRule != nil {
            let currentYear = TheocraticYear.containing(now, calendar: calendar)
            if currentYear.contains(month) {
                let current = now.yearMonth(using: calendar)
                let monthsLeft = currentYear.months.filter { $0 >= current }.count
                let left = max(0, TimeInterval(status.yearlyGoal) * 3_600 - creditedBeforeCurrentMonth)
                let hours = monthsLeft > 0 ? left / TimeInterval(monthsLeft) / 3_600 : 0
                // The epsilon keeps an exact 50.0 from rounding up to 51.
                baseSeconds = max(0, (hours - 1e-9).rounded(.up)) * 3_600
            }
        }

        let total = baseSeconds + TimeInterval(max(0, extraHours)) * 3_600
        return total > 0 ? total : nil
    }

    /// Credits time before the current month from the canonical report, using
    /// the same report-building rules as Planner and Yearly Goal Progress.
    static func creditedBeforeCurrentMonth(
        entries: [Entry],
        submissions: [SubmittedReport],
        trackers: [Tracker],
        status: PublisherStatus?,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> TimeInterval {
        guard let rule = status?.yearlyGoalRule else { return 0 }
        let report = TheocraticYearReportBuilder.report(
            for: TheocraticYear.containing(now, calendar: calendar),
            entries: entries, submissions: submissions, trackers: trackers,
            now: now, calendar: calendar, locale: locale)
        return creditedSeconds(before: now.yearMonth(using: calendar), in: report, rule: rule)
    }

    /// Credited time of the months in `report` before `month`, with the same
    /// formula as `YearlyGoalProgress`.
    static func creditedSeconds(
        before month: YearMonth, in report: TheocraticYearReport, rule: YearlyGoalRule
    ) -> TimeInterval {
        report.months.filter { $0.id < month }.reduce(0) { total, serviceMonth in
            let contribution = serviceMonth.contribution
            return total + rule.creditedSeconds(main: contribution.main, separate: contribution.separate)
        }
    }
}
