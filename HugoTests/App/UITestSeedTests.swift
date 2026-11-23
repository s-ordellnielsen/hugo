import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct UITestSeedTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test
    func insertsThreeEntriesOnTheGivenDayWithTwoBibleStudies() throws {
        let context = ModelContext(try InMemoryModelContainer.make())
        let now = Date(timeIntervalSince1970: 1_795_000_000)  // 2026-11-17, midday UTC

        try UITestSeed.insert(into: context, now: now, calendar: calendar)

        let entries = try context.fetch(FetchDescriptor<Entry>())
        #expect(entries.count == 3)
        #expect(entries.map(\.bibleStudies).reduce(0, +) == UITestSeed.totalBibleStudies)
        #expect(entries.allSatisfy { calendar.isDate($0.date, inSameDayAs: now) })
        let names = Set(try context.fetch(FetchDescriptor<Tracker>()).map(\.name))
        #expect(names == [UITestSeed.fieldServiceName, UITestSeed.creditName])
    }

    @Test
    func isRequestedOnlyInTestModeWithTheArgument() {
        let argument = [UITestSeed.launchArgument]
        #expect(UITestSeed.isRequested(arguments: argument, environment: ["HUGO_TEST_MODE": "1"]))
        #expect(!UITestSeed.isRequested(arguments: argument, environment: [:]))
        #expect(!UITestSeed.isRequested(arguments: [], environment: ["HUGO_TEST_MODE": "1"]))
    }
}
