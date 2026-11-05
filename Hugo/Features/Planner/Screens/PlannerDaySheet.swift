import SwiftData
import SwiftUI

/// One day in the Planner: its plans, and for today and earlier days its logged
/// entries. A plan can be logged, which opens Add Entry filled from the plan.
struct PlannerDaySheet: View {
    let day: CalendarDay
    let today: Date

    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]
    @Query private var plans: [Plan]
    @Query private var trackers: [Tracker]

    @State private var isAddingPlan = false
    @State private var editingPlan: Plan?
    @State private var loggingItem: PlannedItem?
    @State private var loggingSeconds: TimeInterval = 0
    @State private var isAddingEntry = false
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
        let bars = barsByID
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.section) {
                    plannedSection(bars: bars)
                    if canLog {
                        loggedSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(day.startDate().formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("navigation.dismiss", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            .sheet(isPresented: $isAddingPlan) {
                PlanFormView(day: day)
            }
            .sheet(item: $editingPlan) { plan in
                PlanFormView(day: day, plan: plan)
            }
            .sheet(item: $loggingItem) { item in
                AddEntryView(
                    seededDate: day.midday(),
                    seededDuration: (loggingSeconds / 60).rounded(.down) * 60,
                    preferredTrackerID: item.trackerID,
                    seededStartMinute: item.startMinute)
            }
            .sheet(isPresented: $isAddingEntry) {
                AddEntryView(seededDate: day.midday())
            }
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func plannedSection(bars: [String: PlannerBar]) -> some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            Text("planner.legend.planned")
                .font(.headline)
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
                        ? { startLogging(item, bars: bars) } : nil
                )
            }
            Button("planner.plan.add", systemImage: "plus") {
                isAddingPlan = true
            }
            .buttonStyle(.bordered)
        }
    }

    private var loggedSection: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            Text("planner.legend.logged")
                .font(.headline)
            if entries.isEmpty {
                Text("planner.day.logged.empty")
                    .foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                EntryRow(entry: entry, selectedEntry: $selectedEntry)
            }
            Button("entry.add.label", systemImage: "plus") {
                isAddingEntry = true
            }
            .buttonStyle(.bordered)
        }
    }

    /// The Log button opens Add Entry with the plan's remaining time, so a
    /// partly logged plan suggests only what is still missing.
    private func startLogging(_ item: PlannedItem, bars: [String: PlannerBar]) {
        loggingSeconds = bars[item.id]?.remainingSeconds ?? item.duration
        loggingItem = item
    }

    private var canLog: Bool { day <= CalendarDay(today) }

    private var items: [PlannedItem] {
        plans.map { PlannedItem($0, trackers: trackers) }
            .sorted { ($0.startMinute ?? Int.max) < ($1.startMinute ?? Int.max) }
    }

    /// The day's bars, matched by plan 068's rules. Plan bars share the item's id.
    private var barsByID: [String: PlannerBar] {
        let plannerDay = PlannerDay.make(
            day: day, items: items, entries: entries, trackers: trackers, today: CalendarDay(today))
        return Dictionary(plannerDay.bars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

#Preview {
    PlannerDaySheet(day: CalendarDay(.now), today: .now).modelContainer(.preview)
}
