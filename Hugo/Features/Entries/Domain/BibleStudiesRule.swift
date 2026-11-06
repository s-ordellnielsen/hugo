import Foundation

/// When an entry offers Bible studies. A category can turn them off, but an
/// entry that already has Bible studies keeps its control, so Hugo never hides
/// a count the user entered.
nonisolated enum BibleStudiesRule {
    static func showsControl(categoryAllows: Bool, count: Int) -> Bool {
        categoryAllows || count > 0
    }

    /// The count to save for a new entry: 0 when its category turns Bible studies off.
    static func savedCount(_ count: Int, categoryAllows: Bool) -> Int {
        categoryAllows ? max(0, count) : 0
    }
}
