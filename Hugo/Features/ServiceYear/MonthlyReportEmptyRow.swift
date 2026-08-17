import SwiftData
import SwiftUI

struct MonthlyReportEmptyRow: View {
    let month: TheocraticYearMonth

    @State private var isPresented: Bool = false
    @State private var isPresentingSubmitSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
            HStack {
                Text(month.displayName)
                    .font(.caption)
                    .textCase(.uppercase)
                    .tracking(HugoLayout.Typography.eyebrowTracking)
                    .fontWeight(.semibold)
                    .foregroundStyle(month.isFuture ? .tertiary : .secondary)
                Spacer()
                if !month.isFuture && !month.isSubmitted {
                    Text("year.month.empty")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
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
                            isPresented = true
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

            MonthSubmissionStatusView(month: month)
        }
        .padding(.horizontal, HugoLayout.Spacing.card)
        .padding(.vertical, HugoLayout.Spacing.roomy)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.compactCard))
        .accessibilityElement(children: .contain)
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
            .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    MonthlyReportEmptyRow(month: ReportPreviewFixtures.emptyMonth)
        .modelContainer(.preview)
}
