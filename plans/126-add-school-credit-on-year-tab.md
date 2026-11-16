# Plan 126: Let regular pioneers add school credit to a month on the Year tab

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 9d5a547..HEAD -- Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift Hugo/Features/ServiceYear/Screens`
> Expected: no output. Also confirm plans 124 and 125 are committed:
> `grep -n "schoolCreditSeconds" Hugo/Features/ServiceYear/Domain/TheocraticYearReport.swift` → one match, and
> `grep -n "schoolCredits" Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` → at least one match. If not, STOP.

## Status

- **Priority**: P2
- **Effort**: M + owner (device check and CloudKit schema deploy)
- **Risk**: LOW. UI only, on top of the data and counting from plans 124 and 125.
- **Depends on**: 124, 125
- **Category**: direction
- **Planned at**: commit `9d5a547`, 2026-11-16
- **Issue**: [SLN-156](https://linear.app/sebastianln/issue/SLN-156)

## Why this matters

After plans 124 and 125, Hugo stores school credit, counts it toward the yearly goal and sends it on the report, but the user can't add any. A regular pioneer goes to Pioneer Service School about once every four or five years, so the option must be easy to find when needed and stay out of the way the rest of the time.

After this plan:
- Each month card on the Year tab has **Add School Credit** in its menu (the `…` button), but only for publisher statuses that some school applies to (today: regular pioneer) and only for past and current months.
- It opens a short form: the school (fixed when only one applies), the hours (a stepper from 1 to the school's quota, starting at the quota, 30 for Pioneer Service School), and a footer that explains how the credit counts and what to do when the school spans two months.
- A month with credit shows one line per credit in its card, e.g. "Pioneer Service School: 30 hours". Tapping the line opens the same form to change or delete it.
- The year details screen (tap the totals card) shows a **School credit** row in Totals when the year has any.

Owner decisions (2026-11-16): credit counts 100% toward the yearly goal; a school spanning two months is entered as one credit per month; the option shows only for statuses a school applies to. Existing credits stay visible and keep counting if the status changes later.

## Current state

### Month card (`Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`)

```swift
struct ServiceYearMonthRow: View {
    let month: ServiceMonth

