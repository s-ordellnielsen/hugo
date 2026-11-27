import Foundation
import SwiftData
import Testing

@testable import Hugo

private struct StubCloudLookup: CloudTrackerLookup {
    let hasData: Bool
    func hasAnyTracker() async throws -> Bool { hasData }
}

/// Writes garbage where the store should be, but reports a passing verification.
private struct GarbageCopier: StoreCopying {
    func copyStore(from source: URL, to destination: URL) throws {
        try Data("not a database".utf8).write(to: destination)
    }

    func verifyCopy(of source: URL, at destination: URL) throws {}
}

@MainActor
private func seedLegacyStore(at url: URL, names: [String]) throws {
    let schema = Schema(versionedSchema: CurrentSchema.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [configuration])
    let context = ModelContext(container)
    for name in names {
        context.insert(Tracker(name: name))
    }
    try context.save()
}

@MainActor
private struct Fixture {
    let legacy: TemporaryStore
    let group: TemporaryStore

    var legacyURL: URL { legacy.directoryURL.appending(path: "default.store") }
    var newStoreURL: URL { group.directoryURL.appending(path: "default.store") }
    var markerURL: URL { group.directoryURL.appending(path: "store-move-state") }

    init() throws {
        legacy = try TemporaryStore()
        group = try TemporaryStore()
    }

    func remove() {
        legacy.remove()
        group.remove()
    }

    func relocator(copier: any StoreCopying = FileStoreCopier()) -> StoreRelocator {
        StoreRelocator(legacyStoreURL: legacyURL, groupDirectory: group.directoryURL, copier: copier)
    }

    func markerText() -> String? {
        try? String(contentsOf: markerURL, encoding: .utf8)
    }

    func newStoreFilesExist() -> Bool {
        StoreFiles.all(for: newStoreURL).contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    func legacyFileExists() -> Bool {
        FileManager.default.fileExists(atPath: legacyURL.path)
    }
}

/// Opens the production factory and returns the tracker count. The container is released before returning.
@MainActor
private func launchCount(_ fixture: Fixture, copier: any StoreCopying = FileStoreCopier()) throws -> Int {
    let container = try ModelContainerFactory.makeProductionContainer(
        relocator: fixture.relocator(copier: copier),
        cloudKitDatabase: .none
    )
    return try ModelContext(container).fetchCount(FetchDescriptor<Tracker>())
}

@MainActor
struct ModelContainerFactoryTests {
    @Test
    func firstLaunchOpensTheCopyAndMarksIt() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedLegacyStore(at: fixture.legacyURL, names: ["Bethel", "Ministry"])

        #expect(try launchCount(fixture) == 2)
        #expect(fixture.markerText() == "copied")
        #expect(fixture.legacyFileExists())
    }

    @Test
    func freshInstallMarksTheStoreConfirmed() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        #expect(try launchCount(fixture) == 0)
        #expect(fixture.markerText() == "confirmed")
    }

    @Test
    func secondLaunchDeletesLegacyFilesAndKeepsRows() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedLegacyStore(at: fixture.legacyURL, names: ["Bethel", "Ministry"])

        #expect(try launchCount(fixture) == 2)
        #expect(fixture.legacyFileExists())

        #expect(try launchCount(fixture) == 2)
        #expect(!fixture.legacyFileExists())
        #expect(fixture.markerText() == "confirmed")
    }

    @Test
    func badAppGroupStoreAfterCopyThrowsAndNeverUsesLegacy() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedLegacyStore(at: fixture.legacyURL, names: ["Bethel"])
        #expect(try launchCount(fixture) == 1)

        try Data("not a database".utf8).write(to: fixture.newStoreURL)

        #expect(throws: (any Error).self) {
            _ = try ModelContainerFactory.makeProductionContainer(
                relocator: fixture.relocator(),
                cloudKitDatabase: .none
            )
        }
        #expect(fixture.legacyFileExists())
        #expect(fixture.markerText() == "copied")
    }

    @Test
    func firstLaunchCopyThatFailsToOpenFallsBackToLegacy() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedLegacyStore(at: fixture.legacyURL, names: ["Bethel", "Ministry"])

        let count = try launchCount(fixture, copier: GarbageCopier())

        #expect(count == 2)
        #expect(!fixture.newStoreFilesExist())
        #expect(fixture.markerText() == nil)
        #expect(fixture.legacyFileExists())
    }

    @Test
    func openingTheStoreDoesNotSeedDefaultCategory() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedLegacyStore(at: fixture.legacyURL, names: ["Bethel"])

        try await assertNoSeeding(relocator: fixture.relocator())
        try await assertNoSeeding(relocator: StoreRelocator(legacyStoreURL: fixture.legacyURL, groupDirectory: nil))
    }

    private func assertNoSeeding(relocator: StoreRelocator) async throws {
        let container = try ModelContainerFactory.makeProductionContainer(
            relocator: relocator,
            cloudKitDatabase: .none
        )
        let context = ModelContext(container)
        let suiteName = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let bootstrapper = AppBootstrapper(lookup: StubCloudLookup(hasData: false), userDefaults: defaults)

        await bootstrapper.start(context: context)

        #expect(try context.fetchCount(FetchDescriptor<Tracker>()) == 1)
    }
}
