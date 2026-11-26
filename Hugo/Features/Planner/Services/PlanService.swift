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

    /// Moves the plans with `planIDs` to `day`, keeping their duration, start
    /// time and category. Rows that share an id move together. Returns how many
    /// rows moved.
    @discardableResult
    func move(planIDs: [UUID], to day: CalendarDay) throws -> Int {
        guard !planIDs.isEmpty else { return 0 }
        let descriptor = FetchDescriptor<Plan>(predicate: #Predicate<Plan> { planIDs.contains($0.id) })
        let plans = try context.fetch(descriptor)
        let date = day.midday(calendar: calendar)
        try context.performIsolatedChange {
            for plan in plans { plan.date = date }
        }
        return plans.count
    }

    func delete(_ plan: Plan) throws {
        try context.performIsolatedChange { context.delete(plan) }
    }
}
