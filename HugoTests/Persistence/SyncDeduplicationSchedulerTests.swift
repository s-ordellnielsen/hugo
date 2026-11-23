import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct SyncDeduplicationSchedulerTests {
    private let delay = Duration.milliseconds(50)
    /// Five times the scheduler delay, so a run that should have fired has time to fire.
    private let settle = Duration.milliseconds(300)
    private let quiet = Duration.milliseconds(300)

    @MainActor
    private final class RunCounter {
        var count = 0
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try InMemoryModelContainer.make())
    }

    private func makeScheduler(counter: RunCounter) -> SyncDeduplicationScheduler {
        SyncDeduplicationScheduler(delay: delay, perform: { _ in counter.count += 1 })
    }

    @Test
    func burstOfRequestsRunsOnce() async throws {
        let context = try makeContext()
        let counter = RunCounter()
        let scheduler = makeScheduler(counter: counter)

        for _ in 0..<5 {
            scheduler.request(context: context)
        }
        try await Task.sleep(for: settle)

        #expect(counter.count == 1)
    }

    @Test
    func requestsFarApartRunTwice() async throws {
        let context = try makeContext()
        let counter = RunCounter()
        let scheduler = makeScheduler(counter: counter)

        scheduler.request(context: context)
        try await Task.sleep(for: settle)
        scheduler.request(context: context)
        try await Task.sleep(for: settle)

        #expect(counter.count == 2)
    }

    @Test
    func noRequestNeverRuns() async throws {
        let counter = RunCounter()
        _ = makeScheduler(counter: counter)

        try await Task.sleep(for: quiet)

        #expect(counter.count == 0)
    }
}
