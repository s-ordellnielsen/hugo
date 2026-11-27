import Foundation

/// Mirrors the widget settings and reloads the widget's timelines once after a quiet period.
/// Every `request` cancels the run that is still waiting and starts a new wait, so a burst of
/// saves costs one mirror write and one reload.
@MainActor
final class WidgetRefreshScheduler {
    private let delay: Duration
    private let mirror: WidgetSettingsMirror
    private let reload: () -> Void
    private var pending: Task<Void, Never>?

    init(delay: Duration = .seconds(1), mirror: WidgetSettingsMirror, reload: @escaping () -> Void) {
        self.delay = delay
        self.mirror = mirror
        self.reload = reload
    }

    func request() {
        pending?.cancel()
        pending = Task { [delay, mirror, reload] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            mirror.write()
            reload()
        }
    }
}
