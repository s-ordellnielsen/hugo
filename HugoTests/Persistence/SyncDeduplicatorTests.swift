import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct SyncDeduplicatorTests {
    private let early = Date(timeIntervalSince1970: 1_000)
    private let late = Date(timeIntervalSince1970: 2_000)

    private func makeContext() throws -> ModelContext {
        ModelContext(try InMemoryModelContainer.make())
    }

    private func makeTracker(
        id: UUID = UUID(), name: String = "Field Service", isDefault: Bool = false, createdAt: Date
    ) -> Tracker {
        let tracker = Tracker(id: id, name: name, isDefault: isDefault)
        tracker.createdAt = createdAt
        return tracker
    }

    private func makeEntry(for tracker: Tracker, in context: ModelContext) -> Entry {
        let entry = Entry(date: Date(timeIntervalSince1970: 5_000), duration: 3_600, tracker: tracker)
        context.insert(entry)
        return entry
    }

    /// Two same-id default trackers with one entry each.
    private func makeSharedIDSetup(
        in context: ModelContext, earlyName: String = "Field Service", lateName: String = "Field Service"
    ) throws -> (first: Tracker, second: Tracker, entries: [Entry]) {
        let sharedID = UUID()
        let first = makeTracker(id: sharedID, name: earlyName, isDefault: true, createdAt: early)
        let second = makeTracker(id: sharedID, name: lateName, isDefault: true, createdAt: late)
        context.insert(first)
        context.insert(second)
        let entries = [makeEntry(for: first, in: context), makeEntry(for: second, in: context)]
        try context.save()
        return (first, second, entries)
    }

    @Test
    func mergesCategoriesSharingAnID() throws {
        let context = try makeContext()
        let setup = try makeSharedIDSetup(in: context)

        let removed = try SyncDeduplicator(context: context).mergeDuplicateCategories()

        let trackers = try context.fetch(FetchDescriptor<Tracker>())
        #expect(removed == 1)
        #expect(trackers.count == 1)
        #expect(trackers.first?.createdAt == early)
        #expect(trackers.first?.isDefault == true)
        for entry in setup.entries {
            #expect(entry.tracker?.createdAt == early)
        }
    }

    @Test
    func earliestCopyKeepsTheUsersRename() throws {
        let context = try makeContext()
        _ = try makeSharedIDSetup(in: context, earlyName: "Tjeneste", lateName: "Field Service")

        try SyncDeduplicator(context: context).mergeDuplicateCategories()

        let trackers = try context.fetch(FetchDescriptor<Tracker>())
        #expect(trackers.count == 1)
        #expect(trackers.first?.name == "Tjeneste")
    }

    @Test
    func movedEntriesGetFreshSnapshots() throws {
        let context = try makeContext()
        let setup = try makeSharedIDSetup(in: context, earlyName: "Tjeneste", lateName: "Field Service")

        try SyncDeduplicator(context: context).mergeDuplicateCategories()

        for entry in setup.entries {
            #expect(entry.storedTracker?.name == "Tjeneste")
        }
    }

    @Test
    func distinctCategoriesAreUntouched() throws {
        let context = try makeContext()
        context.insert(makeTracker(name: "A", createdAt: early))
        context.insert(makeTracker(name: "B", createdAt: late))
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateCategories()

        #expect(removed == 0)
        #expect(try context.fetch(FetchDescriptor<Tracker>()).count == 2)
    }

    @Test
    func indistinguishableCopiesAreKept() throws {
        let context = try makeContext()
        let sharedID = UUID()
        context.insert(makeTracker(id: sharedID, createdAt: early))
        context.insert(makeTracker(id: sharedID, createdAt: early))
        try context.save()

        let removed = try SyncDeduplicator(context: context).mergeDuplicateCategories()

        #expect(removed == 0)
        #expect(try context.fetch(FetchDescriptor<Tracker>()).count == 2)
    }

    @Test
    func onlyOneDefaultRemains() throws {
        let context = try makeContext()
        context.insert(makeTracker(name: "Early", isDefault: true, createdAt: early))
        context.insert(makeTracker(name: "Late", isDefault: true, createdAt: late))
        try context.save()

        try SyncDeduplicator(context: context).mergeDuplicateCategories()

        let defaults = try context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.isDefault }))
        #expect(defaults.count == 1)
        #expect(defaults.first?.createdAt == early)
    }

    @Test
    func isIdempotent() throws {
        let context = try makeContext()
        _ = try makeSharedIDSetup(in: context)
        let deduplicator = SyncDeduplicator(context: context)

        try deduplicator.mergeDuplicateCategories()
        let second = try deduplicator.mergeDuplicateCategories()

        #expect(second == 0)
    }
}
