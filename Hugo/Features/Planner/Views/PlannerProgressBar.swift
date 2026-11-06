import SwiftUI

/// Logged and still-planned time on a track that ends at the target, or at the
/// projected time when the plan goes past the target.
struct PlannerProgressBar: View {
    let loggedSeconds: TimeInterval
    let stillPlannedSeconds: TimeInterval
    let targetSeconds: TimeInterval

    private var projectedSeconds: TimeInterval { loggedSeconds + stillPlannedSeconds }

    var body: some View {
        let scale = max(targetSeconds, projectedSeconds, 1)
        MarkedProgressBar(
            filled: loggedSeconds / scale,
            extended: projectedSeconds / scale,
            marker: projectedSeconds > targetSeconds ? targetSeconds / scale : nil
        )
    }
}
