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
        VStack(alignment: .trailing, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                ZStack(alignment: .center) {
                    Circle()
                        .fill(.hugoAccent)
                        .frame(width: 64, height: 64)
                    Image(systemName: "doc.badge.clock.fill")
                        .foregroundStyle(.white)
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("report.reminder.title.\(monthName)")
                        .font(.headline)
                        .foregroundStyle(.hugoAccent)

                    Text("report.reminder.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("report.reminder.callToAction")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 32))
        .onTapGesture {
            isPresentingSubmitSheet.toggle()
        }
        .sheet(isPresented: $isPresentingSubmitSheet) {
            NavigationStack {
                SubmitReportView(month: month)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            ReportReminderCard(month: Date().yearMonth())
                .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
