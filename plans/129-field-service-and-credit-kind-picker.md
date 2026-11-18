# Plan 129: Call the category kinds Field Service and Credit, and pick the kind on two cards that explain it

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat c918888..HEAD -- Hugo/Features/Categories Hugo/Persistence/Legacy/TrackerType.swift Hugo/Features/Reports/Views/ReportingLineCard.swift Hugo/Features/Planner/Domain/PlannerMonthStatus.swift HugoTests/Features/Categories`
> Expected: only the changes from plan 128 (in `AddCategoryView.swift`,
> `CategoryDetailView.swift` and the deleted `CategoryAdvancedOptionsView.swift`).
> Confirm plan 128 landed: `grep -rn "allow-bible-studies\|CategoryAdvancedOptionsView" Hugo --include='*.swift'` → no output, and
> `grep -n "tracker.type == .main" Hugo/Features/Entries/Domain/EntryCategory.swift` → one match. If not, STOP.
> Also run `git status --short -- Hugo/Resources/Localizable.xcstrings CONTEXT.md` → no output. If either has uncommitted changes, STOP.

## Status

- **Priority**: P2
- **Effort**: L + owner (device check in English and Danish, VoiceOver, largest text size)
- **Risk**: MED. Many user-facing strings change in two languages, and a new control replaces a system `Picker`. No persisted name, schema or report message text changes.
- **Depends on**: 128 (the Bible studies toggle is gone, so the picker is where the rule is explained)
- **Category**: direction
- **Planned at**: commit `c918888`, 2026-11-18
- **Issue**: pending (to be created in Linear)

## Why this matters

Every category is either "Main" ("Primær") or "Separate" ("Separat"). A tester didn't know what that meant. The owner decided (2026-11-18) to name the kinds after what publishers already call them: **Field Service** ("Forkyndelse") and **Credit** ("Godtgørelse"). Hour credits (LDC, Bethel) and school credits are both credits in the end.

The kind is chosen today with a plain inline `Picker` and one long footer sentence. After this plan it is chosen on two cards. Each card has a symbol, the kind's name, one plain sentence and an example. Under the cards, three short lines say what the chosen kind means: where the time goes on the report, how it counts toward the yearly goal, and whether entries can have Bible studies. Plan 128 removed the Bible studies toggle, so this is where that rule is explained.

The same cards replace the kind `Picker` on the category detail screen, where the kind stays editable, with a footer that says what changing it does.

Persisted names do not change: `TrackerType.main` and `.separate`, `Tracker`, every schema file and every stored raw value stay as they are. The text of the report message sent to the group overseer does not change either (see "Report message" below).

## Current state

### The kind type (`Hugo/Persistence/Legacy/TrackerType.swift:10-28`)

```swift
nonisolated enum TrackerType: String, Codable, Comparable, Identifiable, CaseIterable {
    case main
    case separate

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .main: return String(localized: "tracker.outputtype.main.label")
        case .separate: return String(localized: "tracker.outputtype.separate.label")
        }
    }

    var description: String {
        switch self {
        case .main: return String(localized: "tracker.outputtype.main.description")
        case .separate: return String(localized: "tracker.outputtype.separate.description")
        }
    }
