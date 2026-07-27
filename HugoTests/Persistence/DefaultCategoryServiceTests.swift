import Foundation
import SwiftData
import Testing
@testable import Hugo

@MainActor
struct DefaultCategoryServiceTests {
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

        try DefaultCategoryService(context: context).setDefault(third)
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

        try DefaultCategoryService(context: context).setDefault(tracker)
        let defaults = try context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.isDefault }))

        #expect(defaults.count == 1)
        #expect(defaults.first?.id == tracker.id)
    }
}

extension DefaultCategoryServiceTests {
    @Test
    func clearingDefaultLeavesNoDefaults() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let tracker = Tracker(name: "Current", isDefault: true)
        context.insert(tracker)
        try context.save()

        try DefaultCategoryService(context: context).clearDefault()
        let defaults = try context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.isDefault }))

        #expect(defaults.isEmpty)
    }

    @Test
    func selectingCategoryRepairsMultipleExistingDefaults() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let first = Tracker(name: "First", isDefault: true)
        let second = Tracker(name: "Second", isDefault: true)
        let selected = Tracker(name: "Selected")
        context.insert(first)
        context.insert(second)
        context.insert(selected)
        try context.save()

        try DefaultCategoryService(context: context).setDefault(selected)
        let defaults = try context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.isDefault }))

        #expect(defaults.count == 1)
        #expect(defaults.first?.id == selected.id)
    }
}
