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
    /// Called when a day's plans are dropped on `target`. Returns whether the
    /// drop was accepted. Nil turns drag and drop off.
    var onDropPlans: ((PlanMoveRequest, PlannerDay) -> Bool)? = nil
    /// The day the hardware keyboard has highlighted, or nil.
    var keyboardDay: CalendarDay? = nil
    @ViewBuilder var dayPopover: (CalendarDay) -> DayPopover

    @State private var dropTarget: CalendarDay?

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
                        dragSource(PlannerDayCell(day: day), day: day)
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
                    .background {
                        if dropTarget == day.id {
                            RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.calendarDay)
                                .fill(.primary.opacity(0.1))
                                .overlay {
                                    RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.calendarDay)
                                        .strokeBorder(.primary.opacity(0.35), lineWidth: 1)
                                }
                        }
                    }
                    .dropDestination(for: PlanMoveRequest.self) { requests, _ in
                        guard let request = requests.first, let onDropPlans else { return false }
                        return onDropPlans(request, day)
                    } isTargeted: { isTargeted in
                        if isTargeted, onDropPlans != nil, PlanMoveRule.acceptsDrops(day) {
                            dropTarget = day.id
                        } else if dropTarget == day.id {
                            dropTarget = nil
                        }
                    }
                    .overlay {
                        if keyboardDay == day.id {
                            RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.calendarDay)
                                .fill(.primary.opacity(0.08))
                                .overlay {
                                    RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.calendarDay)
                                        .strokeBorder(.primary.opacity(0.3), lineWidth: 1)
                                }
                                .accessibilityHidden(true)
                        }
                    }
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

    /// The cell, draggable only when the day has plans and drops are on. The
    /// modifier goes on the label, not on the `Button`, so the button (and the
    /// popover anchored to it) keeps its identity when a day gains or loses plans.
    @ViewBuilder
    private func dragSource(_ cell: PlannerDayCell, day: PlannerDay) -> some View {
        if onDropPlans != nil, let request = PlanMoveRequest(day: day) {
            cell.draggable(request)
        } else {
            cell
        }
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
