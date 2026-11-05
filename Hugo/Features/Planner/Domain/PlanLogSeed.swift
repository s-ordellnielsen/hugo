import Foundation

/// What Add Entry starts with when the user logs a category's plans: the day,
/// the category, the start time of the first plan not covered yet, and the
/// category's planned time not covered yet.
nonisolated struct PlanLogSeed: Identifiable, Equatable, Sendable {
    /// The bar's id.
    let id: String
    /// 12:00 on the day.
    let date: Date
    /// The category's remaining planned time, rounded down to whole minutes.
    let duration: TimeInterval
    let trackerID: UUID?
    /// Minutes after midnight, or nil.
    let startMinute: Int?

    /// `bar` is a `.plan` bar from `PlannerDay.make` for `day`. Covered time
    /// counts against the bar's plans in start-time order, so the start time is
    /// that of the first plan with at least a minute left.
    init(bar: PlannerBar, day: CalendarDay, calendar: Calendar = .current) {
        self.id = bar.id
        self.date = day.midday(calendar: calendar)
        self.duration = (bar.remainingSeconds / 60).rounded(.down) * 60
        self.trackerID = bar.items.first?.trackerID
        var covered = bar.filledSeconds
        var startMinute: Int?
        for item in bar.items {
            if item.duration - covered >= 60 {
                startMinute = item.startMinute
                break
            }
            covered = max(0, covered - item.duration)
        }
        self.startMinute = startMinute
    }
}
