import SwiftData

/// Runs `SyncDeduplicator` once after a quiet period. Every `request` cancels
/// the run that is still waiting and starts a new wait, so a burst of CloudKit
/// import events costs one run. The merges are idempotent, so skipping the
/// intermediate runs loses nothing.
@MainActor
final class SyncDeduplicationScheduler {
    private let delay: Duration
    private let perform: (ModelContext) -> Void
    private var pending: Task<Void, Never>?

    init(
        delay: Duration = .milliseconds(500),
        perform: @escaping (ModelContext) -> Void = { SyncDeduplicator(context: $0).run() }
    ) {
        self.delay = delay
        self.perform = perform
    }

    func request(context: ModelContext) {
        pending?.cancel()
        pending = Task { [delay, perform] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            perform(context)
        }
    }
}
