import Foundation

/// One plan as the Planner reads it. Today every item comes from a `Plan` row.
/// Repeating plans will produce items too, without storing rows, so Planner
/// math and lists read items, never `Plan` directly.
nonisolated struct PlannedItem: Identifiable, Equatable, Sendable {
    /// The plan's `id` as a string. Repeating plans will use their own scheme.
    let id: String
    let day: CalendarDay
    let duration: TimeInterval
    /// Minutes after midnight, or nil.
    let startMinute: Int?
    let categoryName: String
    let categoryIconName: String
    let categoryType: TrackerType
    /// The live category's id, or nil when the category no longer exists.
    let trackerID: UUID?
    /// The live category's color, or nil for Automatic (views use `CategoryColorStyle`).
    let color: CategoryColor?

    /// The same key `Entry.resolvedCategory()` produces for this category, so
    /// logged time can be matched to the plan.
    var categoryKey: String {
        if let trackerID { return trackerID.uuidString }
        return "stored:\(categoryName)|\(categoryIconName)|\(categoryType.rawValue)"
    }
}

extension PlannedItem {
    /// Uses the live category when `trackers` has one with the plan's
    /// `categoryID`, otherwise the plan's snapshot.
    nonisolated init(_ plan: Plan, trackers: [Tracker], calendar: Calendar = .current) {
        let live = plan.categoryID.flatMap { id in trackers.first { $0.id == id } }
        self.init(
            id: plan.id.uuidString,
            day: CalendarDay(plan.date, calendar: calendar),
            duration: max(plan.duration, 0),
            startMinute: plan.startMinute,
            categoryName: live?.name ?? plan.categoryName,
            categoryIconName: live?.iconName ?? plan.categoryIconName,
            categoryType: live?.type ?? plan.categoryType,
            trackerID: live?.id,
            color: live?.categoryColor)
    }
}
