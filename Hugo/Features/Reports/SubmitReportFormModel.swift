import Foundation
import Observation
import SwiftData

/// State and workflow for the monthly report submission sheet. Pure logic
/// (rounding, composing, due checks) lives in the domain enums; this model
/// only coordinates inputs, derived values, and persistence.
@MainActor
@Observable
final class SubmitReportFormModel {
    let month: YearMonth

    private(set) var lines: [ReportingLine] = []
    private(set) var results: [ReportingLineResult] = []
    private var rules: [String: RoundingRule] = [:]
    private var didSeedRules = false

    /// The composed message ready to hand to Messages (or the pasteboard).
    /// Set by `prepareSubmission()`; cleared when the rule changes.
    private(set) var preparedContent: ReportMessageContent?

    private let calendar: Calendar
    private let now: Date
    private let locale: Locale
    private let userDefaults: UserDefaults

    private var entries: [Entry] = []
    private var submissions: [SubmittedReport] = []
    private var submissionsByMonth: [YearMonth: SubmittedReport] = [:]
    private var monthEntries: [Entry] = []
    private(set) var summary: MonthlyReportSummary?

    init(
        month: YearMonth,
        calendar: Calendar = .current,
        now: Date = .now,
        locale: Locale = .current,
        userDefaults: UserDefaults = .standard
    ) {
        self.month = month
        self.calendar = calendar
        self.now = now
        self.locale = locale
        self.userDefaults = userDefaults
    }

    // MARK: - Inputs

    /// Feeds the model its data. The view calls this on appear and whenever
    /// its queries change, keeping the model free of query concerns.
    func load(entries: [Entry], submissions: [SubmittedReport]) {
        self.entries = entries
        self.submissions = submissions
        self.submissionsByMonth = TheocraticYearReportBuilder.canonicalSubmissionsByMonth(submissions)
        self.monthEntries = entries.filter { $0.date.yearMonth(using: calendar) == month }
        self.summary = MonthlyReportBuilder.summaries(from: monthEntries, calendar: calendar).first
        self.lines = ReportingLineCalculator.lines(from: monthEntries, calendar: calendar)

        if !didSeedRules {
            for storedLine in existingSubmission?.reportingLines ?? [] {
                guard let rule = storedLine.rounding else { continue }
                rules[storedLine.id] = rule
            }
            didSeedRules = true
        }

        recompute()
    }

    // MARK: - Derived values

    func rule(for lineID: String) -> RoundingRule? {
        rules[lineID]
    }

    func setRule(_ rule: RoundingRule?, for lineID: String) {
        rules[lineID] = rule
        recompute()
    }

    var isComplete: Bool {
        ReportingLineCalculator.isComplete(results)
    }

    var canSend: Bool {
        isSubmittable && isComplete
    }

    /// An existing report for this exact month (re-submission replaces it).
    var existingSubmission: SubmittedReport? {
        submissionsByMonth[month]
    }

    /// A report can be submitted for every past or current month, including
    /// a zero-activity month. Persisting that zero-valued snapshot records an
    /// intentional report submission and prevents the reminder from recurring.
    var isSubmittable: Bool {
        month <= now.yearMonth(using: calendar)
    }

    var overseerFullName: String {
        userDefaults.string(forKey: UserDefaultsKeys.overseerFullName) ?? ""
    }

    var overseerPhoneNumber: String {
        userDefaults.string(forKey: UserDefaultsKeys.overseerPhoneNumber) ?? ""
    }

    var hasOverseer: Bool {
        !overseerPhoneNumber.isEmpty
    }

    // MARK: - Workflow

    /// Builds the message for the current line rules. The view presents Messages
    /// (or copies to the pasteboard) from the returned content, then calls
    /// `persistSubmission(in:)` once the user confirms.
    @discardableResult
    func prepareSubmission() -> ReportMessageContent? {
        guard canSend else { return nil }

        let content = ReportComposer.message(
            month: month,
            results: results,
            bibleStudies: summary?.totalBibleStudies ?? 0,
            template: greetingTemplate,
            firstName: overseerFirstName,
            lastName: overseerLastName,
            locale: locale,
            calendar: calendar
        )
        preparedContent = content
        return content
    }

    /// Persists the submission snapshot. An existing row for the same month
    /// (a real submission or a V8→V9 backfill sentinel) is updated in place,
    /// preserving `firstSubmittedAt` and the CloudKit record identity; the
    /// theocratic-year rollup keys submissions by month and would double-count
    /// a delete-and-insert duplicate.
    /// Returns the stored report (nil when not submittable or rounding is undecided).
    @discardableResult
    func persistSubmission(in context: ModelContext) throws -> SubmittedReport? {
        guard canSend else { return nil }

        let mainResult = results.first { $0.line.type == .main }
        let categoryHours = ReportingLineCalculator.categoryHours(
            results: results,
            categories: summary?.categories ?? []
        )
        let snapshots = (summary?.categories ?? []).map { category in
            SubmittedReport.SubmittedCategory(
                name: category.name,
                iconName: category.iconName,
                typeRaw: category.type?.rawValue,
                actualSeconds: category.duration,
                submittedHours: categoryHours[category.id] ?? 0
            )
        }
        let carriedInSeconds = results.reduce(0) { $0 + $1.line.carriedInSeconds }
        let carriedOutSeconds = results.reduce(0) { total, result in
            guard case .transferred(let seconds) = result.disposition else { return total }
            return total + seconds
        }
        let roundedUpSeconds = results.reduce(0) { total, result in
            guard case .roundedUp(let seconds) = result.disposition else { return total }
            return total + seconds
        }
        let roundedDownSeconds = results.reduce(0) { total, result in
            guard case .roundedDown(let seconds) = result.disposition else { return total }
            return total + seconds
        }
        let submittedHours = results.reduce(0) { $0 + $1.submittedHours }
        let closedAt = monthEntries.map(\.createdAt).max() ?? now

        let report: SubmittedReport
        if let existing = existingSubmission {
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

        report.roundingRuleRaw = mainResult?.rule?.rawValue ?? ""
        report.fieldServiceSeconds = mainResult?.line.actualSeconds ?? 0
        report.actualTotalSeconds = summary?.totalSeconds ?? 0
        report.submittedHours = submittedHours
        report.carriedInSeconds = carriedInSeconds
        report.carriedOutSeconds = carriedOutSeconds
        report.roundedUpSeconds = roundedUpSeconds
        report.roundedDownSeconds = roundedDownSeconds
        report.totalBibleStudies = summary?.totalBibleStudies ?? 0
        report.categories = snapshots
        report.reportingLines = results.map(\.persisted)

        reconcileGeneratedEntries(for: report, in: context)
        try context.save()
        return report
    }

    // MARK: - Private

    private var greetingTemplate: String {
        let stored = userDefaults.string(forKey: UserDefaultsKeys.overseerGreetingTemplate)

        return stored?.isEmpty == false
            ? stored!
            : String(localized: "report.greeting.default", locale: locale)
    }

    private var overseerFirstName: String {
        userDefaults.string(forKey: UserDefaultsKeys.overseerFirstName) ?? overseerFullName
    }

    private var overseerLastName: String {
        userDefaults.string(forKey: UserDefaultsKeys.overseerLastName) ?? ""
    }

    private func recompute() {
        preparedContent = nil
        results = ReportingLineCalculator.compute(lines, rules: rules)
    }

    private func reconcileGeneratedEntries(for report: SubmittedReport, in context: ModelContext) {
        let nextMonthStart = month.nextMonth(calendar: calendar).date(calendar: calendar)
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
                    date: nextMonthStart,
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
