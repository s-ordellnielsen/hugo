import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct WidgetStoreReaderTests {
    /// A group directory with its App Group store path, and a suite holding the widget settings.
    @MainActor
    private final class Fixture {
        let group: TemporaryStore
        let suiteName = UUID().uuidString
        let suite: UserDefaults

        init() throws {
            group = try TemporaryStore()
            suite = UserDefaults(suiteName: suiteName)!
        }

        var storeURL: URL { group.directoryURL.appending(path: StoreRelocator.storeFileName) }
        var markerURL: URL { group.directoryURL.appending(path: StoreRelocator.markerFileName) }

        func remove() {
            group.remove()
            suite.removePersistentDomain(forName: suiteName)
        }

        func writeMarker(_ text: String) throws {
            try Data(text.utf8).write(to: markerURL)
        }

        func writeSettings(_ settings: WidgetSettings) throws {
            suite.set(try JSONEncoder().encode(settings), forKey: UserDefaultsKeys.widgetSettings)
        }

        func writeCurrentSettings() throws {
            try writeSettings(
                WidgetSettings(
                    publisherStatusID: "regular-pioneer", bufferHours: 0,
                    storeSchemaVersion: WidgetSettings.schemaVersionString()))
        }

        func reader() -> WidgetStoreReader {
            WidgetStoreReader(groupDirectory: group.directoryURL, settingsSuite: suite)
        }

        /// The names in the group directory, sorted.
        func listing() -> [String] {
            ((try? FileManager.default.contentsOfDirectory(atPath: group.directoryURL.path)) ?? []).sorted()
        }
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12))!
    }

    private func date(_ day: Int, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func openWriteContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [configuration])
    }

    /// Seeds the store the way the app would: two entries and one plan in November 2026, and one entry in October.
    private func seedStore(at url: URL) throws {
        let container = try openWriteContainer(at: url)
        let context = ModelContext(container)
        context.insert(Entry(date: date(3), duration: 3_600 * 10, tracker: nil))
        context.insert(Entry(date: date(10), duration: 3_600 * 5, tracker: nil))
        context.insert(Entry(date: date(31, month: 10), duration: 3_600 * 100, tracker: nil))
        context.insert(Plan(date: date(20), duration: 3_600 * 2, tracker: nil))
        try context.save()
    }

    @Test
    func readyStateShowsTheMonthFromTheStore() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedStore(at: fixture.storeURL)
        try fixture.writeMarker(StoreRelocator.confirmedState)
        try fixture.writeCurrentSettings()

        let state = fixture.reader().load(now: now, calendar: calendar)

        guard case .ready(let progress) = state else {
            Issue.record("Expected a ready state, got \(state)")
            return
        }
        #expect(progress.loggedSeconds == 3_600 * 15)
        #expect(progress.goalHours == 50)
        #expect(progress.fill.basis == .monthlyGoal(hours: 50))
    }

    @Test
    func loadDoesNotChangeTheStore() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedStore(at: fixture.storeURL)
        try fixture.writeMarker(StoreRelocator.confirmedState)
        try fixture.writeCurrentSettings()
        let before = try Data(contentsOf: fixture.storeURL)

        _ = fixture.reader().load(now: now, calendar: calendar)

        #expect(try Data(contentsOf: fixture.storeURL) == before)
        let rows = try ModelContext(openWriteContainer(at: fixture.storeURL)).fetchCount(FetchDescriptor<Entry>())
        #expect(rows == 3)
    }

    @Test
    func missingGroupDirectoryIsUnavailable() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.writeCurrentSettings()

        let reader = WidgetStoreReader(groupDirectory: nil, settingsSuite: fixture.suite)

        #expect(reader.load(now: now, calendar: calendar) == .unavailable)
    }

    @Test
    func placeholderWhenTheStoreIsNotReadable() throws {
        // No marker, so the app has not moved the store.
        let noMarker = try Fixture()
        defer { noMarker.remove() }
        try seedStore(at: noMarker.storeURL)
        try noMarker.writeCurrentSettings()
        #expect(noMarker.reader().load(now: now, calendar: calendar) == .unavailable)

        // Marker says copied, but the store file is gone.
        let noStore = try Fixture()
        defer { noStore.remove() }
        try noStore.writeMarker(StoreRelocator.copiedState)
        try noStore.writeCurrentSettings()
        #expect(noStore.reader().load(now: now, calendar: calendar) == .unavailable)

        // A store file without a marker is never trusted.
        let storeOnly = try Fixture()
        defer { storeOnly.remove() }
        try seedStore(at: storeOnly.storeURL)
        try storeOnly.writeCurrentSettings()
        #expect(storeOnly.reader().load(now: now, calendar: calendar) == .unavailable)

        // No settings mirror yet.
        let noSettings = try Fixture()
        defer { noSettings.remove() }
        try seedStore(at: noSettings.storeURL)
        try noSettings.writeMarker(StoreRelocator.confirmedState)
        #expect(noSettings.reader().load(now: now, calendar: calendar) == .unavailable)

        // The app wrote settings for another schema version.
        let otherSchema = try Fixture()
        defer { otherSchema.remove() }
        try seedStore(at: otherSchema.storeURL)
        try otherSchema.writeMarker(StoreRelocator.confirmedState)
        try otherSchema.writeSettings(
            WidgetSettings(publisherStatusID: "publisher", bufferHours: 0, storeSchemaVersion: "0.0.1"))
        #expect(otherSchema.reader().load(now: now, calendar: calendar) == .unavailable)

        // A garbage file where the store should be.
        let garbage = try Fixture()
        defer { garbage.remove() }
        try Data("not a database".utf8).write(to: garbage.storeURL)
        try garbage.writeMarker(StoreRelocator.confirmedState)
        try garbage.writeCurrentSettings()
        #expect(garbage.reader().load(now: now, calendar: calendar) == .unavailable)
    }

    @Test
    func placeholderCasesCreateNoFiles() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try seedStore(at: fixture.storeURL)
        try fixture.writeCurrentSettings()
        let before = fixture.listing()

        #expect(fixture.reader().load(now: now, calendar: calendar) == .unavailable)

        #expect(fixture.listing() == before)
    }
}
