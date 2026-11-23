/// What tapping a Planner day opens. A day with no plans and no logged
/// entries goes straight to Add Plan, unless it is in the past, where adding a plan
/// makes little sense. Every other day opens the day sheet.
nonisolated enum PlannerDayDestination: Equatable, Sendable {
    case daySheet
    case addPlan

    init(day: PlannerDay) {
        self = day.bars.isEmpty && !day.isPast ? .addPlan : .daySheet
    }
}
