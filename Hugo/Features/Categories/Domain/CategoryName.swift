import Foundation

nonisolated enum CategoryName {
    /// The name to keep after editing: the trimmed edit, or the original
    /// name when the edit is empty.
    static func committed(edited: String, original: String) -> String {
        let trimmed = edited.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? original : trimmed
    }
}