```

`label` is shown as the section headers of `CategoryListView` and `CategoryPicker` (`Section(type.label)`) and as the picker options. `description` is shown only in the picker footers of `AddCategoryView` and `CategoryDetailView`. The raw values `main` and `separate` are stored in SwiftData and CloudKit; never change them.

### The pickers

`Hugo/Features/Categories/Screens/AddCategoryView.swift` (after plan 128):

```swift
                Section {
                    Picker("tracker.type.label.long", selection: $type) {
                        ForEach(TrackerType.allCases) { trackerType in
                            Text(trackerType.label).tag(trackerType)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("tracker.type.label.long")
                } footer: {
                    Text(type.description)
                }
```

`@State private var type: TrackerType = .main` holds the choice. The sheet is presented from `CategoryListView` and `CategoryPicker`.

`Hugo/Features/Categories/Screens/CategoryDetailView.swift` (after plan 128): the kind is **editable today**.

```swift
            Section {
                Picker("tracker.type.label.long", selection: $tracker.type) {
                    ForEach(TrackerType.allCases) { trackerType in
                        Text(trackerType.label).tag(trackerType)
                    }
                }
                .pickerStyle(.navigationLink)
                .labelsHidden()
            } footer: {
                Text(tracker.type.description)
            }
```

`tracker` is a `@Bindable` SwiftData model, so a change is written at once.

What changing the kind of an existing category does today (keep it that way):
- Every month that is not submitted is computed from entries, so its lines and counted time change at once.
- A submitted month keeps its submitted hours in the year total. If its entries' lines no longer match the report, `ServiceMonth.unreportedChange` (`Hugo/Features/Reports/Domain/ServiceMonth.swift:136-166`) reports `.changedTotals`, and the month card shows that it changed since the report was submitted.
- Entry snapshots are refreshed when the category is deleted (`CategoryDeletionService` calls `entry.refreshStoredTracker()`), so a snapshot gets the latest kind.
- Since plan 128, Bible studies follow the kind; existing counts are never cleared.

### Rules the cards must state (verified in code)

- Field Service time: all of it goes on the one Field Service line (`ReportingLineCalculator`), and all of it counts toward the yearly goal.
- Credit time: one line per category, named after the category (`ReportComposer.message`, `Hugo/Features/Reports/Domain/ReportComposer.swift:58-66`). It counts toward the goal only until the month reaches the monthly goal plus the allowance (`Hugo/Features/ServiceYear/Domain/YearlyGoalRule.swift`):

```swift
    func creditedSeconds(main: TimeInterval, separate: TimeInterval) -> TimeInterval {
        let room = max(0, monthlyGoalSeconds + separateAllowanceSeconds - main)
        return main + min(separate, room)
    }
```

- Only a status with a yearly goal has a `YearlyGoalRule` (`PublisherStatus.yearlyGoalRule`). Today that is only regular pioneer: 600 hours a year, monthly goal 50, `separateAllowanceHours: 5`, so the limit is 55 hours (`Hugo/Features/PublisherStatus/Domain/PublisherStatus.swift:57-61`).
- Bible studies (plan 128): `EntryCategory.allowsBibleStudies` is `tracker.type == .main`.

### Report message (not changed by this plan)

`ReportComposer.message` writes the Field Service line with the key `report.compose.field-service` (English "Field Service", Danish "Timer") and each Credit line with the category's own name. No kind label goes into the message. This plan leaves `report.compose.field-service` alone, so **nothing the overseer receives changes**. The Danish "Timer" is the word on the congregation's report form; keep it.

`category.default.label` (English "Field Service", Danish "Tjeneste") is also written into entry snapshots: `ReportSubmissionService.swift:93` names carried-in Field Service entries with it, and `HugoMigrationPlan.swift:345` uses it in a migration. Changing its Danish value would give new carried-in entries a different snapshot name from older ones (the snapshot key includes the name, so they would group apart). Leave its value alone. Its only display use, the Field Service line title in `ReportingLineCard.swift:57`, switches to another key in Step 3.

### Every user-facing string about the kinds (from the catalog at `c918888`)

Produced by searching `Hugo/Resources/Localizable.xcstrings` for Main/Primær, Separate/Separat, "other categories", "Other"/"Andet", "Tjeneste", "field service" and checking each key's use in Swift. Onboarding, Settings, accessibility labels and the report message have no other kind wording.

| Key | Used in | English now | Danish now |
|---|---|---|---|
| `tracker.outputtype.main.label` | `TrackerType.label` | Main | Primær |
| `tracker.outputtype.separate.label` | `TrackerType.label` | Separate | Separat |
| `tracker.outputtype.main.description` | `TrackerType.description` | All main categories will be combined into one single metric in the report: Field Service | All primære kategorier vil blive sammenlagt til ét felt i din rapport: Tjeneste |
| `tracker.outputtype.separate.description` | `TrackerType.description` | Separate categories will be added to the report separate from Field Service and can be used to track other aspects of our ministry like Bethel or LDC | Separate kategorier bliver føjet til din rapport separat fra "Tjeneste" og kan bruges til at holde styr på andre aspekter af din tjeneste, fx betel eller LDC |
| `monthlyReport.detail.largeTotal.main.label` | Year details, Totals | Field Service | Tjeneste |
| `monthlyReport.detail.largeTotal.separate.label` | Year details, Totals | Other | Andet |
| `planner.header.uncounted` | `PlannerMonthStatus.uncountedSentence` | %@ in other categories won't count toward your goal | %@ i andre kategorier tæller ikke med mod dit årsmål |
| `schoolCredit.form.footer.%lld` | school credit form footer | This school gives up to %lld hours. They count toward your yearly goal like field service and are sent on this month's report. If the school ran over two months, add credit to each month. | Skolen giver op til %lld timer. De tæller med mod dit årsmål ligesom almindelige timer og bliver sendt med denne måneds rapport. Hvis skolen strakte sig over to måneder, så log timer i hver måned. |
| `category.default.label` | Field Service line title on Submit Report; snapshot names | Field Service | Tjeneste |
| `report.compose.field-service` | report message | Field Service | Timer |
| `tracker.fieldservice.name` | name of the default category on a new install | Field Service | Forkyndelse |
| `tracker.type.label.long` | header of the kind section | Category Type | Type |

`planner.header.uncounted` comes from Swift with a `defaultValue` (`Hugo/Features/Planner/Domain/PlannerMonthStatus.swift:91-98`):

```swift
    nonisolated var uncountedSentence: String? {
        guard uncountedSeconds >= Self.differenceThreshold else { return nil }
        let amount = ServiceDurationFormatter.hoursString(from: uncountedSeconds)
        return String(
            localized: "planner.header.uncounted",
            defaultValue: "\(amount) in other categories won't count toward your goal",
            comment: "Separate-category time beyond the allowance. The argument is a duration.")
    }
```

When Swift has a `defaultValue` and `comment`, the catalog's English value and comment must match them, or the build rewrites the catalog. Change both together.

`ReportingLineCard.swift:55-61`:

```swift
    @ViewBuilder
    private var lineTitle: some View {
        if result.line.type == .main {
            Text("category.default.label")
        } else {
            Text(verbatim: result.line.name)
        }
    }
```

### Vocabulary clash in `CONTEXT.md`

`CONTEXT.md` (after plans 127 and 128) has **Main category**, **Separate category**, **Credited time** ("The app shows it as 'Counted toward goal'", _Avoid_: Counted time), **Separate allowance** and **School credit**, and flags that "Field Service" names both the default category and the reporting line. With a kind called Credit, "credited time" would read as "time in Credit categories", but it means all time that counts toward the goal, Field Service included. Step 6 resolves this.

### Design references

- `Hugo/DesignSystem/Components/SelectableOptionRow.swift`: the app's selectable row (`Button`, `.buttonStyle(.plain)`, `.accessibilityElement(children: .combine)`, `.accessibilityAddTraits(isSelected ? .isSelected : [])`, `Checkmark(checked:)`). The cards follow the same accessibility pattern.
- `Hugo/DesignSystem/Components/Checkmark.swift`: `Checkmark(checked: Bool)`, accent checkmark that animates with `Motion.feedback`.
- `Hugo/DesignSystem/Motion/Motion.swift`: `.motion(Motion.value, value:)` respects Reduce Motion.
- Tokens in `Hugo/DesignSystem/Theme/Theme.swift`: `HugoLayout.Spacing.tight/compact/regular/spacious`, `HugoLayout.CornerRadius.compactCard` (24), `HugoLayout.Size.minimumHitTarget` (44). `.hugoAccent` is the accent color and works as a `ShapeStyle`.
- Selection haptics: `TheocraticYearPicker.swift:92` uses `.sensoryFeedback(.selection, trigger:)`.
- Owner style (README "Design decisions carried into every plan"): native SwiftUI, monochrome chrome, `.hugoAccent` only for selection and progress; system grouped backgrounds; never flashy.
- Localized text with a locale: `LocalizedStringResource(_:defaultValue:locale:comment:)` (see `Hugo/Features/SchoolCredits/Domain/School.swift:31-36`). `String(localized:locale:)` does **not** pick the catalog language (README note for plan 117).

### Conventions

- AGENTS.md section 7: a view that shows a category kind belongs to the Categories feature, so the picker goes in `Hugo/Features/Categories/Views/` and its pure logic in `Hugo/Features/Categories/Domain/`. Not `DesignSystem`.
- Domain types are `nonisolated` and `Sendable`. Views take `locale` from the environment; domain functions take `locale` as a parameter with a `.current` default.
- Tests use Swift Testing and mirror the source path.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0 |
| Build | `xcodebuild build -project Hugo.xcodeproj -scheme Debug -destination 'generic/platform=iOS Simulator' -quiet 2>&1 \| grep -c "error:"` | `0` |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug -destination 'platform=iOS Simulator,name=Hugo Verify iOS 26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/CategoryKindFactTests -only-testing:HugoTests/PlannerMonthStatusTests` | `** TEST SUCCEEDED **` |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |

Do not run the focused tests while `Scripts/verify.sh` runs; both use the same simulator.

## Suggested executor toolkit

- If available, invoke the `write-swift` skill before writing `CategoryKindFact.swift` and `CategoryKindPicker.swift`.

## Scope

**In scope:**
- `Hugo/Features/Categories/Domain/CategoryKindFact.swift` (create)
- `Hugo/Features/Categories/Views/CategoryKindPicker.swift` (create)
- `Hugo/Features/Categories/Screens/AddCategoryView.swift`
- `Hugo/Features/Categories/Screens/CategoryDetailView.swift`
- `Hugo/Persistence/Legacy/TrackerType.swift` (one doc comment, nothing else)
- `Hugo/Features/Reports/Views/ReportingLineCard.swift` (one key)
- `Hugo/Features/Planner/Domain/PlannerMonthStatus.swift` (`defaultValue` and `comment` of one string)
- `HugoTests/Features/Categories/Domain/CategoryKindFactTests.swift` (create)
- `Hugo/Resources/Localizable.xcstrings`
- `CONTEXT.md`

**Out of scope:**
- Renaming `TrackerType`, its cases or raw values, `Tracker`, any schema file, `separateAllowanceHours`, `creditedSeconds` or any other code identifier. Code keeps "main"/"separate"/"credited"; `CONTEXT.md` maps them.
- `report.compose.field-service`, `category.default.label` and `tracker.fieldservice.name` values. See "Report message".
- Code comments outside the files in scope.
- A help article. Plan 130 adds "Field Service and Credit" to a new Help menu.
- `EntryCategory`, `BibleStudiesRule`, `AddEntryFormModel` (plan 128).

## Git workflow

- Work on `main` directly. No branch, no worktree.
- One commit after `Scripts/verify.sh` exits 0: `feat: call the category kinds Field Service and Credit and explain them on two cards`.
- Never stage `.claude/`, `plans/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Do not push.

## Steps

### Step 1: The facts (pure logic)

Create `Hugo/Features/Categories/Domain/CategoryKindFact.swift`:

```swift
import Foundation

/// What a category kind means, in plain sentences for the kind picker: where
/// the time goes on the report, how it counts toward the yearly goal, and
/// whether its entries can have Bible studies. `TrackerType.main` is a Field
/// Service category and `.separate` a Credit category (see CONTEXT.md).
nonisolated struct CategoryKindFact: Identifiable, Equatable, Sendable {
    enum Topic: Sendable {
        case report
        case goal
        case bibleStudies
    }

    let topic: Topic
    let text: String

    var id: Topic { topic }

    var systemImage: String {
        switch topic {
        case .report: "doc.text"
        case .goal: "target"
        case .bibleStudies: "book"
        }
    }

    /// The facts for `kind` in this order: report, goal, Bible studies. The
    /// goal fact is left out when `status` is nil or has no yearly goal.
    static func facts(
        for kind: TrackerType, status: PublisherStatus?, locale: Locale = .current
    ) -> [CategoryKindFact] {
        var facts = [CategoryKindFact(topic: .report, text: reportText(for: kind, locale: locale))]
        if let rule = status?.yearlyGoalRule {
            facts.append(CategoryKindFact(topic: .goal, text: goalText(for: kind, rule: rule, locale: locale)))
        }
        facts.append(CategoryKindFact(topic: .bibleStudies, text: studiesText(for: kind, locale: locale)))
        return facts
    }

    /// The symbol on the kind's card.
    static func systemImage(for kind: TrackerType) -> String {
        switch kind {
        case .main: "figure.walk"
        case .separate: "hammer"
        }
    }

    /// The example line on the kind's card.
    static func example(for kind: TrackerType, locale: Locale = .current) -> String {
        switch kind {
        case .main:
            String(
                localized: LocalizedStringResource(
                    "category.kind.main.example",
                    defaultValue: "For example house to house, return visits and public witnessing.",
                    locale: locale,
                    comment: "Example line on the Field Service card in the category type picker."))
        case .separate:
            String(
                localized: LocalizedStringResource(
                    "category.kind.separate.example",
                    defaultValue: "For example LDC or Bethel.",
                    locale: locale,
                    comment: "Example line on the Credit card in the category type picker."))
        }
    }

    private static func reportText(for kind: TrackerType, locale: Locale) -> String {
        switch kind {
        case .main:
            String(
                localized: LocalizedStringResource(
                    "category.kind.fact.main.report",
                    defaultValue: "Added together and sent as one line on your report.",
                    locale: locale,
                    comment: "Category type picker, Field Service: where the time goes on the report."))
        case .separate:
            String(
                localized: LocalizedStringResource(
                    "category.kind.fact.separate.report",
                    defaultValue: "Sent on its own line on your report, with the category's name.",
                    locale: locale,
                    comment: "Category type picker, Credit: where the time goes on the report."))
        }
    }

    private static func goalText(for kind: TrackerType, rule: YearlyGoalRule, locale: Locale) -> String {
        switch kind {
        case .main:
            return String(
                localized: LocalizedStringResource(
                    "category.kind.fact.main.goal",
                    defaultValue: "Counts in full toward your yearly goal.",
                    locale: locale,
                    comment: "Category type picker, Field Service: how the time counts toward the yearly goal."))
        case .separate:
            let limit = ServiceDurationFormatter.hoursString(
                from: rule.monthlyGoalSeconds + rule.separateAllowanceSeconds, locale: locale)
            let allowance = ServiceDurationFormatter.hoursString(from: rule.separateAllowanceSeconds, locale: locale)
            return String(
                localized: LocalizedStringResource(
                    "category.kind.fact.separate.goal",
                    defaultValue:
                        "Counts toward your yearly goal until the month reaches \(limit): your monthly goal plus \(allowance).",
                    locale: locale,
                    comment:
                        "Category type picker, Credit: how the time counts toward the yearly goal. The first argument is the monthly goal plus the credit allowance, such as 55 hours; the second is the allowance, such as 5 hours."
                ))
        }
    }

    private static func studiesText(for kind: TrackerType, locale: Locale) -> String {
        switch kind {
        case .main:
            String(
                localized: LocalizedStringResource(
                    "category.kind.fact.main.studies",
                    defaultValue: "You can add Bible studies to entries in this category.",
                    locale: locale,
                    comment: "Category type picker, Field Service: Bible studies are allowed."))
        case .separate:
            String(
                localized: LocalizedStringResource(
                    "category.kind.fact.separate.studies",
                    defaultValue: "You can't add Bible studies to entries in this category.",
                    locale: locale,
                    comment: "Category type picker, Credit: Bible studies are not allowed."))
        }
    }
}
```

The `defaultValue` and `comment` texts must be exactly the English values and comments you add to the catalog in Step 4.

**Verify**: build → `0`.

### Step 2: The picker view

Create `Hugo/Features/Categories/Views/CategoryKindPicker.swift`:

```swift
import SwiftUI

/// Picks a category's kind on two cards, Field Service and Credit, and says
/// under them what the chosen kind means for the report, the yearly goal and
/// Bible studies. Put it in a `Form` section; it draws its own card
/// backgrounds, so the section row is cleared (see `categoryKindRow()`).
struct CategoryKindPicker: View {
    @Binding var kind: TrackerType

    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @Environment(\.locale) private var locale

    private var facts: [CategoryKindFact] {
        CategoryKindFact.facts(for: kind, status: PublisherStatus.status(for: statusID), locale: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.spacious) {
            VStack(spacing: HugoLayout.Spacing.compact) {
                ForEach(TrackerType.allCases) { option in
                    card(for: option)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("tracker.type.label.long"))

            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                ForEach(facts) { fact in
                    Label {
                        Text(fact.text)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: fact.systemImage)
                    }
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, HugoLayout.Spacing.spacious)
        }
        .motion(Motion.value, value: kind)
        .sensoryFeedback(.selection, trigger: kind)
    }

    private func card(for option: TrackerType) -> some View {
        let isSelected = option == kind
        let shape = RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.compactCard, style: .continuous)
        return Button {
            kind = option
        } label: {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
                    Image(systemName: CategoryKindFact.systemImage(for: option))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.hugoAccent) : AnyShapeStyle(.secondary))
                    Text(option.label)
                        .font(.headline)
                    Spacer(minLength: HugoLayout.Spacing.compact)
                    Checkmark(checked: isSelected)
                }
                Text(option.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(CategoryKindFact.example(for: option, locale: locale))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(HugoLayout.Spacing.spacious)
            .frame(maxWidth: .infinity, minHeight: HugoLayout.Size.minimumHitTarget, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: shape)
            .overlay {
                shape.strokeBorder(isSelected ? Color.hugoAccent : Color.clear, lineWidth: 2)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    /// Clears a `Form` row so the kind picker's cards sit on the grouped background.
    func categoryKindRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }
}

#Preview("In a form") {
    @Previewable @State var kind: TrackerType = .main
    Form {
        Section {
            CategoryKindPicker(kind: $kind)
                .categoryKindRow()
        } header: {
            Text("tracker.type.label.long")
        }
    }
    .defaultAppStorage(UserDefaults(suiteName: "CategoryKindPickerPreview")!)
}

