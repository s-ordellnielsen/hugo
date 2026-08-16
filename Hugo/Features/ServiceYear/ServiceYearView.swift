import SwiftData
import SwiftUI

struct ServiceYearView: View {
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @Query(sort: \SubmittedReport.year) private var submissions: [SubmittedReport]

    @State private var scrollPosition: TheocraticYear.ID?
    @State private var displayedYear: TheocraticYear?
    @State private var isScrolledFromTop = false

    var resetToken: UUID = UUID()

    private var years: [TheocraticYear] {
        TheocraticYear.availableYears(
            entryDates: entries.map(\.date),
            now: .now
        )
    }

    private var currentYear: TheocraticYear {
        Date().theocraticYear()
    }

    private var activeYear: TheocraticYear {
        displayedYear ?? currentYear
    }

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(years) { year in
                        ServiceYearPageView(
                            report: TheocraticYearReportBuilder.report(
                                for: year, entries: entries, submissions: submissions),
                            isActive: year.id == scrollPosition,
                            onScrolledFromTopChange: { newValue in
                                isScrolledFromTop = newValue
                            }
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
            .navigationTitle(activeYear.displayName)
            .navigationSubtitle("year.subtitle")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectHidden(!isScrolledFromTop, for: .top)
            .toolbar {
                ToolbarItem(placement: .principal) {
					HStack(spacing: 0) {
						Text(String(activeYear.startYear))
							.contentTransition(.numericText(value: Double(activeYear.startYear)))
						Text(String("/"))
						Text(String(activeYear.startYear + 1))
							.contentTransition(.numericText(value: Double(activeYear.startYear + 1)))
							.animation(.snappy.delay(0.05), value: activeYear.startYear + 1)
					}
					.font(.system(.headline, design: .serif, weight: .bold))
					.lineLimit(1)
					.minimumScaleFactor(0.75)
					.monospacedDigit()
                }
				ToolbarItem {
					SettingsButton(sizeClass: .compact)
				}
            }
        }
        .onAppear {
            if scrollPosition == nil {
                scrollPosition = currentYear.id
                displayedYear = currentYear
            }
        }
        .onChange(
            of: scrollPosition,
            { _, newValue in
                guard let newValue, let year = years.first(where: { $0.id == newValue }) else { return }
				withAnimation(.snappy) {
					displayedYear = year
				}
            }
        )
        .onChange(of: resetToken) {
            withAnimation {
                scrollPosition = currentYear.id
                displayedYear = currentYear
            }
        }
    }
}

#Preview {
    ServiceYearView()
        .modelContainer(.preview)
}
