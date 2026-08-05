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

    @Test
    func convertsDurationToSeconds() {
        let model = AddEntryFormModel(calendar: calendar, now: date(2026, 1, 1))
        model.durationDate = date(2026, 1, 1, hour: 1, minute: 30)
        #expect(model.durationInSeconds == 5_400)
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
        model.durationDate = date(2026, 1, 1, hour: 1)
        #expect(model.draft() == nil)
        #expect(model.validationMessage != nil)
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

    @Test(arguments: [0.0, 60.0, 5_400.0, 86_340.0])
    func durationRoundTrips(seconds: TimeInterval) {
        let reference = date(2026, 1, 1)
        let pickerDate = EntryDurationConversion.date(from: seconds, calendar: calendar, reference: reference)
        #expect(EntryDurationConversion.seconds(from: pickerDate, calendar: calendar) == seconds)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
