import CloudKit
import SwiftData
import UIKit

/// Gathers the facts for the debug menu's Copy Diagnostics button. It reads
/// counts, never record contents. Do not call it from unit tests: CloudKit
/// raises an exception in an unsigned test host (see `CloudKitTrackerLookup`).
struct DiagnosticsCollector {
    let modelContext: ModelContext
    var bundle: Bundle = .main

    func collect() async -> DiagnosticsReport {
        let version = CurrentSchema.versionIdentifier
        return DiagnosticsReport(
            appVersion: AppVersion(infoDictionary: bundle.infoDictionary ?? [:]),
            systemVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            deviceModel: UIDevice.current.model,
            language: bundle.preferredLocalizations.first ?? "unknown",
            iCloudStatus: await iCloudStatus(),
            schemaName: String(describing: CurrentSchema.self),
            schemaVersion: "\(version.major).\(version.minor).\(version.patch)",
            entryCount: try? modelContext.fetchCount(FetchDescriptor<Entry>()),
            categoryCount: try? modelContext.fetchCount(FetchDescriptor<Tracker>())
        )
    }

    private func iCloudStatus() async -> String {
        do {
            switch try await CKContainer.default().accountStatus() {
            case .available: return "available"
            case .noAccount: return "no account"
            case .restricted: return "restricted"
            case .temporarilyUnavailable: return "temporarily unavailable"
            case .couldNotDetermine: return "could not determine"
            @unknown default: return "unknown"
            }
        } catch {
            return "error \((error as NSError).code)"
        }
    }
}