#Preview("Danish, largest text") {
    @Previewable @State var kind: TrackerType = .separate
    Form {
        Section {
            CategoryKindPicker(kind: $kind)
                .categoryKindRow()
        }
    }
    .environment(\.locale, Locale(identifier: "da_DK"))
    .dynamicTypeSize(.accessibility5)
}

#Preview("Dark") {
    @Previewable @State var kind: TrackerType = .separate
    Form {
        Section {
            CategoryKindPicker(kind: $kind)
                .categoryKindRow()
        }
    }
    .preferredColorScheme(.dark)
}
```

Notes for this step:
- The extension is fileprivate in spirit but both screens need it; keep it `internal` in this file. It names no feature type, but it exists only for this picker, so it stays here, not in `DesignSystem`.
- `.buttonStyle(.plain)` on each card is required: inside a `Form` row, buttons without a plain or borderless style all fire on any tap in the row.
- Each card is one VoiceOver element ("Field Service. Time you spend preaching and teaching. For example house to house, …") with the Selected trait on the chosen one, like `SelectableOptionRow`. The facts are read one by one after the cards.
- The cards stack vertically at every text size, and every `Text` wraps (`fixedSize(horizontal: false, vertical: true)`), so nothing truncates at the accessibility sizes.
- `.motion(Motion.value, value: kind)` animates the border, checkmark and fact text; with Reduce Motion it uses the short ease that `MotionModifier` picks. There is no movement.
- If `AnyShapeStyle(.hugoAccent)` does not compile, use `AnyShapeStyle(Color.hugoAccent)`.

**Verify**: build → `0`.

### Step 3: Use the picker on both screens, and fix the line title

1. `AddCategoryView.swift`: replace the whole kind `Section { Picker(...) ... } header: { ... } footer: { Text(type.description) }` with:

```swift
                Section {
                    CategoryKindPicker(kind: $type)
                        .categoryKindRow()
                } header: {
                    Text("tracker.type.label.long")
                }
