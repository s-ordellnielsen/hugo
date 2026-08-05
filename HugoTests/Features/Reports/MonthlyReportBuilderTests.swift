import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct MonthlyReportBuilderTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let locale = Locale(identifier: "en_US_POSIX")

    @Test
    func returnsNoSummariesForEmptyEntries() {
        #expect(MonthlyReportBuilder.summaries(from: [], calendar: calendar, locale: locale).isEmpty)
    }

    @Test
    func groupsAcrossYearBoundaryInDescendingOrder() {
        let entries = [
            Entry(date: date(2025, 12, 15), duration: 60, tracker: nil),
            Entry(date: date(2026, 1, 2), duration: 120, tracker: nil),
        ]
        let summaries = MonthlyReportBuilder.summaries(from: entries, calendar: calendar, locale: locale)

        #expect(summaries.map(\.id) == [YearMonth(year: 2026, month: 1), YearMonth(year: 2025, month: 12)])
        #expect(summaries.map(\.totalSeconds) == [120, 60])
    }

    @Test
    func aggregatesCategoryAndBibleStudyTotals() {
        let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
        let separate = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let entries = [
            Entry(date: date(2026, 1, 1), duration: 3_600, tracker: main, bibleStudies: 1),
            Entry(date: date(2026, 1, 2), duration: 1_800, tracker: main, bibleStudies: 2),
            Entry(date: date(2026, 1, 3), duration: 900, tracker: separate),
        ]
        let summary = try! #require(
            MonthlyReportBuilder.summaries(from: entries, calendar: calendar, locale: locale).first)

        #expect(summary.totalSeconds == 6_300)
        #expect(summary.totalBibleStudies == 3)
        #expect(summary.mainDuration == 5_400)
        #expect(summary.separateDuration == 900)
        #expect(summary.categories.map(\.name) == ["Field Service", "Bethel"])
        #expect(summary.categories.map(\.duration) == [5_400, 900])
    }

    @Test
    func usesStoredTrackerWhenLiveTrackerWasDeleted() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let tracker = Tracker(name: "Deleted", type: .separate, iconName: "archivebox")
        let entry = Entry(date: date(2026, 1, 1), duration: 1_800, tracker: tracker)
        context.insert(tracker)
        context.insert(entry)
        try context.save()
        context.delete(tracker)
        try context.save()
        let persistedEntry = try #require(context.fetch(FetchDescriptor<Entry>()).first)

        let summary = try #require(
            MonthlyReportBuilder.summaries(from: [persistedEntry], calendar: calendar, locale: locale).first)
        #expect(summary.categories.count == 1)
        #expect(summary.categories.first?.name == "Deleted")
        #expect(summary.categories.first?.iconName == "archivebox")
        #expect(summary.separateDuration == 1_800)
    }

    @Test
    func includesFullyUntrackedEntriesInTotal() throws {
        let entry = Entry(date: date(2026, 1, 1), duration: 600, tracker: nil)
        let summary = try #require(
            MonthlyReportBuilder.summaries(from: [entry], calendar: calendar, locale: locale).first)

        #expect(summary.totalSeconds == 600)
        #expect(summary.categories.count == 1)
        #expect(summary.categories.first?.name == String(localized: "entry.untracked", locale: locale))
        #expect(summary.categories.first?.type == nil)
    }

    @Test
    func usesInjectedLocaleForDisplayName() throws {
        let entry = Entry(date: date(2026, 9, 1), duration: 60, tracker: nil)
        let summary = try #require(
            MonthlyReportBuilder.summaries(from: [entry], calendar: calendar, locale: locale).first)
        #expect(summary.displayName == "September 2026")
    }

    @Test
    func breaksEqualCategoryTotalsDeterministicallyByName() {
        let alpha = Tracker(name: "Alpha", type: .separate)
        let beta = Tracker(name: "Beta", type: .separate)
        let entries = [
            Entry(date: date(2026, 1, 1), duration: 600, tracker: beta),
            Entry(date: date(2026, 1, 2), duration: 600, tracker: alpha),
        ]
        let summary = MonthlyReportBuilder.summaries(from: entries, calendar: calendar, locale: locale)[0]
        #expect(summary.categories.map(\.name) == ["Alpha", "Beta"])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
