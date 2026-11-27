import Foundation
import OSLog
import SwiftData

enum WidgetState: Equatable, Sendable {
    case ready(MonthProgress)
    /// The placeholder: the app has not moved the store, or has not run this build.
    case unavailable
}

/// Reads the App Group store for the widget. Read-only: it never relocates, copies, migrates,
/// deletes or creates anything. Anything missing or unexpected gives `.unavailable`.
struct WidgetStoreReader {
    private static let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Widget")

    private let groupDirectory: URL?
    private let settingsSuite: UserDefaults?
    private let fileManager: FileManager

    init(groupDirectory: URL?, settingsSuite: UserDefaults?, fileManager: FileManager = .default) {
        self.groupDirectory = groupDirectory
        self.settingsSuite = settingsSuite
        self.fileManager = fileManager
    }

    static func production() -> WidgetStoreReader {
        WidgetStoreReader(
            groupDirectory: StoreRelocator.productionGroupDirectory(),
            settingsSuite: WidgetSettingsMirror.appGroupSuite())
    }

    func load(now: Date, calendar: Calendar) -> WidgetState {
        guard let groupDirectory else { return .unavailable }
        guard markerAllowsReading(in: groupDirectory) else { return .unavailable }
        let storeURL = groupDirectory.appending(path: StoreRelocator.storeFileName)
        guard fileManager.fileExists(atPath: storeURL.path) else { return .unavailable }
        guard
            let settings = WidgetSettingsMirror.read(from: settingsSuite),
            settings.storeSchemaVersion == WidgetSettings.schemaVersionString()
        else { return .unavailable }

        do {
            let progress = try fetchProgress(storeURL: storeURL, settings: settings, now: now, calendar: calendar)
            return .ready(progress)
        } catch {
            Self.logger.error("Widget could not read the store: \(error.localizedDescription, privacy: .public)")
            return .unavailable
        }
    }

    private func markerAllowsReading(in groupDirectory: URL) -> Bool {
        let markerURL = groupDirectory.appending(path: StoreRelocator.markerFileName)
        guard let text = try? String(contentsOf: markerURL, encoding: .utf8) else { return false }
        let state = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return state == StoreRelocator.copiedState || state == StoreRelocator.confirmedState
    }

    /// Opens the store without migration and without saving, then reads the month the same way the Overview does.
    private func fetchProgress(
        storeURL: URL, settings: WidgetSettings, now: Date, calendar: Calendar
    ) throws -> MonthProgress {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let configuration = ModelConfiguration(
            schema: schema, url: storeURL, allowsSave: false, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let range = now.yearMonth(using: calendar).dateRange(calendar: calendar)
        let start = range.lowerBound
        let end = range.upperBound
        let entries = try context.fetch(
            FetchDescriptor<Entry>(predicate: #Predicate<Entry> { $0.date >= start && $0.date < end }))
        let plans = try context.fetch(
            FetchDescriptor<Plan>(predicate: #Predicate<Plan> { $0.date >= start && $0.date < end }))
        let plannedSeconds = plans.reduce(0) { $0 + max($1.duration, 0) }

        return MonthProgress.make(
            entries: entries, plannedSeconds: plannedSeconds, settings: settings, now: now, calendar: calendar)
    }
}
