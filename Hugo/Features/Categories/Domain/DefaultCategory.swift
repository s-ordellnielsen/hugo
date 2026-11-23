import Foundation

/// Decides which category is the default, from the stored id.
nonisolated enum DefaultCategory {
    /// `storedID` is the raw value of `UserDefaultsKeys.defaultCategoryID`.
    static func resolve(storedID: String?, in categories: [Tracker]) -> Tracker? {
        if storedID == "" { return nil }
        if let storedID, let id = UUID(uuidString: storedID),
            let match = categories.first(where: { $0.id == id })
        {
            return match
        }
        return
            categories
            .filter { $0.type == .main }
            .min {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }
}
