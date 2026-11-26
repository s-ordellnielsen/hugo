/// The context-menu actions of a Planner day. Plans belong to today and later;
/// logged time belongs to today and earlier, since Add Entry cannot date an
/// entry in the future.
nonisolated struct PlannerDayActions: Equatable, Sendable {
    let canAddPlan: Bool
    let canLogTime: Bool

    init(day: PlannerDay) {
        canAddPlan = !day.isPast
        canLogTime = day.isPast || day.isToday
    }
}
