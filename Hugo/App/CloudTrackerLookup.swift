import CloudKit
import Foundation

protocol CloudTrackerLookup: Sendable {
    func hasAnyTracker() async throws -> Bool
}

struct CloudKitTrackerLookup: CloudTrackerLookup, Sendable {
    func hasAnyTracker() async throws -> Bool {
        // `CKContainer.default()` throws an *Objective-C* exception (not a
        // Swift error) when no iCloud account is present — e.g. an unsigned
        // simulator — which Swift `do/catch` cannot intercept. That trap killed
        // the whole app during bootstrap, taking the unit-test host down with
        // it before any test could run. Never touch CloudKit from the test
        // runner; treat the cloud as empty there.
        if Self.isRunningTests { return false }

        let database = CKContainer.default().privateCloudDatabase
        let query = CKQuery(recordType: "CD_Tracker", predicate: NSPredicate(value: true))
        do {
            let (results, _) = try await database.records(matching: query)
            return results.contains { (_, result) in
                if case .success = result { return true }
                return false
            }
        } catch {
            // A signed-out or offline device must not break first-run seeding;
            // fall back to local defaults instead of failing the bootstrap.
            return false
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
