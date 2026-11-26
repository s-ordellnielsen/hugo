import Foundation

/// What Duplicate fills Add Entry with: the entry's duration, category and
/// start time. The date is left to Add Entry, which uses today, and Bible
/// studies are not copied, since they belong to one conversation.
nonisolated struct EntryDuplicateSeed: Equatable, Identifiable, Sendable {
    /// Lets a sheet present the seed. Not part of equality.
    let id = UUID()
    let duration: TimeInterval
    let categoryID: UUID?
    /// Minutes after midnight of the entry's start, in `calendar`'s time zone.
    let startMinute: Int

    init(entryDate: Date, duration: TimeInterval, categoryID: UUID?, calendar: Calendar = .current) {
        self.duration = max(0, duration)
        self.categoryID = categoryID
        let parts = calendar.dateComponents([.hour, .minute], from: entryDate)
        self.startMinute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.duration == rhs.duration && lhs.categoryID == rhs.categoryID && lhs.startMinute == rhs.startMinute
    }
}
