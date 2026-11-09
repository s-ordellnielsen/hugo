import Foundation

/// One category's logged time on one day.
nonisolated struct LoggedCategoryTime: Equatable, Sendable {
    /// `EntryCategory.key`.
    let key: String
    let name: String
    let iconName: String
    /// Nil for untracked time, which counts as main.
    let type: TrackerType?
    let color: CategoryColor?
    var seconds: TimeInterval
}

/// One bar in a calendar day: one category's plans and how much of them logged
/// time covers, or logged time in a category with no plan that day.
nonisolated struct PlannerBar: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case plan
        case unplanned
    }

    /// `plan:` or `unplanned:` followed by the category key.
    let id: String
    let kind: Kind
    let categoryName: String
    let categoryIconName: String
    let color: CategoryColor?
    /// The category's planned time on the day, or the unplanned logged time.
    let seconds: TimeInterval
    /// Logged time counted toward this bar. Can be more than `seconds` when
    /// more was logged than planned. Equals `seconds` for unplanned time.
    let filledSeconds: TimeInterval
    /// The category's plans on the day in start-time order. Empty for unplanned time.
    let items: [PlannedItem]

    /// How full the bar is, from 0 to 1.
    var fraction: Double { seconds > 0 ? min(1, filledSeconds / seconds) : 0 }

    /// Planned time not covered yet. Always 0 for unplanned time.
    var remainingSeconds: TimeInterval { max(0, seconds - filledSeconds) }

    /// True when less than a minute of the plan is left.
    var isFull: Bool { remainingSeconds < 60 }
}

/// Matches one day's logged time to its plans, per category. Start times are
/// ignored: an entry does not record whether its time was picked or guessed.
/// Each category's plans share one bar. A bar takes time from its own category
/// first, then other time of the same kind (main or separate). Time beyond a
/// category's plans stays on that category's bar. Logged time left over in a
/// category with no plan becomes an unplanned bar.
nonisolated enum PlanMatcher {
    static func bars(plans: [PlannedItem], logged: [LoggedCategoryTime]) -> [PlannerBar] {
        let ordered = plans.enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.startMinute ?? Int.max
                let right = rhs.element.startMinute ?? Int.max
                return left != right ? left < right : lhs.offset < rhs.offset
            }
            .map(\.element)

        // One group per category, in the order of each category's first plan.
        var groupKeys: [String] = []
        var groupItems: [String: [PlannedItem]] = [:]
        for plan in ordered {
            if groupItems[plan.categoryKey] == nil {
                groupKeys.append(plan.categoryKey)
            }
            groupItems[plan.categoryKey, default: []].append(plan)
        }
        let plannedSeconds = groupItems.mapValues { items in items.reduce(0) { $0 + $1.duration } }

        let categories = logged.sorted { $0.key < $1.key }
        var unused = Dictionary(categories.map { ($0.key, $0.seconds) }, uniquingKeysWith: +)
        var filled: [String: TimeInterval] = [:]

        func fill(_ group: String, from key: String, upTo limit: TimeInterval) {
            let take = min(max(0, limit - (filled[group] ?? 0)), unused[key] ?? 0)
            guard take > 0 else { return }
            filled[group, default: 0] += take
            unused[key, default: 0] -= take
        }

        for key in groupKeys {
            fill(key, from: key, upTo: plannedSeconds[key] ?? 0)
        }
        for key in groupKeys {
            let type = groupItems[key]?.first?.categoryType ?? .main
            for category in categories where (category.type ?? .main) == type {
                fill(key, from: category.key, upTo: plannedSeconds[key] ?? 0)
            }
        }
        for key in groupKeys {
            fill(key, from: key, upTo: .infinity)
        }

        let planBars = groupKeys.compactMap { key -> PlannerBar? in
            guard let items = groupItems[key], let first = items.first else { return nil }
            return PlannerBar(
                id: "plan:\(key)", kind: .plan, categoryName: first.categoryName,
                categoryIconName: first.categoryIconName, color: first.color,
                seconds: plannedSeconds[key] ?? 0, filledSeconds: filled[key] ?? 0, items: items)
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
                    seconds: seconds, filledSeconds: seconds, items: [])
            }
        return planBars + unplannedBars
    }
}
