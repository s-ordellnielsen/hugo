import SwiftUI

struct MonthlyProgressCircle: View {
    /// Share of the circle's area to fill, from 0 to 1.
    let fraction: Double

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var preferredSize: CGFloat = HugoLayout.Size.monthlyProgressDiameter

    private var clampedFraction: Double { min(max(fraction, 0), 1) }

    /// The fill's height as a share of the diameter, chosen so the colored
    /// area matches `fraction` (a circle is narrow at the bottom, so a
    /// quarter of the area needs about 30 % of the height).
    private var fillHeight: Double { CircleFillGeometry.height(forAreaFraction: clampedFraction) }

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
                                    ceil(fillHeight * Double(side) + (clampedFraction >= 1 ? 1 : 0)))
                            )
                    }
                    .motion(Motion.progress, value: fillHeight)
            }
            .frame(width: side, height: side)
            .clipShape(Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: HugoLayout.Size.monthlyProgressDiameter)
    }
}
