import SwiftData
import SwiftUI

struct ServiceYearView: View {
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @Query(sort: \SubmittedReport.year) private var submissions: [SubmittedReport]
    @State private var selectedYear: TheocraticYear?
    @State private var years: [TheocraticYear] = []
    @State private var reportsByYear: [TheocraticYear: TheocraticYearReport] = [:]

    var resetToken: UUID = UUID()

    private func rebuild() {
        let available = TheocraticYear.availableYears(entryDates: entries.map(\.date), now: .now)
        years = available
        reportsByYear = Dictionary(
            uniqueKeysWithValues: available.map { year in
                (
                    year,
                    TheocraticYearReportBuilder.report(
                        for: year, entries: entries, submissions: submissions
                    )
                )
            }
        )
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

    @ViewBuilder
    private func page(for year: TheocraticYear) -> some View {
        if let report = reportsByYear[year] {
            NavigationStack {
                ServiceYearPageView(report: report)
                    .navigationTitle(year.displayName)
                    .navigationSubtitle("year.subtitle")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tag(year)
        }
    }

    var body: some View {
        TabView(selection: yearSelection) {
            ForEach(years) { year in
                page(for: year)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .vertical)
        .onAppear {
            rebuild()
        }
        .onChange(of: entries) {
            rebuild()
        }
        .onChange(of: submissions) {
            rebuild()
        }
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
