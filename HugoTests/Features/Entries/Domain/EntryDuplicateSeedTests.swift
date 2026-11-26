import Foundation
import Testing

@testable import Hugo

struct EntryDuplicateSeedTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func copiesDurationAndCategory() {
        let id = UUID()
        let seed = EntryDuplicateSeed(
            entryDate: date(hour: 9), duration: 5_400, categoryID: id, calendar: calendar)
        #expect(seed.duration == 5_400)
        #expect(seed.categoryID == id)
    }

    @Test
    func startMinuteComesFromTheEntryTime() {
        let seed = EntryDuplicateSeed(
            entryDate: date(hour: 14, minute: 35), duration: 3_600, categoryID: nil, calendar: calendar)
        #expect(seed.startMinute == 875)
    }

    @Test
    func midnightIsMinuteZero() {
        let seed = EntryDuplicateSeed(
            entryDate: date(hour: 0), duration: 3_600, categoryID: nil, calendar: calendar)
        #expect(seed.startMinute == 0)
    }

    @Test
    func negativeDurationBecomesZero() {
        let seed = EntryDuplicateSeed(
            entryDate: date(hour: 9), duration: -60, categoryID: nil, calendar: calendar)
        #expect(seed.duration == 0)
    }

    @Test
    func missingCategoryStaysNil() {
        let seed = EntryDuplicateSeed(
            entryDate: date(hour: 9), duration: 3_600, categoryID: nil, calendar: calendar)
        #expect(seed.categoryID == nil)
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: hour, minute: minute))!
    }
}
