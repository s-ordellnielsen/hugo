import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct SubmitReportFormModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let month = YearMonth(year: 2026, month: 6)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)  // fixed "now"

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func entry(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        seconds: TimeInterval = 3_600,
        createdAt: Date? = nil,
        tracker: Tracker? = nil
    ) -> Entry {
        let e = Entry(date: date(year, month, day), duration: seconds, tracker: tracker, bibleStudies: 0)
        e.createdAt = createdAt ?? date(year, month, day, hour: 9)
        return e
    }

    private func makeModel(
        userDefaults: UserDefaults? = nil,
        defaultRule: String? = nil
    ) -> SubmitReportFormModel {
        let defaults = userDefaults ?? UserDefaults(suiteName: "SubmitReportFormModelTests-\(UUID().uuidString)")!
        if let defaultRule {
            defaults.set(defaultRule, forKey: UserDefaultsKeys.defaultRoundingRule)
        }
        return SubmitReportFormModel(month: month, calendar: calendar, now: now, userDefaults: defaults)
    }

    // MARK: - Defaults & rule selection

    @Test
    func seedsTheRuleFromTheUserDefault() {
        #expect(makeModel(defaultRule: "transfer").selectedRule == .transfer)
        #expect(makeModel(defaultRule: "down").selectedRule == .down)
        #expect(makeModel(defaultRule: nil).selectedRule == .up)
        #expect(makeModel(defaultRule: "bogus").selectedRule == .up)
    }

    @Test
    func computationRefreshesWhenTheRuleChanges() {
        let model = makeModel()
        model.load(entries: [entry(2026, 6, 5, seconds: 5_400)], submissions: [])

        model.selectedRule = .down
        #expect(model.computation.submittedHours == 1)
        #expect(model.computation.roundedDownSeconds == 1_800)

        model.selectedRule = .up
        #expect(model.computation.submittedHours == 2)
        #expect(model.computation.roundedUpSeconds == 1_800)

        model.selectedRule = .transfer
        #expect(model.computation.submittedHours == 1)
        #expect(model.computation.carriedOutSeconds == 1_800)
    }

    // MARK: - Carry chain

    @Test
    func carriedInDerivesFromThePreviousMonthsSubmission() {
        let previous = SubmittedReport(
            year: 2026, month: 5,
            firstSubmittedAt: date(2026, 6, 1), submittedAt: date(2026, 6, 1),
            carriedOutSeconds: 2_400
        )
        let model = makeModel()
        model.load(entries: [entry(2026, 6, 5)], submissions: [previous])

        #expect(model.carriedIn == 2_400)
        // 1h actual + 40m carried in = 1h40m → transfer floors to 1h, carries 40m.
        model.selectedRule = .transfer
        #expect(model.computation.submittedHours == 1)
        #expect(model.computation.carriedOutSeconds == 2_400)
    }

    @Test
    func carriedInIsZeroWithoutAPreviousSubmissionOrWithUpDownRules() {
        let model = makeModel()
        model.load(entries: [entry(2026, 6, 5)], submissions: [])
        #expect(model.carriedIn == 0)

        let roundDownPrevious = SubmittedReport(
            year: 2026, month: 5,
            firstSubmittedAt: date(2026, 6, 1), submittedAt: date(2026, 6, 1),
            roundingRuleRaw: "down",
            carriedOutSeconds: 0,
            roundedDownSeconds: 1_200
        )
        model.load(entries: [entry(2026, 6, 5)], submissions: [roundDownPrevious])
        #expect(model.carriedIn == 0)

        // A sentinel backfill row must never contribute carry-in.
        let sentinel = SubmittedReport(year: 2026, month: 5, carriedOutSeconds: 9_999)
        model.load(entries: [entry(2026, 6, 5)], submissions: [sentinel])
        #expect(model.carriedIn == 0)
    }

    // MARK: - isSubmittable

    @Test
    func submittabilityMatrix() {
        // Entries in the month → submittable.
        let model = makeModel()
        model.load(entries: [entry(2026, 6, 5)], submissions: [])
        #expect(model.isSubmittable)

        // An empty month without carry-in is still submittable: a zero-value
        // submission records that the user intentionally reported no activity.
        model.load(entries: [], submissions: [])
        #expect(model.isSubmittable)

        // Empty month WITH carry-in is likewise submittable.
        let previous = SubmittedReport(
            year: 2026, month: 5,
            firstSubmittedAt: date(2026, 6, 1), submittedAt: date(2026, 6, 1),
            carriedOutSeconds: 1_200
        )
        model.load(entries: [], submissions: [previous])
        #expect(model.isSubmittable)

        // Entries in a different month still leave this month as a valid
        // zero-activity report.
        model.load(entries: [entry(2026, 7, 1)], submissions: [])
        #expect(model.isSubmittable)
    }

    @Test
    func futureMonthsAreNeverSubmittable() {
        let future = YearMonth(year: now.yearMonth(using: calendar).year + 1, month: 1)
        let model = SubmitReportFormModel(month: future, calendar: calendar, now: now)
        model.load(entries: [entry(future.year, 1, 5)], submissions: [])
        #expect(!model.isSubmittable)
    }

    // MARK: - Persistence

    // The throwing signature is intentional: persistence failures must reach the UI.
    @Test
    func persistSubmissionHappyPathUsesThrowingSignature() throws {
        let container = try InMemoryModelContainer.make()
        let model = makeModel()
        model.load(entries: [], submissions: [])
        let report = try model.persistSubmission(in: container.mainContext)
        #expect(report != nil)
    }

    @Test
    func persistInsertsOneSnapshotWithCorrectTotals() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext

        let model = makeModel()
        let june5 = entry(2026, 6, 5, seconds: 7_200, createdAt: date(2026, 6, 5, hour: 9))
        let june20 = entry(2026, 6, 20, seconds: 5_400, createdAt: date(2026, 6, 20, hour: 9))
        model.load(entries: [june5, june20], submissions: [])
        model.selectedRule = .down

        // 3h30m → floor 3h, 30m dropped.
        let report = try #require(try model.persistSubmission(in: context))

        #expect(report.year == 2026)
        #expect(report.month == 6)
        #expect(report.submittedAt == now)
        #expect(report.firstSubmittedAt == now)
        #expect(report.entriesClosedAt == date(2026, 6, 20, hour: 9))
        #expect(report.roundingRuleRaw == "down")
        #expect(report.actualTotalSeconds == 12_600)
        #expect(report.submittedHours == 3)
        #expect(report.roundedDownSeconds == 1_800)
        #expect(report.carriedOutSeconds == 0)
        #expect(try context.fetchCount(FetchDescriptor<SubmittedReport>()) == 1)
    }

    @Test
    func resubmissionReplacesAndPreservesFirstSubmittedAt() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext

        let model = makeModel()
        let first = entry(2026, 6, 5, seconds: 3_600, createdAt: date(2026, 6, 5, hour: 9))
        model.load(entries: [first], submissions: [])

        let original = try #require(try model.persistSubmission(in: context))
        let firstSubmittedAt = original.firstSubmittedAt

        // A new entry arrives after the first submission; the user re-submits.
        let later = entry(2026, 6, 25, seconds: 3_600, createdAt: date(2026, 6, 25, hour: 9))
        let laterNow = now.addingTimeInterval(86_400)
        let remodel = SubmitReportFormModel(month: month, calendar: calendar, now: laterNow)
        remodel.load(entries: [first, later], submissions: [original])

        let replacement = try #require(try remodel.persistSubmission(in: context))

        #expect(try context.fetchCount(FetchDescriptor<SubmittedReport>()) == 1)
        #expect(replacement.firstSubmittedAt == firstSubmittedAt)
        #expect(replacement.submittedAt == laterNow)
        #expect(replacement.entriesClosedAt == date(2026, 6, 25, hour: 9))
        #expect(replacement.actualTotalSeconds == 7_200)
    }

    @Test
    func persistingIntoSentinelUpdatesInPlace() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext

        // A V8→V9 backfill sentinel: `submittedAt`/`firstSubmittedAt` stay at
        // the `.distantPast` default, marking the month as never submitted.
        let sentinel = SubmittedReport(year: 2026, month: 6)
        context.insert(sentinel)
        try context.save()

        let model = makeModel()
        model.load(entries: [entry(2026, 6, 5, createdAt: date(2026, 6, 5, hour: 9))], submissions: [sentinel])

        let report = try #require(try model.persistSubmission(in: context))

        // Still exactly one row: the sentinel became the real submission.
        #expect(try context.fetchCount(FetchDescriptor<SubmittedReport>()) == 1)
        #expect(report === sentinel)
        let stored = try #require(context.fetch(FetchDescriptor<SubmittedReport>()).first)
        #expect(stored.submittedAt == now)
        #expect(stored.firstSubmittedAt == now)
        #expect(stored.submittedHours == 1)
    }

    @Test
    func persistSnapshotsCategoriesFromTheComputation() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext

        let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
        let separate = Tracker(name: "LDC", type: .separate, iconName: "building")
        let model = makeModel()
        model.load(
            entries: [
                entry(2026, 6, 5, seconds: 8_400, tracker: main),
                entry(2026, 6, 10, seconds: 6_000, tracker: separate),
            ], submissions: [])
        model.selectedRule = .down

        let report = try #require(try model.persistSubmission(in: context))

        // 2h20m main + 1h40m separate = 4h → floors 2+1, extra hour to the
        // larger remainder (separate, 40m).
        #expect(report.submittedHours == 4)
        #expect(report.fieldServiceSeconds == 8_400)
        #expect(report.categories?.count == 2)
        #expect(report.categories?.first { $0.name == "Field Service" }?.submittedHours == 2)
        #expect(report.categories?.first { $0.name == "LDC" }?.submittedHours == 2)
        #expect(report.categories?.first { $0.name == "LDC" }?.type == .separate)
        #expect(report.categories?.first { $0.name == "Field Service" }?.iconName == "figure.walk")
    }

    @Test
    func persistStoresAZeroValuedSubmissionForAnEmptyMonth() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext

        let model = makeModel()
        model.load(entries: [], submissions: [])

        let report = try #require(try model.persistSubmission(in: context))
        #expect(try context.fetchCount(FetchDescriptor<SubmittedReport>()) == 1)
        #expect(report.fieldServiceSeconds == 0)
        #expect(report.actualTotalSeconds == 0)
        #expect(report.submittedHours == 0)
        #expect(report.totalBibleStudies == 0)
        #expect(report.categories?.isEmpty == true)
        #expect(report.entriesClosedAt == now)
    }

    // MARK: - Composer handoff

    @Test
    func prepareSubmissionHandsTheRightInputsToTheComposer() {
        let defaults = UserDefaults(
            suiteName: "SubmitReportFormModelTests-\(UUID().uuidString)"
        )!

        defaults.set("TEST {first} {month}", forKey: UserDefaultsKeys.overseerGreetingTemplate)
        defaults.set("Jens", forKey: UserDefaultsKeys.overseerFirstName)

        let main = Tracker(
            name: "Field Service",
            type: .main,
            iconName: "figure.walk"
        )

        let model = makeModel(userDefaults: defaults)
        model.load(
            entries: [
                entry(2026, 6, 5, seconds: 19_200, tracker: main)
            ],
            submissions: []
        )

        let content = model.prepareSubmission()

        #expect(content != nil)
        #expect(model.preparedContent != nil)

        // Verifies that the first-name template input was substituted.
        #expect(content?.body.contains("TEST Jens") == true)

        // Verifies that template tags were processed without asserting the
        // localized month value.
        #expect(content?.body.contains("{first}") == false)
        #expect(content?.body.contains("{month}") == false)

        // Verifies the actual business logic independently of localized labels.
        #expect(model.computation.submittedHours == 6)

        // Changing the rule invalidates the prepared message.
        model.selectedRule = .transfer

        #expect(model.preparedContent == nil)
        #expect(model.computation.submittedHours == 5)

        let recomposed = model.prepareSubmission()

        #expect(recomposed != nil)
        #expect(recomposed?.body.contains("TEST Jens") == true)
        #expect(model.computation.submittedHours == 5)
    }

    @Test
    func prepareSubmissionComposesAZeroValuedReportForAnEmptyMonth() {
        let model = makeModel()
        model.load(entries: [], submissions: [])

        let content = model.prepareSubmission()

        #expect(content != nil)

        let reportLines =
            content?.body
            .components(separatedBy: "\n\n")
            .last?
            .split(separator: "\n")
            .map(String.init) ?? []

        #expect(reportLines.count == 2)

        let reportValues = reportLines.compactMap { line -> Int? in
            guard let valuePart = line.split(separator: ":", maxSplits: 1).last else {
                return nil
            }

            let numericValue =
                valuePart
                .split(whereSeparator: \.isWhitespace)
                .first

            return numericValue.flatMap { Int($0) }
        }

        #expect(reportValues == [0, 0])
    }
}
