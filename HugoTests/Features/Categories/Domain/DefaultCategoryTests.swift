import Foundation
import Testing

@testable import Hugo

@MainActor
struct DefaultCategoryTests {
    private let early = Date(timeIntervalSince1970: 1_000)
    private let late = Date(timeIntervalSince1970: 2_000)

    private func makeTracker(name: String, type: TrackerType = .main, createdAt: Date) -> Tracker {
        let tracker = Tracker(name: name, type: type)
        tracker.createdAt = createdAt
        return tracker
    }

    @Test
    func storedIdReturnsThatCategory() {
        let older = makeTracker(name: "Older", createdAt: early)
        let stored = makeTracker(name: "Stored", type: .separate, createdAt: late)

        let resolved = DefaultCategory.resolve(storedID: stored.id.uuidString, in: [older, stored])

        #expect(resolved?.id == stored.id)
    }

    @Test
    func unsetReturnsTheOldestMainCategory() {
        let separate = makeTracker(name: "Bethel", type: .separate, createdAt: early)
        let newer = makeTracker(name: "Newer", createdAt: late)
        let older = makeTracker(name: "Older", createdAt: early.addingTimeInterval(10))

        let resolved = DefaultCategory.resolve(storedID: nil, in: [separate, newer, older])

        #expect(resolved?.id == older.id)
    }

    @Test
    func unsetBreaksCreatedAtTiesByIdString() {
        let first = makeTracker(name: "A", createdAt: early)
        let second = makeTracker(name: "B", createdAt: early)
        let expected = [first, second].min { $0.id.uuidString < $1.id.uuidString }

        let resolved = DefaultCategory.resolve(storedID: nil, in: [second, first])

        #expect(resolved?.id == expected?.id)
    }

    @Test
    func staleIdFallsBackToTheOldestMainCategory() {
        let older = makeTracker(name: "Older", createdAt: early)
        let newer = makeTracker(name: "Newer", createdAt: late)

        let resolved = DefaultCategory.resolve(storedID: UUID().uuidString, in: [newer, older])

        #expect(resolved?.id == older.id)
    }

    @Test
    func malformedIdFallsBackToTheOldestMainCategory() {
        let older = makeTracker(name: "Older", createdAt: early)

        let resolved = DefaultCategory.resolve(storedID: "not-a-uuid", in: [older])

        #expect(resolved?.id == older.id)
    }

    @Test
    func emptyStringMeansNoDefault() {
        let main = makeTracker(name: "Main", createdAt: early)

        #expect(DefaultCategory.resolve(storedID: "", in: [main]) == nil)
    }

    @Test
    func unsetWithOnlySeparateCategoriesReturnsNil() {
        let separate = makeTracker(name: "Bethel", type: .separate, createdAt: early)

        #expect(DefaultCategory.resolve(storedID: nil, in: [separate]) == nil)
    }
}
