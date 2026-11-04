import Foundation

/// Time per category for a set of entries. Every screen that splits time by
/// category uses this, so an entry lands in the same row everywhere.
nonisolated struct CategoryTotal: Identifiable {
    /// The live category's UUID string, `stored:<name>|<icon>|<type>` for a
    /// category snapshot with no live match, or `untracked`.
    let id: String
    let name: String
    let iconName: String
    /// Nil only for untracked time.
    let type: TrackerType?
    let duration: TimeInterval
    /// The live category the row belongs to, if any.
    let trackerID: UUID?
}

nonisolated enum CategoryTotals {
    /// Groups `entries` by category. An entry without a live category joins a
    /// live one when it can:
    /// - carried-in main time joins the default main category;
    /// - any other category snapshot joins the live category with the same
    ///   name and type.
    /// `trackers` are the live categories to match against; categories attached
    /// to `entries` are always considered as well. Rows are sorted by
    /// duration (longest first), then name, then id.
    static func rows(entries: [Entry], trackers: [Tracker] = [], locale: Locale = .current) -> [CategoryTotal] {
        let candidates = liveCandidates(entries: entries, trackers: trackers)
        let defaultMain = candidates.first { $0.isDefault && $0.type == .main }

        var totals: [String: CategoryTotal] = [:]
        for entry in entries {
            let category = entry.resolvedCategory(locale: locale)
            let row: CategoryTotal
            if category.trackerID != nil {
                row = CategoryTotal(
                    id: category.key, name: category.name, iconName: category.iconName, type: category.type,
                    duration: 0, trackerID: category.trackerID)
            } else if category.type == nil {
                row = CategoryTotal(
                    id: category.key, name: category.name, iconName: category.iconName, type: nil,
                    duration: 0, trackerID: nil)
            } else if entry.isCarriedIn, category.type == .main, let defaultMain {
                row = liveRow(defaultMain)
            } else if let match = candidates.first(where: { $0.name == category.name && $0.type == category.type }) {
                row = liveRow(match)
            } else {
                row = CategoryTotal(
                    id: category.key, name: category.name, iconName: category.iconName, type: category.type,
                    duration: 0, trackerID: nil)
            }
            let existing = totals[row.id] ?? row
            totals[row.id] = CategoryTotal(
                id: existing.id, name: existing.name, iconName: existing.iconName, type: existing.type,
                duration: existing.duration + entry.duration, trackerID: existing.trackerID)
        }

        return totals.values.sorted {
            if $0.duration != $1.duration { return $0.duration > $1.duration }
            if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return $0.id < $1.id
        }
    }

    private static func liveRow(_ tracker: Tracker) -> CategoryTotal {
        CategoryTotal(
            id: tracker.id.uuidString, name: tracker.name, iconName: tracker.iconName, type: tracker.type,
            duration: 0, trackerID: tracker.id)
    }

    /// `trackers` plus every category attached to `entries`, without duplicates,
    /// in a deterministic order: default first, then oldest, then by id.
    private static func liveCandidates(entries: [Entry], trackers: [Tracker]) -> [Tracker] {
        var byID: [UUID: Tracker] = [:]
        for tracker in trackers + entries.compactMap(\.tracker) { byID[tracker.id] = tracker }
        return byID.values.sorted {
            if $0.isDefault != $1.isDefault { return $0.isDefault }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
