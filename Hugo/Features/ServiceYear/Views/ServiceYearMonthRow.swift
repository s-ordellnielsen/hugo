//
//  ServiceYearMonthRow.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 20/08/2026.
//

import SwiftData
import SwiftUI

struct ServiceYearMonthRow: View {
    let month: ServiceMonth
    /// The month's school credits.
    var schoolCredits: [SchoolCredit] = []

    @Namespace private var transition
    @State private var isPresentingAddEntry = false
    @State private var isPresentingSubmitSheet = false

    private var summary: MonthlyReportSummary? {
        month.summary
    }

    /// No entries and no school credit: the headline is drawn faded.
    private var isEmptyMonth: Bool {
        summary == nil && schoolCredits.isEmpty
    }

    var body: some View {
        Group {
            if month.isFuture {
                card
            } else {
                NavigationLink {
                    MonthDetailView(month: month, schoolCredits: schoolCredits)
                        .navigationTransition(.zoom(sourceID: month.id, in: transition))
                } label: {
                    card
                        .matchedTransitionSource(id: month.id, in: transition) { source in
                            source.clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
                        }
                }
                .buttonStyle(.card)
                .contentShape(.contextMenuPreview, .rect(cornerRadius: HugoLayout.CornerRadius.card))
                .contextMenu {
                    quickActions
                }
            }
        }
        .sheet(isPresented: $isPresentingAddEntry) {
            AddEntryView(seededDate: month.id.date())
        }
        .sheet(isPresented: $isPresentingSubmitSheet) {
            NavigationStack {
                SubmitReportView(month: month.id)
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading) {
            header

            if let submittedAt = month.submittedReport?.submittedDate {
                submissionStatus(submittedAt)
            }

            adjustmentNotes

            if summary != nil || !schoolCreditLines.isEmpty {
                activityBreakdown
            }
        }
        .padding(HugoLayout.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
    }

    /// The everyday actions on long-press. Everything else is on the detail page.
    @ViewBuilder
    private var quickActions: some View {
        Button("entry.add.label", systemImage: "plus") {
            isPresentingAddEntry = true
        }
        Button {
            isPresentingSubmitSheet = true
        } label: {
            Label {
                Text(month.submitActionTitle)
            } icon: {
                Image(systemName: "doc.badge.arrow.up")
            }
        }
    }
}

extension ServiceYearMonthRow {
    fileprivate var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                monthTitle
                duration
            }

            Spacer(minLength: HugoLayout.Spacing.regular)

            if !month.isFuture {
                Image(systemName: "chevron.forward")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    fileprivate var monthTitle: some View {
        Text(month.displayName)
            .font(.caption)
            .textCase(.uppercase)
            .tracking(HugoLayout.Typography.eyebrowTracking)
            .fontWeight(.semibold)
            .foregroundStyle(month.isFuture ? .tertiary : .secondary)
    }

    private var duration: some View {
        MonthHeadline(seconds: month.contribution.total, isFaded: isEmptyMonth)
    }
}

extension ServiceYearMonthRow {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    @ViewBuilder
    fileprivate func submissionStatus(_ submittedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
            Label(
                "report.status.submitted.\(Self.dateFormatter.string(from: submittedAt))",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.hugoAccent)

            if month.unreportedChange != nil {
                Label(
                    "report.status.unreported-entries",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.top, HugoLayout.Spacing.compact)
    }
}

extension ServiceYearMonthRow {
    /// Short notes explaining why reported hours differ from logged time:
    /// time transferred in, then what rounding did to the submitted report.
    @ViewBuilder
    fileprivate var adjustmentNotes: some View {
        let adjustments = month.adjustments
        if month.carriedIn != nil || adjustments != nil {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                if let carriedIn = month.carriedIn {
                    note(glyph: "↘", text: Text(carriedIn.label()))
                }
                if let adjustments {
                    if adjustments.roundedUpSeconds > 0 {
                        note(glyph: "⤒", text: Text("report.line.rounded-up.\(duration(adjustments.roundedUpSeconds))"))
                    }
                    if adjustments.roundedDownSeconds > 0 {
                        note(
                            glyph: "⤓",
                            text: Text("report.line.rounded-down.\(duration(adjustments.roundedDownSeconds))"))
                    }
                    if adjustments.transferredSeconds > 0 {
                        note(
                            glyph: "↗",
                            text: Text("report.line.transferred.\(duration(adjustments.transferredSeconds))"))
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, HugoLayout.Spacing.compact)
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        ServiceDurationFormatter.accessibilityString(from: seconds)
    }

    private func note(glyph: String, text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
            Text(verbatim: glyph)
                .accessibilityHidden(true)
            text
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

extension ServiceYearMonthRow {
    /// The month's school credit, one line per school.
    private var schoolCreditLines: [SchoolCreditLine] {
        SchoolCreditLine.lines(from: schoolCredits, in: month.id)
    }

    /// Categories, then school credit, then Bible studies, each group split
    /// from the next by a divider.
    @ViewBuilder
    fileprivate var activityBreakdown: some View {
        let categories = summary?.categories ?? []
        let schoolLines = schoolCreditLines

        Divider()

        VStack(spacing: HugoLayout.Spacing.regular) {
            ForEach(categories) { category in
                categoryRow(category)
            }

            if !schoolLines.isEmpty {
                if !categories.isEmpty {
                    sectionDivider
                }

                ForEach(schoolLines) { line in
                    schoolCreditRow(line)
                }
            }

            sectionDivider

            bibleStudiesRow(summary?.totalBibleStudies ?? 0)
        }
        .padding(.top, HugoLayout.Spacing.regular)
        .labelReservedIconWidth(HugoLayout.Size.labelReservedIconWidth)
    }

    fileprivate func categoryRow(_ category: MonthlyCategorySummary) -> some View {
        MonthBreakdownRow(
            title: Text(category.name),
            systemImage: category.iconName,
            value: ServiceDurationFormatter.hoursString(from: category.duration)
        )
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, HugoLayout.Spacing.compact)
    }

    fileprivate func schoolCreditRow(_ line: SchoolCreditLine) -> some View {
        MonthBreakdownRow(
            title: Text(School.name(forID: line.schoolID)),
            systemImage: "graduationcap",
            value: ServiceDurationFormatter.hoursString(from: TimeInterval(line.hours) * 3_600)
        )
    }

    fileprivate func bibleStudiesRow(_ count: Int) -> some View {
        MonthBreakdownRow(title: Text("report.bible-studies"), systemImage: "book", value: String(count))
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            ServiceYearMonthRow(month: ReportPreviewFixtures.monthWithActivity)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    .modelContainer(.preview)
}
