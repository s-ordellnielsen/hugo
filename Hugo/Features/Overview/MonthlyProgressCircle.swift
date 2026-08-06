import SwiftUI

struct MonthlyProgressCircle: View {
    let progress: Double
    let maxValue: Double
    let marker: Double?

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var preferredSize: CGFloat = 360

    var normalizedProgress: Double { maxValue > 0 ? min(max(progress / maxValue, 0), 1) : 0 }

    var body: some View {
        GeometryReader { proxy in
            let side = min(preferredSize, proxy.size.width)
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
                    .frame(width: side, height: side)
                Rectangle()
                    .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .bottom, endPoint: .top))
                    .frame(
                        width: side,
                        height: CGFloat(ceil(normalizedProgress * Double(side) + (normalizedProgress >= 1 ? 1 : 0)))
                    )
                    .animation(.spring(response: 0.6, dampingFraction: 0.9), value: normalizedProgress)
            }
            .frame(width: side, height: side)
            .clipShape(Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 360)
    }
}
