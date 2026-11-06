import Combine
import SwiftData
import SwiftUI
import UIKit

struct PlannerView: View {
    var resetToken: UUID

    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Calendar.current.startOfDay(for: .now)

    init(resetToken: UUID = UUID()) {
        self.resetToken = resetToken
    }

    var body: some View {
        PlannerPager(today: today, resetToken: resetToken)
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
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @AppStorage(UserDefaultsKeys.plannerTargetBase) private var targetBase: PlannerTargetBase = .monthlyGoal
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0

    @State private var scrollPosition: YearMonth?
    @State private var displayedMonth: YearMonth?
    @State private var scrolledPages: [YearMonth: Bool] = [:]

    init(today: Date, resetToken: UUID) {
        self.today = today
        self.resetToken = resetToken
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
            entries: yearEntries, submissions: submissions, trackers: trackers, status: status, now: today)
    }

    var body: some View {
        let credited = creditedBeforeCurrentMonth
        NavigationStack {
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
            .navigationTitle(activeMonth.monthYearString())
            .navigationSubtitle("tab.planner")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectHidden(!isScrolledFromTop, for: .top)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(activeMonth.monthYearString())
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                ToolbarItem {
                    SettingsButton(sizeClass: .compact)
                }
            }
        }
        .onAppear {
            if scrollPosition == nil {
                scrollPosition = currentMonth
                displayedMonth = currentMonth
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
    PlannerView()
        .modelContainer(.preview)
}
