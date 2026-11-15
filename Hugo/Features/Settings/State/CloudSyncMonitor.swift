import Foundation
import Observation

/// Follows this device's iCloud sync for the iCloud row in Settings. The app
/// feeds it every sync event (`record`), starts it watching the network at
/// launch (`startWatchingNetwork`), and Settings asks it to read the
/// account status when it appears (`refreshAccount`). The time of the last
/// successful sync survives relaunches; everything else lives in memory.
@MainActor
@Observable
final class CloudSyncMonitor {
    private(set) var account: CloudAccountState = .unknown
    private(set) var lastSuccess: Date?
    private(set) var failure: CloudSyncFailure?
    private(set) var isOnline = true
    private var running: Set<UUID> = []
    @ObservationIgnored private var networkWatcher: NetworkPathWatcher?

    private let defaults: UserDefaults
    private let readAccount: () async -> CloudAccountState

    init(
        defaults: UserDefaults = .standard,
        readAccount: @escaping () async -> CloudAccountState = CloudAccountStatusReader.read
    ) {
        self.defaults = defaults
        self.readAccount = readAccount
        let stored = defaults.double(forKey: UserDefaultsKeys.cloudSyncLastSuccess)
        lastSuccess = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    var status: CloudSyncStatus {
        CloudSyncStatus.make(
            account: account, isOnline: isOnline, isSyncing: !running.isEmpty, failure: failure,
            lastSuccess: lastSuccess)
    }

    /// Records a sync event. `endDate` is nil while the event runs.
    func record(id: UUID, endDate: Date?, succeeded: Bool, errorCode: Int?) {
        guard let endDate else {
            running.insert(id)
            return
        }
        running.remove(id)
        if succeeded {
            failure = nil
            lastSuccess = endDate
            defaults.set(endDate.timeIntervalSince1970, forKey: UserDefaultsKeys.cloudSyncLastSuccess)
        } else {
            failure = CloudSyncFailure(ckErrorCode: errorCode)
        }
    }

    func refreshAccount() async {
        account = await readAccount()
    }

    func setOnline(_ isOnline: Bool) {
        self.isOnline = isOnline
    }

    /// Starts following the network connection. Call once at launch; later
    /// calls do nothing.
    func startWatchingNetwork() {
        guard networkWatcher == nil else { return }
        networkWatcher = NetworkPathWatcher { [weak self] isOnline in
            self?.setOnline(isOnline)
        }
    }
}
