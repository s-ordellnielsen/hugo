import Foundation

extension PlanPace {
    /// Differences smaller than a minute count as on plan.
    nonisolated static let onPlanThreshold: TimeInterval = 60

    /// "You're 3 hours ahead of your plan", "You're 2 hours behind your plan"
    /// or "You're right on your plan".
    nonisolated var differenceSentence: String {
        let difference = differenceSeconds
        guard abs(difference) >= Self.onPlanThreshold else {
            return String(
                localized: "overview.pace.onPlan", defaultValue: "You're right on your plan",
                comment: "Plan pace sheet: logged time matches the time planned up to now.")
        }
        let amount = ServiceDurationFormatter.hoursString(from: abs(difference))
        if difference > 0 {
            return String(
                localized: "overview.pace.ahead", defaultValue: "You're \(amount) ahead of your plan",
                comment:
                    "Plan pace sheet: logged time is ahead of the plan. The argument is a duration such as 3 hours.")
        }
        return String(
            localized: "overview.pace.behind", defaultValue: "You're \(amount) behind your plan",
            comment: "Plan pace sheet: logged time is behind the plan. The argument is a duration such as 3 hours.")
    }
}
