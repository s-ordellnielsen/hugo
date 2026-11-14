import CloudKit
import Foundation

/// Whether this device's iCloud account can be used, as CloudKit reports it.
nonisolated enum CloudAccountState: Equatable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    /// Not read yet, or CloudKit couldn't tell.
    case unknown
}

/// Why the last sync attempt failed, from its CloudKit error code.
nonisolated enum CloudSyncFailure: Equatable {
    case signedOut
    case storageFull
    case offline
    case other

    init(ckErrorCode: Int?) {
        switch ckErrorCode.flatMap(CKError.Code.init(rawValue:)) {
        case .notAuthenticated?: self = .signedOut
        case .quotaExceeded?: self = .storageFull
        case .networkUnavailable?, .networkFailure?: self = .offline
        default: self = .other
        }
    }
}

/// What the iCloud row in Settings tells the user.
nonisolated enum CloudSyncStatus: Equatable {
    case upToDate(lastSync: Date?)
    case syncing
    case signedOut
    case restricted
    case storageFull
    case offline
    case problem

    /// The account problems come first, then the last failure, then a sync in
    /// progress. A successful sync clears the failure (see `CloudSyncMonitor`).
    static func make(
        account: CloudAccountState,
        isSyncing: Bool,
        failure: CloudSyncFailure?,
        lastSuccess: Date?
    ) -> CloudSyncStatus {
        switch account {
        case .noAccount: return .signedOut
        case .restricted: return .restricted
        case .available, .temporarilyUnavailable, .unknown: break
        }
        switch failure {
        case .signedOut?: return .signedOut
        case .storageFull?: return .storageFull
        case .offline?: return .offline
        case .other?: return .problem
        case nil: break
        }
        if isSyncing { return .syncing }
        if account == .temporarilyUnavailable { return .problem }
        return .upToDate(lastSync: lastSuccess)
    }

    var title: LocalizedStringResource {
        switch self {
        case .upToDate: "settings.sync.status.upToDate"
        case .syncing: "settings.sync.status.syncing"
        case .signedOut: "settings.sync.status.signedOut"
        case .restricted: "settings.sync.status.restricted"
        case .storageFull: "settings.sync.status.storageFull"
        case .offline: "settings.sync.status.offline"
        case .problem: "settings.sync.status.problem"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .upToDate: "settings.sync.message.upToDate"
        case .syncing: "settings.sync.message.syncing"
        case .signedOut: "settings.sync.message.signedOut"
        case .restricted: "settings.sync.message.restricted"
        case .storageFull: "settings.sync.message.storageFull"
        case .offline: "settings.sync.message.offline"
        case .problem: "settings.sync.message.problem"
        }
    }

    var symbolName: String {
        switch self {
        case .upToDate: "checkmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .signedOut, .restricted: "icloud.slash"
        case .storageFull, .problem: "exclamationmark.icloud"
        case .offline: "wifi.slash"
        }
    }
}
