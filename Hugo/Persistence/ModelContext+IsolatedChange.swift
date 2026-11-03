import SwiftData

extension ModelContext {
    /// Saves any pending edits first, then applies `changes` and saves again.
    /// If applying or saving `changes` fails, only `changes` are rolled back,
    /// because everything else was already saved.
    func performIsolatedChange(_ changes: () throws -> Void) throws {
        if hasChanges { try save() }
        do {
            try changes()
            if hasChanges { try save() }
        } catch {
            rollback()
            throw error
        }
    }
}
