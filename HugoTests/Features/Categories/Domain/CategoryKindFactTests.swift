import Foundation
import Testing

@testable import Hugo

struct CategoryKindFactTests {
    private let regularPioneer = PublisherStatus.status(for: "regular-pioneer")!
    private let publisher = PublisherStatus.status(for: "publisher")!
    private let english = Locale(identifier: "en_US")
    private let danish = Locale(identifier: "da_DK")

    @Test(arguments: [TrackerType.main, .separate])
    func aStatusWithAYearlyGoalGetsThreeFactsInOrder(kind: TrackerType) {
        let facts = CategoryKindFact.facts(for: kind, status: regularPioneer, locale: english)
        #expect(facts.map(\.topic) == [.report, .goal, .bibleStudies])
    }

    @Test(arguments: [TrackerType.main, .separate])
    func noYearlyGoalLeavesOutTheGoalFact(kind: TrackerType) {
        #expect(
            CategoryKindFact.facts(for: kind, status: publisher, locale: english).map(\.topic)
                == [.report, .bibleStudies])
        #expect(
            CategoryKindFact.facts(for: kind, status: nil, locale: english).map(\.topic)
                == [.report, .bibleStudies])
    }

    @Test
    func creditGoalFactNamesTheMonthlyGoalPlusTheAllowance() throws {
        let goal = try #require(
            CategoryKindFact.facts(for: .separate, status: regularPioneer, locale: english)
                .first { $0.topic == .goal })
        #expect(goal.text.contains("55 hours"))
        #expect(goal.text.contains("5 hours"))
    }

    @Test
    func kindsDifferOnEveryFact() {
        let main = CategoryKindFact.facts(for: .main, status: regularPioneer, locale: english).map(\.text)
        let credit = CategoryKindFact.facts(for: .separate, status: regularPioneer, locale: english).map(\.text)
        #expect(zip(main, credit).allSatisfy { $0 != $1 })
    }

    @Test
    func factsUseTheGivenLanguage() throws {
        let report = try #require(
            CategoryKindFact.facts(for: .separate, status: regularPioneer, locale: danish).first)
        #expect(report.text == "Sendes på sin egen linje i rapporten med kategoriens navn.")
        #expect(CategoryKindFact.example(for: .separate, locale: danish) == "Fx LDC eller betel.")
    }

    @Test
    func eachKindHasItsOwnSymbol() {
        #expect(CategoryKindFact.systemImage(for: .main) != CategoryKindFact.systemImage(for: .separate))
    }
}
