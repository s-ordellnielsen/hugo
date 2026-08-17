import SwiftUI

struct MonthlyProgressCircle: View {
    let progress: Double
    let maxValue: Double

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var preferredSize: CGFloat = HugoLayout.Size.monthlyProgressDiameter

    var normalizedProgress: Double { maxValue > 0 ? min(max(progress / maxValue, 0), 1) : 0 }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [.hugoAccent.opacity(0.7), .hugoAccent]
                : [.hugoAccent, .hugoAccent.opacity(0.55)],
            startPoint: UnitPoint(x: 0.456, y: 1),
            endPoint: UnitPoint(x: 0.544, y: 0)
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(preferredSize, proxy.size.width)
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
                    .frame(width: side, height: side)
                Rectangle()
                    .fill(progressGradient)
                    .frame(width: side, height: side)
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(
                                width: side,
                                height: CGFloat(
                                    ceil(normalizedProgress * Double(side) + (normalizedProgress >= 1 ? 1 : 0)))
                            )
                    }
                    .motion(Motion.progress, value: normalizedProgress)
            }
            .frame(width: side, height: side)
            .clipShape(Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: HugoLayout.Size.monthlyProgressDiameter)
    }
}
