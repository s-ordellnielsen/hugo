import SwiftUI

struct MonthlyReportRow: View {
    let month: TheocraticYearMonth

    @State private var isExpanded: Bool = false
    @State private var isPresentingSubmitSheet: Bool = false

    private var summary: MonthlyReportSummary {
        // Callers only render this row for months with entries.
        month.summary!
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(summary.displayName)
                    .font(.caption)
                    .textCase(.uppercase)
                    .tracking(HugoLayout.Typography.eyebrowTracking)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    if !month.isFuture {
                        Section {
                            Button("report.submit.button", systemImage: "doc.badge.arrow.up") {
                                isPresentingSubmitSheet = true
                            }
                        }
                    }
                    Section {
                        Button("report.row.menu.details", systemImage: "doc.text.magnifyingglass") {
                            isExpanded = true
                        }
                    }
                } label: {
                    Label("common.more", systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .font(.body)
                        .padding(.horizontal, HugoLayout.Spacing.regular)
                        .padding(.vertical, HugoLayout.Spacing.compact)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, -HugoLayout.Spacing.regular)
                .padding(.vertical, -HugoLayout.Spacing.compact)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(ServiceDurationFormatter.string(from: summary.totalSeconds))
                    .font(.system(.title, design: .serif, weight: .bold))
                Text("reportList.row.hours.label")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }

            MonthSubmissionStatusView(month: month)

            Divider()
            VStack(spacing: HugoLayout.Spacing.regular) {
                ForEach(summary.categories) { category in
                    HStack {
                        Label(category.name, systemImage: category.iconName)
                        Spacer()
                        Text(ServiceDurationFormatter.string(from: category.duration))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Divider().padding(.vertical, HugoLayout.Spacing.compact)
                HStack {
                    Label("report.bible-studies", systemImage: "book")
                    Spacer()
                    Text(String(summary.totalBibleStudies))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, HugoLayout.Spacing.regular)
            .labelReservedIconWidth(HugoLayout.Size.labelReservedIconWidth)

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
        .padding(HugoLayout.Spacing.card)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        .onTapGesture {
            isExpanded.toggle()
        }
    }
}
