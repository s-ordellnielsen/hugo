import CloudKit
import Foundation

protocol CloudTrackerLookup: Sendable {
    func hasAnyTracker() async throws -> Bool
}

struct CloudKitTrackerLookup: CloudTrackerLookup, Sendable {
    func hasAnyTracker() async throws -> Bool {
        let database = CKContainer.default().privateCloudDatabase
        let query = CKQuery(recordType: "CD_Tracker", predicate: NSPredicate(value: true))
        let (results, _) = try await database.records(matching: query)
        return results.contains { (_, result) in
            if case .success = result { return true }
            return false
        }
    }
}
