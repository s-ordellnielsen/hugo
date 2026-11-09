import Foundation

extension Tracker {
    /// The category color, or nil for Automatic.
    nonisolated var categoryColor: CategoryColor? {
        CategoryColor(storedHue: colorHue, storedTone: colorTone)
    }

    /// Stores `color`, or clears both fields for Automatic.
    func setCategoryColor(_ color: CategoryColor?) {
        colorHue = color?.hue
        colorTone = color?.tone
    }
}