```

2. `CategoryDetailView.swift`: replace the kind `Section { Picker(...) .pickerStyle(.navigationLink) ... } footer: { Text(tracker.type.description) }` with:

```swift
            Section {
                CategoryKindPicker(kind: $tracker.type)
                    .categoryKindRow()
            } header: {
                Text("tracker.type.label.long")
            } footer: {
                Text("category.kind.change.footer")
            }
```

   The kind stays editable, as it is today. The footer tells the user what a change does.

3. `ReportingLineCard.swift` `lineTitle`: change `Text("category.default.label")` to `Text("monthlyReport.detail.largeTotal.main.label")`. English stays "Field Service"; Danish becomes "Forkyndelse" in Step 4, the same word as the kind. `category.default.label` keeps its value for snapshot names.

4. `PlannerMonthStatus.swift` `uncountedSentence`: change the `defaultValue` to `"\(amount) of credit won't count toward your goal"` and the `comment` to `"Credit-category time beyond the credit allowance. The argument is a duration."`.

5. `TrackerType.swift`: add this doc comment above `nonisolated enum TrackerType` and change nothing else in the file:

```swift
/// A category's kind. `main` is a Field Service category and `separate` a
/// Credit category; the UI and CONTEXT.md use those names. The case names
/// are stored in SwiftData and CloudKit, so they never change.
```

**Verify**: build → `0`. `grep -rn "pickerStyle(.navigationLink)" Hugo/Features/Categories` → no output.

### Step 4: Strings

Save the catalog helper from plan 042 as `/tmp/xcstrings_edit.py` (outside the repo; do not commit it):

```python
import json
import re

