import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct DefaultCategoryServiceTests {
    private let early = Date(timeIntervalSince1970: 1_000)
    private let late = Date(timeIntervalSince1970: 2_000)

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "DefaultCategoryServiceTests-\(UUID().uuidString)")!
    }

    private func makeTracker(name: String, isDefault: Bool = false, createdAt: Date) -> Tracker {
        let tracker = Tracker(name: name, isDefault: isDefault)
        tracker.createdAt = createdAt
        return tracker
    }

    @Test
    func setDefaultStoresTheId() {
        let defaults = makeDefaults()
        let tracker = makeTracker(name: "Field Service", createdAt: early)

        DefaultCategoryService(userDefaults: defaults).setDefault(tracker)

        #expect(defaults.string(forKey: UserDefaultsKeys.defaultCategoryID) == tracker.id.uuidString)
    }

    @Test
    func setDefaultNilStoresAnEmptyString() {
        let defaults = makeDefaults()

        DefaultCategoryService(userDefaults: defaults).setDefault(nil)

        #expect(defaults.string(forKey: UserDefaultsKeys.defaultCategoryID) == "")
    }

    @Test
    func migrationCopiesTheLegacyDefault() throws {
        let context = ModelContext(try InMemoryModelContainer.make())
        let legacy = makeTracker(name: "Field Service", isDefault: true, createdAt: early)
        context.insert(legacy)
        try context.save()
        let defaults = makeDefaults()

        try DefaultCategoryService(userDefaults: defaults).migrateLegacyDefault(context: context)

        #expect(defaults.string(forKey: UserDefaultsKeys.defaultCategoryID) == legacy.id.uuidString)
        #expect(defaults.bool(forKey: UserDefaultsKeys.hasMigratedDefaultCategory))
    }

    @Test
    func migrationPicksTheSurvivorWhenSeveralAreDefault() throws {
        let context = ModelContext(try InMemoryModelContainer.make())
        let older = makeTracker(name: "Older", isDefault: true, createdAt: early)
        let newer = makeTracker(name: "Newer", isDefault: true, createdAt: late)
        context.insert(newer)
        context.insert(older)
        try context.save()
        let defaults = makeDefaults()

        try DefaultCategoryService(userDefaults: defaults).migrateLegacyDefault(context: context)

        #expect(defaults.string(forKey: UserDefaultsKeys.defaultCategoryID) == older.id.uuidString)
    }

    @Test
    func migrationKeepsAnExistingSetting() throws {
        let context = ModelContext(try InMemoryModelContainer.make())
        context.insert(makeTracker(name: "Legacy", isDefault: true, createdAt: early))
        try context.save()
        let defaults = makeDefaults()
        defaults.set("preset", forKey: UserDefaultsKeys.defaultCategoryID)

        try DefaultCategoryService(userDefaults: defaults).migrateLegacyDefault(context: context)

        #expect(defaults.string(forKey: UserDefaultsKeys.defaultCategoryID) == "preset")
        #expect(defaults.bool(forKey: UserDefaultsKeys.hasMigratedDefaultCategory))
    }

    @Test
    func migrationRunsOnce() throws {
        let context = ModelContext(try InMemoryModelContainer.make())
        let first = makeTracker(name: "First", isDefault: true, createdAt: early)
        context.insert(first)
        try context.save()
        let defaults = makeDefaults()
        let service = DefaultCategoryService(userDefaults: defaults)

        try service.migrateLegacyDefault(context: context)
        defaults.set("changed", forKey: UserDefaultsKeys.defaultCategoryID)
        context.insert(makeTracker(name: "Added", isDefault: true, createdAt: late))
        try context.save()
        try service.migrateLegacyDefault(context: context)

        #expect(defaults.string(forKey: UserDefaultsKeys.defaultCategoryID) == "changed")
    }

    @Test
    func migrationWithoutLegacyRowsStillMarksDone() throws {
        let context = ModelContext(try InMemoryModelContainer.make())
        context.insert(makeTracker(name: "Plain", createdAt: early))
        try context.save()
        let defaults = makeDefaults()

        try DefaultCategoryService(userDefaults: defaults).migrateLegacyDefault(context: context)

        #expect(defaults.object(forKey: UserDefaultsKeys.defaultCategoryID) == nil)
        #expect(defaults.bool(forKey: UserDefaultsKeys.hasMigratedDefaultCategory))
    }
}
