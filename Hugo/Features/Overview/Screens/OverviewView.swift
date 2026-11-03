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
    @Query private var submissions: [SubmittedReport]

    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    @State private var showingAddEntry = false
    @State private var showingDetails = false

    init(today: Date) {
        self.today = today
        let interval = CurrentMonthInterval.current(now: today, calendar: .current)
        let start = interval.start
        let end = interval.end
        _entries = Query(
            filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
    }

    private var metrics: OverviewMetrics {
        OverviewMetrics.make(
            entries: entries, status: PublisherStatus.status(for: statusID), now: .now, calendar: .current)
    }

    /// The month whose report reminder should show, if any: a month is due
    /// (per `ReportReminderSchedule`) and has no real submission. Backfill
    /// sentinels (`submittedAt == .distantPast`) count as unsubmitted.
    private var reminderMonth: YearMonth? {
        guard let due = ReportReminderSchedule.dueMonth(now: .now, calendar: .current) else { return nil }
        guard let submission = TheocraticYearReportBuilder.canonicalSubmission(for: due, in: submissions) else {
            return due
        }
        return (submission.submittedAt ?? .distantPast) == .distantPast ? due : nil
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
                        expectedProgress: metrics.expectedProgress, onAddEntry: { showingAddEntry = true },
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
