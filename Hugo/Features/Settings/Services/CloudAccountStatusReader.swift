import CloudKit
import Foundation

/// Reads whether this device's iCloud account can be used. Returns `.unknown`
/// in the unit-test host: `CKContainer.default()` raises an Objective-C
/// exception there that would end the test run (see `CloudKitTrackerLookup`).
enum CloudAccountStatusReader {
    static func read() async -> CloudAccountState {
        if isRunningTests { return .unknown }
        do {
            switch try await CKContainer.default().accountStatus() {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .temporarilyUnavailable: return .temporarilyUnavailable
            case .couldNotDetermine: return .unknown
            @unknown default: return .unknown
            }
        } catch {
            return .unknown
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
