import Foundation
import OSLog
import Observation
import SwiftData

/// Opens Hugo's SwiftData store at launch. If opening or migrating the store
/// throws, it keeps the error text instead of crashing, so the app can show
/// `StoreLoadFailureView`. It never deletes or changes the store.
@MainActor
@Observable
final class ModelContainerLoader {
    enum State {
        case loaded(ModelContainer)
        case failed(details: String)
    }

    private(set) var state: State
    @ObservationIgnored private let makeContainer: @MainActor () throws -> ModelContainer
    private static let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Persistence")

    init(makeContainer: @escaping @MainActor () throws -> ModelContainer) {
        self.makeContainer = makeContainer
        self.state = Self.load(using: makeContainer)
    }

    /// Tries to open the store again. Does nothing once it is open.
    func retry() {
        guard case .failed = state else { return }
        state = Self.load(using: makeContainer)
    }

    private static func load(using makeContainer: @MainActor () throws -> ModelContainer) -> State {
        do {
            return .loaded(try makeContainer())
        } catch {
            let details = String(describing: error)
            logger.error("Could not open the data store: \(details, privacy: .public)")
            return .failed(details: details)
        }
    }
}

/// Thrown instead of opening the store when the app is launched with
/// `-HugoSimulateStoreLoadFailure`, so the failure screen can be checked on a
/// device. Only Xcode can pass launch arguments, so App Store users can't
/// trigger it.
struct SimulatedStoreLoadFailure: Error, CustomStringConvertible {
    var description: String {
        "Simulated store load failure (launch argument -HugoSimulateStoreLoadFailure)"
    }
}
