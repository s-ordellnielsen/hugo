import SwiftUI

struct MonthlyReportRow: View {
    let month: TheocraticYearMonth

    @State private var isExpanded: Bool = false
    @State private var isPresentingSubmitSheet: Bool = false

    private var summary: MonthlyReportSummary {
        // Callers only render this row for months with entries.
        month.summary!
    }

    private var submitButtonTitle: String {
        month.isSubmitted
            ? String(localized: "report.submit.resubmit")
            : String(localized: "report.submit.button")
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(summary.displayName)
                    .font(.caption)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                Spacer()
                Menu {
                    if !month.isFuture {
                        Button(submitButtonTitle, systemImage: "paperplane") {
                            isPresentingSubmitSheet = true
                        }
                    }
                    Button("report.row.menu.details", systemImage: "doc.text.magnifyingglass") {
                        isExpanded = true
                    }
                } label: {
                    Label("common.more", systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, -12)
                .padding(.vertical, -8)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(ServiceDurationFormatter.string(from: summary.totalSeconds))
                    .font(.title)
                    .fontWeight(.heavy)
                Text("reportList.row.hours.label")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }

            MonthSubmissionStatusView(month: month)

            Divider()
            VStack(spacing: 12) {
                ForEach(summary.categories) { category in
                    HStack {
                        Label(category.name, systemImage: category.iconName)
                        Spacer()
                        Text(ServiceDurationFormatter.string(from: category.duration))
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    }
                }
                Divider().padding(.vertical, 8)
                HStack {
                    Label("report.bible-studies", systemImage: "book")
                    Spacer()
                    Text(String(summary.totalBibleStudies))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 12)
            .labelReservedIconWidth(24)

        }
        .sheet(isPresented: $isExpanded) {
            NavigationStack {
                MonthlyReportDetailView(month: month)
            }
        }
        .sheet(isPresented: $isPresentingSubmitSheet) {
            NavigationStack {
                SubmitReportView(month: month.id)
                    .presentationDetents([.medium, .large])
            }
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 32))
        .tint(.primary)
        .onTapGesture {
            isExpanded.toggle()
        }
    }
}
