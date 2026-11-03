import Foundation
import OSLog
import SwiftData

/// Merges rows that CloudKit sync duplicated. CloudKit cannot enforce unique
/// values, so two devices that each created the same logical row (for example
/// the seeded default category) end up with two copies after sync.
///
/// Every device runs this independently, so each rule must pick the same
/// survivor on every device using synced attributes only.
@MainActor
struct SyncDeduplicator {
    private static let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Sync")
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Runs every merge and logs failures. Safe to call often.
    func run() {
        do {
            let removed = try mergeDuplicateCategories()
            if removed > 0 {
                Self.logger.info("Merged \(removed) duplicate categories")
            }
            let removedReports = try mergeDuplicateMonthlyReports()
            if removedReports > 0 {
                Self.logger.info("Merged \(removedReports) duplicate monthly reports")
            }
            let removedCarries = try mergeDuplicateCarryEntries()
            if removedCarries > 0 {
                Self.logger.info("Merged \(removedCarries) duplicate carried-in entries")
            }
            let repairedCarries = try repairCarryEntryDates()
            if repairedCarries > 0 {
                Self.logger.info("Moved \(repairedCarries) carried-in entries back into their month")
            }
        } catch {
            Self.logger.error("Deduplication failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns the number of deleted duplicates.
    @discardableResult
    func mergeDuplicateCategories() throws -> Int {
        let trackers = try context.fetch(FetchDescriptor<Tracker>())
        var removed = 0
        var changed = false
        var deletedIDs = Set<PersistentIdentifier>()

        for group in Dictionary(grouping: trackers, by: \.id).values where group.count > 1 {
            let sorted = group.sorted(by: Self.survivorPrecedes)
            // The first two are indistinguishable: two devices could each keep
            // a different copy and together delete both.
            guard Self.survivorPrecedes(sorted[0], sorted[1]) else { continue }

            let survivor = sorted[0]
            for loser in sorted.dropFirst() {
                for entry in Array(loser.entries ?? []) {
                    entry.tracker = survivor
                    entry.refreshStoredTracker()
                }
                if loser.isDefault { survivor.isDefault = true }
                deletedIDs.insert(loser.persistentModelID)
                context.delete(loser)
                removed += 1
                changed = true
            }
        }

        let defaults =
            trackers
            .filter { !deletedIDs.contains($0.persistentModelID) && $0.isDefault }
            .sorted(by: Self.survivorPrecedes)
        for extra in defaults.dropFirst() {
            extra.isDefault = false
            changed = true
        }

        if changed { try context.save() }
        return removed
    }

    /// Collapses several report rows for one month into the canonical one.
    /// Returns the number of deleted rows.
    @discardableResult
    func mergeDuplicateMonthlyReports() throws -> Int {
        let reports = try context.fetch(FetchDescriptor<SubmittedReport>())
        var groups: [YearMonth: [SubmittedReport]] = [:]
        for report in reports {
            guard
                let year = report.year, year > 0,
                let month = report.month, (1...12).contains(month)
            else { continue }
            groups[YearMonth(year: year, month: month), default: []].append(report)
        }

        var removed = 0
        for (month, group) in groups where group.count > 1 {
            guard let winner = SubmittedReportSelection.canonical(for: month, in: group)
            else { continue }

            // Real rows that tie cannot be ordered safely: two devices could
            // each keep a different one and together delete both.
            let winnerIsReal = SubmittedReportSelection.isReal(winner)
            if winnerIsReal {
                let tied = group.contains { other in
                    other !== winner
                        && SubmittedReportSelection.isReal(other)
                        && other.submittedAt == winner.submittedAt
                        && other.entriesClosedAt == winner.entriesClosedAt
                }
                if tied { continue }
            }

            // The pre-fix V10 to V11 migration could attach a real report's
            // lines to a placeholder.
            if winnerIsReal, winner.reportingLines.isEmpty,
                let donor = group.first(where: {
                    !SubmittedReportSelection.isReal($0) && !$0.reportingLines.isEmpty
                })
            {
                winner.reportingLines = donor.reportingLines
            }

            for loser in group where loser !== winner {
                for entry in Array(loser.generatedEntries ?? []) {
                    entry.sourceSubmission = winner
                }
                context.delete(loser)
                removed += 1
            }
        }

        if removed > 0 { try context.save() }
        return removed
    }

    /// Collapses carried-in entries that two devices each created for the same
    /// source month and line. Returns the number of removed entries.
    @discardableResult
    func mergeDuplicateCarryEntries() throws -> Int {
        let entries = try context.fetch(
            FetchDescriptor<Entry>(
                predicate: #Predicate { $0.sourceReportYear != nil && $0.sourceReportMonth != nil }
            )
        )
        var groups: [CarryKey: [Entry]] = [:]
        for entry in entries {
            guard let year = entry.sourceReportYear, let month = entry.sourceReportMonth else { continue }
            let key = CarryKey(
                month: YearMonth(year: year, month: month),
                lineID: entry.sourceReportingLineID ?? ""
            )
            groups[key, default: []].append(entry)
        }
        let duplicated = groups.filter { $0.value.count > 1 }
        guard !duplicated.isEmpty else { return 0 }

        let canonical = SubmittedReportSelection.canonicalByMonth(
            try context.fetch(FetchDescriptor<SubmittedReport>())
        )

        var removed = 0
        for (key, group) in duplicated {
            let report = canonical[key.month]
            let template = group.min { Self.templatePrecedes($0, $1, canonicalReport: report) }!

            let replacement: Entry
            if let report {
                replacement = Entry(
                    date: template.date,
                    duration: template.duration,
                    tracker: nil,
                    source: (submission: report, lineID: key.lineID)
                )
            } else {
                replacement = Entry(date: template.date, duration: template.duration, tracker: nil)
                replacement.sourceReportYear = key.month.year
                replacement.sourceReportMonth = key.month.month
                replacement.sourceReportingLineID = key.lineID
            }
            replacement.storedTracker = template.storedTracker
            replacement.createdAt = template.createdAt

            // Delete every copy and insert one: if each device kept "its" copy
            // and deleted the other, sync would delete both.
            for entry in group { context.delete(entry) }
            context.insert(replacement)
            removed += group.count - 1
        }

        try context.save()
        return removed
    }

    /// Moves carried-in entries back into the month after their source report
    /// when a time-zone change pushed them out of it. Entries already in the
    /// right month are left alone, so devices in different time zones (within
    /// 12 hours of each other) never rewrite each other's dates.
    @discardableResult
    func repairCarryEntryDates(calendar: Calendar = .current) throws -> Int {
        let entries = try context.fetch(
            FetchDescriptor<Entry>(
                predicate: #Predicate { $0.sourceReportYear != nil && $0.sourceReportMonth != nil }
            )
        )
        var repaired = 0
        for entry in entries {
            guard let year = entry.sourceReportYear, let month = entry.sourceReportMonth else { continue }
            let intended = YearMonth(year: year, month: month).nextMonth(calendar: calendar)
            guard entry.date.yearMonth(using: calendar) != intended else { continue }
            entry.date = intended.middayOnFirst(calendar: calendar)
            repaired += 1
        }
        if repaired > 0 { try context.save() }
        return repaired
    }

    private struct CarryKey: Hashable {
        let month: YearMonth
        let lineID: String
    }

    /// Canonical report's entry first, then latest `createdAt`, larger
    /// duration, earlier date.
    private static func templatePrecedes(
        _ a: Entry,
        _ b: Entry,
        canonicalReport: SubmittedReport?
    ) -> Bool {
        let aCanonical = canonicalReport != nil && a.sourceSubmission === canonicalReport
        let bCanonical = canonicalReport != nil && b.sourceSubmission === canonicalReport
        if aCanonical != bCanonical { return aCanonical }
        if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
        if a.duration != b.duration { return a.duration > b.duration }
        return a.date < b.date
    }

    /// Earliest `createdAt` wins; ties fall back to the remaining synced fields.
    private static func survivorPrecedes(_ a: Tracker, _ b: Tracker) -> Bool {
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        if a.name != b.name { return a.name < b.name }
        if a.iconName != b.iconName { return a.iconName < b.iconName }
        if a.type.rawValue != b.type.rawValue { return a.type.rawValue < b.type.rawValue }
        if a.hue != b.hue { return a.hue < b.hue }
        if a.sat != b.sat { return a.sat < b.sat }
        return a.bri < b.bri
    }
}
