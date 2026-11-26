import SwiftData
import SwiftUI

struct PlannerMonthPage: View {
    let month: YearMonth
    let today: Date
    let targetSeconds: TimeInterval?
    let rule: YearlyGoalRule?
    var onScrolledFromTopChange: ((Bool) -> Void)? = nil

    @Query private var entries: [Entry]
    @Query private var plans: [Plan]
    @Query private var trackers: [Tracker]
    @Environment(\.modelContext) private var context
    @State private var moveError: String?
    /// The day whose popover is open.
    @State private var presentedDay: CalendarDay?
    /// What the open (or closing) popover shows. Never reset on dismissal: the
    /// content stays on screen during the dismiss animation, and saving a plan
    /// makes an empty day non-empty, so recomputing it would flip Add Plan to the
    /// day view while it closes.
    @State private var popoverDestination: PlannerDayDestination = .daySheet

    init(
        month: YearMonth, today: Date, targetSeconds: TimeInterval?, rule: YearlyGoalRule?,
        onScrolledFromTopChange: ((Bool) -> Void)? = nil
    ) {
        self.month = month
        self.today = today
        self.targetSeconds = targetSeconds
        self.rule = rule
        self.onScrolledFromTopChange = onScrolledFromTopChange
        let range = month.dateRange()
        let start = range.lowerBound
        let end = range.upperBound
        _entries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date)
        _plans = Query(filter: #Predicate<Plan> { $0.date >= start && $0.date < end }, sort: \Plan.date)
    }

    private var plannerMonth: PlannerMonth {
        PlannerMonth.make(
            month: month, items: plans.map { PlannedItem($0, trackers: trackers) }, entries: entries,
            trackers: trackers, now: today)
    }

    var body: some View {
        let plannerMonth = self.plannerMonth
        ScrollView {
            AdaptiveTwoColumnStack(
                leadingWidth: HugoLayout.Size.plannerStatusColumnWidth,
                inset: HugoLayout.Spacing.spacious, spacing: HugoLayout.Spacing.card
            ) {
                PlannerStatusHeader(
                    status: PlannerMonthStatus.make(
                        month: plannerMonth, targetSeconds: targetSeconds, rule: rule)
                )
                .padding(.bottom, HugoLayout.Spacing.card)
            } trailing: {
                VStack(spacing: HugoLayout.Spacing.card) {
                    PlannerCalendarGrid(
                        month: plannerMonth, onSelect: select,
                        onAddPlan: { open($0, .addPlan) }, onLogTime: { open($0, .logTime) },
                        presentedDay: $presentedDay, onDropPlans: movePlans
                    ) { day in
                        dayPopover(for: day)
                    }
                    if !plannerMonth.hasPlans {
                        PlannerIntroCard()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 0
        } action: { _, isScrolledFromTop in
            onScrolledFromTopChange?(isScrolledFromTop)
        }
        .errorAlert(message: $moveError)
    }

    /// Moves the dragged day's plans to `target`. Past days and the source day
    /// refuse the drop.
    private func movePlans(_ request: PlanMoveRequest, to target: PlannerDay) -> Bool {
        guard PlanMoveRule.canDrop(from: request.sourceDay, on: target) else { return false }
        do {
            try PlanService(context: context).move(planIDs: request.planIDs, to: target.id)
            return true
        } catch {
            moveError = error.localizedDescription
            return false
        }
    }

    /// An empty day opens Add Plan directly; every other day opens the day sheet.
    private func select(_ day: CalendarDay) {
        let plannerDay = plannerMonth.days.first { $0.id == day }
        popoverDestination = plannerDay.map(PlannerDayDestination.init(day:)) ?? .daySheet
        presentedDay = day
    }

    /// Opens `destination` in the day's popover, as a tap would.
    private func open(_ day: CalendarDay, _ destination: PlannerDayDestination) {
        popoverDestination = destination
        presentedDay = day
    }

    @ViewBuilder
    private func dayPopover(for day: CalendarDay) -> some View {
        switch popoverDestination {
        case .addPlan:
            PlanFormView(day: day)
                .popoverContentSize()
        case .logTime:
            AddEntryView(seededDate: day.startDate())
                .popoverContentSize()
        case .daySheet:
            PlannerDaySheet(day: day, today: today)
                .presentationDetents([.medium, .large])
                .popoverContentSize()
        }
    }
}
