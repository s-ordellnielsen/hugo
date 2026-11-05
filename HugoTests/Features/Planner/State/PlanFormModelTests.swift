import Foundation
import Testing

@testable import Hugo

@MainActor
struct PlanFormModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let day = CalendarDay(year: 2026, month: 11, day: 4)

    @Test
    func newFormCannotBeSavedWithoutDurationOrCategory() {
        let model = PlanFormModel(day: day, calendar: calendar)

        #expect(model.durationInSeconds == 0)
        #expect(model.isSaveDisabled)
        #expect(model.draft() == nil)
        #expect(model.validationMessage != nil)
    }

    @Test
    func editingPlanPrefillsDurationStartTimeAndCategory() {
        let fieldService = Tracker(name: "Field Service", isDefault: true)
        let ldc = Tracker(name: "LDC", type: .separate)
        let plan = Plan(date: day.midday(calendar: calendar), duration: 7_200, startMinute: 630, tracker: ldc)
        let model = PlanFormModel(day: day, plan: plan, calendar: calendar)

        #expect(model.durationInSeconds == 7_200)
        #expect(model.startMinute == 630)
        model.reconcileSelection(with: [fieldService, ldc])
        #expect(model.selectedTracker?.id == ldc.id)
        #expect(model.isSaveDisabled == false)
    }

    @Test
    func clearingStartTimeDropsItFromTheDraft() throws {
        let fieldService = Tracker(name: "Field Service", isDefault: true)
        let model = PlanFormModel(day: day, calendar: calendar)
        model.durationInSeconds = 3_600
        model.reconcileSelection(with: [fieldService])
        model.startTime = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 10))
        model.startTime = nil

        let draft = try #require(model.draft())
        #expect(draft.startMinute == nil)
    }
}
