import Foundation
import Testing

@testable import Hugo

@MainActor
struct ReportingLineCalculatorTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func entry(
        seconds: TimeInterval,
        tracker: Tracker? = nil,
        day: Int = 1
    ) -> Entry {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: day))!
        return Entry(date: date, duration: seconds, tracker: tracker)
    }

    private func line(seconds: TimeInterval) -> ReportingLine {
        ReportingLine(
            id: "",
            type: .main,
            name: "",
            iconName: "figure.walk",
            actualSeconds: seconds,
            carriedInSeconds: 0,
            carriedInFrom: []
        )
    }

    @Test
    func emptyEntriesProduceOneEmptyMainLine() {
        let result = ReportingLineCalculator.lines(from: [], calendar: calendar)

        #expect(result.count == 1)
        #expect(result[0].type == .main)
        #expect(result[0].id == "")
        #expect(result[0].actualSeconds == 0)
    }

    @Test
    func mainTrackersAndUntrackedEntriesShareTheMainLine() {
        let firstMain = Tracker(name: "Field Service", type: .main, iconName: "house.fill")
        let secondMain = Tracker(name: "Other Main", type: .main, iconName: "sun.max.fill")
        let entries = [
            entry(seconds: 600, tracker: firstMain), entry(seconds: 900, tracker: secondMain), entry(seconds: 300),
        ]

        let result = ReportingLineCalculator.lines(from: entries, calendar: calendar)

        #expect(result.count == 1)
        #expect(result[0].actualSeconds == 1_800)
        #expect(result[0].iconName == "figure.walk")
    }

    @Test
    func separateTrackersWithTheSameNameShareALineAndUseTheFirstDatedIcon() {
        let laterTracker = Tracker(name: "Study", type: .separate, iconName: "book.fill")
        let earlierTracker = Tracker(name: "Study", type: .separate, iconName: "book")
        let entries = [
            entry(seconds: 900, tracker: laterTracker, day: 2), entry(seconds: 600, tracker: earlierTracker, day: 1),
        ]

        let result = ReportingLineCalculator.lines(from: entries, calendar: calendar)

        #expect(result.count == 2)
        #expect(result[1].id == "Study")
        #expect(result[1].actualSeconds == 1_500)
        #expect(result[1].iconName == "book")
    }

    @Test
    func generatedEntryIsCountedAsActualAndCarriedIn() {
        let generatedEntry = entry(seconds: 900)
        generatedEntry.sourceReportYear = 2026
        generatedEntry.sourceReportMonth = 5

        let result = ReportingLineCalculator.lines(from: [generatedEntry], calendar: calendar)

        #expect(result[0].actualSeconds == 900)
        #expect(result[0].carriedInSeconds == 900)
        #expect(result[0].carriedInFrom == [YearMonth(year: 2026, month: 5)])
    }

    @Test
    func carriedInSourceMonthsAreDeduplicatedAndSorted() {
        let mayEntry = entry(seconds: 100)
        mayEntry.sourceReportYear = 2026
        mayEntry.sourceReportMonth = 5
        let aprilEntry = entry(seconds: 200)
        aprilEntry.sourceReportYear = 2026
        aprilEntry.sourceReportMonth = 4
        let duplicateMayEntry = entry(seconds: 300)
        duplicateMayEntry.sourceReportYear = 2026
        duplicateMayEntry.sourceReportMonth = 5

        let result = ReportingLineCalculator.lines(from: [mayEntry, aprilEntry, duplicateMayEntry], calendar: calendar)

        #expect(result[0].carriedInSeconds == 600)
        #expect(result[0].carriedInFrom == [YearMonth(year: 2026, month: 4), YearMonth(year: 2026, month: 5)])
    }

    @Test
    func linesPutMainFirstAndSortSeparateNamesNaturally() {
        let entries = [
            entry(seconds: 60, tracker: Tracker(name: "Zulu", type: .separate)),
            entry(seconds: 60, tracker: Tracker(name: "Field", type: .main)),
            entry(seconds: 60, tracker: Tracker(name: "Alpha", type: .separate)),
        ]

        let result = ReportingLineCalculator.lines(from: entries, calendar: calendar)

        #expect(result.map(\.id) == ["", "Alpha", "Zulu"])
    }

    @Test
    func computeAppliesEachRemainderDisposition() {
        let undecided = ReportingLineCalculator.compute(line(seconds: 5_400), rule: nil)
        #expect(undecided.submittedHours == 1)
        #expect(undecided.disposition == .undecided(seconds: 1_800))
        #expect(undecided.rule == nil)

        let roundedUp = ReportingLineCalculator.compute(line(seconds: 5_400), rule: .up)
        #expect(roundedUp.submittedHours == 2)
        #expect(roundedUp.disposition == .roundedUp(seconds: 1_800))
        #expect(roundedUp.rule == .up)

        let roundedDown = ReportingLineCalculator.compute(line(seconds: 5_400), rule: .down)
        #expect(roundedDown.submittedHours == 1)
        #expect(roundedDown.disposition == .roundedDown(seconds: 1_800))
        #expect(roundedDown.rule == .down)

        let transferred = ReportingLineCalculator.compute(line(seconds: 5_400), rule: .transfer)
        #expect(transferred.submittedHours == 1)
        #expect(transferred.disposition == .transferred(seconds: 1_800))
        #expect(transferred.rule == .transfer)
    }

    @Test
    func wholeHourLineNeedsNoRoundingAndIgnoresThePassedRule() {
        let result = ReportingLineCalculator.compute(line(seconds: 7_200), rule: .up)

        #expect(result.submittedHours == 2)
        #expect(result.disposition == .none)
        #expect(result.rule == nil)
        #expect(!result.line.needsRule)
    }

    @Test
    func isCompleteRejectsUndecidedLines() {
        let results = [
            ReportingLineCalculator.compute(line(seconds: 5_400), rule: nil),
            ReportingLineCalculator.compute(line(seconds: 7_200), rule: nil),
        ]

        #expect(!ReportingLineCalculator.isComplete(results))
        #expect(
            ReportingLineCalculator.isComplete([
                ReportingLineCalculator.compute(line(seconds: 5_400), rule: .down), results[1],
            ]))
    }

    @Test
    func computeLinesLooksUpRulesByLineIdentifier() {
        let fieldService = line(seconds: 5_400)
        let study = ReportingLine(
            id: "Study",
            type: .separate,
            name: "Study",
            iconName: "book",
            actualSeconds: 5_400,
            carriedInSeconds: 0,
            carriedInFrom: []
        )

        let results = ReportingLineCalculator.compute([fieldService, study], rules: ["": .up, "Study": .transfer])

        #expect(results.map(\.submittedHours) == [2, 1])
        #expect(results.map(\.rule) == [.up, .transfer])
    }

    @Test
    func persistedLineUsesSchemaShapeAndEmptyRoundingForWholeHours() {
        let mainResult = ReportingLineCalculator.compute(line(seconds: 7_200), rule: .up)
        let persistedMain = mainResult.persisted

        #expect(persistedMain.typeRaw == TrackerType.main.rawValue)
        #expect(persistedMain.typeName == "")
        #expect(persistedMain.id == "")
        #expect(persistedMain.roundingRaw == "")

        let separateResult = ReportingLineCalculator.compute(
            ReportingLine(
                id: "Study",
                type: .separate,
                name: "Study",
                iconName: "book",
                actualSeconds: 5_400,
                carriedInSeconds: 0,
                carriedInFrom: []
            ),
            rule: .transfer
        )
        let persistedSeparate = separateResult.persisted

        #expect(persistedSeparate.typeRaw == TrackerType.separate.rawValue)
        #expect(persistedSeparate.typeName == "Study")
        #expect(persistedSeparate.roundingRaw == RoundingRule.transfer.rawValue)
    }
}
