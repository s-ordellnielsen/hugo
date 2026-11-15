import CloudKit
import Foundation
import Testing

@testable import Hugo

@MainActor
struct CloudSyncMonitorTests {
    private let defaults = UserDefaults(suiteName: "CloudSyncMonitorTests-\(UUID().uuidString)")!
    private let end = Date(timeIntervalSince1970: 1_800_000_000)

    private func monitor(account: CloudAccountState = .available) -> CloudSyncMonitor {
        CloudSyncMonitor(defaults: defaults, readAccount: { account })
    }

    @Test
    func aRunningEventShowsSyncingUntilItEnds() {
        let monitor = monitor()
        let id = UUID()

        monitor.record(id: id, endDate: nil, succeeded: false, errorCode: nil)
        #expect(monitor.status == .syncing)

        monitor.record(id: id, endDate: end, succeeded: true, errorCode: nil)
        #expect(monitor.status == .upToDate(lastSync: end))
    }

    @Test
    func theLastSuccessSurvivesARelaunch() {
        monitor().record(id: UUID(), endDate: end, succeeded: true, errorCode: nil)

        #expect(monitor().lastSuccess == end)
    }

    @Test
    func aFailureShowsUntilTheNextSuccess() {
        let monitor = monitor()

        monitor.record(id: UUID(), endDate: end, succeeded: false, errorCode: CKError.Code.quotaExceeded.rawValue)
        #expect(monitor.status == .storageFull)

        monitor.record(id: UUID(), endDate: end.addingTimeInterval(60), succeeded: true, errorCode: nil)
        #expect(monitor.status == .upToDate(lastSync: end.addingTimeInterval(60)))
    }

    @Test
    func losingTheNetworkShowsOfflineAndComingBackShowsSyncingAgain() {
        let monitor = monitor()
        monitor.record(id: UUID(), endDate: nil, succeeded: false, errorCode: nil)

        monitor.setOnline(false)
        #expect(monitor.status == .offline)

        monitor.setOnline(true)
        #expect(monitor.status == .syncing)
    }

    @Test
    func refreshingTheAccountCanShowSignedOut() async {
        let monitor = monitor(account: .noAccount)

        await monitor.refreshAccount()

        #expect(monitor.status == .signedOut)
    }
}
