import Foundation
import OSLog
import SwiftData

/// Merges rows that CloudKit sync duplicated. CloudKit cannot enforce unique
/// values, so two devices that each created the same logical row (for example
/// the seeded default category) end up with two copies after sync.
///
/// Every device runs this independently, so each rule must pick the same
/// survivor on every device using synced attributes only.
@MainActor
struct SyncDeduplicator {
    private static let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Sync")
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Runs every merge and logs failures. Safe to call often.
    func run() {
        do {
            let removed = try mergeDuplicateCategories()
            if removed > 0 {
                Self.logger.info("Merged \(removed) duplicate categories")
            }
        } catch {
            Self.logger.error("Deduplication failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns the number of deleted duplicates.
    @discardableResult
    func mergeDuplicateCategories() throws -> Int {
        let trackers = try context.fetch(FetchDescriptor<Tracker>())
        var removed = 0
        var changed = false
        var deletedIDs = Set<PersistentIdentifier>()

        for group in Dictionary(grouping: trackers, by: \.id).values where group.count > 1 {
            let sorted = group.sorted(by: Self.survivorPrecedes)
            // The first two are indistinguishable: two devices could each keep
            // a different copy and together delete both.
            guard Self.survivorPrecedes(sorted[0], sorted[1]) else { continue }

            let survivor = sorted[0]
            for loser in sorted.dropFirst() {
                for entry in Array(loser.entries ?? []) {
                    entry.tracker = survivor
                    entry.refreshStoredTracker()
                }
                if loser.isDefault { survivor.isDefault = true }
                deletedIDs.insert(loser.persistentModelID)
                context.delete(loser)
                removed += 1
                changed = true
            }
        }

        let defaults =
            trackers
            .filter { !deletedIDs.contains($0.persistentModelID) && $0.isDefault }
            .sorted(by: Self.survivorPrecedes)
        for extra in defaults.dropFirst() {
            extra.isDefault = false
            changed = true
        }

        if changed { try context.save() }
        return removed
    }

    /// Earliest `createdAt` wins; ties fall back to the remaining synced fields.
    private static func survivorPrecedes(_ a: Tracker, _ b: Tracker) -> Bool {
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        if a.name != b.name { return a.name < b.name }
        if a.iconName != b.iconName { return a.iconName < b.iconName }
        if a.type.rawValue != b.type.rawValue { return a.type.rawValue < b.type.rawValue }
        if a.hue != b.hue { return a.hue < b.hue }
        if a.sat != b.sat { return a.sat < b.sat }
        return a.bri < b.bri
    }
}
