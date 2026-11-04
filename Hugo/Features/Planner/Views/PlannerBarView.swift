import SwiftUI

/// The rounded rectangle behind a bar: outline and tint in `color`, filled from
/// the left up to `fraction`. Also drawn on its own in legends.
struct PlannerBarShape: View {
    let fraction: Double
    let color: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.calendarBar)
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                shape.fill(color.opacity(0.15))
                Rectangle()
                    .fill(color.opacity(0.55))
                    .frame(width: proxy.size.width * min(1, max(0, fraction)))
            }
        }
        .clipShape(shape)
        .overlay { shape.strokeBorder(color, lineWidth: 1) }
    }
}

/// One plan, or unplanned logged time, in a calendar day.
struct PlannerBarView: View {
    let bar: PlannerBar

    @ScaledMetric(relativeTo: .caption2) private var height = HugoLayout.Size.calendarBarHeight

    private var color: Color {
        guard let color = bar.color else { return .hugoAccent }
        return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }

    var body: some View {
        let hours = Text(PlannerHoursText.short(bar.seconds)).monospacedDigit()
        let icon = Image(systemName: bar.categoryIconName)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) {
                icon
                hours
            }
            hours
            icon
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .lineLimit(1)
        .foregroundStyle(.primary)
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, minHeight: height)
        .background { PlannerBarShape(fraction: bar.fraction, color: color) }
    }
}
