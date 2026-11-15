import Foundation
import Network

/// Calls `onChange` with whether the device has a network connection, once at
/// the start and again whenever it changes. It watches for as long as it
/// exists. `NWPathMonitor` needs a queue of its own; the result is handed to
/// the main actor.
final class NetworkPathWatcher {
    private let monitor = NWPathMonitor()

    init(onChange: @escaping @MainActor @Sendable (Bool) -> Void) {
        monitor.pathUpdateHandler = { path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in onChange(isOnline) }
        }
        monitor.start(queue: DispatchQueue(label: "com.ordellnielsen.Hugo.network-path"))
    }
}
