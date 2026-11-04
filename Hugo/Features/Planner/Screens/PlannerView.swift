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

    @State private var scrollPosition: YearMonth?
    @State private var displayedMonth: YearMonth?

    private var months: [YearMonth] { PlannerMonth.reachableMonths(from: today) }
    private var currentMonth: YearMonth { today.yearMonth() }
    private var activeMonth: YearMonth { displayedMonth ?? currentMonth }

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(months, id: \.self) { month in
                        PlannerMonthPage(month: month, today: today)
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
