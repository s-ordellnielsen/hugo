import Foundation
import SwiftData

/// What the plan form produces.
struct PlanDraft {
    let day: CalendarDay
    let duration: TimeInterval
    /// Minutes after midnight, or nil.
    let startMinute: Int?
    let tracker: Tracker
}

/// Creates, changes and deletes plans. Every write is saved on its own, so a
/// failure never discards other edits.
@MainActor
struct PlanService {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    @discardableResult
    func add(_ draft: PlanDraft) throws -> Plan {
        let plan = Plan(
            date: draft.day.midday(calendar: calendar), duration: draft.duration,
            startMinute: draft.startMinute, tracker: draft.tracker)
        try context.performIsolatedChange { context.insert(plan) }
        return plan
    }

    func update(_ plan: Plan, with draft: PlanDraft) throws {
        try context.performIsolatedChange {
            plan.date = draft.day.midday(calendar: calendar)
            plan.duration = draft.duration
            plan.startMinute = draft.startMinute
            plan.setCategory(draft.tracker)
        }
    }

    func delete(_ plan: Plan) throws {
        try context.performIsolatedChange { context.delete(plan) }
    }
}
