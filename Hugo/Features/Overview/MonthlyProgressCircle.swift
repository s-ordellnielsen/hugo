import SwiftUI

struct MonthlyProgressCircle: View {
    let progress: Double
    let maxValue: Double
    let marker: Double?
    @Environment(\.colorScheme) private var colorScheme
    private let size: CGFloat = 360

    var normalizedProgress: Double { maxValue > 0 ? min(max(progress / maxValue, 0), 1) : 0 }
    var body: some View {
        ZStack(alignment: .bottom) {
            Circle().fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)).frame(width: size, height: size)
            Rectangle().fill(LinearGradient(colors: [.orange, .yellow], startPoint: .bottom, endPoint: .top)).frame(width: size, height: CGFloat(ceil(normalizedProgress * Double(size) + (normalizedProgress >= 1 ? 1 : 0))))
                .animation(.spring(response: 0.6, dampingFraction: 0.9), value: normalizedProgress)
        }.frame(width: size, height: size).clipShape(Circle())
    }
}
