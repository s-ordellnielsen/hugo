import Foundation

/// How much of the current month counts as "expected so far" on the yearly goal bar.
nonisolated enum YearlyGoalPacing: String, CaseIterable, Sendable {
    case proRated
    case completedMonths
    case includeCurrentMonth
}

nonisolated extension YearlyGoalPacing {
    func currentMonthFraction(now: Date = .now, calendar: Calendar = .current) -> Double {
        switch self {
        case .proRated:
            let current = now.yearMonth(using: calendar)
            let day = calendar.component(.day, from: now)
            return Double(day) / Double(current.lastDay(calendar: calendar))
        case .completedMonths:
            return 0
        case .includeCurrentMonth:
            return 1
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .proRated: "settings.yearlyGoal.pacing.proRated.description"
        case .completedMonths: "settings.yearlyGoal.pacing.completedMonths.description"
        case .includeCurrentMonth: "settings.yearlyGoal.pacing.includeCurrentMonth.description"
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .proRated: "settings.yearlyGoal.pacing.proRated"
        case .completedMonths: "settings.yearlyGoal.pacing.completedMonths"
        case .includeCurrentMonth: "settings.yearlyGoal.pacing.includeCurrentMonth"
        }
    }
}
