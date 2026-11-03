import Foundation
import SwiftData
import Testing

@testable import Hugo

private struct StubCloudLookup: CloudTrackerLookup {
    let hasData: Bool
    func hasAnyTracker() async throws -> Bool { hasData }
}

private struct FailingCloudLookup: CloudTrackerLookup {
    struct Unexpected: Error {}
    func hasAnyTracker() async throws -> Bool { throw Unexpected() }
}

@MainActor
struct AppBootstrapperTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AppBootstrapperTests-\(UUID().uuidString)")!
    }

    @Test
    func seedsDefaultCategoryOnFirstLaunchWithoutCloudData() async throws {
        let context = ModelContext(try InMemoryModelContainer.make())
        let defaults = makeDefaults()
        let bootstrapper = AppBootstrapper(lookup: StubCloudLookup(hasData: false), userDefaults: defaults)

        await bootstrapper.start(context: context)

        let trackers = try context.fetch(FetchDescriptor<Tracker>())
        #expect(trackers.count == 1)
        #expect(trackers.first?.id == DefaultCategoryDefinition.all[0].id)
        #expect(trackers.first?.isDefault == true)
        #expect(defaults.bool(forKey: UserDefaultsKeys.hasRunInitialSetup))
        #expect(bootstrapper.state == .ready)
    }

    @Test
    func doesNotSeedWhenCloudHasData() async throws {
        let context = ModelContext(try InMemoryModelContainer.make())
        let defaults = makeDefaults()
        let bootstrapper = AppBootstrapper(lookup: StubCloudLookup(hasData: true), userDefaults: defaults)

        await bootstrapper.start(context: context)

        #expect(try context.fetch(FetchDescriptor<Tracker>()).isEmpty)
        #expect(defaults.bool(forKey: UserDefaultsKeys.hasRunInitialSetup))
        #expect(bootstrapper.state == .ready)
    }

    @Test
    func neverSeedsOrAsksCloudAfterFirstLaunch() async throws {
        let context = ModelContext(try InMemoryModelContainer.make())
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.hasRunInitialSetup)
        let bootstrapper = AppBootstrapper(lookup: FailingCloudLookup(), userDefaults: defaults)

        await bootstrapper.start(context: context)

        #expect(try context.fetch(FetchDescriptor<Tracker>()).isEmpty)
        #expect(bootstrapper.state == .ready)
    }

    @Test
    func doesNotSeedWhenStoreAlreadyHasCategories() async throws {
        let context = ModelContext(try InMemoryModelContainer.make())
        context.insert(Tracker(name: "Bethel"))
        try context.save()
        let bootstrapper = AppBootstrapper(lookup: StubCloudLookup(hasData: false), userDefaults: makeDefaults())

        await bootstrapper.start(context: context)

        #expect(try context.fetch(FetchDescriptor<Tracker>()).count == 1)
    }
}
