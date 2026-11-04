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
    private var pendingLoad: (entries: [Entry], submissions: [SubmittedReport])?

    /// The composed message ready to hand to Messages (or the pasteboard).
    /// Set by `prepareSubmission()`; cleared when the rule changes.
    private(set) var preparedContent: ReportMessageContent?

    private let calendar: Calendar
    private let now: Date
    private let locale: Locale
    private let userDefaults: UserDefaults

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
        // A prepared message is what the user is about to send. Keep the numbers
        // it was built from until the user sends or cancels it.
        guard preparedContent == nil else {
            pendingLoad = (entries, submissions)
            return
        }
        self.submissionsByMonth = SubmittedReportSelection.canonicalByMonth(submissions)
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

    /// Discards the prepared message and applies data that arrived meanwhile.
    func cancelPreparedSubmission() {
        preparedContent = nil
        if let pending = pendingLoad {
            pendingLoad = nil
            load(entries: pending.entries, submissions: pending.submissions)
        }
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

    /// True when submitting now would change, add or remove minutes carried
    /// into the next month, and the next month already has a real submission.
    var changesSubmittedNextMonth: Bool {
        let next = month.nextMonth(calendar: calendar)
        guard let nextReport = submissionsByMonth[next], SubmittedReportSelection.isReal(nextReport)
        else { return false }

        var existing: [String: TimeInterval] = [:]
        for entry in existingSubmission?.generatedEntries ?? [] {
            existing[entry.sourceReportingLineID ?? "", default: 0] += entry.duration
        }
        var planned: [String: TimeInterval] = [:]
        for result in results {
            if case .transferred(let seconds) = result.disposition { planned[result.id] = seconds }
        }
        return existing != planned
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
    /// `persistSubmission(using:)` once the user confirms.
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

    /// Saves the submission through `service` once the user has confirmed.
    /// An existing row for the same month is updated in place by the service.
    /// Returns the stored report (nil when not submittable or rounding is undecided).
    @discardableResult
    func persistSubmission(using service: ReportSubmissionService) throws -> SubmittedReport? {
        guard canSend else { return nil }

        let report = try service.submit(
            results,
            summary: summary,
            for: month,
            replacing: existingSubmission,
            at: now
        )
        preparedContent = nil
        pendingLoad = nil
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

}
