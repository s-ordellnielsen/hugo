import Foundation

/// One category's logged time on one day.
nonisolated struct LoggedCategoryTime: Equatable, Sendable {
    /// `EntryCategory.key`.
    let key: String
    let name: String
    let iconName: String
    /// Nil for untracked time, which counts as main.
    let type: TrackerType?
    let color: CategoryProgressColor?
    var seconds: TimeInterval
}

/// One bar in a calendar day: a plan and how much of it logged time covers, or
/// logged time that no plan covers.
nonisolated struct PlannerBar: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case plan
        case unplanned
    }

    /// The plan item's id, or `unplanned:` followed by the category key.
    let id: String
    let kind: Kind
    let categoryName: String
    let categoryIconName: String
    let color: CategoryProgressColor?
    /// The plan's duration, or the unplanned logged time.
    let seconds: TimeInterval
    /// Logged time counted toward this bar. Equals `seconds` for unplanned time.
    let filledSeconds: TimeInterval

    /// How full the bar is, from 0 to 1.
    var fraction: Double { seconds > 0 ? min(1, filledSeconds / seconds) : 0 }

    /// Planned time not covered yet. Always 0 for unplanned time.
    var remainingSeconds: TimeInterval { max(0, seconds - filledSeconds) }

    /// True when less than a minute of the plan is left.
    var isFull: Bool { remainingSeconds < 60 }
}

/// Matches one day's logged time to its plans: the same category first, then
/// the same kind (main or separate). Logged time left over becomes unplanned bars.
nonisolated enum PlanMatcher {
    static func bars(plans: [PlannedItem], logged: [LoggedCategoryTime]) -> [PlannerBar] {
        let ordered = plans.enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.startMinute ?? Int.max
                let right = rhs.element.startMinute ?? Int.max
                return left != right ? left < right : lhs.offset < rhs.offset
            }
            .map(\.element)
        let categories = logged.sorted { $0.key < $1.key }
        var unused = Dictionary(categories.map { ($0.key, $0.seconds) }, uniquingKeysWith: +)
        var filled: [String: TimeInterval] = [:]

        func fill(_ plan: PlannedItem, from key: String) {
            let need = plan.duration - (filled[plan.id] ?? 0)
            let take = min(max(0, need), unused[key] ?? 0)
            guard take > 0 else { return }
            filled[plan.id, default: 0] += take
            unused[key, default: 0] -= take
        }

        for plan in ordered {
            fill(plan, from: plan.categoryKey)
        }
        for plan in ordered {
            for category in categories where (category.type ?? .main) == plan.categoryType {
                fill(plan, from: category.key)
            }
        }

        let planBars = ordered.map { plan in
            PlannerBar(
                id: plan.id, kind: .plan, categoryName: plan.categoryName,
                categoryIconName: plan.categoryIconName, color: plan.color,
                seconds: plan.duration, filledSeconds: filled[plan.id] ?? 0)
        }
        let unplannedBars =
            categories
            .filter { (unused[$0.key] ?? 0) >= 60 }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { category in
                let seconds = unused[category.key] ?? 0
                return PlannerBar(
                    id: "unplanned:\(category.key)", kind: .unplanned, categoryName: category.name,
                    categoryIconName: category.iconName, color: category.color,
                    seconds: seconds, filledSeconds: seconds)
            }
        return planBars + unplannedBars
    }
}
