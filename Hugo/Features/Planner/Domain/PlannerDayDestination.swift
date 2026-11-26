/// What a Planner day opens. Tapping a day with no plans and no logged
/// entries goes straight to Add Plan, unless it is in the past, where adding a plan
/// makes little sense. Every other tap opens the day sheet. `logTime` is only
/// reached from the day's context menu.
nonisolated enum PlannerDayDestination: Equatable, Sendable {
    case daySheet
    case addPlan
    /// Add Entry dated that day. Never returned by `init(day:)`.
    case logTime

    init(day: PlannerDay) {
        self = day.bars.isEmpty && !day.isPast ? .addPlan : .daySheet
    }
}
