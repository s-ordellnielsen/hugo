import SwiftData
import SwiftUI

struct OverviewView: View {
    @Query private var entries: [Entry]
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @State private var showingAddEntry = false
    @State private var showingDetails = false
    private let calendar = Calendar.current
    private let now = Date.now

    init() {
        let interval = CurrentMonthInterval.current(now: .now, calendar: .current)
        let start = interval.start
        let end = interval.end
        _entries = Query(
            filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
    }

    private var metrics: OverviewMetrics {
        OverviewMetrics.make(
            entries: entries, status: PublisherStatus.status(for: statusID), now: now, calendar: calendar)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    MonthlyProgressCard(
                        value: metrics.progress, monthlyGoal: metrics.monthlyGoal,
                        expectedProgress: metrics.expectedProgress, onAddEntry: { showingAddEntry = true },
                        onShowDetails: { showingDetails = true })
                    Spacer(minLength: 32)
                    EntryListView(entries: entries)
                }.padding()
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("overview.title")
			.navigationBarTitleDisplayMode(.inline)
            .toolbar { SettingsButton() }.sheet(isPresented: $showingAddEntry) { AddEntryView() }.sheet(
                isPresented: $showingDetails
            ) { MonthlyProgressDetailView() }
        }
    }
}
