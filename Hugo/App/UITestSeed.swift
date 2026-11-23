import Foundation
import SwiftData

/// Data for the UI tests. It is inserted only when the app is running in test
/// mode (`HUGO_TEST_MODE=1`, which also selects the in-memory store) and was
/// launched with `-HugoUITestSeed`. A normal launch never sees it.
///
/// Entries are placed on today, a few hours after midnight, so they fall in the
/// current month and the current theocratic year whatever day the tests run.
@MainActor
enum UITestSeed {
    static let launchArgument = "-HugoUITestSeed"

    /// The name of the Field Service category in the seed. The tests look for it.
    static let fieldServiceName = "Field Service"
    /// The name of the Credit category in the seed.
    static let creditName = "Bethel"
    /// Total Bible studies across the seeded entries.
    static let totalBibleStudies = 2

    static func isRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["HUGO_TEST_MODE"] == "1" && arguments.contains(launchArgument)
    }

    static func insert(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws {
        let field = Tracker(name: fieldServiceName, type: .main, isDefault: true, iconName: "figure.walk")
        let credit = Tracker(name: creditName, type: .separate, iconName: "building.2")
        context.insert(field)
        context.insert(credit)

        let midnight = calendar.startOfDay(for: now)
        let hour: TimeInterval = 3_600
        context.insert(
            Entry(date: midnight.addingTimeInterval(1 * hour), duration: 5_400, tracker: field, bibleStudies: 2))
        context.insert(Entry(date: midnight.addingTimeInterval(2 * hour), duration: 3_600, tracker: field))
        context.insert(Entry(date: midnight.addingTimeInterval(3 * hour), duration: 1_800, tracker: credit))
        try context.save()
    }
}
