import Combine
import SwiftData
import SwiftUI
import UIKit

struct PlannerView: View {
    var resetToken: UUID

    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Calendar.current.startOfDay(for: .now)

    @Binding var displayedMonth: YearMonth?

    init(resetToken: UUID = UUID(), displayedMonth: Binding<YearMonth?> = .constant(nil)) {
        self.resetToken = resetToken
        _displayedMonth = displayedMonth
    }

    var body: some View {
        PlannerPager(today: today, resetToken: resetToken, displayedMonth: $displayedMonth)
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

private struct PlannerPager: View {
    let today: Date
    let resetToken: UUID

    @Query private var yearEntries: [Entry]
    @Query private var submissions: [SubmittedReport]
    @Query private var trackers: [Tracker]
    @Query private var schoolCredits: [SchoolCredit]
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @AppStorage(UserDefaultsKeys.plannerTargetBase) private var targetBase: PlannerTargetBase = .monthlyGoal
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0

    @State private var scrollPosition: YearMonth?
    @Binding var displayedMonth: YearMonth?
    @State private var scrolledPages: [YearMonth: Bool] = [:]

    init(today: Date, resetToken: UUID, displayedMonth: Binding<YearMonth?>) {
        self.today = today
        self.resetToken = resetToken
        _displayedMonth = displayedMonth
        let range = TheocraticYear.containing(today).dateRange()
        let start = range.lowerBound
        let end = range.upperBound
        _yearEntries = Query(
            filter: #Predicate<Entry> { $0.date >= start && $0.date < end },
            sort: \Entry.date
        )
        _submissions = Query(sort: \SubmittedReport.year)
    }

    private var months: [YearMonth] { PlannerMonth.reachableMonths(from: today) }
    private var currentMonth: YearMonth { today.yearMonth() }
    private var activeMonth: YearMonth { displayedMonth ?? currentMonth }
    private var isScrolledFromTop: Bool { scrolledPages[activeMonth] ?? false }
    private var status: PublisherStatus? { PublisherStatus.status(for: statusID) }

    /// Credited time of this theocratic year's months before the current month.
    /// Built only when the target needs it.
    private var creditedBeforeCurrentMonth: TimeInterval {
        guard targetBase == .yearlyGoalShare else { return 0 }
        return PlannerTarget.creditedBeforeCurrentMonth(
            entries: yearEntries, submissions: submissions, trackers: trackers, schoolCredits: schoolCredits,
            status: status, now: today)
    }

    var body: some View {
        let credited = creditedBeforeCurrentMonth
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(months, id: \.self) { month in
                    PlannerMonthPage(
                        month: month, today: today,
                        targetSeconds: PlannerTarget.seconds(
                            for: month, base: targetBase, extraHours: extraHours, status: status,
                            creditedBeforeCurrentMonth: credited, now: today),
                        rule: status?.yearlyGoalRule,
                        onScrolledFromTopChange: { scrolledPages[month] = $0 }
                    )
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .editorialNavigationTitle(activeMonth.monthYearString())
        .navigationSubtitle("tab.planner")
        .scrollEdgeEffectHidden(!isScrolledFromTop, for: .top)
        .toolbar {
            ToolbarItem {
                SettingsButton(sizeClass: .compact)
            }
        }
        .onAppear {
            if scrollPosition == nil {
                let month = displayedMonth ?? currentMonth
                scrollPosition = month
                displayedMonth = month
            }
        }
        .onChange(of: scrollPosition) { _, newValue in
            guard let newValue, months.contains(newValue) else { return }
            withAnimation(.snappy) {
                displayedMonth = newValue
            }
        }
        .onChange(of: resetToken) {
            withAnimation {
                scrollPosition = currentMonth
                displayedMonth = currentMonth
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlannerView()
    }
    .modelContainer(.preview)
}
