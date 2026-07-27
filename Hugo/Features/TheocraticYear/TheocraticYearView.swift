import SwiftData
import SwiftUI

struct TheocraticYearView: View {
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @State private var selectedYear: TheocraticYear?

    private var years: [TheocraticYear] {
        TheocraticYear.availableYears(entryDates: entries.map(\.date), now: .now)
    }

    private var currentYear: TheocraticYear {
        Date().theocraticYear()
    }

    private var activeYear: TheocraticYear {
        selectedYear ?? currentYear
    }

    private var yearSelection: Binding<TheocraticYear> {
        Binding(get: { activeYear }, set: { selectedYear = $0 })
    }

    var body: some View {
        TabView(selection: yearSelection) {
            ForEach(years) { year in
                NavigationStack {
                    TheocraticYearPageView(
                        report: TheocraticYearReportBuilder.report(for: year, entries: entries),
                        initialMonth: year == currentYear ? Date().yearMonth() : nil
                    )
                    .navigationTitle(year.displayName)
                    .navigationSubtitle("year.subtitle")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .tag(year)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .vertical)
    }
}

#Preview {
    TheocraticYearView()
        .modelContainer(.preview)
}
