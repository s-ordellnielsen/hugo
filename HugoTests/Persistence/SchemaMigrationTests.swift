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
        let entries = try context.fetch(FetchDescriptor<Entry>())
		let reports = try context.fetch(FetchDescriptor<SchemaV11.Report>())

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
        let entries = try container.mainContext.fetch(FetchDescriptor<Entry>())
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
        #expect(migratedReal.fieldServiceSeconds == 19_200)
        #expect(migratedReal.submittedHours == 5)
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
            fieldServiceSeconds: 19_200,
            actualTotalSeconds: 20_400,
            submittedHours: 5,
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
        #expect(fetched.fieldServiceSeconds == 19_200)
        #expect(fetched.actualTotalSeconds == 20_400)
        #expect(fetched.submittedHours == 5)
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

    @Test func migratingV10StorePreservesCategorySnapshotUnchanged() async throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let report = SchemaV10.SubmittedReport(
            year: 2026, month: 8, firstSubmittedAt: Date(timeIntervalSince1970: 10_000),
            submittedAt: Date(timeIntervalSince1970: 20_000),
            entriesClosedAt: Date(timeIntervalSince1970: 9_000),
            roundingRuleRaw: "",
            fieldServiceSeconds: 19_200,
            actualTotalSeconds: 20_400,
            submittedHours: 5,
            carriedInSeconds: 0,
            carriedOutSeconds: 0,
            roundedUpSeconds: 0,
            roundedDownSeconds: 0,
            totalBibleStudies: 2,
            categories: [
                SchemaV10.SubmittedReport.SubmittedCategory(
                    name: "Field Service",
                    iconName: "figure.walk",
                    typeRaw: TrackerType.main.rawValue,
                    actualSeconds: 19_200,
                    submittedHours: 5
                ),
                SchemaV10.SubmittedReport.SubmittedCategory(
                    name: "Bethel",
                    iconName: "building",
                    typeRaw: TrackerType.separate.rawValue,
                    actualSeconds: 1_200,
                    submittedHours: 0
                ),
            ]
        )
		let originalCategories = report.categories
		
		try makeV10Store(at: store.storeURL, submissions: [report])
		
		let container = try makeCurrentStore(at: store.storeURL)
		
		let reports = try container.mainContext.fetch(FetchDescriptor<SubmittedReport>())
		
		#expect(reports.count == 1)
		
		let migratedReport = try #require(reports.first { $0.year == 2026 && $0.month == 8 })
		
		#expect(fields(migratedReport.categories!.first(where: { $0.name == "Field Service"})!) == fields(originalCategories!.first(where: { $0.name == "Field Service"})!))
		#expect(fields(migratedReport.categories!.first(where: { $0.name == "Bethel"})!) == fields(originalCategories!.first(where: { $0.name == "Bethel"})!))
		
		func fields(_ c: SchemaV10.SubmittedReport.SubmittedCategory) -> (String, String, String, TimeInterval, Int) {
			(c.name, c.iconName, c.typeRaw, c.actualSeconds, c.submittedHours)
		}
		
		func fields(_ c: SchemaV11.SubmittedReport.SubmittedCategory) -> (String, String, String, TimeInterval, Int) {
			(c.name, c.iconName, c.typeRaw, c.actualSeconds, c.submittedHours)
		}
    }


    @Test
    func migratingV10StoreMergesMainCategoriesIntoOneFieldServiceLine() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let separateCategory = SchemaV10.SubmittedReport.SubmittedCategory(
            name: "Bethel",
            iconName: "building",
            typeRaw: TrackerType.separate.rawValue,
            actualSeconds: 1_800,
            submittedHours: 1
        )
        let report = SchemaV10.SubmittedReport(
            year: 2026,
            month: 8,
            submittedAt: Date(timeIntervalSince1970: 20_000),
            fieldServiceSeconds: 10_800,
            actualTotalSeconds: 12_600,
            submittedHours: 4,
            categories: [
                SchemaV10.SubmittedReport.SubmittedCategory(
                    name: "Field Service",
                    iconName: "figure.walk",
                    typeRaw: TrackerType.main.rawValue,
                    actualSeconds: 3_600,
                    submittedHours: 1
                ),
                SchemaV10.SubmittedReport.SubmittedCategory(
                    name: "Ministry School",
                    iconName: "book",
                    typeRaw: TrackerType.main.rawValue,
                    actualSeconds: 7_200,
                    submittedHours: 2
                ),
                separateCategory,
            ]
        )
        try makeV10Store(at: store.storeURL, submissions: [report])

        let container = try makeCurrentStore(at: store.storeURL)
        let migratedReport = try #require(
            try container.mainContext.fetch(FetchDescriptor<SubmittedReport>()).first
        )

        #expect(migratedReport.reportingLines.count == 2)
        #expect(migratedReport.reportingLines.filter { $0.type == .main }.count == 1)

        let mainLine = try #require(
            migratedReport.reportingLines.first { $0.type == .main }
        )
        #expect(mainLine.id == "")
        #expect(mainLine.durationInSeconds == 10_800)
        #expect(mainLine.submittedHours == 3)
    }

    @Test
    func migratingV10StorePreservesSeparateCategoriesAsIndividualLines() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let category = SchemaV10.SubmittedReport.SubmittedCategory(
            name: "Bethel",
            iconName: "building",
            typeRaw: TrackerType.separate.rawValue,
            actualSeconds: 1_800,
            submittedHours: 1
        )
        let report = SchemaV10.SubmittedReport(
            year: 2026,
            month: 8,
            submittedAt: Date(timeIntervalSince1970: 20_000),
            categories: [category]
        )
        try makeV10Store(at: store.storeURL, submissions: [report])

        let container = try makeCurrentStore(at: store.storeURL)
        let migratedReport = try #require(
            try container.mainContext.fetch(FetchDescriptor<SubmittedReport>()).first
        )
        let separateLine = try #require(
            migratedReport.reportingLines.first { $0.typeName == category.name }
        )

        #expect(migratedReport.reportingLines.count == 2)
        #expect(separateLine.type == .separate)
        #expect(separateLine.typeName == category.name)
        #expect(separateLine.id == category.name)
        #expect(separateLine.durationInSeconds == 1_800)
        #expect(separateLine.submittedHours == 1)
        #expect(separateLine.rounding == .up)
    }

    @Test
    func migratingV10StoreInfersDownRoundingForSeparateCategories() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let category = SchemaV10.SubmittedReport.SubmittedCategory(
            name: "Bethel",
            iconName: "building",
            typeRaw: TrackerType.separate.rawValue,
            actualSeconds: 5_400,
            submittedHours: 1
        )
        let report = SchemaV10.SubmittedReport(
            year: 2026,
            month: 8,
            submittedAt: Date(timeIntervalSince1970: 20_000),
            categories: [category]
        )
        try makeV10Store(at: store.storeURL, submissions: [report])

        let container = try makeCurrentStore(at: store.storeURL)
        let migratedReport = try #require(
            try container.mainContext.fetch(FetchDescriptor<SubmittedReport>()).first
        )
        let separateLine = try #require(
            migratedReport.reportingLines.first { $0.typeName == category.name }
        )

        #expect(separateLine.durationInSeconds == 5_400)
        #expect(separateLine.submittedHours == 1)
        #expect(separateLine.rounding == .down)
    }

    @Test
    func migratingV10StoreWithNoRoundingLeavesRoundingRawEmpty() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let category = SchemaV10.SubmittedReport.SubmittedCategory(
            name: "Bethel",
            iconName: "building",
            typeRaw: TrackerType.separate.rawValue,
            actualSeconds: 7_200,
            submittedHours: 2
        )
        let report = SchemaV10.SubmittedReport(
            year: 2026,
            month: 8,
            submittedAt: Date(timeIntervalSince1970: 20_000),
            categories: [category]
        )
        try makeV10Store(at: store.storeURL, submissions: [report])

        let container = try makeCurrentStore(at: store.storeURL)
        let migratedReport = try #require(
            try container.mainContext.fetch(FetchDescriptor<SubmittedReport>()).first
        )
        let separateLine = try #require(
            migratedReport.reportingLines.first { $0.typeName == category.name }
        )

        #expect(separateLine.roundingRaw == "")
        #expect(separateLine.rounding == nil)
    }

    @Test
    func migratingV10StoreWithCarryOutCreatesOneGeneratedEntryOnMainLine() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let report = SchemaV10.SubmittedReport(
            year: 2026,
            month: 8,
            submittedAt: Date(timeIntervalSince1970: 20_000),
            fieldServiceSeconds: 7_200,
            actualTotalSeconds: 7_200,
            submittedHours: 2,
            carriedOutSeconds: 1_200,
            categories: [
                SchemaV10.SubmittedReport.SubmittedCategory(
                    name: "Field Service",
                    iconName: "figure.walk",
                    typeRaw: TrackerType.main.rawValue,
                    actualSeconds: 7_200,
                    submittedHours: 2
                )
            ]
        )
        try makeV10Store(at: store.storeURL, submissions: [report])

        let container = try makeCurrentStore(at: store.storeURL)
        let context = container.mainContext
        let migratedReport = try #require(
            try context.fetch(FetchDescriptor<SubmittedReport>()).first
        )
        let mainLine = try #require(
            migratedReport.reportingLines.first { $0.type == .main }
        )
        let entries = try context.fetch(FetchDescriptor<SchemaV11.Entry>())
        let entry = try #require(entries.first)
        let expectedDate = YearMonth(year: 2026, month: 8).nextMonth().date()
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: entry.date
        )
        let createdAtComponents = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: entry.createdAt
        )

        #expect(mainLine.rounding == .transfer)
        #expect(mainLine.durationInSeconds == 8_400)
        #expect(entries.count == 1)
        #expect(entry.duration == 1_200)
        #expect(entry.date == expectedDate)
        #expect(entry.createdAt == expectedDate)
        #expect(dateComponents.year == 2026)
        #expect(dateComponents.month == 9)
        #expect(dateComponents.day == 1)
        #expect(createdAtComponents.year == 2026)
        #expect(createdAtComponents.month == 9)
        #expect(createdAtComponents.day == 1)
        #expect(entry.sourceSubmission === migratedReport)
        #expect(entry.sourceReportingLineID == "")
        #expect(entry.sourceReportYear == 2026)
        #expect(entry.sourceReportMonth == 8)
    }

    @Test
    func migratingV10StoreWithoutCarryOutCreatesNoGeneratedEntries() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let submissions = [
            SchemaV10.SubmittedReport(
                year: 2026,
                month: 6,
                submittedAt: Date(timeIntervalSince1970: 20_000),
                categories: [
                    SchemaV10.SubmittedReport.SubmittedCategory(
                        name: "June",
                        typeRaw: TrackerType.main.rawValue,
                        actualSeconds: 1_800,
                        submittedHours: 1
                    )
                ]
            ),
            SchemaV10.SubmittedReport(
                year: 2026,
                month: 7,
                submittedAt: Date(timeIntervalSince1970: 20_001),
                categories: [
                    SchemaV10.SubmittedReport.SubmittedCategory(
                        name: "July",
                        typeRaw: TrackerType.main.rawValue,
                        actualSeconds: 5_400,
                        submittedHours: 1
                    )
                ]
            ),
            SchemaV10.SubmittedReport(
                year: 2026,
                month: 8,
                submittedAt: Date(timeIntervalSince1970: 20_002),
                categories: [
                    SchemaV10.SubmittedReport.SubmittedCategory(
                        name: "August",
                        typeRaw: TrackerType.main.rawValue,
                        actualSeconds: 3_600,
                        submittedHours: 1
                    )
                ]
            ),
        ]
        try makeV10Store(at: store.storeURL, submissions: submissions)

        let container = try makeCurrentStore(at: store.storeURL)
        let context = container.mainContext
        let reports = try context.fetch(FetchDescriptor<SubmittedReport>())
        let entries = try context.fetch(FetchDescriptor<SchemaV11.Entry>())

        #expect(entries.isEmpty)

        let expectedRounding: [Int: RoundingRule?] = [
            6: .up,
            7: .down,
            8: nil,
        ]
        for (month, rounding) in expectedRounding {
            let report = try #require(reports.first { $0.year == 2026 && $0.month == month })
            let mainLine = try #require(
                report.reportingLines.first { $0.type == .main }
            )
            #expect(mainLine.rounding == rounding)
        }
    }

    @Test
    func migratingV10StoreSkipsSentinelReports() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let sentinel = SchemaV10.SubmittedReport(
            year: 2026,
            month: 8,
            submittedAt: .distantPast,
            carriedOutSeconds: 1_200,
            categories: [
                SchemaV10.SubmittedReport.SubmittedCategory(
                    name: "Sentinel",
                    typeRaw: TrackerType.main.rawValue,
                    actualSeconds: 3_600,
                    submittedHours: 1
                )
            ]
        )
        let real = SchemaV10.SubmittedReport(
            year: 2026,
            month: 9,
            submittedAt: Date(timeIntervalSince1970: 20_000),
            categories: [
                SchemaV10.SubmittedReport.SubmittedCategory(
                    name: "Field Service",
                    typeRaw: TrackerType.main.rawValue,
                    actualSeconds: 3_600,
                    submittedHours: 1
                )
            ]
        )
        try makeV10Store(at: store.storeURL, submissions: [sentinel, real])

        let container = try makeCurrentStore(at: store.storeURL)
        let context = container.mainContext
        let reports = try context.fetch(FetchDescriptor<SubmittedReport>())
        let entries = try context.fetch(FetchDescriptor<SchemaV11.Entry>())
        let migratedSentinel = try #require(
            reports.first { $0.year == 2026 && $0.month == 8 }
        )
        let migratedReal = try #require(
            reports.first { $0.year == 2026 && $0.month == 9 }
        )
        let realMainLine = try #require(
            migratedReal.reportingLines.first { $0.type == .main }
        )

        #expect(migratedSentinel.reportingLines.isEmpty)
        #expect(entries.isEmpty)
        #expect(realMainLine.durationInSeconds == 3_600)
        #expect(realMainLine.submittedHours == 1)
    }

    @Test
    func migratingV10StoreHandlesNilCategoriesSafely() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let report = SchemaV10.SubmittedReport(
            year: 2026,
            month: 8,
            submittedAt: Date(timeIntervalSince1970: 20_000)
        )
        report.categories = nil
        try makeV10Store(at: store.storeURL, submissions: [report])

        let container = try makeCurrentStore(at: store.storeURL)
        let migratedReport = try #require(
            try container.mainContext.fetch(FetchDescriptor<SubmittedReport>()).first
        )
        let mainLine = try #require(
            migratedReport.reportingLines.first { $0.type == .main }
        )

        #expect(mainLine.type == .main)
        #expect(mainLine.durationInSeconds == 0)
        #expect(mainLine.submittedHours == 0)
        #expect(mainLine.rounding == nil)
    }

    @Test
    func migratingV10StoreDoesNotFalselyFlagReceivingMonthAsUnreported() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let receivingMonth = YearMonth(year: 2026, month: 9)
        let receivingMonthStart = receivingMonth.date()
        let sendingReport = SchemaV10.SubmittedReport(
            year: 2026,
            month: 8,
            submittedAt: Date(timeIntervalSince1970: 20_000),
            carriedOutSeconds: 1_200,
            categories: [
                SchemaV10.SubmittedReport.SubmittedCategory(
                    name: "Field Service",
                    typeRaw: TrackerType.main.rawValue,
                    actualSeconds: 7_200,
                    submittedHours: 2
                )
            ]
        )
        let receivingReport = SchemaV10.SubmittedReport(
            year: receivingMonth.year,
            month: receivingMonth.month,
            submittedAt: Date(timeIntervalSince1970: 20_001),
            entriesClosedAt: receivingMonthStart,
            categories: [
                SchemaV10.SubmittedReport.SubmittedCategory(
                    name: "Field Service",
                    typeRaw: TrackerType.main.rawValue,
                    actualSeconds: 3_600,
                    submittedHours: 1
                )
            ]
        )
        try makeV10Store(at: store.storeURL, submissions: [sendingReport, receivingReport])

        let container = try makeCurrentStore(at: store.storeURL)
        let context = container.mainContext
        let reports = try context.fetch(FetchDescriptor<SubmittedReport>())
        let entries = try context.fetch(FetchDescriptor<SchemaV11.Entry>())
        let migratedReceivingReport = try #require(
            reports.first {
                $0.year == receivingMonth.year && $0.month == receivingMonth.month
            }
        )
        let generatedEntry = try #require(entries.first)

        #expect(entries.count == 1)
        #expect(generatedEntry.createdAt == receivingMonthStart)
        #expect(
            !ReportReminderSchedule.hasUnreportedEntries(
                report: migratedReceivingReport,
                entries: entries,
                month: receivingMonth
            )
        )
    }

    @Test
    func migratingV10StorePreservesUnrelatedReportFields() throws {
        let store = try TemporaryStore()
        defer { store.remove() }

        let firstSubmittedAt = Date(timeIntervalSince1970: 10_000)
        let submittedAt = Date(timeIntervalSince1970: 20_000)
        let entriesClosedAt = Date(timeIntervalSince1970: 9_000)
        let report = SchemaV10.SubmittedReport(
            year: 2026,
            month: 8,
            firstSubmittedAt: firstSubmittedAt,
            submittedAt: submittedAt,
            entriesClosedAt: entriesClosedAt,
            fieldServiceSeconds: 19_200,
            actualTotalSeconds: 20_400,
            submittedHours: 5,
            totalBibleStudies: 3,
            categories: [
                SchemaV10.SubmittedReport.SubmittedCategory(
                    name: "Field Service",
                    typeRaw: TrackerType.main.rawValue,
                    actualSeconds: 19_200,
                    submittedHours: 5
                )
            ]
        )
        try makeV10Store(at: store.storeURL, submissions: [report])

        let container = try makeCurrentStore(at: store.storeURL)
        let migratedReport = try #require(
            try container.mainContext.fetch(FetchDescriptor<SubmittedReport>()).first
        )

        #expect(migratedReport.year == 2026)
        #expect(migratedReport.month == 8)
        #expect(migratedReport.firstSubmittedAt == firstSubmittedAt)
        #expect(migratedReport.submittedAt == submittedAt)
        #expect(migratedReport.entriesClosedAt == entriesClosedAt)
        #expect(migratedReport.totalBibleStudies == 3)
        #expect(migratedReport.fieldServiceSeconds == 19_200)
        #expect(migratedReport.actualTotalSeconds == 20_400)
    }
	
	@Test
	func currentStoreRoundTripsSubmittedReportWithReportingLines() throws {
		let container = try InMemoryModelContainer.make()
		let context = container.mainContext
		
		let report = SubmittedReport(year: 2026, month: 8)
		report.reportingLines = [
			SubmittedReport.SubmittedReportingLine(
				typeRaw: TrackerType.main.rawValue,
				typeName: "",
				durationInSeconds: 10_800,
				submittedHours: 3,
				roundingRaw: RoundingRule.transfer.rawValue
			),
			SubmittedReport.SubmittedReportingLine(
				typeRaw: TrackerType.separate.rawValue,
				typeName: "Bethel",
				durationInSeconds: 1_800,
				submittedHours: 1,
				roundingRaw: RoundingRule.up.rawValue
			),
		]
		context.insert(report)
		try context.save()
		
		let fetched = try #require(try context.fetch(FetchDescriptor<SubmittedReport>()).first)
		
		#expect(fetched.reportingLines.count == 2)
		
		let mainLine = try #require(fetched.reportingLines.first { $0.type == .main })
		#expect(mainLine.id == "")
		#expect(mainLine.durationInSeconds == 10_800)
		#expect(mainLine.submittedHours == 3)
		#expect(mainLine.rounding == .transfer)
		
		let separateLine = try #require(fetched.reportingLines.first { $0.type == .separate })
		#expect(separateLine.id == "Bethel")
		#expect(separateLine.typeName == "Bethel")
		#expect(separateLine.durationInSeconds == 1_800)
		#expect(separateLine.rounding == .up)
	}
	
	@Test
	func currentStoreRoundTripsGeneratedEntrySourceLinkage() throws {
		let container = try InMemoryModelContainer.make()
		let context = container.mainContext
		
		let report = SubmittedReport(year: 2026, month: 8)
		context.insert(report)
		
		let entry = Entry(
			date: Date(timeIntervalSince1970: 100_000),
			duration: 1_200,
			tracker: nil,
			source: (submission: report, lineID: "")
		)
		context.insert(entry)
		try context.save()
		
		let fetchedEntry = try #require(try context.fetch(FetchDescriptor<Entry>()).first)
		let fetchedReport = try #require(try context.fetch(FetchDescriptor<SubmittedReport>()).first)
		
		#expect(fetchedEntry.sourceSubmission?.persistentModelID == fetchedReport.persistentModelID)
		#expect(fetchedEntry.sourceReportingLineID == "")
		#expect(fetchedEntry.sourceReportYear == 2026)
		#expect(fetchedEntry.sourceReportMonth == 8)
		#expect(fetchedReport.generatedEntries?.map(\.persistentModelID) == [fetchedEntry.persistentModelID])
	}
	
	@Test
	func currentStoreLeavesSourceFieldsNilForOrdinaryEntries() throws {
		let container = try InMemoryModelContainer.make()
		let context = container.mainContext
		
		let entry = Entry(date: Date(), duration: 3_600, tracker: nil)
		context.insert(entry)
		try context.save()
		
		let fetched = try #require(try context.fetch(FetchDescriptor<Entry>()).first)
		
		#expect(fetched.sourceSubmission == nil)
		#expect(fetched.sourceReportingLineID == nil)
		#expect(fetched.sourceReportYear == nil)
		#expect(fetched.sourceReportMonth == nil)
	}
	
	@Test
	func currentStoreNullifiesSourceSubmissionWhenReportDeleted() throws {
		let container = try InMemoryModelContainer.make()
		let context = container.mainContext
		
		let report = SubmittedReport(year: 2026, month: 8)
		context.insert(report)
		let entry = Entry(
			date: Date(),
			duration: 1_200,
			tracker: nil,
			source: (submission: report, lineID: "")
		)
		context.insert(entry)
		try context.save()
		
		context.delete(report)
		try context.save()
		
		let fetched = try #require(try context.fetch(FetchDescriptor<Entry>()).first)
		
		#expect(fetched.sourceSubmission == nil)      // relationship nullified
		#expect(fetched.sourceReportingLineID == "")   // scalar snapshot survives
		#expect(fetched.sourceReportYear == 2026)
		#expect(fetched.sourceReportMonth == 8)
	}
	
	@Test
	func migratesFullChainFromV1ToCurrentSchemaWithoutThrowing() throws {
		let store = try TemporaryStore()
		defer { store.remove() }
		
		try makeV1Store(
			at: store.storeURL,
			entries: [
				SchemaV1.Entry(
					type: .fieldService,
					timestamp: Date(timeIntervalSince1970: 1_700_000_000),
					duration: 3_600
				),
				SchemaV1.Entry(
					type: .bethel,
					timestamp: Date(timeIntervalSince1970: 1_700_100_000),
					duration: 1_800
				),
			]
		)
		
		let container = try makeCurrentStore(at: store.storeURL)
		let context = container.mainContext
		
		let entries = try context.fetch(FetchDescriptor<Entry>())
		let reports = try context.fetch(FetchDescriptor<SubmittedReport>())
		
		// The chain shouldn't throw, and the two seeded entries should survive
		// every stage (V1→V2 recreates them as SchemaV2.Entry; every later
		// stage is a lightweight or non-destructive custom migration for Entry).
		#expect(entries.count == 2)
		#expect(entries.map(\.duration).sorted() == [1_800, 3_600])
		
		// V8→V9 backfills one sentinel SubmittedReport per month that has
		// entries — both seeded entries fall in the same month here, so expect one.
		#expect(reports.count == 1)
		#expect(reports.first?.submittedAt == .distantPast)
	}
	
	private func makeV1Store(
		at url: URL,
		entries: [SchemaV1.Entry] = []
	) throws {
		let schema = Schema(versionedSchema: SchemaV1.self)
		let configuration = ModelConfiguration(
			schema: schema,
			url: url,
			cloudKitDatabase: .none
		)
		let container = try ModelContainer(for: schema, configurations: [configuration])
		let context = container.mainContext
		
		entries.forEach(context.insert)
		
		try context.save()
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

    private func makeV10Store(
        at url: URL,
        submissions: [SchemaV10.SubmittedReport] = []
    ) throws {
        let schema = Schema(versionedSchema: SchemaV10.self)
        let configuration = ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

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
