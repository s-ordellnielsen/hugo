import SwiftUI

struct PlannerCalendarGrid: View {
    let month: PlannerMonth

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: HugoLayout.Spacing.tight, alignment: .top), count: 7)

    var body: some View {
        VStack(spacing: HugoLayout.Spacing.regular) {
            LazyVGrid(columns: columns, spacing: HugoLayout.Spacing.compact) {
                ForEach(Array(CalendarGridLayout.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                ForEach(0..<CalendarGridLayout.leadingBlankDays(in: month.month), id: \.self) { _ in
                    Color.clear.accessibilityHidden(true)
                }
                ForEach(month.days) { day in
                    PlannerDayCell(day: day)
                }
            }
            PlannerLegend()
        }
        .padding(HugoLayout.Spacing.regular)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
    }
}
