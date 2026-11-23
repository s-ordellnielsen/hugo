import SwiftData
import SwiftUI

/// The pushes from the category list. Carries the tracker's identifier only.
nonisolated enum CategoryRoute: Hashable {
    case detail(PersistentIdentifier)
}

/// Shows one category. The tracker is looked up again when the page is pushed,
/// so a category that CloudKit removed shows an empty state instead of a stale page.
struct CategoryRouteView: View {
    @Query private var trackers: [Tracker]
    private let id: PersistentIdentifier

    init(id: PersistentIdentifier) {
        self.id = id
    }

    var body: some View {
        if let tracker = trackers.first(where: { $0.persistentModelID == id }) {
            CategoryDetailView(tracker: tracker)
        } else {
            ContentUnavailableView("common.error", systemImage: "exclamationmark.triangle")
        }
    }
}
