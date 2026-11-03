import Foundation
import Testing

@testable import Hugo

@MainActor
struct AddEntryFormModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test(arguments: [9_000.0, 86_400.0])
    func durationIsStoredWithoutClockConversion(seconds: TimeInterval) throws {
        var copenhagen = Calendar(identifier: .gregorian)
        copenhagen.timeZone = try #require(TimeZone(identifier: "Europe/Copenhagen"))
        // 2027-03-28 is the EU spring-forward Sunday; 02:00-02:59 does not exist.
        let springForward = try #require(
            copenhagen.date(from: DateComponents(year: 2027, month: 3, day: 28, hour: 12)))
        let model = AddEntryFormModel(calendar: copenhagen, now: springForward)
        model.selectedTracker = Tracker(name: "Field Service")

        model.durationInSeconds = seconds

        #expect(model.durationInSeconds == seconds)
        #expect(model.isSubmitDisabled == false)
    }

    @Test
    func combinesDateWithOptionalTime() throws {
        let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))
        model.date = date(2026, 1, 5)
        model.time = date(2026, 1, 1, hour: 14, minute: 25)
        let combined = try #require(model.combinedDate)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: combined)
        #expect(components.year == 2026)
        #expect(components.month == 1)
        #expect(components.day == 5)
        #expect(components.hour == 14)
        #expect(components.minute == 25)
    }

    @Test
    func optionalTimeDefaultsToMidnight() throws {
        let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))
        model.date = date(2026, 1, 5)
        let combined = try #require(model.combinedDate)
        let components = calendar.dateComponents([.hour, .minute, .second], from: combined)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test
    func bibleStudiesNeverBecomeNegative() {
        let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))
        model.decrementBibleStudies()
        model.incrementBibleStudies()
        model.decrementBibleStudies()
        model.decrementBibleStudies()
        #expect(model.bibleStudies == 0)
    }

    @Test
    func emptyCategoryPreventsDraftCreation() {
        let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))
        model.durationInSeconds = 3_600
        #expect(model.draft() == nil)
        #expect(model.validationMessage != nil)
    }

    @Test
    func draftWithoutTrackerProducesLocalizedValidationMessage() {
        let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))
        model.durationInSeconds = 3_600
        #expect(model.draft() == nil)
        #expect(model.validationMessage != "entry.add.validation.invalid")
        #expect(model.validationMessage?.isEmpty == false)
    }

    @Test
    func selectionPrefersDefaultAndPreservesExistingSelection() {
        let first = Tracker(name: "First")
        let selected = Tracker(name: "Selected")
        let defaultTracker = Tracker(name: "Default", isDefault: true)
        let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))

        model.reconcileSelection(with: [first, defaultTracker])
        #expect(model.selectedTracker?.id == defaultTracker.id)
        model.selectedTracker = selected
        model.reconcileSelection(with: [first, selected, defaultTracker])
        #expect(model.selectedTracker?.id == selected.id)
        model.reconcileSelection(with: [first, defaultTracker])
        #expect(model.selectedTracker?.id == defaultTracker.id)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
