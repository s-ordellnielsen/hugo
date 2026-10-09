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
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func entry(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        seconds: TimeInterval = 3_600,
        createdAt: Date? = nil,
        tracker: Tracker? = nil,
        source: (submission: SubmittedReport, lineID: String)? = nil
    ) -> Entry {
        let value = Entry(date: date(year, month, day), duration: seconds, tracker: tracker, source: source)
        value.createdAt = createdAt ?? date(year, month, day, hour: 9)
        return value
    }

    private func makeModel(
        now: Date? = nil,
        userDefaults: UserDefaults? = nil
    ) -> SubmitReportFormModel {
        let defaults = userDefaults ?? UserDefaults(suiteName: "SubmitReportFormModelTests-\(UUID().uuidString)")!
        return SubmitReportFormModel(month: month, calendar: calendar, now: now ?? self.now, userDefaults: defaults)
    }

    private func mainLineID(in model: SubmitReportFormModel) -> String {
        #expect(model.lines.contains { $0.type == .main })
        return model.lines.first { $0.type == .main }?.id ?? ""
    }

    @Test
    func summaryIsNilBeforeLoadAndPopulatedAfterLoad() {
        let model = makeModel()
        #expect(model.summary == nil)

        model.load(entries: [entry(2026, 6, 5, seconds: 3_600)], submissions: [])

        #expect(model.summary?.totalSeconds == 3_600)
        #expect(model.lines.first?.type == .main)
    }

    @Test
    func remainderWithoutRuleBlocksSubmissionUntilRuleIsSelected() throws {
        let model = makeModel()
        model.load(entries: [entry(2026, 6, 5, seconds: 5_400)], submissions: [])

        #expect(!model.canSend)
        #expect(model.prepareSubmission() == nil)
        #expect(try model.persistSubmission(in: InMemoryModelContainer.make().mainContext) == nil)

        model.setRule(.down, for: mainLineID(in: model))

        #expect(model.canSend)
        #expect(model.results.first?.submittedHours == 1)
    }

    @Test
    func generatedCarryEntryIsCountedOnceInsteadOfAddingPriorLegacyCarry() {
        let previous = SubmittedReport(year: 2026, month: 5, carriedOutSeconds: 1_800)
        let ordinaryEntry = entry(2026, 6, 5, seconds: 3_600)
        let generatedEntry = entry(
            2026,
            6,
            6,
            seconds: 1_800,
            source: (submission: previous, lineID: "")
        )
        generatedEntry.storedTracker = .init(name: "Field Service", icon: "figure.walk", type: .main)

        let model = makeModel()
        model.load(entries: [ordinaryEntry, generatedEntry], submissions: [previous])

        #expect(model.lines.first?.actualSeconds == 5_400)
        #expect(model.lines.first?.carriedInSeconds == 1_800)
        #expect(model.summary?.totalSeconds == 5_400)
        #expect(!model.canSend)
    }

    @Test
    func settingRuleRecomputesTheLineResultAndInvalidatesPreparedMessage() {
        let model = makeModel()
        model.load(entries: [entry(2026, 6, 5, seconds: 5_400)], submissions: [])
        model.setRule(.down, for: mainLineID(in: model))
        #expect(model.prepareSubmission() != nil)
        #expect(model.results.first?.submittedHours == 1)

        model.setRule(.up, for: mainLineID(in: model))

        #expect(model.preparedContent == nil)
        #expect(model.results.first?.submittedHours == 2)
        #expect(model.results.first?.disposition == .roundedUp(seconds: 1_800))
    }

    @Test
    func futureMonthsAreNotSubmittable() {
        let future = YearMonth(year: now.yearMonth(using: calendar).year + 1, month: 1)
        let model = SubmitReportFormModel(month: future, calendar: calendar, now: now)
        model.load(entries: [entry(future.year, future.month, 5)], submissions: [])

        #expect(!model.isSubmittable)
        #expect(!model.canSend)
    }

    @Test
    func transferPersistsReportingLineAndLinkedNextMonthEntry() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let model = makeModel()
        model.load(entries: [entry(2026, 6, 5, seconds: 5_400)], submissions: [])
        model.setRule(.transfer, for: mainLineID(in: model))

        let report = try #require(try model.persistSubmission(in: context))

        #expect(report.reportingLines.count == 1)
        #expect(report.reportingLines[0].roundingRaw == "transfer")
        #expect(report.reportingLines[0].submittedHours == 1)
        #expect(report.carriedOutSeconds == 1_800)
        #expect(try context.fetchCount(FetchDescriptor<SubmittedReport>()) == 1)

        let generated = try #require(context.fetch(FetchDescriptor<Entry>()).first)
        #expect(generated.date == date(2026, 7, 1, hour: 0))
        #expect(generated.duration == 1_800)
        #expect(generated.sourceSubmission === report)
        #expect(generated.sourceReportingLineID == "")
        #expect(generated.sourceReportYear == 2026)
        #expect(generated.sourceReportMonth == 6)

        // This also verifies SwiftData maintains the V11 inverse relationship
        // after save. Plan 033 requires stopping if it does not.
        #expect(report.generatedEntries?.count == 1)
        #expect(report.generatedEntries?.first === generated)
    }

    @Test
    func resubmittingWithDownRemovesCarryAndUpdatesReportInPlace() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let firstModel = makeModel()
        firstModel.load(entries: [entry(2026, 6, 5, seconds: 5_400)], submissions: [])
        firstModel.setRule(.transfer, for: mainLineID(in: firstModel))
        let original = try #require(try firstModel.persistSubmission(in: context))
        let firstSubmittedAt = original.firstSubmittedAt

        let secondModel = makeModel(now: now.addingTimeInterval(86_400))
        secondModel.load(entries: [entry(2026, 6, 5, seconds: 5_400)], submissions: [original])
        secondModel.setRule(.down, for: mainLineID(in: secondModel))
        let replacement = try #require(try secondModel.persistSubmission(in: context))

        #expect(replacement === original)
        #expect(replacement.firstSubmittedAt == firstSubmittedAt)
        #expect(replacement.submittedAt == now.addingTimeInterval(86_400))
        #expect(replacement.reportingLines[0].roundingRaw == "down")
        #expect(replacement.generatedEntries?.isEmpty == true)
        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SubmittedReport>()) == 1)
    }

    @Test
    func unchangedTransferKeepsExistingGeneratedEntryAndCreationDate() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let entries = [entry(2026, 6, 5, seconds: 5_400)]
        let firstModel = makeModel()
        firstModel.load(entries: entries, submissions: [])
        firstModel.setRule(.transfer, for: mainLineID(in: firstModel))
        let report = try #require(try firstModel.persistSubmission(in: context))
        let generated = try #require(report.generatedEntries?.first)
        let originalCreatedAt = date(2026, 7, 2, hour: 9)
        generated.createdAt = originalCreatedAt
        try context.save()

        let laterModel = makeModel(now: now.addingTimeInterval(86_400))
        laterModel.load(entries: entries, submissions: [report])
        let replacement = try #require(try laterModel.persistSubmission(in: context))

        #expect(replacement.generatedEntries?.count == 1)
        #expect(replacement.generatedEntries?.first === generated)
        #expect(generated.createdAt == originalCreatedAt)
        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 1)
    }

    @Test
    func separateLineTransferStoresSeparateCategorySnapshot() throws {
        let container = try InMemoryModelContainer.make()
        let tracker = Tracker(name: "LDC", type: .separate, iconName: "building")
        let model = makeModel()
        model.load(entries: [entry(2026, 6, 5, seconds: 5_400, tracker: tracker)], submissions: [])
        let line = try #require(model.lines.first { $0.type == .separate })
        model.setRule(.transfer, for: line.id)

        let report = try #require(try model.persistSubmission(in: container.mainContext))
        let generated = try #require(report.generatedEntries?.first)

        #expect(generated.sourceReportingLineID == "LDC")
        #expect(generated.storedTracker?.type == .separate)
        #expect(generated.storedTracker?.name == "LDC")
        #expect(generated.duration == 1_800)
    }

    @Test
    func reopeningSeedsStoredRulesOnlyOnFirstLoad() {
        let stored = SubmittedReport(
            year: 2026,
            month: 6,
            reportingLines: [
                .init(
                    typeRaw: TrackerType.main.rawValue,
                    typeName: "",
                    durationInSeconds: 5_400,
                    submittedHours: 1,
                    roundingRaw: "transfer"
                )
            ]
        )
        let model = makeModel()
        let entries = [entry(2026, 6, 5, seconds: 5_400)]
        model.load(entries: entries, submissions: [stored])

        #expect(model.rule(for: "") == .transfer)
        #expect(model.canSend)

        model.setRule(.up, for: "")
        model.load(entries: entries, submissions: [stored])

        #expect(model.rule(for: "") == .up)
        #expect(model.results.first?.submittedHours == 2)
    }

    @Test
    func zeroActivityMonthSubmitsWithoutARoundingRule() throws {
        let container = try InMemoryModelContainer.make()
        let model = makeModel()
        model.load(entries: [], submissions: [])

        #expect(model.isSubmittable)
        #expect(model.canSend)
        #expect(model.results.count == 1)
        #expect(model.results[0].submittedHours == 0)
        #expect(model.prepareSubmission() != nil)

        let report = try #require(try model.persistSubmission(in: container.mainContext))

        #expect(report.reportingLines.count == 1)
        #expect(report.reportingLines[0].submittedHours == 0)
        #expect(report.reportingLines[0].roundingRaw.isEmpty)
        #expect(report.actualTotalSeconds == 0)
        #expect(report.entriesClosedAt == now)
    }

    @Test
    func submittingSentinelUpdatesInPlaceAndSetsFirstSubmittedAt() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let sentinel = SubmittedReport(year: 2026, month: 6)
        context.insert(sentinel)
        try context.save()

        let model = makeModel()
        model.load(entries: [entry(2026, 6, 5)], submissions: [sentinel])
        let report = try #require(try model.persistSubmission(in: context))

        #expect(report === sentinel)
        #expect(report.firstSubmittedAt == now)
        #expect(report.submittedAt == now)
        #expect(try context.fetchCount(FetchDescriptor<SubmittedReport>()) == 1)
    }

    @Test
    func composerUsesPreparedTemplateAndCurrentPerLineHours() {
        let defaults = UserDefaults(suiteName: "SubmitReportFormModelTests-\(UUID().uuidString)")!
        defaults.set("TEST {first} {month}", forKey: UserDefaultsKeys.overseerGreetingTemplate)
        defaults.set("Jens", forKey: UserDefaultsKeys.overseerFirstName)

        let model = makeModel(userDefaults: defaults)
        model.load(entries: [entry(2026, 6, 5, seconds: 19_200)], submissions: [])
        model.setRule(.down, for: mainLineID(in: model))

        let content = model.prepareSubmission()

        #expect(content?.body.contains("TEST Jens") == true)
        #expect(content?.body.contains("{first}") == false)
        #expect(content?.body.contains("{month}") == false)
        #expect(model.results.first?.submittedHours == 5)
    }
}
