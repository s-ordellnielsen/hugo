import SwiftUI

/// Logged and still-planned time on a track that ends at the target, or at the
/// projected time when the plan goes past the target.
struct PlannerProgressBar: View {
    let loggedSeconds: TimeInterval
    let stillPlannedSeconds: TimeInterval
    let targetSeconds: TimeInterval

    private var projectedSeconds: TimeInterval { loggedSeconds + stillPlannedSeconds }

    var body: some View {
        GeometryReader { proxy in
            let scale = max(targetSeconds, projectedSeconds, 1)
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(Color.hugoAccent.opacity(0.35))
                    .frame(width: width * min(1, projectedSeconds / scale))
                Capsule()
                    .fill(Color.hugoAccent)
                    .frame(width: width * min(1, loggedSeconds / scale))
                if projectedSeconds > targetSeconds {
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2)
                        .offset(x: width * targetSeconds / scale - 1)
                }
            }
        }
        .frame(height: HugoLayout.Size.goalTrackHeight)
        .motion(Motion.progress, value: projectedSeconds)
        .accessibilityHidden(true)
    }
}
