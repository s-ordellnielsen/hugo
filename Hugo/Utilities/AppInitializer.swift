//
//  AppInitializer.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 14/10/2025.
//

import CloudKit
import Combine
import CoreData
import Foundation
import SwiftData

class AppInitializer {
    private static let cloudWaitTimeout: TimeInterval = 8
    private static let trackerRecordType: String = "CD_Tracker"

    static func initialize(modelContext: ModelContext) async {
        await checkAndSeedIfNeeded(modelContext: modelContext)
    }

    private static func checkAndSeedIfNeeded(modelContext: ModelContext) async {
        let runKey = UserDefaults.hasRunInitialSetupKey

        if UserDefaults.standard.bool(forKey: runKey) {
            return
        }

        var descriptor = FetchDescriptor<Tracker>()
        descriptor.fetchLimit = 1
        if (try? modelContext.fetch(descriptor).first) != nil {
            UserDefaults.standard.set(true, forKey: runKey)
            return
        }

        let cloudHasAnyTracker = await cloudHasAny(.tracker)
        if cloudHasAnyTracker {
            UserDefaults.standard.set(true, forKey: runKey)
            return
        }

        let notified = await waitForCloudKitEvent(timeout: cloudWaitTimeout)
        if notified {
            let cloudHasAnyTrackerAfter = await cloudHasAny(.tracker)
            if cloudHasAnyTrackerAfter {
                UserDefaults.standard.set(true, forKey: runKey)
                return
            }
        }

        await addDefaultTrackers(modelContext: modelContext)

        UserDefaults.standard.set(true, forKey: runKey)
    }

    private static func cloudHasAny(_ recordType: CloudRecordType) async -> Bool {
        let query = CKQuery(
            recordType: recordType.record,
            predicate: NSPredicate(value: true)
        )
        let db = CKContainer.default().privateCloudDatabase
        
        print("Running CKQuery for record type:", recordType.record)
        print("Predicate:", query.predicate)

        do {
            let (matchResults, _) = try await db.records(matching: query)
            for (_, result) in matchResults {
                if case .success(_) = result {
                    return true
                }
            }
            return false
        } catch {
            if let ck = error as? CKError {
                print("CloudKit query CKError code:", ck.code.rawValue, ck.code)
                print("CKError localizedDescription:", ck.localizedDescription)
                print("CKError userInfo:", ck.userInfo)
            } else {
                print("CloudKit query non-CKError:", String(describing: error))
            }
            return false
        }
    }

    private static func waitForCloudKitEvent(timeout: TimeInterval) async
        -> Bool
    {
        guard timeout > 0 else { return false }

        return await withCheckedContinuation {
            (cont: CheckedContinuation<Bool, Never>) in
            var didResume = false

            let notificationTask = Task {
                let values = NotificationCenter.default
                    .publisher(
                        for: NSPersistentCloudKitContainer
                            .eventChangedNotification
                    )
                    .values

                for await _ in values {
                    if !didResume {
                        didResume = true
                        cont.resume(returning: true)
                    }
                    break
                }
            }

            let timeoutTask = Task.detached {
                try? await Task.sleep(
                    nanoseconds: UInt64(timeout * 1_000_000_000)
                )
                if !didResume {
                    didResume = true
                    // Cancel the notificationTask to stop listening
                    notificationTask.cancel()
                    cont.resume(returning: false)
                }
            }

            Task {
                while !didResume {
                    try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
                }

                notificationTask.cancel()
                timeoutTask.cancel()
            }
        }
    }

    private static func addDefaultTrackers(modelContext: ModelContext) async {
        for config in DefaultTrackerConfig.defaults {
            let localizedName = String(localized: config.localizationKey)

            let newDefaultTracker = Tracker(
                id: UUID(),
                name: localizedName,
                iconName: "figure.walk",
                hue: 0.6
            )

            print("Adding new default tracker")
            modelContext.insert(newDefaultTracker)
        }

        do {
            try modelContext.save()
        } catch {
            print(
                "Error saving default trackers: \(error.localizedDescription)"
            )
        }
    }
    
    private enum CloudRecordType: String, Codable, CaseIterable, Identifiable {
        case tracker
        case entry
        
        var id: String { rawValue }

        var record: String {
            switch self {
            case .tracker: return "CD_Tracker"
            case .entry: return "CD_Entry"
            }
        }
    }
}
