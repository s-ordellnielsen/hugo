import SwiftUI

struct PlannerCalendarGrid<DayPopover: View>: View {
    let month: PlannerMonth
    var onSelect: ((CalendarDay) -> Void)? = nil
    /// Context-menu actions. Nil hides the item.
    var onAddPlan: ((CalendarDay) -> Void)? = nil
    var onLogTime: ((CalendarDay) -> Void)? = nil
    /// The day whose popover is open. Each cell anchors its own popover, so the
    /// arrow points at the tapped day.
    var presentedDay: Binding<CalendarDay?> = .constant(nil)
    @ViewBuilder var dayPopover: (CalendarDay) -> DayPopover

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
                    Button {
                        onSelect?(day.id)
                    } label: {
                        PlannerDayCell(day: day)
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelect == nil)
                    .contentShape(.contextMenuPreview, .rect(cornerRadius: HugoLayout.Spacing.regular))
                    .contextMenu {
                        let actions = PlannerDayActions(day: day)
                        if actions.canAddPlan, let onAddPlan {
                            Button("planner.plan.add", systemImage: "calendar.badge.plus") { onAddPlan(day.id) }
                        }
                        if actions.canLogTime, let onLogTime {
                            Button("planner.day.action.logTime", systemImage: "plus.circle") { onLogTime(day.id) }
                        }
                    }
                    .contentShape(.hoverEffect, .rect(cornerRadius: HugoLayout.CornerRadius.calendarDay))
                    .hoverEffect(.highlight)
                    .popover(isPresented: isPresented(day.id)) {
                        dayPopover(day.id)
                    }
                }
            }
            PlannerLegend()
        }
        .padding(HugoLayout.Spacing.regular)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
    }

    private func isPresented(_ day: CalendarDay) -> Binding<Bool> {
        Binding(
            get: { presentedDay.wrappedValue == day },
            set: { isPresented in
                if !isPresented, presentedDay.wrappedValue == day {
                    presentedDay.wrappedValue = nil
                }
            }
        )
    }
}

extension PlannerCalendarGrid where DayPopover == EmptyView {
    init(month: PlannerMonth, onSelect: ((CalendarDay) -> Void)? = nil) {
        self.init(month: month, onSelect: onSelect, presentedDay: .constant(nil)) { _ in EmptyView() }
    }
}
