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
    @State private var showingRoundingHelp = false
    @State private var pendingSend: (() -> Void)?

    @AppStorage(UserDefaultsKeys.overseerFullName) private var overseerFullName = ""
    @AppStorage(UserDefaultsKeys.overseerPhoneNumber) private var overseerPhoneNumber = ""

    init(month: YearMonth) {
        _model = State(initialValue: SubmitReportFormModel(month: month))

        let range = month.dateRange()
        let start = range.lowerBound
        let end = range.upperBound
        _entries = Query(
            filter: #Predicate<Entry> { $0.date >= start && $0.date < end },
            sort: \Entry.date,
            order: .reverse
        )

        let targetYear = month.year
        let targetMonth = month.month
        let next = month.nextMonth()
        let nextYear = next.year
        let nextMonth = next.month
        _submissions = Query(
            filter: #Predicate<SubmittedReport> {
                ($0.year == targetYear && $0.month == targetMonth)
                    || ($0.year == nextYear && $0.month == nextMonth)
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

                if model.results.contains(where: { $0.line.needsRule }) {
                    Button("report.rounding.help.link", systemImage: "questionmark.circle") {
                        showingRoundingHelp = true
                    }
                    .font(.subheadline)
                    .padding(.top, HugoLayout.Spacing.compact)
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
                    confirmIfNeeded(sendViaMessages)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .tint(.hugoAccent)
                .disabled(!model.canSend || !MessageComposeView.canSendText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("common.more", systemImage: "ellipsis") {
                    Button("report.submit.send-message", systemImage: "arrow.up.message") {
                        confirmIfNeeded(sendViaMessages)
                    }
                    .disabled(!model.canSend || !MessageComposeView.canSendText)

                    Button("report.submit.copy", systemImage: "document.on.document") {
                        confirmIfNeeded(copyReport)
                    }
                    .disabled(!model.canSend)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if MessageComposeView.canSendText {
                    confirmIfNeeded(sendViaMessages)
                } else {
                    confirmIfNeeded(copyReport)
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
        .sheet(isPresented: $showingRoundingHelp) { HelpView(for: "RoundingRule") }
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
                    } else {
                        model.cancelPreparedSubmission()
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
        .confirmationDialog(
            "report.submit.next-month-warning.message",
            isPresented: Binding(get: { pendingSend != nil }, set: { if !$0 { pendingSend = nil } }),
            titleVisibility: .visible
        ) {
            Button("report.submit.next-month-warning.continue") {
                let action = pendingSend
                pendingSend = nil
                action?()
            }
            Button(role: .cancel) { pendingSend = nil }
        }
    }

    private func confirmIfNeeded(_ action: @escaping () -> Void) {
        if model.changesSubmittedNextMonth {
            pendingSend = action
        } else {
            action()
        }
    }

    private func persist() {
        do {
            var stored: SubmittedReport?
            try context.performIsolatedChange {
                stored = try model.persistSubmission(using: ReportSubmissionService(context: context))
            }
            guard stored != nil else {
                saveErrorMessage = String(localized: "report.submit.not-saved")
                return
            }
            dismiss()
        } catch {
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
