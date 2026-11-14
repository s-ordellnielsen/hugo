import Foundation
import SwiftData

/// Saves a month's report and keeps its carried-in entries in the next month
/// in step with the report's transferred minutes.
@MainActor
struct ReportSubmissionService {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// Writes the report for `month` from the confirmed line results and saves
    /// the context. `existing` (a real report or a placeholder) is updated in
    /// place so CloudKit keeps one row per month; otherwise a new row is
    /// inserted. Report-level rounding, carry and category fields are left at
    /// their defaults: only migrations from older schema versions read them,
    /// and the reporting lines hold the same information. Carried-in entries
    /// are created, updated or deleted to match the transferred lines.
    @discardableResult
    func submit(
        _ results: [ReportingLineResult],
        summary: MonthlyReportSummary?,
        for month: YearMonth,
        replacing existing: SubmittedReport?,
        at now: Date
    ) throws -> SubmittedReport {
        let submittedHours = results.reduce(0) { $0 + $1.submittedHours }
        let closedAt = summary?.entries.map(\.createdAt).max() ?? now

        let report: SubmittedReport
        if let existing {
            if existing.firstSubmittedAt == nil || existing.firstSubmittedAt == .distantPast {
                existing.firstSubmittedAt = now
            }
            existing.submittedAt = now
            existing.entriesClosedAt = closedAt
            report = existing
        } else {
            report = SubmittedReport(
                year: month.year,
                month: month.month,
                firstSubmittedAt: now,
                submittedAt: now,
                entriesClosedAt: closedAt
            )
            context.insert(report)
        }

        report.actualTotalSeconds = summary?.totalSeconds ?? 0
        report.submittedHours = submittedHours
        report.totalBibleStudies = summary?.totalBibleStudies ?? 0
        report.reportingLines = results.map(\.persisted)

        reconcileCarriedInEntries(for: report, results: results, month: month, now: now)
        try context.save()
        return report
    }

    private func reconcileCarriedInEntries(
        for report: SubmittedReport,
        results: [ReportingLineResult],
        month: YearMonth,
        now: Date
    ) {
        let carryDate = month.carriedInDate(calendar: calendar)
        var existingByLine = Dictionary(grouping: report.generatedEntries ?? [], by: { $0.sourceReportingLineID ?? "" })

        for result in results {
            guard case .transferred(let seconds) = result.disposition else { continue }

            if let entry = existingByLine[result.id]?.first {
                if entry.duration != seconds {
                    entry.duration = seconds
                    entry.createdAt = now
                }
                existingByLine[result.id]?.removeFirst()
            } else {
                let entry = Entry(
                    date: carryDate,
                    duration: seconds,
                    tracker: nil,
                    source: (submission: report, lineID: result.id)
                )
                entry.storedTracker =
                    if result.line.type == .main {
                        .init(name: String(localized: "category.default.label"), icon: "figure.walk", type: .main)
                    } else {
                        .init(name: result.line.name, icon: result.line.iconName, type: .separate)
                    }
                entry.createdAt = now
                context.insert(entry)
            }
        }

        for leftover in existingByLine.values.flatMap({ $0 }) {
            context.delete(leftover)
        }
    }
}
