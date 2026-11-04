import Foundation
import SwiftData

@MainActor
struct CategoryDeletionService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Deletes a category. Each entry's and plan's snapshot is refreshed first,
    /// so they keep the category's latest name and type.
    func delete(_ tracker: Tracker) throws {
        for entry in tracker.entries ?? [] {
            entry.refreshStoredTracker()
        }
        let trackerID = tracker.id
        for plan in try context.fetch(FetchDescriptor<Plan>()) where plan.categoryID == trackerID {
            plan.setCategory(tracker)
        }
        context.delete(tracker)
        try context.save()
    }
}
