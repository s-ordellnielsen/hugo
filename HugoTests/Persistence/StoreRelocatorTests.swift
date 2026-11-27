import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
private func openStore(at url: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: CurrentSchema.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [configuration])
}

@MainActor
private func seedStore(at url: URL, names: [String]) throws {
    let container = try openStore(at: url)
    let context = ModelContext(container)
    for name in names {
        context.insert(Tracker(name: name))
    }
    try context.save()
}

@MainActor
private func trackerCount(at url: URL) throws -> Int {
    let container = try openStore(at: url)
    return try ModelContext(container).fetchCount(FetchDescriptor<Tracker>())
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

    func newStoreFilesExist() -> Bool {
        StoreFiles.all(for: newStoreURL).contains { FileManager.default.fileExists(atPath: $0.path) }
    }
}

@MainActor
private final class CountingCopier: StoreCopying {
    var copyCount = 0
    private let base = FileStoreCopier()

    func copyStore(from source: URL, to destination: URL) throws {
        copyCount += 1
        try base.copyStore(from: source, to: destination)
    }

    func verifyCopy(of source: URL, at destination: URL) throws {
        try base.verifyCopy(of: source, at: destination)
    }
}

/// Copies the main file and then fails, like an app that quits mid-copy.
private struct InterruptedCopier: StoreCopying {
    struct Interrupted: Error {}

    func copyStore(from source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
        throw Interrupted()
    }

    func verifyCopy(of source: URL, at destination: URL) throws {}
}

/// Copies normally but fails verification.
private struct CorruptVerifyCopier: StoreCopying {
    struct Mismatch: Error {}

    func copyStore(from source: URL, to destination: URL) throws {
        try FileStoreCopier().copyStore(from: source, to: destination)
    }

    func verifyCopy(of source: URL, at destination: URL) throws {
        throw Mismatch()
    }
}

@MainActor
struct StoreRelocatorTests {
    @Test
    func copySucceedsAndKeepsLegacyFiles() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedStore(at: fixture.legacyURL, names: ["Bethel", "Ministry"])

        let resolution = fixture.relocator().resolve()