PATH = "Hugo/Resources/Localizable.xcstrings"


def load():
    with open(PATH, encoding="utf-8") as f:
        return json.loads(f.read())


def save(data):
    out = json.dumps(data, indent=2, separators=(",", " : "), ensure_ascii=False)
    out = re.sub(r"^( *)(.*)\{\}", lambda m: f"{m.group(1)}{m.group(2)}{{\n\n{m.group(1)}}}", out, flags=re.M)
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(out)


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def entry(comment, en, da):
    return {"comment": comment, "localizations": {"da": unit(da), "en": unit(en)}}


def natural(key):
    # Xcode orders catalog keys case-insensitively with numbers compared by value.
    return [(0, int(t)) if t.isdigit() else (1, t.lower()) for t in re.split(r"(\d+)", key) if t != ""]


def insert_sorted(strings, key, value):
    items = list(strings.items())
    index = next((i for i, (k, _) in enumerate(items) if natural(k) > natural(key)), len(items))
    items.insert(index, (key, value))
    return dict(items)
```

Confirm it is lossless first: `python3 -I -c "import sys; sys.path.insert(0, '/tmp'); import xcstrings_edit as x; x.save(x.load())"` then `git diff --stat -- Hugo/Resources/Localizable.xcstrings` → nothing. If not, reset the file and STOP.

**4a. Change these existing keys** (English, Danish, and the new comment):

| Key | English | Danish | Comment |
|---|---|---|---|
| `tracker.outputtype.main.label` | Field Service | Forkyndelse | Name of the Field Service category type (code: TrackerType.main). Card title in the type picker and section header in category lists. |
| `tracker.outputtype.separate.label` | Credit | Godtgørelse | Name of the Credit category type (code: TrackerType.separate), such as LDC or Bethel. Card title in the type picker and section header in category lists. |
| `tracker.outputtype.main.description` | Time you spend preaching and teaching. | Tid, du bruger på at forkynde og undervise. | One sentence on the Field Service card in the category type picker. |
| `tracker.outputtype.separate.description` | Hours you may report as credit for other approved work. | Timer, du må rapportere som godtgørelse for andet godkendt arbejde. | One sentence on the Credit card in the category type picker. |
| `monthlyReport.detail.largeTotal.main.label` | Field Service | Forkyndelse | Label of the Field Service line: on Submit Report, and the Field Service total on the year details screen. |
| `monthlyReport.detail.largeTotal.separate.label` | Credit | Godtgørelse | Year details, Totals: the time in Credit categories. |
| `planner.header.uncounted` | %@ of credit won't count toward your goal | %@ godtgørelse tæller ikke med mod dit årsmål | Credit-category time beyond the credit allowance. The argument is a duration. |
| `schoolCredit.form.footer.%lld` | This school gives up to %lld hours. They count in full toward your yearly goal, like Field Service time, and are sent on this month's report. If the school ran over two months, add credit to each month. | Skolen giver op til %lld timer. De tæller fuldt ud med mod dit årsmål ligesom forkyndelse og bliver sendt med denne måneds rapport. Hvis skolen strakte sig over to måneder, så log timer i hver måned. | (keep the existing comment) |

For the two `monthlyReport.detail.largeTotal.*` keys and the two `tracker.outputtype.*.label` keys, also delete `"isCommentAutoGenerated"` when you set the comment.

**4b. Add these keys** with `insert_sorted`, `en` and `da` both `"state" : "translated"`:

| Key | English | Danish | Comment |
|---|---|---|---|
| `category.kind.main.example` | For example house to house, return visits and public witnessing. | Fx fra hus til hus, genbesøg og offentlig forkyndelse. | Example line on the Field Service card in the category type picker. |
| `category.kind.separate.example` | For example LDC or Bethel. | Fx LDC eller Betel. | Example line on the Credit card in the category type picker. |
| `category.kind.fact.main.report` | Added together and sent as one line on your report. | Lægges sammen og sendes som dine timer i rapporten. | Category type picker, Field Service: where the time goes on the report. |
| `category.kind.fact.separate.report` | Sent on its own line on your report, with the category's name. | Sendes på sin egen linje i rapporten med kategoriens navn. | Category type picker, Credit: where the time goes on the report. |
| `category.kind.fact.main.goal` | Counts in full toward your yearly goal. | Tæller fuldt ud med mod dit årsmål. | Category type picker, Field Service: how the time counts toward the yearly goal. |
| `category.kind.fact.separate.goal` | Counts toward your yearly goal until the month reaches %1$@: your monthly goal plus %2$@. | Tæller med mod dit årsmål, indtil måneden når %1$@: dit månedsmål plus %2$@. | Category type picker, Credit: how the time counts toward the yearly goal. The first argument is the monthly goal plus the credit allowance, such as 55 hours; the second is the allowance, such as 5 hours. |
| `category.kind.fact.main.studies` | You can add Bible studies to entries in this category. | Du kan tilføje bibelstudier til registreringer i denne kategori. | Category type picker, Field Service: Bible studies are allowed. |
| `category.kind.fact.separate.studies` | You can't add Bible studies to entries in this category. | Du kan ikke tilføje bibelstudier til registreringer i denne kategori. | Category type picker, Credit: Bible studies are not allowed. |
| `category.kind.change.footer` | Changing the type changes how all of this category's time counts. Months you have already reported may then show that they changed. | Hvis du ændrer typen, ændrer det, hvordan al tid i kategorien tæller. Måneder, du allerede har rapporteret, kan så vise, at de er ændret. | Footer under the category type cards on the category detail screen. |

Write the edits as one Python script that uses the helper (`load`, change values in `d['strings'][key]['localizations'][lang]['stringUnit']['value']`, set `comment`, `insert_sorted` for each new key with `entry(comment, en, da)`, then `save`). Use straight apostrophes (`'`) in "can't", "won't", "category's", "month's", exactly as the Swift `defaultValue` strings in Step 1.

