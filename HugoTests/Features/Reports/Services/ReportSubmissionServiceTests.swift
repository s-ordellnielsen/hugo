import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct ReportSubmissionServiceTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let month = YearMonth(year: 2026, month: 6)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func juneEntry(seconds: TimeInterval) -> Entry {
        Entry(date: date(2026, 6, 5), duration: seconds, tracker: nil)
    }

    private func reportingResults(
        _ entries: [Entry],
        rule: RoundingRule
    ) -> (results: [ReportingLineResult], summary: MonthlyReportSummary?) {
        let lines = ReportingLineCalculator.lines(from: entries, calendar: calendar)
        let results = ReportingLineCalculator.compute(lines, rules: ["": rule])
        let summary = MonthlyReportBuilder.summaries(from: entries, calendar: calendar).first
        return (results, summary)
    }

    @Test
    func transferCreatesOneCarriedInEntryInTheNextMonth() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let (results, summary) = reportingResults([juneEntry(seconds: 5_400)], rule: .transfer)

        let report = try ReportSubmissionService(context: context, calendar: calendar)
            .submit(results, summary: summary, for: month, replacing: nil, at: now)

        let carried = report.generatedEntries ?? []
        #expect(carried.count == 1)
        #expect(carried.first?.duration == 1_800)
        #expect(carried.first?.date == month.carriedInDate(calendar: calendar))
        #expect(carried.first?.storedTracker?.type == .main)
    }

    @Test
    func submissionWritesOnlyTheFieldsTheAppReads() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let (results, summary) = reportingResults([juneEntry(seconds: 5_400)], rule: .transfer)

        let report = try ReportSubmissionService(context: context, calendar: calendar)
            .submit(results, summary: summary, for: month, replacing: nil, at: now)

        #expect(report.reportingLines.count == 1)
        #expect(report.submittedHours == 1)
        #expect(report.actualTotalSeconds == 5_400)
        #expect(report.totalBibleStudies == 0)
        // Read only by migrations from V9 and V10 stores, so no longer written.
        #expect(report.roundingRuleRaw == "")
        #expect(report.fieldServiceSeconds == 0)
        #expect(report.carriedInSeconds == 0)
        #expect(report.carriedOutSeconds == 0)
        #expect(report.roundedUpSeconds == 0)
        #expect(report.roundedDownSeconds == 0)
        #expect(report.categories?.isEmpty == true)
    }

    @Test
    func resubmittingUpdatesTheExistingRowInPlace() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let service = ReportSubmissionService(context: context, calendar: calendar)
        let (transferred, transferSummary) = reportingResults([juneEntry(seconds: 5_400)], rule: .transfer)
        let first = try service.submit(
            transferred, summary: transferSummary, for: month, replacing: nil, at: now)

        let later = now.addingTimeInterval(60)
        let (rounded, roundedSummary) = reportingResults([juneEntry(seconds: 5_400)], rule: .down)
        let second = try service.submit(
            rounded, summary: roundedSummary, for: month, replacing: first, at: later)

        #expect(second === first)
        #expect(second.firstSubmittedAt == now)
        #expect(second.submittedAt == later)
        #expect(try context.fetch(FetchDescriptor<Entry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SubmittedReport>()).count == 1)
    }

    @Test
    func placeholderGetsItsFirstSubmittedDate() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let placeholder = SubmittedReport(year: 2026, month: 6, entriesClosedAt: date(2026, 6, 1))
        context.insert(placeholder)
        let (results, summary) = reportingResults([juneEntry(seconds: 3_600)], rule: .down)

        let report = try ReportSubmissionService(context: context, calendar: calendar)
            .submit(results, summary: summary, for: month, replacing: placeholder, at: now)

        #expect(report === placeholder)
        #expect(report.firstSubmittedAt == now)
    }
}
