/// Where a day's plans may be dropped: on a day that is not in the past and is
/// not the day they come from. Matches `PlannerDayDestination`, which also
/// treats past days apart.
nonisolated enum PlanMoveRule {
    static func canDrop(from source: CalendarDay, on target: PlannerDay) -> Bool {
        !target.isPast && target.id != source
    }

    /// Whether `target` shows the drop highlight. The payload is unknown while
    /// hovering, so only the target's own state counts.
    static func acceptsDrops(_ target: PlannerDay) -> Bool {
        !target.isPast
    }
}
