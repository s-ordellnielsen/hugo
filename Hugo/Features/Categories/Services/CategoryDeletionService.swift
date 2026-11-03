import Foundation
import SwiftData

@MainActor
struct CategoryDeletionService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Deletes a category. Each entry's snapshot is refreshed first, so the
    /// entry keeps counting toward the category's latest name and type.
    func delete(_ tracker: Tracker) throws {
        for entry in tracker.entries ?? [] {
            entry.refreshStoredTracker()
        }
        context.delete(tracker)
        try context.save()
    }
}
