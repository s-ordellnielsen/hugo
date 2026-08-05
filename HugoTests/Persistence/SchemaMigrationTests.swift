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
                        TrackerSummary(
                            name: "Field Service", duration: 3_600, type: .main, hue: 0.1, sat: 0.8, bri: 0.9,
                            icon: "figure.walk"),
                        TrackerSummary(
                            name: "Bethel", duration: 1_800, type: .separate, hue: 0.2, sat: 0.8, bri: 0.9,
                            icon: "building"),
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
                        TrackerSummary(
                            name: "Field Service", duration: 3_600, type: .main, hue: 0.1, sat: 0.8, bri: 0.9,
                            icon: "figure.walk")
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

    @Test
    func migratingV8StoreBackfillsSubmittedReportSentinelsPerMonth() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let calendar = Calendar.current
        let tracker = SchemaV8.Tracker(name: "Field Service", type: .main)
        let julyFirst = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))
        let julySecond = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15)))
        let june = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10)))

        try makeV8Store(
            at: store.storeURL, trackers: [tracker],
            seeds: [
                (julyFirst, Date(timeIntervalSince1970: 1_000)),
                (julySecond, Date(timeIntervalSince1970: 2_000)),
                (june, Date(timeIntervalSince1970: 3_000)),
            ])

        let container = try makeCurrentStore(at: store.storeURL)
        let reports = try container.mainContext.fetch(
            FetchDescriptor<SubmittedReport>()
        )

        #expect(reports.count == 2)

        let julyReport = try #require(reports.first { $0.year == 2026 && $0.month == 7 })
        let juneReport = try #require(reports.first { $0.year == 2026 && $0.month == 6 })

        for report in [julyReport, juneReport] {
            #expect(report.firstSubmittedAt == .distantPast)
            #expect(report.submittedAt == .distantPast)
            #expect((report.roundingRuleRaw ?? "").isEmpty)
            #expect(report.submittedHours == 0)
            #expect((report.categories ?? []).isEmpty)
        }

        #expect(julyReport.entriesClosedAt == Date(timeIntervalSince1970: 2_000))
        #expect(juneReport.entriesClosedAt == Date(timeIntervalSince1970: 3_000))
        #expect(julyReport.yearMonth == YearMonth(year: 2026, month: 7))
    }

    @Test
    func migratingEmptyV8StoreCreatesNoSubmittedReports() throws {
        let store = try TemporaryStore()
        defer { store.remove() }
        try makeV8Store(at: store.storeURL)

        let container = try makeCurrentStore(at: store.storeURL)
        let reports = try container.mainContext.fetch(
            FetchDescriptor<SubmittedReport>()
        )

        #expect(reports.isEmpty)
    }

    @Test
    func migratingV9StorePreservesSubmittedReportsAcrossTheEligibilityRepair() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        // The deployed V9 (non-optional) shape, as written by the internal
        // TestFlight build: one sentinel and one real submission.
        let sentinel = SchemaV9.SubmittedReport(
            year: 2026, month: 6,
            entriesClosedAt: Date(timeIntervalSince1970: 3_000)
        )
        let real = SchemaV9.SubmittedReport(
            year: 2026, month: 7,
            firstSubmittedAt: Date(timeIntervalSince1970: 10_000),
            submittedAt: Date(timeIntervalSince1970: 20_000),
            entriesClosedAt: Date(timeIntervalSince1970: 9_000),
            roundingRuleRaw: "transfer",
            fieldServiceSeconds: 19_200,
            actualTotalSeconds: 20_400,
            submittedHours: 5,
            carriedOutSeconds: 2_400,
            totalBibleStudies: 3,
            categories: [
                SchemaV9.SubmittedReport.SubmittedCategory(
                    name: "Field Service",
                    iconName: "figure.walk",
                    typeRaw: TrackerType.main.rawValue,
                    actualSeconds: 19_200,
                    submittedHours: 5
                )
            ]
        )
        try makeV9Store(at: store.storeURL, submissions: [sentinel, real])

        let container = try makeCurrentStore(at: store.storeURL)
        let reports = try container.mainContext.fetch(FetchDescriptor<SubmittedReport>())

        #expect(reports.count == 2)

        let migratedSentinel = try #require(reports.first { $0.year == 2026 && $0.month == 6 })
        #expect(migratedSentinel.submittedAt == .distantPast)
        #expect(migratedSentinel.firstSubmittedAt == .distantPast)
        #expect(migratedSentinel.entriesClosedAt == Date(timeIntervalSince1970: 3_000))

        let migratedReal = try #require(reports.first { $0.year == 2026 && $0.month == 7 })
        #expect(migratedReal.firstSubmittedAt == Date(timeIntervalSince1970: 10_000))
        #expect(migratedReal.submittedAt == Date(timeIntervalSince1970: 20_000))
        #expect(migratedReal.entriesClosedAt == Date(timeIntervalSince1970: 9_000))
        #expect(migratedReal.roundingRuleRaw == "transfer")
        #expect(migratedReal.fieldServiceSeconds == 19_200)
        #expect(migratedReal.submittedHours == 5)
        #expect(migratedReal.carriedOutSeconds == 2_400)
        #expect(migratedReal.totalBibleStudies == 3)
        #expect(migratedReal.categories?.first?.name == "Field Service")
        #expect(migratedReal.yearMonth == YearMonth(year: 2026, month: 7))
    }

    @Test
    func currentStoreRoundTripsSubmittedReportWithCategorySnapshots() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext

        let report = SubmittedReport(
            year: 2026,
            month: 7,
            firstSubmittedAt: Date(timeIntervalSince1970: 10_000),
            submittedAt: Date(timeIntervalSince1970: 20_000),
            entriesClosedAt: Date(timeIntervalSince1970: 9_000),
            roundingRuleRaw: "transfer",
            fieldServiceSeconds: 19_200,
            actualTotalSeconds: 20_400,
            submittedHours: 5,
            carriedInSeconds: 1_200,
            carriedOutSeconds: 2_400,
            roundedUpSeconds: 0,
            roundedDownSeconds: 0,
            totalBibleStudies: 3,
            categories: [
                SubmittedReport.SubmittedCategory(
                    name: "Field Service",
                    iconName: "figure.walk",
                    typeRaw: TrackerType.main.rawValue,
                    actualSeconds: 19_200,
                    submittedHours: 5
                ),
                SubmittedReport.SubmittedCategory(
                    name: "Bethel",
                    iconName: "building",
                    typeRaw: TrackerType.separate.rawValue,
                    actualSeconds: 1_200,
                    submittedHours: 0
                ),
            ]
        )
        context.insert(report)
        try context.save()

        let fetched = try #require(
            try context.fetch(FetchDescriptor<SubmittedReport>()).first
        )

        #expect(fetched.year == 2026)
        #expect(fetched.month == 7)
        #expect(fetched.yearMonth == YearMonth(year: 2026, month: 7))
        #expect(fetched.firstSubmittedAt == Date(timeIntervalSince1970: 10_000))
        #expect(fetched.submittedAt == Date(timeIntervalSince1970: 20_000))
        #expect(fetched.entriesClosedAt == Date(timeIntervalSince1970: 9_000))
        #expect(fetched.roundingRuleRaw == "transfer")
        #expect(fetched.fieldServiceSeconds == 19_200)
        #expect(fetched.actualTotalSeconds == 20_400)
        #expect(fetched.submittedHours == 5)
        #expect(fetched.carriedInSeconds == 1_200)
        #expect(fetched.carriedOutSeconds == 2_400)
        #expect(fetched.roundedUpSeconds == 0)
        #expect(fetched.roundedDownSeconds == 0)
        #expect(fetched.totalBibleStudies == 3)
        #expect(fetched.categories?.count == 2)
        #expect(fetched.categories?.first?.name == "Field Service")
        #expect(fetched.categories?.first?.iconName == "figure.walk")
        #expect(fetched.categories?.first?.type == .main)
        #expect(fetched.categories?.first?.actualSeconds == 19_200)
        #expect(fetched.categories?.first?.submittedHours == 5)
        #expect(fetched.categories?.last?.type == .separate)
        #expect(fetched.categories?.map(\.id) == ["Field Service", "Bethel"])
    }

    private func makeV8Store(
        at url: URL,
        trackers: [SchemaV8.Tracker] = [],
        seeds: [(date: Date, createdAt: Date)] = []
    ) throws {
        let schema = Schema(versionedSchema: SchemaV8.self)
        let configuration = ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        trackers.forEach(context.insert)
        for seed in seeds {
            let entry = SchemaV8.Entry(
                date: seed.date,
                duration: 3_600,
                tracker: trackers.first
            )
            entry.createdAt = seed.createdAt
            context.insert(entry)
        }
        try context.save()
    }

    private func makeV9Store(
        at url: URL,
        trackers: [SchemaV8.Tracker] = [],
        seeds: [(date: Date, createdAt: Date)] = [],
        submissions: [SchemaV9.SubmittedReport] = []
    ) throws {
        let schema = Schema(versionedSchema: SchemaV9.self)
        let configuration = ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        trackers.forEach(context.insert)
        for seed in seeds {
            let entry = SchemaV8.Entry(
                date: seed.date,
                duration: 3_600,
                tracker: trackers.first
            )
            entry.createdAt = seed.createdAt
            context.insert(entry)
        }
        submissions.forEach(context.insert)
        try context.save()
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
