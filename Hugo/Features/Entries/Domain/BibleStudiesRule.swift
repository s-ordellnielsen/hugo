import Foundation

/// When an entry offers Bible studies. A separate category doesn't take new
/// ones, but an entry that already has Bible studies keeps its control, so Hugo
/// never hides a count the user entered.
nonisolated enum BibleStudiesRule {
    static func showsControl(categoryAllows: Bool, count: Int) -> Bool {
        categoryAllows || count > 0
    }

    /// The count to save for a new entry: 0 in a separate category.
    static func savedCount(_ count: Int, categoryAllows: Bool) -> Int {
        categoryAllows ? max(0, count) : 0
    }
}
