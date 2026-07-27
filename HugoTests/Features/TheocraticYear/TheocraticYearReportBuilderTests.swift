import Foundation
import Testing

@testable import Hugo

@MainActor
struct TheocraticYearReportBuilderTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let locale = Locale(identifier: "en_US_POSIX")

    @Test
    func emptyEntriesProduceTwelveEmptyMonthsAndZeroTotals() {
        let report = makeReport(entries: [])
        #expect(report.months.count == 12)
        #expect(!report.hasEntries)
        #expect(report.totalSeconds == 0)
        #expect(report.totalBibleStudies == 0)
        #expect(report.mainDuration == 0)
        #expect(report.separateDuration == 0)
    }

    @Test
    func excludesEntriesOutsideRequestedYear() {
        let report = makeReport(entries: [Entry(date: date(2026, 8, 31), duration: 3_600, tracker: nil)])
        #expect(!report.hasEntries)
        #expect(report.totalSeconds == 0)
    }

    @Test
    func addsSummaryOnlyForMonthsWithEntries() throws {
        let report = makeReport(entries: [Entry(date: date(2026, 9, 1), duration: 3_600, tracker: nil)])
        let september = try #require(report.months.first)
        #expect(september.summary?.totalSeconds == 3_600)
        #expect(report.months.dropFirst().allSatisfy { $0.summary == nil })
    }

    @Test
    func aggregatesTotalsAcrossMonthsAndCategoryTypes() {
        let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
        let separate = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let report = makeReport(entries: [
            Entry(date: date(2026, 9, 1), duration: 3_600, tracker: main, bibleStudies: 1),
            Entry(date: date(2027, 1, 1), duration: 1_800, tracker: separate, bibleStudies: 2),
        ])
        #expect(report.totalSeconds == 5_400)
        #expect(report.totalBibleStudies == 3)
        #expect(report.mainDuration == 3_600)
        #expect(report.separateDuration == 1_800)
    }

    @Test
    func ordersMonthsFromSeptemberThroughAugust() {
        let year = TheocraticYear(startYear: 2026)
        let report = makeReport(for: year, entries: [])
        #expect(report.months.map(\.id) == year.months)
    }

    @Test
    func marksOnlyMonthsAfterNowAsFuture() {
        let report = makeReport(entries: [], now: date(2026, 10, 15))
        #expect(report.months[0].isFuture == false)
        #expect(report.months[1].isFuture == false)
        #expect(report.months[2].isFuture == true)
    }

    private func makeReport(entries: [Entry]) -> TheocraticYearReport {
        makeReport(for: TheocraticYear(startYear: 2026), entries: entries, now: date(2026, 10, 15))
    }

    private func makeReport(entries: [Entry], now: Date) -> TheocraticYearReport {
        makeReport(for: TheocraticYear(startYear: 2026), entries: entries, now: now)
    }

    private func makeReport(for year: TheocraticYear, entries: [Entry]) -> TheocraticYearReport {
        makeReport(for: year, entries: entries, now: date(2026, 10, 15))
    }

    private func makeReport(for year: TheocraticYear, entries: [Entry], now: Date) -> TheocraticYearReport {
        TheocraticYearReportBuilder.report(
            for: year,
            entries: entries,
            now: now,
            calendar: calendar,
            locale: locale
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