**Verify**:
- `python3 -I -c "import json;s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];k=[x for x in s if x.startswith('category.kind.')];print(len(k), all(s[x]['localizations'][l]['stringUnit']['value'] for x in k for l in ('en','da')))"` → `9 True`.
- `python3 -I -c "import json;s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print([v['localizations'][l]['stringUnit']['value'] for k,v in s.items() if k.startswith('tracker.outputtype') and k.endswith('label') for l in ('en','da')])"` → `['Field Service', 'Forkyndelse', 'Credit', 'Godtgørelse']`.
- `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` → about 175 added and 28 removed lines (measured by the advisor on a copy of the catalog). Hundreds of changed lines mean keys moved: reset with `git checkout -- Hugo/Resources/Localizable.xcstrings` and STOP.

**Keep the kind names in one place.** The kind names live only in `tracker.outputtype.main.label` and `tracker.outputtype.separate.label`. Do not copy "Forkyndelse" or "Godtgørelse" into new keys as fixed words where you can avoid it; the fact sentences above refer to "this category" instead. (`monthlyReport.detail.largeTotal.*` and `planner.header.uncounted` repeat the words; Maintenance notes lists them.)

### Step 5: Tests

Create `HugoTests/Features/Categories/Domain/CategoryKindFactTests.swift`:

