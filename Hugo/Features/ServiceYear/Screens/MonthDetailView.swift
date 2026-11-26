import SwiftData
import SwiftUI

/// One month of the Service Year tab: its total and report status, a breakdown by
/// category, school and Bible studies, and its entries. Holds the month's
/// actions: submit the report, add an entry, and add, change or delete
/// school credit. Pushed from the month card.
struct MonthDetailView: View {
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    let month: ServiceMonth
    /// The month's school credits.
    var schoolCredits: [SchoolCredit] = []

    @State private var isPresentingAddEntry = false
    @State private var isPresentingSubmitSheet = false
    @State private var addingSchool: School?
    @State private var editingSchoolCredit: SchoolCredit?

    /// The schools the publisher status may add credit for.
    private var availableSchools: [School] {
        School.available(forStatusID: statusID)
    }

    /// The month's school credits, oldest first.
    private var sortedSchoolCredits: [SchoolCredit] {
        schoolCredits.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            submitSection
            summarySection
            MonthEntriesSection(month: month)
        }
        .readableListWidth()
        .editorialNavigationTitle(month.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addMenu
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
        .sheet(item: $addingSchool) { school in
            SchoolCreditFormView(month: month.id, defaultSchool: school)
        }
        .sheet(item: $editingSchoolCredit) { credit in
            SchoolCreditFormView(
                month: month.id, credit: credit,
                defaultSchool: School(rawValue: credit.schoolID) ?? .pioneerServiceSchool)
        }
    }
}

extension MonthDetailView {
    /// The month's total, whether its report was sent and any change since,
    /// drawn on the page background like a large title. It is the submit
    /// section's header, not a row: rows are clipped to the section's rounded
    /// shape even with a clear background, which cut off the status icon.
    private var header: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            MonthHeadline(
                seconds: month.contribution.total,
                size: .large,
                isFaded: month.summary == nil && schoolCredits.isEmpty
            )
            reportStatus
            if let change = month.unreportedChange {
                statusLine(
                    Text(bannerKey(for: change)),
                    systemImage: "exclamationmark.triangle.fill",
                    iconStyle: .yellow,
                    textStyle: .secondary
                )
            }
        }
        .textCase(nil)
        .padding(.bottom, HugoLayout.Spacing.regular)
    }

    @ViewBuilder
    private var reportStatus: some View {
        if let submittedAt = month.submittedReport?.submittedDate {
            statusLine(
                Text("report.status.submitted.\(submittedAt.formatted(date: .abbreviated, time: .omitted))"),
                systemImage: "checkmark.circle.fill",
                iconStyle: .hugoAccent,
                textStyle: .hugoAccent
            )
        } else {
            statusLine(
                Text("monthDetail.status.notSubmitted"),
                systemImage: "circle.dashed",
                iconStyle: .secondary,
                textStyle: .secondary
            )
        }
    }

    /// An icon and text under the total. Built from an `HStack`, not a
    /// `Label`: a list row gives a `Label`'s icon a fixed-width slot, which
    /// clips the symbol and leaves a wide gap before the text.
    private func statusLine(
        _ text: Text, systemImage: String, iconStyle: some ShapeStyle, textStyle: some ShapeStyle
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
            Image(systemName: systemImage)
                .foregroundStyle(iconStyle)
            text
                .foregroundStyle(textStyle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    /// The header, then the submit action: prominent until the report is
    /// sent and again whenever the month changes after it was sent.
    fileprivate var submitSection: some View {
        Section {
            submitButton
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        } header: {
            header
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        let button = Button {
            isPresentingSubmitSheet = true
        } label: {
            Label {
                Text(month.submitActionTitle)
            } icon: {
                Image(systemName: "doc.badge.arrow.up")
            }
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)

        if month.isSubmitted, month.unreportedChange == nil {
            button.buttonStyle(.glass)
        } else {
            button
                .buttonStyle(.glassProminent)
                .tint(.hugoAccent)
        }
    }

    private func bannerKey(for change: ServiceMonth.UnreportedChange) -> LocalizedStringKey {
        switch change {
        case .newEntries: "report.detail.unreported.banner"
        case .changedTotals: "report.detail.changed.banner"
        }
    }
}

extension MonthDetailView {
    /// Categories, then school credit, then Bible studies. Tapping a school
    /// credit opens its form, where it can be changed or deleted.
    fileprivate var summarySection: some View {
        Section {
            ForEach(month.summary?.categories ?? []) { category in
                MonthBreakdownRow(
                    title: Text(category.name),
                    systemImage: category.iconName,
                    value: ServiceDurationFormatter.hoursString(from: category.duration)
                )
            }

            ForEach(sortedSchoolCredits) { credit in
                schoolCreditRow(credit)
            }

            MonthBreakdownRow(
                title: Text("report.bible-studies"),
                systemImage: "book",
                value: String(month.summary?.totalBibleStudies ?? 0)
            )
        } header: {
            Text("monthDetail.section.summary")
        } footer: {
            adjustmentsFooter
        }
    }

    @ViewBuilder
    private func schoolCreditRow(_ credit: SchoolCredit) -> some View {
        let row = MonthBreakdownRow(
            title: Text(School.name(forID: credit.schoolID)),
            systemImage: "graduationcap",
            value: ServiceDurationFormatter.hoursString(from: TimeInterval(credit.hours) * 3_600)
        )
        // Credits of a school added by a newer build can't be edited here.
        if School(rawValue: credit.schoolID) != nil {
            Button {
                editingSchoolCredit = credit
            } label: {
                row.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("monthDetail.schoolCredit.a11y.hint")
        } else {
            row
        }
    }

    /// Why the reported hours differ from the logged time, as on the month card.
    @ViewBuilder
    private var adjustmentsFooter: some View {
        if let adjustments = month.adjustments {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                if adjustments.roundedUpSeconds > 0 {
                    Text("report.line.rounded-up.\(spoken(adjustments.roundedUpSeconds))")
                }
                if adjustments.roundedDownSeconds > 0 {
                    Text("report.line.rounded-down.\(spoken(adjustments.roundedDownSeconds))")
                }
                if adjustments.transferredSeconds > 0 {
                    Text("report.line.transferred.\(spoken(adjustments.transferredSeconds))")
                }
            }
        }
    }

    private func spoken(_ seconds: TimeInterval) -> String {
        ServiceDurationFormatter.accessibilityString(from: seconds)
    }
}

extension MonthDetailView {
    /// Adds an entry, or offers entry and school when the status has a school.
    @ViewBuilder
    fileprivate var addMenu: some View {
        if availableSchools.isEmpty {
            Button("entry.add.label", systemImage: "plus") {
                isPresentingAddEntry = true
            }
        } else {
            Menu("common.add", systemImage: "plus") {
                Button("entry.add.label", systemImage: "clock") {
                    isPresentingAddEntry = true
                }
                Menu("schoolCredit.menu.add", systemImage: "graduationcap") {
                    ForEach(availableSchools) { school in
                        Button(school.name()) {
                            addingSchool = school
                        }
                    }
                }
            }
        }
    }
}

#Preview("With entries") {
    NavigationStack {
        MonthDetailView(month: ReportPreviewFixtures.monthWithActivity)
    }
    .modelContainer(.preview)
}

#Preview("Empty month") {
    NavigationStack {
        MonthDetailView(month: ReportPreviewFixtures.emptyMonth)
    }
    .modelContainer(.preview)
}
