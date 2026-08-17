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
        VStack(alignment: .trailing, spacing: HugoLayout.Spacing.card) {
            HStack(alignment: .top, spacing: HugoLayout.Spacing.spacious) {
                ZStack(alignment: .center) {
                    Circle()
                        .fill(.hugoAccent)
                        .frame(width: HugoLayout.Size.prominentSymbol, height: HugoLayout.Size.prominentSymbol)
                    Image(systemName: "doc.badge.clock.fill")
                        .foregroundStyle(.white)
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
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
                .padding(.top, HugoLayout.Spacing.compact)
            }
        }
        .padding(HugoLayout.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
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