```swift
import Foundation
import Testing

@testable import Hugo

struct CategoryKindFactTests {
    private let regularPioneer = PublisherStatus.status(for: "regular-pioneer")!
    private let publisher = PublisherStatus.status(for: "publisher")!
    private let english = Locale(identifier: "en_US")
    private let danish = Locale(identifier: "da_DK")

    @Test(arguments: [TrackerType.main, .separate])
    func aStatusWithAYearlyGoalGetsThreeFactsInOrder(kind: TrackerType) {
        let facts = CategoryKindFact.facts(for: kind, status: regularPioneer, locale: english)
        #expect(facts.map(\.topic) == [.report, .goal, .bibleStudies])
    }

    @Test(arguments: [TrackerType.main, .separate])
    func noYearlyGoalLeavesOutTheGoalFact(kind: TrackerType) {
        #expect(
            CategoryKindFact.facts(for: kind, status: publisher, locale: english).map(\.topic)
                == [.report, .bibleStudies])
        #expect(
            CategoryKindFact.facts(for: kind, status: nil, locale: english).map(\.topic)
                == [.report, .bibleStudies])
    }

    @Test
    func creditGoalFactNamesTheMonthlyGoalPlusTheAllowance() throws {
        let goal = try #require(
            CategoryKindFact.facts(for: .separate, status: regularPioneer, locale: english)
                .first { $0.topic == .goal })
        #expect(goal.text.contains("55 hours"))
        #expect(goal.text.contains("5 hours"))
    }

    @Test
    func kindsDifferOnEveryFact() {
        let main = CategoryKindFact.facts(for: .main, status: regularPioneer, locale: english).map(\.text)
        let credit = CategoryKindFact.facts(for: .separate, status: regularPioneer, locale: english).map(\.text)
        #expect(zip(main, credit).allSatisfy { $0 != $1 })
    }

    @Test
    func factsUseTheGivenLanguage() throws {
        let report = try #require(
            CategoryKindFact.facts(for: .separate, status: regularPioneer, locale: danish).first)
        #expect(report.text == "Sendes på sin egen linje i rapporten med kategoriens navn.")
        #expect(CategoryKindFact.example(for: .separate, locale: danish) == "Fx LDC eller Betel.")
    }

    @Test
    func eachKindHasItsOwnSymbol() {
        #expect(CategoryKindFact.systemImage(for: .main) != CategoryKindFact.systemImage(for: .separate))
    }
}
```

**Verify**: focused tests command → `** TEST SUCCEEDED **` with all `CategoryKindFactTests` passing (8 test cases counting arguments). If `factsUseTheGivenLanguage` fails with an English string, the catalog entry is missing or misspelled; fix the catalog, do not change the test.

### Step 6: `CONTEXT.md`

Edit only the entries named here. Keep every other entry as it is.

1. Replace **Category**, **Main category**, **Separate category** and **Default category** with:

```markdown
**Category**:
What an entry's time counts as, such as Field Service or Bethel. Every category has a kind: it is either a Field Service category or a Credit category.
_Avoid_: Tracker, type

**Category kind**:
Whether a category is a Field Service category or a Credit category. The user picks it on two cards when adding or editing a category; the screens label the choice "Category Type" / "Type". Stored as `TrackerType`, whose cases stay `main` (Field Service) and `separate` (Credit).
_Avoid_: Output type, main, separate (in text users read)

**Field Service category**:
A category for time spent preaching and teaching. Its time is reported together on the Field Service line, counts in full toward the yearly goal, and its entries can have Bible studies. Danish: "Forkyndelse". Code: `TrackerType.main`.
_Avoid_: Main category, primary category

**Credit category**:
A category for hours a publisher may report as credit, such as Bethel or LDC. Each Credit category is reported on its own line, and its time counts toward the yearly goal only up to the credit allowance. New entries in it get no Bible studies; an entry that already has some keeps them. Danish: "Godtgørelse". Code: `TrackerType.separate`.
_Avoid_: Separate category, other, secondary category

**Credit**:
Hours reported for approved work other than field service: the time in Credit categories and school credit. Each is reported on a line of its own. Credit-category time counts toward the yearly goal only up to the credit allowance; school credit counts in full.

**Default category**:
The Field Service category that new entries use unless the user picks another. A new install starts with one, named Field Service ("Forkyndelse").
```

2. In **Untracked entry**, replace "Its time counts as main time everywhere: on the Field Service line, in the month's main total and toward the yearly goal." with "Its time counts as Field Service time everywhere: on the Field Service line, in the month's Field Service total and toward the yearly goal."

3. In **Reporting line**, replace the definition with: "One line of a report: the Field Service line, which holds all Field Service time, or one Credit category. Each line is rounded on its own. School credit is sent on lines of its own but is not a reporting line."

4. Replace **Credited time** and **Separate allowance** with:

```markdown
**Counted time**:
The part of a month's time that counts toward the yearly goal: all Field Service time and school credit, plus Credit-category time until the month reaches its monthly goal plus the credit allowance. The app shows it as "Counted toward goal" / "Tæller med mod målet". Code names remain `creditedSeconds`.
_Avoid_: Credited time (it sounds like time in Credit categories)

**Credit allowance**:
The hours of Credit-category time that may count beyond the monthly goal in one month: 5 for a regular pioneer. Code names remain `separateAllowanceHours` and `separateAllowanceSeconds`.
_Avoid_: Separate allowance
```

5. In **School credit**, replace "It counts toward the yearly goal and the year total like main time, never goes through rounding, and is reported on its own line." with "It counts in full toward the yearly goal and the year total, like Field Service time, never goes through rounding, and is reported on its own line. It is credit, but not a Credit category."

6. In **Expected time** and **Adjusted target**, replace the words "credited time" with "counted time".

7. In **Covered time**, replace "(main or separate)" with "(Field Service or Credit)".

8. Replace the **Flagged ambiguities** list with:

```markdown
- "Actual" has meant logged time in some places and year total in others. Say logged time, reported hours, year total or counted time instead.
- "Field Service" names a category kind, the default category and the reporting line that holds all Field Service time. Say "a Field Service category" for any category of that kind, "the default category" for the one a new install creates, and "the Field Service line" for the line. In Danish the kind, the default category and the app's line label are all "Forkyndelse", but the report message calls the line "Timer", the word on the congregation's report form.
- "Credit" names a category kind, school credit and both together. Say "Credit category" for the kind, "school credit" for school hours, and "credit" only for both together. Never say "credited time"; say "counted time".
```

