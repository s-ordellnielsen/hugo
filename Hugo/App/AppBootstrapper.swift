import Foundation
import OSLog
import Observation
import SwiftData

@MainActor
@Observable
final class AppBootstrapper {
    enum State: Equatable {
        case idle
        case checking
        case ready
        case failed
    }

    private(set) var state: State = .idle
    private(set) var errorMessage: String?
    private let lookup: any CloudTrackerLookup
    private let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Bootstrap")

    init(lookup: any CloudTrackerLookup = CloudKitTrackerLookup()) {
        self.lookup = lookup
    }

    func start(context: ModelContext) async {
        guard state != .checking else { return }
        state = .checking
        errorMessage = nil

        do {
            let descriptor = FetchDescriptor<Tracker>()
            if try context.fetch(descriptor).isEmpty {
                if try await lookup.hasAnyTracker() == false {
                    try seedDefaults(in: context)
                }
            }
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasRunInitialSetup)
            state = .ready
        } catch is CancellationError {
            state = .idle
        } catch {
            logger.error("Bootstrap failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            state = .failed
        }
    }

    func retry(context: ModelContext) async {
        state = .idle
        await start(context: context)
    }

    private func seedDefaults(in context: ModelContext) throws {
        for definition in DefaultCategoryDefinition.all {
            let tracker = Tracker(
                id: definition.id,
                name: String(localized: definition.nameKey),
                type: .main,
                isDefault: definition.isDefault,
                iconName: definition.iconName,
                hue: definition.hue,
                sat: definition.saturation,
                bri: definition.brightness
            )
            context.insert(tracker)
        }
        try context.save()
    }
}
