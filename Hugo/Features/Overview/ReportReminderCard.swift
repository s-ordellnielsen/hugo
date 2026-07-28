import SwiftUI

/// Reminder card on the Overview tab prompting the user to submit the report
/// for `month`. Shown only when `ReportReminderSchedule.dueMonth` is non-nil
/// and the month has no real submission; disappears solely by submitting.
struct ReportReminderCard: View {
    let month: YearMonth

    @State private var isPresentingSubmitSheet = false

    private var monthName: String {
        month.date().formatted(.dateTime.month(.wide))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "report.reminder.title.\(monthName)",
                systemImage: "exclamationmark.paperplane.fill"
            )
            .font(.headline)
            .foregroundStyle(.orange)

            Text("report.reminder.description")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("report.reminder.action") {
                isPresentingSubmitSheet.toggle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(32)
        // Stub sheet — replaced by SubmitReportView(month:) in Task 5.
        .sheet(isPresented: $isPresentingSubmitSheet) {
            NavigationStack {
                Text("report.submit.placeholder")
                    .navigationTitle(monthName)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
    }
}

#Preview {
    ReportReminderCard(month: Date().yearMonth())
        .padding()
        .background(Color(.systemGroupedBackground))
}
