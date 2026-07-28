import SwiftData
import SwiftUI

struct MonthlyReportEmptyRow: View {
    let month: TheocraticYearMonth
	
	@State private var isPresented: Bool = false

    var body: some View {
        HStack {
            Text(month.displayName)
                .font(.caption)
                .textCase(.uppercase)
                .tracking(1.5)
                .fontWeight(.semibold)
                .foregroundStyle(month.isFuture ? .tertiary : .secondary)
            Spacer()
            if !month.isFuture {
                Text("year.month.empty")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .accessibilityElement(children: .combine)
		.onTapGesture {
			isPresented.toggle()
		}
		.sheet(isPresented: $isPresented) {
			AddEntryView(seededDate: month.id.date())
		}
    }
}

#Preview {
    MonthlyReportEmptyRow(month: ReportPreviewFixtures.emptyMonth)
        .modelContainer(.preview)
}
