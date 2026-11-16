import SwiftData
import SwiftUI

/// Adds school credit to a month, or changes or deletes an existing credit.
/// The month is fixed; to move a credit, delete it and add it in the other month.
struct SchoolCreditFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    private let month: YearMonth
    private let credit: SchoolCredit?

    @State private var school: School
    @State private var hours: Int
    @State private var errorMessage: String?
    @State private var isDeleteConfirmationShown = false

    /// `credit` must have a school this build knows; the month card only
    /// offers editing for those.
    init(month: YearMonth, credit: SchoolCredit? = nil, defaultSchool: School) {
        self.month = month
        self.credit = credit
        let school = credit.flatMap { School(rawValue: $0.schoolID) } ?? defaultSchool
        _school = State(initialValue: school)
        _hours = State(initialValue: credit?.hours ?? school.creditHours)
    }

    /// The schools the status allows, plus the credit's own school when editing.
    private var schools: [School] {
        var schools = School.available(forStatusID: statusID)
        if !schools.contains(school) { schools.append(school) }
        return schools
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if schools.count > 1 {
                        Picker("schoolCredit.form.school", selection: $school) {
                            ForEach(schools) { school in
                                Text(school.name()).tag(school)
                            }
                        }
                    } else {
                        LabeledContent("schoolCredit.form.school", value: school.name())
                    }
                    Stepper(value: $hours, in: school.hoursRange) {
                        LabeledContent("schoolCredit.form.hours") {
                            Text(ServiceDurationFormatter.hoursString(from: TimeInterval(hours) * 3_600))
                                .monospacedDigit()
                        }
                    }
                } footer: {
                    Text("schoolCredit.form.footer.\(school.creditHours)")
                }
                if credit != nil {
                    Section {
                        Button("schoolCredit.form.delete", role: .destructive) {
                            isDeleteConfirmationShown = true
                        }
                    }
                }
            }
            .editorialNavigationTitle(credit == nil ? "schoolCredit.form.title.add" : "schoolCredit.form.title.edit")
            .navigationSubtitle(Text(month.monthYearString()))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("navigation.dismiss", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem {
                    Button("schoolCredit.form.save", systemImage: "checkmark", action: save)
                        .buttonStyle(.glassProminent)
                        .tint(.hugoAccent)
                }
            }
            .confirmationDialog(
                "schoolCredit.form.delete.confirm",
                isPresented: $isDeleteConfirmationShown,
                titleVisibility: .visible
            ) {
                Button("schoolCredit.form.delete", role: .destructive, action: delete)
            }
            .errorAlert(message: $errorMessage)
            .onChange(of: school) { _, newSchool in
                hours = min(max(hours, newSchool.hoursRange.lowerBound), newSchool.hoursRange.upperBound)
            }
        }
    }

    private func save() {
        let draft = SchoolCreditDraft(school: school, month: month, hours: hours)
        do {
            let service = SchoolCreditService(context: context)
            if let credit {
                try service.update(credit, with: draft)
            } else {
                try service.add(draft)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() {
        guard let credit else { return }
        do {
            try SchoolCreditService(context: context).delete(credit)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SchoolCreditFormView(month: YearMonth(year: 2026, month: 10), defaultSchool: .pioneerServiceSchool)
        .modelContainer(.preview)
}
