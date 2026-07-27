import Foundation
import SwiftData

@MainActor
struct DefaultCategoryService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func setDefault(_ tracker: Tracker?) throws {
        let defaults = try context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.isDefault }))
        defaults.forEach { $0.isDefault = false }
        tracker?.isDefault = true
        try context.save()
    }

    func clearDefault() throws {
        try setDefault(nil)
    }
}
