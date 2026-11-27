import Foundation
import Testing

@testable import Hugo

@MainActor
struct WidgetRefreshSchedulerTests {
    private let delay = Duration.milliseconds(50)
    /// Five times the scheduler delay, so a run that should have fired has time to fire.
    private let settle = Duration.milliseconds(300)

    @MainActor
    private final class ReloadCounter {
        var count = 0
    }

    private func makeScheduler(counter: ReloadCounter, suite: UserDefaults?) -> WidgetRefreshScheduler {
        WidgetRefreshScheduler(
            delay: delay,
            mirror: WidgetSettingsMirror(source: .standard, suite: suite),
            reload: { counter.count += 1 })
    }

    @Test
    func burstOfRequestsReloadsOnce() async throws {
        let suiteName = UUID().uuidString
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let counter = ReloadCounter()
        let scheduler = makeScheduler(counter: counter, suite: suite)

        for _ in 0..<3 {
            scheduler.request()
        }
        try await Task.sleep(for: settle)

        #expect(counter.count == 1)
        #expect(WidgetSettingsMirror.read(from: suite) != nil)
    }

    @Test
    func requestAfterTheDelayReloadsAgain() async throws {
        let counter = ReloadCounter()
        let scheduler = makeScheduler(counter: counter, suite: nil)

        scheduler.request()
        try await Task.sleep(for: settle)
        scheduler.request()
        try await Task.sleep(for: settle)

        #expect(counter.count == 2)
    }
}
