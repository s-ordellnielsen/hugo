import SwiftData
import SwiftUI
import UIKit

struct SubmitReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var entries: [Entry]
    @Query private var submissions: [SubmittedReport]

    @State private var model: SubmitReportFormModel
    @State private var isComposingMessage = false
    @State private var showingCopiedNotice = false
    @State private var saveErrorMessage: String?
    @State private var showingSettings = false

    @AppStorage(UserDefaultsKeys.overseerFullName) private var overseerFullName = ""
    @AppStorage(UserDefaultsKeys.overseerPhoneNumber) private var overseerPhoneNumber = ""

    init(month: YearMonth) {
        _model = State(initialValue: SubmitReportFormModel(month: month))

        let start = month.date()
        let end = month.nextMonth().date()
        _entries = Query(
            filter: #Predicate<Entry> { $0.date >= start && $0.date < end },
            sort: \Entry.date,
            order: .reverse
        )

        let targetYear = month.year
        let targetMonth = month.month
        let prev = YearMonth.previous(before: month)
        let prevYear = prev.year
        let prevMonth = prev.month
        _submissions = Query(
            filter: #Predicate<SubmittedReport> {
                ($0.year == targetYear && $0.month == targetMonth) || ($0.year == prevYear && $0.month == prevMonth)
            },
            sort: \SubmittedReport.year
        )
    }

    private var summary: MonthlyReportSummary? {
        model.summary
    }

    private var orderedResults: [ReportingLineResult] {
        let mainLines = model.results.filter { $0.line.type == .main }
        let separateLines = model.results.filter { $0.line.type == .separate }
        let pendingLines = separateLines.filter { $0.line.needsRule && $0.rule == nil }
        let resolvedLines = separateLines.filter { !$0.line.needsRule || $0.rule != nil }
        return mainLines + pendingLines + resolvedLines
    }

    private var bottomButtonTitle: LocalizedStringKey {
        MessageComposeView.canSendText ? "report.submit.send" : "report.submit.copy"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(String(model.month.monthYearString()))
                    .font(.title)
                    .fontDesign(.serif)
                    .fontWeight(.bold)

                Spacer(minLength: HugoLayout.Spacing.roomy)

                ForEach(orderedResults) { result in
                    ReportingLineCard(
                        result: result,
                        rule: Binding(
                            get: { model.rule(for: result.id) },
                            set: { model.setRule($0, for: result.id) }
                        ),
                        monthName: { $0.monthName() }
                    )
                }

                Spacer(minLength: HugoLayout.Spacing.section)

                HStack {
                    Label("report.bible-studies", systemImage: "book")
                    Spacer()
                    Text(String(summary?.totalBibleStudies ?? 0))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.compactCard))

                Spacer(minLength: HugoLayout.Spacing.section)

                Section {
                    HStack {
                        if model.hasOverseer {
                            Label(model.overseerFullName, systemImage: "person.crop.circle")
                        } else {
                            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                                Text("report.overseer.empty")
                                    .foregroundStyle(.secondary)
                                Button("report.submit.overseer.settings-link") {
                                    showingSettings = true
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.compactCard))
                } header: {
                    Text("settings.report.overseer")
                        .font(.headline)
                        .padding(.leading)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .labelReservedIconWidth(32)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("report.submit.send-message", systemImage: "arrow.up.message.fill") {
                    sendViaMessages()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .tint(.hugoAccent)
                .disabled(!model.canSend || !MessageComposeView.canSendText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("common.more", systemImage: "ellipsis") {
                    Button("report.submit.send-message", systemImage: "arrow.up.message") {
                        sendViaMessages()
                    }
                    .disabled(!model.canSend || !MessageComposeView.canSendText)

                    Button("report.submit.copy", systemImage: "document.on.document") {
                        copyReport()
                    }
                    .disabled(!model.canSend)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if MessageComposeView.canSendText {
                    sendViaMessages()
                } else {
                    copyReport()
                }
            } label: {
                Text(bottomButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.hugoAccent)
            .controlSize(.large)
            .disabled(!model.canSend)
            .padding(.horizontal)
            .padding(.vertical, HugoLayout.Spacing.compact)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                ReportSettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(role: .cancel) { showingSettings = false }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .onAppear { syncModel() }
        .onChange(of: entries) { syncModel() }
        .onChange(of: submissions) { syncModel() }
        .onChange(of: overseerFullName) { syncModel() }
        .onChange(of: overseerPhoneNumber) { syncModel() }
        .sheet(isPresented: $isComposingMessage) {
            if let content = model.preparedContent {
                MessageComposeView(
                    recipients: model.overseerPhoneNumber.isEmpty ? [] : [model.overseerPhoneNumber],
                    body: content.body
                ) { sent in
                    isComposingMessage = false
                    if sent {
                        persist()
                    }
                }
            }
        }
        .alert("report.submit.copied", isPresented: $showingCopiedNotice) {
            Button("common.ok") {
                persist()
            }
        }
        .errorAlert(message: $saveErrorMessage)
    }

    private func persist() {
        do {
            try model.persistSubmission(in: context)
            dismiss()
        } catch {
            context.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }

    private func syncModel() {
        model.load(entries: entries, submissions: submissions)
    }

    private func sendViaMessages() {
        guard model.prepareSubmission() != nil else { return }
        isComposingMessage = true
    }

    private func copyReport() {
        guard let content = model.prepareSubmission() else { return }
        UIPasteboard.general.string = content.body
        showingCopiedNotice = true
    }
}

#Preview {
    NavigationStack {
        SubmitReportView(month: Date().yearMonth())
    }
    .modelContainer(.preview)
}
