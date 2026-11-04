import SwiftData
import SwiftUI

struct PlannerMonthPage: View {
    let month: YearMonth
    let today: Date
    var onScrolledFromTopChange: ((Bool) -> Void)? = nil

    @Query private var entries: [Entry]
    @Query private var plans: [Plan]
    @Query private var trackers: [Tracker]

    init(month: YearMonth, today: Date, onScrolledFromTopChange: ((Bool) -> Void)? = nil) {
        self.month = month
        self.today = today
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
            VStack(spacing: HugoLayout.Spacing.card) {
                PlannerCalendarGrid(month: plannerMonth)
                if !plannerMonth.hasPlans {
                    PlannerIntroCard()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 0
        } action: { _, isScrolledFromTop in
            onScrolledFromTopChange?(isScrolledFromTop)
        }
    }
}
