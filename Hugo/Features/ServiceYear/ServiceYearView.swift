import SwiftData
import SwiftUI

struct ServiceYearView: View {
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @Query(sort: \SubmittedReport.year) private var submissions: [SubmittedReport]
    @State private var selectedYear: TheocraticYear?
	
	var resetToken: UUID = UUID()

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
                    ServiceYearPageView(
                        report: TheocraticYearReportBuilder.report(for: year, entries: entries, submissions: submissions),
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
		.onChange(of: resetToken) {
			withAnimation {
				selectedYear = nil
			}
		}
    }
}

#Preview {
    ServiceYearView()
        .modelContainer(.preview)
}
