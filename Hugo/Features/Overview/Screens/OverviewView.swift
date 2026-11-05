import Combine
import SwiftData
import SwiftUI
import UIKit

struct OverviewView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Calendar.current.startOfDay(for: .now)

    var body: some View {
        OverviewDayView(today: today)
            .id(today)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshToday() }
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: UIApplication.significantTimeChangeNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                refreshToday()
            }
    }

    private func refreshToday() {
        let start = Calendar.current.startOfDay(for: .now)
        if start != today { today = start }
    }
}

private struct OverviewDayView: View {
    let today: Date

    @Query private var entries: [Entry]
    @Query private var plans: [Plan]
    @Query private var trackers: [Tracker]
    @Query private var submissions: [SubmittedReport]

    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    @State private var showingAddEntry = false
    @State private var showingDetails = false

    init(today: Date) {
        self.today = today
        let range = today.yearMonth(using: .current).dateRange(calendar: .current)
        let start = range.lowerBound
        let end = range.upperBound
        _entries = Query(
            filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
        _plans = Query(filter: #Predicate<Plan> { $0.date >= start && $0.date < end })
    }

    private var metrics: OverviewMetrics {
        OverviewMetrics.make(
            entries: entries, status: PublisherStatus.status(for: statusID), now: .now, calendar: .current)
    }

    /// Nil unless the current month has plans.
    private var planStatus: MonthlyProgressStatus? {
        let month = PlannerMonth.make(
            month: today.yearMonth(using: .current),
            items: plans.map { PlannedItem($0, trackers: trackers) },
            entries: entries, trackers: trackers, now: .now, calendar: .current)
        return PlanPace.make(month: month).map(MonthlyProgressStatus.make(pace:))
    }

    /// The month whose report reminder should show, if any. See
    /// `ReportReminderSchedule.reminderMonth(now:submissions:calendar:)`.
    private var reminderMonth: YearMonth? {
        ReportReminderSchedule.reminderMonth(now: .now, submissions: submissions, calendar: .current)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    if let reminderMonth {
                        ReportReminderCard(month: reminderMonth)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        Spacer(minLength: HugoLayout.Spacing.section)
                    }
                    MonthlyProgressCard(
                        value: metrics.progress, monthlyGoal: metrics.monthlyGoal,
                        planStatus: planStatus, onAddEntry: { showingAddEntry = true },
                        onShowDetails: { showingDetails = true })
                    Spacer(minLength: HugoLayout.Spacing.section)

                    OverviewListView(entries: entries)
                }
                .motion(Motion.presence, value: reminderMonth)
                .padding()
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    SettingsButton(sizeClass: .compact)
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddEntryView()
            }
            .sheet(isPresented: $showingDetails) {
                MonthlyProgressDetailView(month: Date.now.yearMonth())
            }
        }
    }
}

#Preview {
    OverviewView()
}
