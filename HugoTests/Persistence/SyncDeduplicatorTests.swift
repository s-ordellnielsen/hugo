import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct SyncDeduplicatorTests {
    private let early = Date(timeIntervalSince1970: 1_000)
    private let late = Date(timeIntervalSince1970: 2_000)

    private func makeContext() throws -> ModelContext {
        ModelContext(try InMemoryModelContainer.make())
    }

    private func makeTracker(
        id: UUID = UUID(), name: String = "Field Service", isDefault: Bool = false, createdAt: Date
    ) -> Tracker {
        let tracker = Tracker(id: id, name: name, isDefault: isDefault)
        tracker.createdAt = createdAt
        return tracker
    }

    private func makeEntry(for tracker: Tracker, in context: ModelContext) -> Entry {
        let entry = Entry(date: Date(timeIntervalSince1970: 5_000), duration: 3_600, tracker: tracker)
        context.insert(entry)
        return entry
    }

    /// Two same-id default trackers with one entry each.
    private func makeSharedIDSetup(
        in context: ModelContext, earlyName: String = "Field Service", lateName: String = "Field Service"
    ) throws -> (first: Tracker, second: Tracker, entries: [Entry]) {
        let sharedID = UUID()
        let first = makeTracker(id: sharedID, name: earlyName, isDefault: true, createdAt: early)
        let second = makeTracker(id: sharedID, name: lateName, isDefault: true, createdAt: late)
        context.insert(first)
        context.insert(second)
        let entries = [makeEntry(for: first, in: context), makeEntry(for: second, in: context)]
        try context.save()
        return (first, second, entries)
    }

    @Test
    func mergesCategoriesSharingAnID() throws {
        let context = try makeContext()
        let setup = try makeSharedIDSetup(in: context)

        let removed = try SyncDeduplicator(context: context).mergeDuplicateCategories()

        let trackers = try context.fetch(FetchDescriptor<Tracker>())
        #expect(removed == 1)
        #expect(trackers.count == 1)
        #expect(trackers.first?.createdAt == early)
        #expect(trackers.first?.isDefault == true)
        for entry in setup.entries {
            #expect(entry.tracker?.createdAt == early)
        }
    }

    @Test
    func earliestCopyKeepsTheUsersRename() throws {
        let context = try makeContext()
        _ = try makeSharedIDSetup(in: context, earlyName: "Tjeneste", lateName: "Field Service")

        try SyncDeduplicator(context: context).mergeDuplicateCategories()

        let trackers = try context.fetch(FetchDescriptor<Tracker>())
        #expect(trackers.count == 1)
        #expect(trackers.first?.name == "Tjeneste")
    }

    @Test
    func movedEntriesGetFreshSnapshots() throws {
        let context = try makeContext()
        let setup = try makeSharedIDSetup(in: context, earlyName: "Tjeneste", lateName: "Field Service")

        try SyncDeduplicator(context: context).mergeDuplicateCategories()

        for entry in setup.entries {
            #expect(entry.storedTracker?.name == "Tjeneste")
        }
    }

    @Test
    func distinctCategoriesAreUntouched() throws {
        let context = try makeContext()
        context.insert(makeTracker(name: "A", createdAt: early))
        context.insert(makeTracker(name: "B", createdAt: late))
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateCategories()

        #expect(removed == 0)
        #expect(try context.fetch(FetchDescriptor<Tracker>()).count == 2)
    }

    @Test
    func indistinguishableCopiesAreKept() throws {
        let context = try makeContext()
        let sharedID = UUID()
        context.insert(makeTracker(id: sharedID, createdAt: early))
        context.insert(makeTracker(id: sharedID, createdAt: early))
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateCategories()

        #expect(removed == 0)
        #expect(try context.fetch(FetchDescriptor<Tracker>()).count == 2)
    }

    @Test
    func colorBreaksATieBetweenOtherwiseEqualCopies() throws {
        let context = try makeContext()
        let sharedID = UUID()
        let uncolored = makeTracker(id: sharedID, createdAt: early)
        let colored = makeTracker(id: sharedID, createdAt: early)
        colored.setCategoryColor(CategoryColor(hue: 0.6, tone: 0.55))
        context.insert(uncolored)
        context.insert(colored)
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateCategories()

        let trackers = try context.fetch(FetchDescriptor<Tracker>())
        #expect(removed == 1)
        #expect(trackers.count == 1)
        #expect(trackers.first?.categoryColor == nil)
    }

    @Test
    func onlyOneDefaultRemains() throws {
        let context = try makeContext()
        context.insert(makeTracker(name: "Early", isDefault: true, createdAt: early))
        context.insert(makeTracker(name: "Late", isDefault: true, createdAt: late))
        try context.save()

        try SyncDeduplicator(context: context).mergeDuplicateCategories()

        let defaults = try context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.isDefault }))
        #expect(defaults.count == 1)
        #expect(defaults.first?.createdAt == early)
    }

    @Test
    func isIdempotent() throws {
        let context = try makeContext()
        _ = try makeSharedIDSetup(in: context)
        let deduplicator = SyncDeduplicator(context: context)

        try deduplicator.mergeDuplicateCategories()
        let second = try deduplicator.mergeDuplicateCategories()

        #expect(second == 0)
    }

    // MARK: - Monthly reports and carried-in entries

    private func makeReport(
        month: Int = 6, submittedAt: Date, entriesClosedAt: Date = .distantPast,
        lines: [SubmittedReport.SubmittedReportingLine] = [], in context: ModelContext
    ) -> SubmittedReport {
        let report = SubmittedReport(
            year: 2026, month: month, submittedAt: submittedAt, entriesClosedAt: entriesClosedAt,
            reportingLines: lines)
        context.insert(report)
        return report
    }

    private func makeCarry(
        from report: SubmittedReport, duration: TimeInterval = 1_800, lineID: String = "",
        createdAt: Date = Date(timeIntervalSince1970: 3_000), in context: ModelContext
    ) -> Entry {
        let entry = Entry(
            date: Date(timeIntervalSince1970: 1_782_864_000), duration: duration, tracker: nil,
            source: (submission: report, lineID: lineID))
        entry.createdAt = createdAt
        context.insert(entry)
        return entry
    }

    @Test
    func realSubmissionReplacesPlaceholder() throws {
        let context = try makeContext()
        _ = makeReport(submittedAt: .distantPast, in: context)
        _ = makeReport(submittedAt: early, in: context)
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateMonthlyReports()

        let reports = try context.fetch(FetchDescriptor<SubmittedReport>())
        #expect(removed == 1)
        #expect(reports.count == 1)
        #expect(reports.first?.submittedAt == early)
    }

    @Test
    func latestRealSubmissionWinsAndKeepsCarryEntries() throws {
        let context = try makeContext()
        let older = makeReport(submittedAt: early, in: context)
        _ = makeReport(submittedAt: late, in: context)
        let carry = makeCarry(from: older, in: context)
        try context.save()

        try SyncDeduplicator(context: context).mergeDuplicateMonthlyReports()

        let reports = try context.fetch(FetchDescriptor<SubmittedReport>())
        #expect(reports.count == 1)
        #expect(reports.first?.submittedAt == late)
        #expect(carry.sourceSubmission === reports.first)
    }

    @Test
    func linesMoveFromPlaceholderToRealReport() throws {
        let context = try makeContext()
        let real = makeReport(submittedAt: early, in: context)
        let line = SubmittedReport.SubmittedReportingLine(
            typeRaw: TrackerType.main.rawValue, submittedHours: 2)
        _ = makeReport(submittedAt: .distantPast, lines: [line], in: context)
        try context.save()

        try SyncDeduplicator(context: context).mergeDuplicateMonthlyReports()

        #expect(real.reportingLines.count == 1)
        #expect(real.reportingLines.first?.submittedHours == 2)
    }

    @Test
    func identicalRealReportsAreKept() throws {
        let context = try makeContext()
        _ = makeReport(submittedAt: early, entriesClosedAt: early, in: context)
        _ = makeReport(submittedAt: early, entriesClosedAt: early, in: context)
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateMonthlyReports()

        #expect(removed == 0)
        #expect(try context.fetch(FetchDescriptor<SubmittedReport>()).count == 2)
    }

    @Test
    func differentMonthsAreUntouched() throws {
        let context = try makeContext()
        _ = makeReport(month: 5, submittedAt: early, in: context)
        _ = makeReport(month: 6, submittedAt: early, in: context)
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateMonthlyReports()

        #expect(removed == 0)
        #expect(try context.fetch(FetchDescriptor<SubmittedReport>()).count == 2)
    }

    @Test
    func identicalCarryEntriesCollapseToOne() throws {
        let context = try makeContext()
        let report = makeReport(submittedAt: early, in: context)
        _ = makeCarry(from: report, in: context)
        _ = makeCarry(from: report, in: context)
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateCarryEntries()

        let entries = try context.fetch(FetchDescriptor<Entry>())
        #expect(removed == 1)
        #expect(entries.count == 1)
        #expect(entries.first?.duration == 1_800)
        #expect(entries.first?.sourceReportingLineID == "")
        #expect(entries.first?.sourceSubmission === report)
        let lines = ReportingLineCalculator.lines(from: entries)
        #expect(lines.first { $0.type == .main }?.carriedInSeconds == 1_800)
    }

    @Test
    func differentLinesAreKept() throws {
        let context = try makeContext()
        let report = makeReport(submittedAt: early, in: context)
        _ = makeCarry(from: report, lineID: "", in: context)
        _ = makeCarry(from: report, lineID: "Bethel", in: context)
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateCarryEntries()

        #expect(removed == 0)
        #expect(try context.fetch(FetchDescriptor<Entry>()).count == 2)
    }

    @Test
    func entryLinkedToCanonicalReportIsTheTemplate() throws {
        let context = try makeContext()
        let older = makeReport(submittedAt: early, in: context)
        let newer = makeReport(submittedAt: late, in: context)
        _ = makeCarry(from: older, duration: 1_200, in: context)
        _ = makeCarry(from: newer, duration: 1_800, in: context)
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateCarryEntries()

        let entries = try context.fetch(FetchDescriptor<Entry>())
        #expect(removed == 1)
        #expect(entries.count == 1)
        #expect(entries.first?.duration == 1_800)
    }

    @Test
    func ordinaryEntriesAreUntouched() throws {
        let context = try makeContext()
        let tracker = makeTracker(createdAt: early)
        context.insert(tracker)
        _ = makeEntry(for: tracker, in: context)
        _ = makeEntry(for: tracker, in: context)
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateCarryEntries()

        #expect(removed == 0)
        #expect(try context.fetch(FetchDescriptor<Entry>()).count == 2)
    }

    @Test
    func runIsIdempotent() throws {
        let context = try makeContext()
        _ = makeReport(submittedAt: .distantPast, in: context)
        let report = makeReport(submittedAt: early, in: context)
        _ = makeCarry(from: report, in: context)
        _ = makeCarry(from: report, in: context)
        try context.save()
        let deduplicator = SyncDeduplicator(context: context)

        deduplicator.run()
        deduplicator.run()

        #expect(try deduplicator.mergeDuplicateMonthlyReports() == 0)
        #expect(try deduplicator.mergeDuplicateCarryEntries() == 0)
        #expect(try context.fetch(FetchDescriptor<SubmittedReport>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Entry>()).count == 1)
    }

    // MARK: - Carry entry date repair

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func utcDate(_ month: Int, _ day: Int, hour: Int) -> Date {
        utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test
    func carryEntryOutsideItsMonthIsMoved() throws {
        let context = try makeContext()
        let report = makeReport(submittedAt: early, in: context)
        let entry = makeCarry(from: report, in: context)
        entry.date = utcDate(6, 30, hour: 22)
        try context.save()

        let repaired = try SyncDeduplicator(context: context).repairCarryEntryDates(calendar: utc)

        #expect(repaired == 1)
        #expect(entry.date == utcDate(7, 1, hour: 12))
    }

    @Test
    func carryEntryInsideItsMonthIsUntouched() throws {
        let context = try makeContext()
        let report = makeReport(submittedAt: early, in: context)
        let entry = makeCarry(from: report, in: context)
        entry.date = utcDate(7, 1, hour: 0)
        try context.save()

        let repaired = try SyncDeduplicator(context: context).repairCarryEntryDates(calendar: utc)

        #expect(repaired == 0)
        #expect(entry.date == utcDate(7, 1, hour: 0))
    }

    @Test
    func ordinaryEntriesAreNotRepaired() throws {
        let context = try makeContext()
        let entry = Entry(date: utcDate(6, 30, hour: 22), duration: 3_600, tracker: nil)
        context.insert(entry)
        try context.save()

        let repaired = try SyncDeduplicator(context: context).repairCarryEntryDates(calendar: utc)

        #expect(repaired == 0)
        #expect(entry.date == utcDate(6, 30, hour: 22))
    }
}
