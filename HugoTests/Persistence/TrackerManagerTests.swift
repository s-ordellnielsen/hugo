import Foundation
import SwiftData
import Testing
@testable import Hugo

@MainActor
struct TrackerManagerTests {
    @Test
    func selectingTrackerLeavesOnlySelectedTrackerAsDefault() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let first = Tracker(name: "First", isDefault: true)
        let second = Tracker(name: "Second")
        let third = Tracker(name: "Third")
        context.insert(first)
        context.insert(second)
        context.insert(third)
        try context.save()

        TrackerManager(context).setAsDefault(third)
        let defaults = try context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.isDefault }))

        #expect(defaults.count == 1)
        #expect(defaults.first?.id == third.id)
    }

    @Test
    func selectingCurrentDefaultLeavesOneDefault() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let tracker = Tracker(name: "Current", isDefault: true)
        context.insert(tracker)
        try context.save()

        TrackerManager(context).setAsDefault(tracker)
        let defaults = try context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.isDefault }))

        #expect(defaults.count == 1)
        #expect(defaults.first?.id == tracker.id)
    }
}
