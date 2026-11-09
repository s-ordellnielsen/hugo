import Foundation

/// A hand-picked category color. The row in Add Category and the category
/// screen offers Automatic first, then these, in this order.
nonisolated struct CategoryColorPreset: Identifiable, Sendable {
    let id: String
    let name: LocalizedStringResource
    let color: CategoryColor

    /// No red (it reads as "behind plan") and no yellow (too faint as a thin
    /// bar in light mode). Teal is Automatic, so no preset looks like it.
    static let all: [CategoryColorPreset] = [
        CategoryColorPreset(id: "blue", name: "tracker.color.preset.blue", color: CategoryColor(hue: 0.60, tone: 0.55)),
        CategoryColorPreset(
            id: "indigo", name: "tracker.color.preset.indigo", color: CategoryColor(hue: 0.68, tone: 0.50)),
        CategoryColorPreset(
            id: "purple", name: "tracker.color.preset.purple", color: CategoryColor(hue: 0.78, tone: 0.50)),
        CategoryColorPreset(id: "pink", name: "tracker.color.preset.pink", color: CategoryColor(hue: 0.90, tone: 0.45)),
        CategoryColorPreset(
            id: "orange", name: "tracker.color.preset.orange", color: CategoryColor(hue: 0.07, tone: 0.45)),
        CategoryColorPreset(
            id: "green", name: "tracker.color.preset.green", color: CategoryColor(hue: 0.37, tone: 0.55)),
    ]

    /// The preset whose hue and tone are each within 0.001 of `color`.
    static func matching(_ color: CategoryColor?) -> CategoryColorPreset? {
        guard let color else { return nil }
        return all.first { preset in
            abs(preset.color.hue - color.hue) <= 0.001 && abs(preset.color.tone - color.tone) <= 0.001
        }
    }

    /// The color a new category starts with: the preset used by the fewest
    /// existing categories, first in `all` on a tie. With any preset unused,
    /// that is the first unused one. Automatic and custom colors count for no
    /// preset.
    static func suggested(forNewCategoryAmong existing: [CategoryColor?]) -> CategoryColor {
        var uses = Dictionary(uniqueKeysWithValues: all.map { ($0.id, 0) })
        for color in existing {
            if let preset = matching(color) {
                uses[preset.id, default: 0] += 1
            }
        }
        var least = all[0]
        for preset in all where uses[preset.id, default: 0] < uses[least.id, default: 0] {
            least = preset
        }
        return least.color
    }
}
