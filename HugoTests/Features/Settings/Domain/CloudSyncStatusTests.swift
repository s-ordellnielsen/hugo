import CloudKit
import Foundation
import Testing

@testable import Hugo

struct CloudSyncStatusTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func accountProblemsWinOverEverythingElse() {
        #expect(
            CloudSyncStatus.make(account: .noAccount, isSyncing: true, failure: .offline, lastSuccess: date)
                == .signedOut)
        #expect(
            CloudSyncStatus.make(account: .restricted, isSyncing: false, failure: nil, lastSuccess: nil) == .restricted)
    }

    @Test
    func aFailureWinsOverSyncing() {
        #expect(
            CloudSyncStatus.make(account: .available, isSyncing: true, failure: .storageFull, lastSuccess: date)
                == .storageFull)
        #expect(
            CloudSyncStatus.make(account: .available, isSyncing: false, failure: .offline, lastSuccess: date)
                == .offline)
        #expect(
            CloudSyncStatus.make(account: .available, isSyncing: false, failure: .other, lastSuccess: date) == .problem)
    }

    @Test
    func syncingThenUpToDate() {
        #expect(CloudSyncStatus.make(account: .available, isSyncing: true, failure: nil, lastSuccess: date) == .syncing)
        #expect(
            CloudSyncStatus.make(account: .available, isSyncing: false, failure: nil, lastSuccess: date)
                == .upToDate(lastSync: date))
        #expect(
            CloudSyncStatus.make(account: .unknown, isSyncing: false, failure: nil, lastSuccess: nil)
                == .upToDate(lastSync: nil))
    }

    @Test
    func temporarilyUnavailableAccountIsAProblem() {
        #expect(
            CloudSyncStatus.make(account: .temporarilyUnavailable, isSyncing: false, failure: nil, lastSuccess: date)
                == .problem)
    }

    @Test
    func noNetworkShowsOfflineEvenWhileAnExportWaits() {
        #expect(
            CloudSyncStatus.make(account: .available, isOnline: false, isSyncing: true, failure: nil, lastSuccess: date)
                == .offline)
        #expect(
            CloudSyncStatus.make(account: .noAccount, isOnline: false, isSyncing: false, failure: nil, lastSuccess: nil)
                == .signedOut)
    }

    @Test
    func failuresComeFromCloudKitErrorCodes() {
        #expect(CloudSyncFailure(ckErrorCode: CKError.Code.notAuthenticated.rawValue) == .signedOut)
        #expect(CloudSyncFailure(ckErrorCode: CKError.Code.quotaExceeded.rawValue) == .storageFull)
        #expect(CloudSyncFailure(ckErrorCode: CKError.Code.networkUnavailable.rawValue) == .offline)
        #expect(CloudSyncFailure(ckErrorCode: CKError.Code.networkFailure.rawValue) == .offline)
        #expect(CloudSyncFailure(ckErrorCode: CKError.Code.serverRejectedRequest.rawValue) == .other)
        #expect(CloudSyncFailure(ckErrorCode: nil) == .other)
    }
}
