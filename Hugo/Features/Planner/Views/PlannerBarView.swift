import SwiftUI

/// The rounded rectangle behind a bar: an outline and a light tint in `color`,
/// and a fill in the same `color` from the left up to `fraction`. Also drawn on
/// its own in legends.
struct PlannerBarShape<Style: ShapeStyle>: View {
    let fraction: Double
    let color: Style

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.calendarBar)
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                shape.fill(color.opacity(0.15))
                Rectangle()
                    .fill(color)
                    .frame(width: proxy.size.width * min(1, max(0, fraction)))
            }
        }
        .clipShape(shape)
        .overlay { shape.strokeBorder(color, lineWidth: 1) }
    }
}

/// One plan, or unplanned logged time, in a calendar day: a thin bar that
/// fills from the left. The day sheet shows the category and hours.
struct PlannerBarView: View {
    let bar: PlannerBar

    @ScaledMetric(relativeTo: .caption2) private var height = HugoLayout.Size.calendarBarHeight

    private var color: CategoryColorStyle { CategoryColorStyle(bar.color) }

    var body: some View {
        PlannerBarShape(fraction: bar.fraction, color: color)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}
