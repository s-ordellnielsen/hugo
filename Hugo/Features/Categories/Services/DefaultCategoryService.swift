import Foundation
import SwiftData

@MainActor
struct DefaultCategoryService {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Makes `tracker` the default. `nil` clears the default.
    func setDefault(_ tracker: Tracker?) {
        userDefaults.set(tracker?.id.uuidString ?? "", forKey: UserDefaultsKeys.defaultCategoryID)
    }

    /// Runs once per device. Copies the old `isDefault` row into the setting
    /// unless the setting already has a value (for example from another device).
    func migrateLegacyDefault(context: ModelContext) throws {
        guard !userDefaults.bool(forKey: UserDefaultsKeys.hasMigratedDefaultCategory) else { return }
        if userDefaults.object(forKey: UserDefaultsKeys.defaultCategoryID) == nil {
            let legacy = try context.fetch(FetchDescriptor<Tracker>(predicate: #Predicate { $0.isDefault }))
            if let survivor = legacy.min(by: SyncDeduplicator.survivorPrecedes) {
                userDefaults.set(survivor.id.uuidString, forKey: UserDefaultsKeys.defaultCategoryID)
            }
        }
        userDefaults.set(true, forKey: UserDefaultsKeys.hasMigratedDefaultCategory)
    }
}
