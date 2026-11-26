import SwiftData
import SwiftUI

extension View {
    /// Edit, Duplicate and Delete Entry on long press or right-click. Edit runs
    /// `onEdit` and is left out when it is nil. Duplicate opens Add Entry filled
    /// from the entry, dated today. Delete asks for the same confirmation as the
    /// entry's own More menu. Do not use it on carried-in entries.
    func entryContextMenu(_ entry: Entry, onEdit: (() -> Void)? = nil) -> some View {
        modifier(EntryContextMenu(entry: entry, onEdit: onEdit))
    }
}

private struct EntryContextMenu: ViewModifier {
    @Environment(\.modelContext) private var context

    let entry: Entry
    let onEdit: (() -> Void)?

    @State private var duplicateSeed: EntryDuplicateSeed?
    @State private var isConfirmingDelete = false
    @State private var deletionError: String?

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if let onEdit {
                    Button("entry.action.edit", systemImage: "pencil", action: onEdit)
                }
                Button("entry.action.duplicate", systemImage: "plus.square.on.square") {
                    duplicateSeed = EntryDuplicateSeed(
                        entryDate: entry.date, duration: entry.duration, categoryID: entry.tracker?.id)
                }
                Divider()
                Button("entry.delete.label", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
            .confirmationDialog(
                "entry.delete.confirmation.label",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("entry.delete.confirmation.action", role: .destructive, action: delete)
            } message: {
                Text("entry.delete.confirmation.message")
            }
            .sheet(item: $duplicateSeed) { seed in
                AddEntryView(
                    seededDuration: seed.duration,
                    preferredTrackerID: seed.categoryID,
                    seededStartMinute: seed.startMinute)
            }
            .errorAlert(message: $deletionError)
    }

    private func delete() {
        do {
            try context.performIsolatedChange { context.delete(entry) }
        } catch {
            deletionError = error.localizedDescription
        }
    }
}
