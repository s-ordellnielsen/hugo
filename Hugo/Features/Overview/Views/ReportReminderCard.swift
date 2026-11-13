import SwiftUI

/// Reminder card on the Overview tab prompting the user to submit the report
/// for `month`. Shown only when `ReportReminderSchedule.dueMonth` is non-nil
/// and the month has no real submission; disappears solely by submitting.
struct ReportReminderCard: View {
    let month: YearMonth

    @State private var isPresentingSubmitSheet = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var badgeSize: CGFloat = HugoLayout.Size.prominentSymbol

    private var monthName: String {
        month.date().formatted(.dateTime.month(.wide))
    }

    /// Badge beside the text normally; badge above the text at accessibility
    /// sizes, so the text keeps the card's full width.
    private var cardLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: HugoLayout.Spacing.regular))
            : AnyLayout(HStackLayout(alignment: .top, spacing: HugoLayout.Spacing.spacious))
    }

    var body: some View {
        Button {
            isPresentingSubmitSheet.toggle()
        } label: {
            cardLayout {
                ZStack(alignment: .center) {
                    Circle()
                        .fill(.hugoAccent)
                        .frame(width: badgeSize, height: badgeSize)
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
                        .fontWeight(.semibold)
                        .foregroundStyle(.hugoAccent)
                }
                .padding(.top, HugoLayout.Spacing.compact)
            }
            .padding(HugoLayout.Spacing.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        }
        .buttonStyle(.plain)
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
