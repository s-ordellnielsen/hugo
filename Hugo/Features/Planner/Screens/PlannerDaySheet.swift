import SwiftData
import SwiftUI

/// One day in the Planner: its plans first, then, on days with logged
/// entries, a smaller list of those entries. Logging a plan opens Add Entry
/// filled from the plan.
struct PlannerDaySheet: View {
    let day: CalendarDay
    let today: Date

    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]
    @Query private var plans: [Plan]
    @Query private var trackers: [Tracker]

    @State private var isAddingPlan = false
    @State private var editingPlan: Plan?
    @State private var loggingSeed: PlanLogSeed?
    @State private var selectedEntry: Entry?

    init(day: CalendarDay, today: Date) {
        self.day = day
        self.today = today
        let range = day.dateRange()
        let start = range.lowerBound
        let end = range.upperBound
        _entries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date)
        _plans = Query(filter: #Predicate<Plan> { $0.date >= start && $0.date < end }, sort: \Plan.createdAt)
    }

    var body: some View {
        let plannerDay = self.plannerDay
        let bars = Dictionary(plannerDay.bars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.section) {
                    plannedSection(bars: bars)
                    if !entries.isEmpty {
                        PlannerLoggedEntryList(entries: entries, total: plannerDay.logged.total) { entry in
                            selectedEntry = entry
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(day.startDate().formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("navigation.dismiss", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem {
                    Button("planner.plan.add", systemImage: "plus") {
                        isAddingPlan = true
                    }
                }
            }
            .sheet(isPresented: $isAddingPlan) {
                PlanFormView(day: day)
            }
            .sheet(item: $editingPlan) { plan in
                PlanFormView(day: day, plan: plan)
            }
            .sheet(item: $loggingSeed) { seed in
                AddEntryView(
                    seededDate: seed.date,
                    seededDuration: seed.duration,
                    preferredTrackerID: seed.trackerID,
                    seededStartMinute: seed.startMinute)
            }
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func plannedSection(bars: [String: PlannerBar]) -> some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            if items.isEmpty {
                Text("planner.day.planned.empty")
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                PlannedItemRow(
                    item: item,
                    bar: bars[item.id],
                    showsProgress: canLog,
                    onEdit: { editingPlan = plans.first(where: { $0.id.uuidString == item.id }) },
                    onLog: canLog && !(bars[item.id]?.isFull ?? false)
                        ? { loggingSeed = PlanLogSeed(item: item, bar: bars[item.id]) } : nil
                )
            }
        }
    }

    private var canLog: Bool { day <= CalendarDay(today) }

    private var items: [PlannedItem] {
        plans.map { PlannedItem($0, trackers: trackers) }
            .sorted { ($0.startMinute ?? Int.max) < ($1.startMinute ?? Int.max) }
    }

    /// The day's plans matched with its logged time (plan 068's rules).
    private var plannerDay: PlannerDay {
        PlannerDay.make(day: day, items: items, entries: entries, trackers: trackers, today: CalendarDay(today))
    }
}

#Preview {
    PlannerDaySheet(day: CalendarDay(.now), today: .now).modelContainer(.preview)
}
