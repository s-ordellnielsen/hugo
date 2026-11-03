import Foundation

/// How much of the current month counts as "expected so far" on the yearly goal bar.
nonisolated enum YearlyGoalPacing: String, CaseIterable, Sendable {
    case proRated
    case completedMonths
    case includeCurrentMonth
}

extension YearlyGoalPacing {
    var label: LocalizedStringResource {
        switch self {
        case .proRated: "settings.yearlyGoal.pacing.proRated"
        case .completedMonths: "settings.yearlyGoal.pacing.completedMonths"
        case .includeCurrentMonth: "settings.yearlyGoal.pacing.includeCurrentMonth"
        }
    }
}