        #expect(resolution.location == .appGroup)
        #expect(resolution.isFreshCopy)
        #expect(!resolution.legacyCleanupPending)
        #expect(FileManager.default.fileExists(atPath: fixture.newStoreURL.path))
        #expect(FileManager.default.fileExists(atPath: fixture.legacyURL.path))
        #expect(try trackerCount(at: resolution.storeURL) == 2)
    }

    @Test
    func copierCopiesCompanionFilesAndSupportDirectory() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let source = fixture.legacyURL
        try Data("main".utf8).write(to: source)
        try Data("wal".utf8).write(to: URL(fileURLWithPath: source.path + "-wal"))
        try Data("shm".utf8).write(to: URL(fileURLWithPath: source.path + "-shm"))
        let support = fixture.legacy.directoryURL.appending(path: ".default_SUPPORT", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try Data("inner".utf8).write(to: support.appending(path: "inner.bin"))

        let copier = FileStoreCopier()
        try copier.copyStore(from: source, to: fixture.newStoreURL)
        try copier.verifyCopy(of: source, at: fixture.newStoreURL)

        let destination = fixture.newStoreURL.path
        #expect(FileManager.default.fileExists(atPath: destination + "-wal"))
        #expect(FileManager.default.fileExists(atPath: destination + "-shm"))
        #expect(
            FileManager.default.fileExists(
                atPath: fixture.group.directoryURL.appending(path: ".default_SUPPORT/inner.bin").path))
    }

    @Test
    func copierSkipsMissingCompanionFiles() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try Data("main".utf8).write(to: fixture.legacyURL)

        let copier = FileStoreCopier()
        try copier.copyStore(from: fixture.legacyURL, to: fixture.newStoreURL)
        try copier.verifyCopy(of: fixture.legacyURL, at: fixture.newStoreURL)

        #expect(FileManager.default.fileExists(atPath: fixture.newStoreURL.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.newStoreURL.path + "-wal"))
    }

    @Test
    func interruptedCopyLeavesLegacyLocationAndNoTrace() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedStore(at: fixture.legacyURL, names: ["Bethel", "Ministry"])

        let resolution = fixture.relocator(copier: InterruptedCopier()).resolve()

        #expect(resolution.location == .legacy)
        #expect(resolution.storeURL == fixture.legacyURL)
        #expect(!resolution.isFreshCopy)
        #expect(!fixture.newStoreFilesExist())
        #expect(!FileManager.default.fileExists(atPath: fixture.markerURL.path))
        #expect(try trackerCount(at: fixture.legacyURL) == 2)
    }

    @Test
    func failedVerificationLeavesLegacyLocationAndNoTrace() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedStore(at: fixture.legacyURL, names: ["Bethel"])

        let resolution = fixture.relocator(copier: CorruptVerifyCopier()).resolve()

        #expect(resolution.location == .legacy)
        #expect(!fixture.newStoreFilesExist())
        #expect(!FileManager.default.fileExists(atPath: fixture.markerURL.path))
        #expect(try trackerCount(at: fixture.legacyURL) == 1)
    }

    @Test
    func unavailableGroupUsesLegacyAndCreatesNothing() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedStore(at: fixture.legacyURL, names: ["Bethel"])

        let resolution = StoreRelocator(legacyStoreURL: fixture.legacyURL, groupDirectory: nil).resolve()

        #expect(
            resolution
                == StoreRelocator.Resolution(
                    storeURL: fixture.legacyURL,
                    location: .legacy,
                    isFreshCopy: false,
                    legacyCleanupPending: false
                ))
        #expect(!fixture.newStoreFilesExist())
    }

    @Test
    func unwritableGroupDirectoryUsesLegacyAndLeavesLegacyUntouched() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedStore(at: fixture.legacyURL, names: ["Bethel"])
        let blocker = fixture.group.directoryURL.appending(path: "blocker")
        try Data("file".utf8).write(to: blocker)

        let relocator = StoreRelocator(
            legacyStoreURL: fixture.legacyURL,
            groupDirectory: blocker.appending(path: "sub", directoryHint: .isDirectory)
        )
        let resolution = relocator.resolve()

        #expect(resolution.location == .legacy)
        #expect(try trackerCount(at: fixture.legacyURL) == 1)
    }

    @Test
    func secondLaunchAfterMoveDoesNotCopyAgain() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedStore(at: fixture.legacyURL, names: ["Bethel"])
        let first = fixture.relocator()
        #expect(first.resolve().isFreshCopy)
        first.markCopied()

        let counter = CountingCopier()
        let resolution = fixture.relocator(copier: counter).resolve()

        #expect(resolution.location == .appGroup)
        #expect(!resolution.isFreshCopy)
        #expect(resolution.legacyCleanupPending)
        #expect(counter.copyCount == 0)
    }

    @Test
    func legacyFilesAreDeletedOnlyByAConfirmedLaterLaunch() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedStore(at: fixture.legacyURL, names: ["Bethel"])
        let first = fixture.relocator()
        _ = first.resolve()
        first.markCopied()
        #expect(FileManager.default.fileExists(atPath: fixture.legacyURL.path))

        let second = fixture.relocator().resolve()
        #expect(second.legacyCleanupPending)
        #expect(FileManager.default.fileExists(atPath: fixture.legacyURL.path))

        fixture.relocator().confirmAndDeleteLegacyStore()
        #expect(!FileManager.default.fileExists(atPath: fixture.legacyURL.path))

        let third = fixture.relocator().resolve()
        #expect(third.location == .appGroup)
        #expect(!third.legacyCleanupPending)
        #expect(try trackerCount(at: third.storeURL) == 1)
    }

    @Test
    func copiedMarkerWithMissingStoreCopiesAgain() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedStore(at: fixture.legacyURL, names: ["Bethel"])
        let first = fixture.relocator()
        _ = first.resolve()
        first.markCopied()
        try FileManager.default.removeItem(at: fixture.newStoreURL)

        let resolution = fixture.relocator().resolve()

        #expect(resolution.location == .appGroup)
        #expect(resolution.isFreshCopy)
        #expect(FileManager.default.fileExists(atPath: fixture.newStoreURL.path))
    }

    @Test
    func freshInstallCopiesNothing() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let resolution = fixture.relocator().resolve()

        #expect(resolution.location == .appGroup)
        #expect(!resolution.isFreshCopy)
        #expect(!resolution.legacyCleanupPending)
        #expect(!fixture.newStoreFilesExist())
    }
}
