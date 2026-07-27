import Foundation
import SwiftData
import Testing
@testable import Hugo

@MainActor
struct SchemaMigrationTests {
    @Test
    func migratesReportTrackersIntoEntries() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        try makeV7Store(
            at: store.storeURL,
            reports: [
                SchemaV7.Report(
                    year: 2026,
                    month: 7,
                    fieldService: 3_600,
                    bibleStudies: 1,
                    goalID: nil,
                    goalMonthlyHours: 0,
                    extraTime: 0,
                    trackers: [
                        TrackerSummary(name: "Field Service", duration: 3_600, type: .main, hue: 0.1, sat: 0.8, bri: 0.9, icon: "figure.walk"),
                        TrackerSummary(name: "Bethel", duration: 1_800, type: .separate, hue: 0.2, sat: 0.8, bri: 0.9, icon: "building"),
                    ]
                )
            ]
        )

        let container = try makeCurrentStore(at: store.storeURL)
        let context = container.mainContext
        let entries = try context.fetch(FetchDescriptor<SchemaV8.Entry>())
        let reports = try context.fetch(FetchDescriptor<SchemaV8.Report>())

        #expect(entries.count == 2)
        #expect(reports.isEmpty)
        #expect(entries.map(\.duration).sorted() == [1_800, 3_600])
    }

    @Test
    func migratedEntriesUseReportMonthAndTrackerSnapshot() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let tracker = SchemaV7.Tracker(
            name: "Field Service",
            type: .main,
            isDefault: true,
            iconName: "figure.walk"
        )
        try makeV7Store(
            at: store.storeURL,
            trackers: [tracker],
            reports: [
                SchemaV7.Report(
                    year: 2026,
                    month: 7,
                    fieldService: 3_600,
                    bibleStudies: 0,
                    goalID: nil,
                    goalMonthlyHours: 0,
                    extraTime: 0,
                    trackers: [
                        TrackerSummary(name: "Field Service", duration: 3_600, type: .main, hue: 0.1, sat: 0.8, bri: 0.9, icon: "figure.walk")
                    ]
                )
            ]
        )

        let container = try makeCurrentStore(at: store.storeURL)
        let entries = try container.mainContext.fetch(FetchDescriptor<SchemaV8.Entry>())
        let entry = try #require(entries.first)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: entry.date)

        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 1)
        #expect(entry.storedTracker?.name == "Field Service")
        #expect(entry.storedTracker?.icon == "figure.walk")
        #expect(entry.storedTracker?.type == .main)
    }

    @Test
    func migratesV7StoreWithoutReportsWithoutCreatingEntries() throws {
        let store = try TemporaryStore()
        defer { store.remove() }
        try makeV7Store(at: store.storeURL)

        let container = try makeCurrentStore(at: store.storeURL)
        let entries = try container.mainContext.fetch(FetchDescriptor<SchemaV8.Entry>())

        #expect(entries.isEmpty)
    }

    @Test
    func currentStoreDeletesTrackerAndPreservesEntrySnapshot() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let tracker = Tracker(name: "Field Service", iconName: "figure.walk")
        let entry = Entry(date: Date(), duration: 3_600, tracker: tracker)
        context.insert(tracker)
        context.insert(entry)
        try context.save()

        context.delete(tracker)
        try context.save()

        let fetchedEntry = try #require(try context.fetch(FetchDescriptor<Entry>()).first)
        #expect(fetchedEntry.tracker == nil)
        #expect(fetchedEntry.storedTracker?.name == "Field Service")
        #expect(fetchedEntry.storedTracker?.icon == "figure.walk")
    }

    private func makeV7Store(
        at url: URL,
        trackers: [SchemaV7.Tracker] = [],
        reports: [SchemaV7.Report] = []
    ) throws {
        let schema = Schema(versionedSchema: SchemaV7.self)
        let configuration = ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        trackers.forEach(context.insert)
        reports.forEach(context.insert)
        try context.save()
    }

    private func makeCurrentStore(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let configuration = ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: MigrationPlan.self,
            configurations: [configuration]
        )
    }
}
