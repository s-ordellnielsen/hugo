import Foundation
import Testing

@testable import Hugo

@MainActor
struct CarriedInTimeTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func carriedIn(duration: TimeInterval, fromYear year: Int, month: Int) -> Entry {
        let entry = Entry(date: date(2026, 11, 1), duration: duration, tracker: nil)
        entry.sourceReportYear = year
        entry.sourceReportMonth = month
        return entry
    }

    @Test
    func nilWithoutCarriedInEntries() {
        let entries = [
            Entry(date: date(2026, 11, 3), duration: 3_600, tracker: nil),
            Entry(date: date(2026, 11, 9), duration: 1_800, tracker: nil),
        ]
        #expect(CarriedInTime(entries: entries) == nil)
    }

    @Test
    func nilForAnEmptyMonth() {
        #expect(CarriedInTime(entries: []) == nil)
    }

    @Test
    func sumsCarriedInEntriesOnly() throws {
        let entries = [
            Entry(date: date(2026, 11, 3), duration: 3_600, tracker: nil),
            carriedIn(duration: 1_800, fromYear: 2026, month: 10),
            carriedIn(duration: 900, fromYear: 2026, month: 10),
        ]
        let result = try #require(CarriedInTime(entries: entries))
        #expect(result.seconds == 2_700)
        #expect(result.sourceMonths == [YearMonth(year: 2026, month: 10)])
    }

    @Test
    func listsSourceMonthsOldestFirstWithoutDuplicates() throws {
        let entries = [
            carriedIn(duration: 600, fromYear: 2026, month: 10),
            carriedIn(duration: 600, fromYear: 2026, month: 9),
            carriedIn(duration: 600, fromYear: 2026, month: 10),
        ]
        let result = try #require(CarriedInTime(entries: entries))
        #expect(result.sourceMonths == [YearMonth(year: 2026, month: 9), YearMonth(year: 2026, month: 10)])
    }

    @Test
    func ignoresZeroLengthCarriedInEntries() {
        let entries = [carriedIn(duration: 0, fromYear: 2026, month: 10)]
        #expect(CarriedInTime(entries: entries) == nil)
    }
}
