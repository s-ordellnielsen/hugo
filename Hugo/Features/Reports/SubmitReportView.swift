import SwiftData
import SwiftUI
import UIKit

struct SubmitReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @Query(sort: \SubmittedReport.year) private var submissions: [SubmittedReport]

    @State private var model: SubmitReportFormModel
    @State private var isComposingMessage = false
    @State private var showingCopiedNotice = false
    @State private var saveErrorMessage: String?
    @State private var showingSettings = false

    init(month: YearMonth) {
        _model = State(initialValue: SubmitReportFormModel(month: month))
    }

    private var summary: MonthlyReportSummary? {
        model.summary
    }

    var body: some View {
        List {
            Section {
                if let summary {
                    ForEach(summary.categories.filter { $0.type == .main }) { category in
                        computedRow(category)
                    }
                    ForEach(summary.categories.filter { $0.type != .main }) { category in
                        computedRow(category)
                    }
                }

                if model.carriedIn > 0 {
                    HStack {
                        Label("report.submit.carried-in", systemImage: "arrow.down.right")
                        Spacer()
                        Text("+\(ServiceDurationFormatter.string(from: model.carriedIn))")
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Label("report.bible-studies", systemImage: "book")
                    Spacer()
                    Text(String(summary?.totalBibleStudies ?? 0))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("settings.report.rounding-rule", selection: $model.selectedRule) {
                    ForEach(RoundingRule.allCases) { rule in
                        Text(rule.localizedName).tag(rule)
                    }
                }
                .pickerStyle(.navigationLink)

                if model.computation.carriedOutSeconds > 0 {
                    HStack {
                        Label("report.submit.carried-out", systemImage: "arrow.up.right.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                        Spacer()
                        Text("+\(ServiceDurationFormatter.string(from: model.computation.carriedOutSeconds))")
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    }
                } else if model.computation.roundedUpSeconds > 0 {
                    HStack {
                        Label("report.submit.rounded-up", systemImage: "arrow.up.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                        Spacer()
                        Text("+\(ServiceDurationFormatter.string(from: model.computation.roundedUpSeconds))")
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    }
                } else if model.computation.roundedDownSeconds > 0 {
                    HStack {
                        Label("report.submit.rounded-down", systemImage: "arrow.down.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                        Spacer()
                        Text("−\(ServiceDurationFormatter.string(from: model.computation.roundedDownSeconds))")
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                if model.hasOverseer {
                    Label(model.overseerFullName, systemImage: "person.crop.circle")
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("report.overseer.empty")
                            .foregroundStyle(.secondary)
                        Button("report.submit.overseer.settings-link") {
                            showingSettings = true
                        }
                    }
                }
            } header: {
                Text("settings.report.overseer")
            }

            Section {
                Button("report.submit.copy") {
                    copyReport()
                }
                .disabled(!model.isSubmittable)
            } footer: {
                if !MessageComposeView.canSendText {
                    Text("report.submit.unavailable")
                } else if !model.hasOverseer {
                    Text("report.submit.no-recipient-hint")
                }
            }
        }
        .navigationTitle(model.month.monthYearString())
        .navigationSubtitle("report.submit.subtitle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("navigation.dismiss", systemImage: "xmark", role: .cancel) { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                sendViaMessages()
            } label: {
                Text("report.submit.send")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .disabled(!model.isSubmittable || !MessageComposeView.canSendText)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .presentationDetents([.large])
        }
        .onAppear { syncModel() }
        .onChange(of: entries) { syncModel() }
        .onChange(of: submissions) { syncModel() }
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

    private func computedRow(_ category: MonthlyCategorySummary) -> some View {
        HStack {
            Label(category.name, systemImage: category.iconName)
            Spacer()
            Text("\(model.computation.categoryHours[category.id] ?? 0) \(String(localized: "report.hours.unit"))")
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
        }
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
