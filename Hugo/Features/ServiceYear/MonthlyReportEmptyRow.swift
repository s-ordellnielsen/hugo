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
                Menu {
                    if !month.isFuture {
                        Button("report.submit.button", systemImage: "paperplane") {
                            isPresentingSubmitSheet = true
                        }
                    }
                    Button("navigation.add", systemImage: "plus") {
                        isPresented = true
                    }
                } label: {
                    Label("common.more", systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, -12)
                .padding(.vertical, -8)
            }

            MonthSubmissionStatusView(month: month)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 24))
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