    @State private var isPresentingDetails = false
    @State private var isPresentingAddEntry = false
    @State private var isPresentingSubmitSheet = false
    ...
    var body: some View {
        VStack(alignment: .leading) {
            header

            if month.isSubmitted, let submittedAt = month.submittedReport?.submittedAt {
                submissionStatus(submittedAt)
            }

            adjustmentNotes

            if let summary {
                activityBreakdown(summary)
            }
        }
        .padding(HugoLayout.Spacing.card)
        ...
        .sheet(isPresented: $isPresentingSubmitSheet) {
            NavigationStack {
                SubmitReportView(month: month.id)
            }
        }
    }
}
```

The menu (`moreMenu`, around line 108) has a `Section` with the submit button, then a `Section` with:

```swift
            Section {
                if !month.isFuture {
                    Button(
                        "entry.add.label",
                        systemImage: "plus"
                    ) {
                        isPresentingAddEntry = true
                    }
                }

                if summary != nil {
                    Button(
                        "report.row.menu.details",
                        ...
```

The headline duration (`duration`, around line 82) styles itself on `summary == nil`:

```swift
            Text(headline.value, format: .number)
                .font(.system(.title, design: .serif, weight: .bold))
                .foregroundStyle(summary == nil ? .tertiary : .primary)
            Text(unitLabel)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(summary == nil ? .tertiary : .secondary)
```

`headline` is `HeadlineDuration(seconds: month.contribution.total)`; after plan 125, `total` includes school credit.

`adjustmentNotes` shows small `.caption`, `.secondary` notes with `.padding(.top, HugoLayout.Spacing.compact)`.

The only caller is `ServiceYearPageView.swift:62`: `ServiceYearMonthRow(month: month)` inside `ForEach(report.months) { month in ... }`, plus the `#Preview` at the bottom of the row file. After plan 125, `ServiceYearPageView` has `@Query private var schoolCredits: [SchoolCredit]`.

### Year details (`Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift`)

```swift
    private var totalsSection: some View {
        Section("year.detail.section.totals") {
            LabeledContent("monthlyReport.detail.largeTotal.main.label") {
                duration(report.mainDuration)
            }
            LabeledContent("monthlyReport.detail.largeTotal.separate.label") {
                duration(report.separateDuration)
            }
            LabeledContent("monthlyReport.detail.largeTotal.total.label") {
                duration(report.totalSeconds)
            }
            ...
```

After plan 125, `report.schoolCreditSeconds` exists.

### Form exemplar (`Hugo/Features/Planner/Screens/PlanFormView.swift`)

Copy its structure: `NavigationStack { Form { ... } }`, `.editorialNavigationTitle(...)`, a leading `Button("navigation.dismiss", systemImage: "xmark", role: .cancel) { dismiss() }`, a trailing save button with `.buttonStyle(.glassProminent).tint(.hugoAccent)`, a destructive delete `Section` shown only when editing, a `.confirmationDialog` for delete, `.errorAlert(message:)` for errors, and a service doing the writes:

```swift
    private func save() {
        guard let draft = form.draft() else { return }
        do {
            let service = PlanService(context: context)
            if let plan {
                try service.update(plan, with: draft)
            } else {
                try service.add(draft)
            }
            dismiss()
        } catch {
            form.validationMessage = error.localizedDescription
        }
    }
```

### From plans 124 and 125

- `School` (`Hugo/Features/SchoolCredits/Domain/School.swift`): `School(rawValue:)`, `.creditHours`, `.hoursRange`, `.name(locale:)`, `School.name(forID:locale:)`, `School.available(forStatusID:)`.
- `SchoolCreditService(context:)` with `add(_:)`, `update(_:with:)`, `delete(_:)`; `SchoolCreditDraft(school:month:hours:)`; throws `ValidationError.hoursOutOfRange`.
- `SchoolCredit` model: `schoolID`, `yearMonth`, `hours`.

### Other facts

- Publisher status is read with `@AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""` (see `ServiceYearPageView`).
- `YearMonth.monthYearString(locale:calendar:)` returns e.g. "October 2026" (used in `SubmitReportView`).
- `ServiceDurationFormatter.hoursString(from: TimeInterval)` gives e.g. "30 hours".
- English menu items use title case ("Add Entry", "View Details"); Danish uses sentence case.
- The Year tab is called "Year" / "Tjenesteår".
- Simple views may own local `@State`; no view model is needed for a two-field form (AGENTS.md: "Pure value logic does not need a ViewModel. Simple views may own local state").

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0 |
| Build | `xcodebuild build -project Hugo.xcodeproj -scheme Debug -destination 'generic/platform=iOS Simulator' -quiet 2>&1 \| grep -c "error:"` | `0` |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |

## Scope

**In scope:**
- `Hugo/Features/ServiceYear/Screens/SchoolCreditFormView.swift` (create)
- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift`
- `Hugo/Features/ServiceYear/Views/ServiceYearPageView.swift` (one call site)
- `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift` (one row)
- `Hugo/Resources/Localizable.xcstrings`

**Out of scope:**
- Any domain, service, schema or report file. Plans 124 and 125 did those; if something there seems wrong, STOP and report.
- `SubmitReportView` (plan 125 already shows credits there).
- A help article. The form footer explains the rule.
- Showing credits on the Overview or the Planner.

## Git workflow

- Work on `main` directly. No branch, no worktree.
- One commit after `Scripts/verify.sh` exits 0: `feat: add school credit to a month from the Year tab`.
- Never stage `.claude/`, `plans/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Do not push.

## Steps

### Step 1: Strings

Add to `Hugo/Resources/Localizable.xcstrings`, each in sorted position, `en` and `da` `"state" : "translated"`, with the comment:

| Key | English | Danish | Comment |
|---|---|---|---|
| `schoolCredit.menu.add` | Add School Credit | Tilføj skolekredit | Menu item on a month card on the Year tab. Opens the school credit form. |
| `schoolCredit.form.title.add` | Add School Credit | Tilføj skolekredit | Title of the form that adds school credit to a month. |
| `schoolCredit.form.title.edit` | School Credit | Skolekredit | Title of the form that changes an existing school credit. |
| `schoolCredit.form.school` | School | Skole | Label of the school row in the school credit form. |
| `schoolCredit.form.hours` | Hours | Timer | Label of the hours stepper in the school credit form. |
| `schoolCredit.form.footer.%lld` | This school gives up to %lld hours. They count toward your yearly goal like field service and are sent on this month's report. If the school ran over two months, add credit to each month. | Skolen giver op til %lld timer. De tæller med mod dit årsmål ligesom almindelige timer og bliver sendt med denne måneds rapport. Hvis skolen strakte sig over to måneder, så tilføj kredit i hver måned. | Footer in the school credit form. The argument is the school's maximum number of hours. |
| `schoolCredit.form.save` | Save | Gem | Save button in the school credit form. |
| `schoolCredit.form.delete` | Delete School Credit | Slet skolekredit | Destructive button in the school credit form. |
| `schoolCredit.form.delete.confirm` | Delete this school credit? | Vil du slette denne skolekredit? | Confirmation title before deleting a school credit. |
| `year.detail.schoolCredit` | School credit | Skolekredit | Row label in Totals on the year details screen: hours of school credit in the year. |

**Verify**: `python3 -I -c "import json;d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];k=[x for x in d if x.startswith('schoolCredit.menu') or x.startswith('schoolCredit.form') or x=='year.detail.schoolCredit'];print(len(k), all(d[x]['localizations'][l]['stringUnit']['value'] for x in k for l in ('en','da')))"` → `10 True`.

### Step 2: The form

Create `Hugo/Features/ServiceYear/Screens/SchoolCreditFormView.swift`:

```swift
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
```

Check before building:
- `grep -rn "func errorAlert" Hugo/DesignSystem` → confirm it takes `message: Binding<String?>`. If the type differs, match `PlanFormView`'s use.
- `grep -n "func monthYearString" Hugo/Domain/YearMonth.swift` → confirm the name and that its parameters have defaults.
- `School` must be `Hashable` for `Picker`/`.tag`; a `String` raw-value enum is.

**Verify**: build → `0` errors.

### Step 3: Month card

In `ServiceYearMonthRow.swift`:

1. Add properties:

```swift
    /// The month's school credits.
    var schoolCredits: [SchoolCredit] = []

    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @State private var isPresentingAddSchoolCredit = false
    @State private var editingSchoolCredit: SchoolCredit?
```

   Put `var schoolCredits` right after `let month: ServiceMonth` so the memberwise initializer reads `ServiceYearMonthRow(month:schoolCredits:)`.

2. Add a computed property:

```swift
    /// The school offered first when adding credit, or nil when the status has none.
    private var defaultSchool: School? {
        School.available(forStatusID: statusID).first
    }
```

3. In `body`, after `adjustmentNotes`, add `schoolCreditNotes`. Add the sheets after the existing `.sheet(isPresented: $isPresentingSubmitSheet)`:

```swift
        .sheet(isPresented: $isPresentingAddSchoolCredit) {
            if let defaultSchool {
                SchoolCreditFormView(month: month.id, defaultSchool: defaultSchool)
            }
        }
        .sheet(item: $editingSchoolCredit) { credit in
            SchoolCreditFormView(
                month: month.id, credit: credit, defaultSchool: School(rawValue: credit.schoolID) ?? .pioneerServiceSchool)
        }
```

4. Add the notes view in a new extension:

```swift
extension ServiceYearMonthRow {
    /// One line per school credit. Credits of schools this build knows open
    /// the form when tapped; others are shown as plain text.
    @ViewBuilder
    fileprivate var schoolCreditNotes: some View {
        if !schoolCredits.isEmpty {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                ForEach(schoolCredits) { credit in
                    let text = Text(
                        verbatim:
                            "\(School.name(forID: credit.schoolID)): \(ServiceDurationFormatter.hoursString(from: TimeInterval(credit.hours) * 3_600))"
                    )
                    if School(rawValue: credit.schoolID) != nil {
                        Button {
                            editingSchoolCredit = credit
                        } label: {
                            Label { text } icon: { Image(systemName: "graduationcap") }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Label { text } icon: { Image(systemName: "graduationcap") }
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, HugoLayout.Spacing.compact)
        }
    }
}
```

5. In `moreMenu`, in the `Section` that holds "entry.add.label", right after the Add Entry button's `if !month.isFuture { ... }` block, add:

```swift
                if !month.isFuture, defaultSchool != nil {
                    Button(
                        "schoolCredit.menu.add",
                        systemImage: "graduationcap"
                    ) {
                        isPresentingAddSchoolCredit = true
                    }
                }
```

6. In `duration`, replace both `summary == nil` conditions with `isEmptyMonth`, and add:

```swift
    /// No entries and no school credit: the headline is drawn faded.
    private var isEmptyMonth: Bool {
        summary == nil && schoolCredits.isEmpty
    }
```

**Verify**: build → `0` errors.

### Step 4: Pass the month's credits from the Year page

In `ServiceYearPageView.swift`, change `ServiceYearMonthRow(month: month)` to:

```swift
                    ServiceYearMonthRow(
                        month: month,
                        schoolCredits: schoolCredits.filter { $0.yearMonth == month.id }
                    )
```

### Step 5: Year details total

In `ServiceYearDetailView.totalsSection`, between the separate row and the total row, add:

```swift
            if report.schoolCreditSeconds > 0 {
                LabeledContent("year.detail.schoolCredit") {
                    duration(report.schoolCreditSeconds)
                }
            }
```

**Verify**: `Scripts/verify.sh` → exit 0.

### Step 6: Commit

Commit only the in-scope files with the message from "Git workflow".

## Test plan

This plan is UI only; the logic it calls is tested in plans 124 and 125 (`SchoolCreditServiceTests`, `SchoolTests`, `ServiceMonthTests`). No new unit tests. `Scripts/verify.sh` must pass, and the `#Preview` for `SchoolCreditFormView` must compile.

Owner checks on a device (record results in the plan's status row):
1. Publisher status Regular Pioneer: a past month's `…` menu shows "Add School Credit"; a future month's doesn't. With status Publisher, no month shows it.
2. Add 30 hours to last month. The month card's number grows by 30 and shows "Pioneer Service School: 30 hours". The totals card's "Counted toward goal" grows by 30 even if that month already passed its goal.
3. Tap the credit line, change it to 15, save; then delete it. The card updates each time.
4. Add credit to a submitted month: the card shows "Changed since the report was submitted". Open Submit Report: the credit row and its note appear, and the message contains "Pioneer Service School: 30 h" (Danish: "Pionerskolen: 30 t").
5. VoiceOver reads the credit line and the stepper's hours; Dynamic Type at the largest size doesn't clip the form.
6. Danish: check that "Pionerskolen" and "Skolekredit" are the words you want.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "schoolCredit.menu.add" Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift` → 1 match
- [ ] `grep -n "year.detail.schoolCredit" Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift` → 1 match
- [ ] `test -f Hugo/Features/ServiceYear/Screens/SchoolCreditFormView.swift` → exit 0
- [ ] `git status --short` shows no modified files outside the in-scope list, except the owner's `Debug.xcscheme`

## STOP conditions

- Plans 124 or 125 aren't committed (drift check).
- The month row file differs from the excerpts (for example the menu no longer has the Add Entry button).
- `SchoolCredit` can't be used with `.sheet(item:)` (not `Identifiable`). Report the error instead of wrapping it.
- `errorAlert(message:)` or `monthYearString()` don't exist with a shape you can match.

## Maintenance notes

- **CloudKit deploy (owner, before the TestFlight build):** in a Development build, add a school credit and submit that month's report, so `CD_SchoolCredit` (all fields) and `CD_SubmittedReport.CD_schoolCreditHours` exist in the Development schema. Then deploy the schema to Production in CloudKit Console. Without this, saving a credit on Production fails and can stop all sync on the device (as `CD_Plan.CD_startMinute` did in build 120).
- A second school only needs a `School` case (plan 124). The form shows a picker by itself once a status has more than one school.
- If the owner confirms that a split school must be divided equally, add that as guidance in the footer text, or as a "Split over two months" option in this form.
