import SwiftData
import SwiftUI

struct MonthlyReportEmptyRow: View {
    let month: TheocraticYearMonth

	@State private var isPresented: Bool = false
	@State private var isPresentingSubmitSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(month.displayName)
                    .font(.caption)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .fontWeight(.semibold)
                    .foregroundStyle(month.isFuture ? .tertiary : .secondary)
                Spacer()
                if !month.isFuture && !month.isSubmitted {
                    Text("year.month.empty")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            MonthSubmissionStatusView(month: month)

            if !month.isFuture && !month.isSubmitted {
                Button("report.submit.button") {
                    isPresentingSubmitSheet.toggle()
                }
                .buttonStyle(.bordered)
                .font(.caption)
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
        .sheet(isPresented: $isPresentingSubmitSheet) {
            NavigationStack {
                SubmitReportView(month: month.id)
            }
        }
    }
}

#Preview {
    MonthlyReportEmptyRow(month: ReportPreviewFixtures.emptyMonth)
        .modelContainer(.preview)
}
