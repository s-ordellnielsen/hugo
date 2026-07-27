import SwiftData
import SwiftUI

struct ReportsView: View {
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]

    var body: some View {
        NavigationStack {
            ScrollView {
                if entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.green)
                        Text("report.pending.empty")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .padding(.leading, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(24)
                    .padding()
                } else {
                    MonthlyReportListView(entries: entries)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("reports.title")
        }
    }
}

#Preview {
    ReportsView().modelContainer(.preview)
}
