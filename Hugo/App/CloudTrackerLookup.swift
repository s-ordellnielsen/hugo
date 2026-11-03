import CloudKit
import Foundation

protocol CloudTrackerLookup: Sendable {
    func hasAnyTracker() async throws -> Bool
}

struct CloudKitTrackerLookup: CloudTrackerLookup, Sendable {
    /// True when the user's private database already holds the zone that
    /// SwiftData's CloudKit sync creates, meaning another device or an earlier
    /// install has synced Hugo data that will arrive shortly.
    func hasAnyTracker() async throws -> Bool {
        // `CKContainer.default()` throws an *Objective-C* exception (not a
        // Swift error) when no iCloud account is present — e.g. an unsigned
        // simulator — which Swift `do/catch` cannot intercept. That trap killed
        // the whole app during bootstrap, taking the unit-test host down with
        // it before any test could run. Never touch CloudKit from the test
        // runner; treat the cloud as empty there.
        if Self.isRunningTests { return false }

        let database = CKContainer.default().privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        do {
            _ = try await database.recordZone(for: zoneID)
            return true
        } catch {
            // No zone (a new iCloud user), no account, or offline: seed locally.
            // SyncDeduplicator merges any copy that sync brings in later.
            return false
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
