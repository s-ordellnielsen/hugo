import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct CategoryDeletionServiceTests {
    @Test
    func deletingRenamedCategoryKeepsLatestSnapshot() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let tracker = Tracker(name: "LDC", type: .separate, iconName: "hammer")
        let entry = Entry(date: .now, duration: 1_800, tracker: tracker)
        context.insert(tracker)
        context.insert(entry)
        try context.save()

        tracker.name = "Building"
        tracker.type = .main
        try CategoryDeletionService(context: context).delete(tracker)

        let entries = try context.fetch(FetchDescriptor<Entry>())
        let fetched = try #require(entries.first)
        #expect(fetched.tracker == nil)
        #expect(fetched.storedTracker?.name == "Building")
        #expect(fetched.storedTracker?.type == .main)
        let mainLine = ReportingLineCalculator.lines(from: [fetched]).first { $0.type == .main }
        #expect(mainLine?.actualSeconds == fetched.duration)
    }

    @Test
    func recategorizedEntryFollowsNewCategoryAfterDeletion() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let bethel = Tracker(name: "Bethel", type: .separate)
        let fieldService = Tracker(name: "Field Service", type: .main)
        let entry = Entry(date: .now, duration: 1_800, tracker: bethel)
        context.insert(bethel)
        context.insert(fieldService)
        context.insert(entry)
        try context.save()

        entry.tracker = fieldService
        entry.refreshStoredTracker()
        try CategoryDeletionService(context: context).delete(fieldService)

        let category = entry.resolvedCategory()
        #expect(category.type == .main)
        #expect(category.name == "Field Service")
    }
}
