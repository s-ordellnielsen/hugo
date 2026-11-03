import Foundation

/// The category an entry counts toward. Resolved from the live `Tracker`
/// first, then the `storedTracker` snapshot (kept so entries survive their
/// category being deleted), then an "untracked" fallback.
nonisolated struct EntryCategory: Hashable {
    /// Grouping key: the tracker's UUID string, `stored:<name>|<icon>|<type>`
    /// for a snapshot, or `untracked`.
    let key: String
    let name: String
    let iconName: String
    /// `nil` only for an untracked entry.
    let type: TrackerType?
    /// Set only when the live tracker is attached.
    let trackerID: UUID?
}

extension Entry {
    nonisolated func resolvedCategory(locale: Locale = .current) -> EntryCategory {
        if let tracker {
            return EntryCategory(
                key: tracker.id.uuidString, name: tracker.name, iconName: tracker.iconName,
                type: tracker.type, trackerID: tracker.id)
        }
        if let snapshot = storedTracker {
            return EntryCategory(
                key: "stored:\(snapshot.name)|\(snapshot.icon)|\(snapshot.type.rawValue)",
                name: snapshot.name, iconName: snapshot.icon, type: snapshot.type, trackerID: nil)
        }
        return EntryCategory(
            key: "untracked", name: String(localized: "entry.untracked", locale: locale),
            iconName: "questionmark.circle", type: nil, trackerID: nil)
    }
}

extension Entry {
    /// Copies the live tracker's current name, icon and type into the snapshot.
    /// Does nothing when no tracker is attached.
    func refreshStoredTracker() {
        guard let tracker else { return }
        storedTracker = EntryTracker(name: tracker.name, icon: tracker.iconName, type: tracker.type)
    }
}
