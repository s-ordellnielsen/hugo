import Foundation

/// What Add Entry starts with when the user logs a plan: the plan's day,
/// category and start time, and the part of the plan not covered yet.
nonisolated struct PlanLogSeed: Identifiable, Equatable, Sendable {
    /// The plan item's id.
    let id: String
    /// 12:00 on the plan's day.
    let date: Date
    /// The plan's remaining time, rounded down to whole minutes.
    let duration: TimeInterval
    let trackerID: UUID?
    /// Minutes after midnight, or nil.
    let startMinute: Int?

    /// `bar` is the plan's bar from `PlannerDay.make`. Without a bar, the whole
    /// plan counts as remaining.
    init(item: PlannedItem, bar: PlannerBar?, calendar: Calendar = .current) {
        let remaining = bar?.remainingSeconds ?? item.duration
        self.id = item.id
        self.date = item.day.midday(calendar: calendar)
        self.duration = (remaining / 60).rounded(.down) * 60
        self.trackerID = item.trackerID
        self.startMinute = item.startMinute
    }
}