**Verify**: `grep -n "Main category\|Separate category\|Separate allowance\|Credited time\|main time\|credited time" CONTEXT.md` → only the `_Avoid_` lines (`Main category, primary category`, `Separate category, other, …`, `Separate allowance`, `Credited time (it sounds…`) and the sentence `Never say "credited time"`.

### Step 7: Full gate and commit

Run `Scripts/verify.sh`. After it, `git diff -- Hugo/Resources/Localizable.xcstrings` must show only the keys from Step 4 (a build must not add, reword or mark stale anything else). Commit the in-scope files with the message from "Git workflow".

## Test plan

- New `CategoryKindFactTests` (6 tests, 8 cases): fact order with a yearly goal; no goal fact for a publisher or no status; the Credit goal fact names 55 and 5 hours; the two kinds differ on every fact; Danish text comes from the catalog; distinct symbols.
- Existing tests must pass unchanged, including `PlannerMonthStatusTests` (they check seconds, not the sentence) and the Danish `ReportComposerTests` (the report message is unchanged).
- `Scripts/verify.sh` → exit 0.

Owner checks on a device (record results in the plan's status row):
1. Settings > Categories: sections read "Field Service" and "Credit" (Danish "Forkyndelse", "Godtgørelse").
2. Add Category: two cards; tapping one moves the border and checkmark with a light haptic; the three lines under the cards change. As a regular pioneer the Credit goal line says 55 hours and 5 hours; as a publisher there is no goal line.
3. Category detail: the same cards and the footer about reported months. Change Bethel to Field Service and back on a test device: a submitted month with Bethel time shows "Changed since the report was submitted" while it is Field Service.
4. VoiceOver: each card reads as one element with "Selected" on the chosen one; double-tap selects.
5. Largest accessibility text size: nothing truncates; cards grow taller.
6. Submit Report in Danish: the Field Service line title reads "Forkyndelse"; the copied message still says "Timer: …" and the Credit lines use the category names.
7. Planner with more Credit time than the allowance: "3 hours of credit won't count toward your goal" / "3 timer godtgørelse tæller ikke med mod dit årsmål".
8. Danish wording: confirm "Forkyndelse", "Godtgørelse" and the card sentences read naturally.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `test -f Hugo/Features/Categories/Views/CategoryKindPicker.swift && test -f Hugo/Features/Categories/Domain/CategoryKindFact.swift` → exit 0
- [ ] `grep -rn "CategoryKindPicker(kind:" Hugo/Features/Categories/Screens` → 2 matches (AddCategoryView, CategoryDetailView)
- [ ] `python3 -I -c "import json;s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print([k for k,v in s.items() for l in ('en','da') if v.get('localizations',{}).get(l,{}).get('stringUnit',{}).get('value','') in ('Main','Separate','Primær','Separat','Other','Andet')])"` → `[]`
- [ ] `git diff c918888..HEAD -- Hugo/Persistence | grep "^[-+]" | grep -v "^[-+][-+]" | grep -v "///"` → no output (only the doc comment changed under `Hugo/Persistence`)
- [ ] `grep -n "report.compose.field-service" -A 12 Hugo/Resources/Localizable.xcstrings | grep -c "\"Timer\""` → `1` (the report line is unchanged)
- [ ] `git status --short` shows no modified files outside the in-scope list, except the owner's `Debug.xcscheme`

## STOP conditions

- Plan 128 has not landed (drift check).
- The catalog shows a kind word in a key that is not in the table in "Current state" (for example a new screen added since `c918888`). Report the key instead of guessing its new text.
- A change seems to need renaming a Swift type, enum case, raw value or schema file.
- Any change would alter the text of the report message (`ReportComposer.message`). Report it to the owner instead.
- The cards do not respond to taps inside the `Form` after adding `.buttonStyle(.plain)`.

## Maintenance notes

- **Danish names may change.** The owner chose "Forkyndelse" and "Godtgørelse" (2026-11-18) and may change them. The kind names are in `tracker.outputtype.main.label` and `tracker.outputtype.separate.label`. The same words also appear in `monthlyReport.detail.largeTotal.main.label`, `monthlyReport.detail.largeTotal.separate.label`, `planner.header.uncounted`, `schoolCredit.form.footer.%lld`, `CONTEXT.md`, and after plan 130 in the Danish help article `FieldServiceAndCredit.md` and the menu title `help.article.fieldServiceAndCredit`. Change them together.
- **Owner decisions to confirm:**
  - The Danish in-app line label changes from "Tjeneste" to "Forkyndelse" (Submit Report and year details) to match the kind. The report message keeps "Timer".
  - `category.default.label` keeps Danish "Tjeneste" because carried-in entries store it as their snapshot name. It is no longer shown as the Submit Report line title.
  - The `CONTEXT.md` term "Credited time" becomes "Counted time", which the earlier glossary listed under _Avoid_. The UI already says "Counted toward goal", and "credited" now clashes with the Credit kind. Code names (`creditedSeconds`) stay.
  - The Credit card's symbol is `hammer` (LDC, the example the old text used). Change `CategoryKindFact.systemImage(for:)` if the owner prefers another.
- Code comments in other files still say "main" and "separate" time. That matches the code's case names and is fine; `CONTEXT.md` maps the words.
- A reviewer should check the cards at the largest text size and with VoiceOver, and that the catalog diff contains only the 8 changed and 9 added keys.
- Plan 130 adds a "Field Service and Credit" help article to a Help menu on the category screens.
