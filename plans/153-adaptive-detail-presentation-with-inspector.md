# Plan 153: Show details in an inspector on iPad, in a sheet on iPhone

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> Commit after every step. Stop at every "Owner check" until the owner answers.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/Features/Overview/Views/OverviewListView.swift Hugo/Features/Overview/Screens/OverviewView.swift Hugo/Features/Entries/Screens/EntryDetailView.swift Hugo/DesignSystem/Modifiers`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> Also check that plan 152 is DONE in `plans/README.md`. `git status --short` may show
> `M Hugo/Resources/Localizable.xcstrings` (the owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: MEDIUM. The iPhone path stays a sheet, but an inspector inside the iPad tab layout cannot be unit tested and its placement next to a `NavigationStack` is unverified.
- **Depends on**: 152
- **Category**: feature (iPad)
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-334](https://linear.app/sebastianln/issue/SLN-334), child of [SLN-323](https://linear.app/sebastianln/issue/SLN-323) (iPad). Ships in V1.0.

## Why this matters

On iPad a detail that opens as a sheet covers the list the person was reading
and floats in the middle of a large screen. Decision (owner, 2026-11-23): at
regular width, details open in an `.inspector` panel beside the list. On iPhone
they stay sheets. Forms and pickers (Add Entry, the category picker, time
pickers) stay sheets on both, because they are short, modal tasks.

## Current state

Detail sheets today carry `.presentationDetents([.medium, .large])`:

`Hugo/Features/Overview/Views/OverviewListView.swift:74`
```swift
.sheet(item: $selectedEntry) { entry in
    EntryDetailView(entry: entry)
        .presentationDetents([.medium, .large])
}
```

`Hugo/Features/Planner/Screens/PlannerDaySheet.swift:73` has the same for entries
inside the day sheet. `EntryDetailView` wraps its own `NavigationStack` (line 18),
because it is presented. `MonthEntriesSection.swift:30` also pushes it, which
already nests a stack. Do not change that here.

Plan 152 gives each tab exactly one `NavigationStack` and a bar-less `TabView`
as the iPad detail. An inspector attaches to the view it is applied to.

Today `SettingsButton` reads `horizontalSizeClass`. Nothing else in the feature
code does. This plan adds one more reader, the modifier.

### Inventory of every `.sheet`, `.popover` and `fullScreenCover` (grep at `07d4c61`)

Command: `grep -rn '\.sheet(\|\.fullScreenCover(\|\.popover(\|\.inspector(' Hugo --include='*.swift'`.
There are 33 call sites and no `.inspector` yet. Classes: **detail** (read or edit one
existing item, migrate), **form** (create something or pick a value, stays a sheet),
**other** (flow, info or app level, stays a sheet).

| File:line | What it presents | Class | Action |
|---|---|---|---|
| `App/AppRootView.swift:97` | Onboarding | other | stay |
| `Settings/Views/SettingsButton.swift:17` | Settings from the person icon | other | stay (compact only) |
| `Settings/Screens/OverseerSettingsView.swift:86` | Manual overseer entry | form | stay |
| `Entries/Screens/EntryDetailView.swift:88` | Category picker for an entry | picker | stay |
| `Entries/Screens/AddEntryView.swift:77` | Category picker | picker | stay |
| `Entries/Screens/AddEntryView.swift:81` | Time picker | picker | stay |
| `Planner/Screens/PlanFormView.swift:79` | Category picker | picker | stay |
| `Planner/Screens/PlanFormView.swift:83` | Time picker | picker | stay |
| `Planner/Screens/PlannerDaySheet.swift:60` | Add plan | form | stay |
| `Planner/Screens/PlannerDaySheet.swift:63` | Edit plan | form | stay |
| `Planner/Screens/PlannerDaySheet.swift:66` | Log from plan (Add Entry) | form | stay |
| `Planner/Screens/PlannerDaySheet.swift:73` | Entry detail | detail | excluded, plan 154 owns this screen |
| `Planner/Views/PlannerMonthPage.swift:58` | Day sheet | detail | excluded, plan 154 |
| `ServiceYear/Screens/MonthDetailView.swift:42` | Add entry | form | stay |
| `ServiceYear/Screens/MonthDetailView.swift:45` | Submit report | other (flow) | stay |
| `ServiceYear/Screens/MonthDetailView.swift:50` | Add school credit | form | stay |
| `ServiceYear/Screens/MonthDetailView.swift:53` | Edit school credit | form | stay |
| `ServiceYear/Views/ServiceYearMonthRow.swift:50` | Add entry | form | stay |
| `ServiceYear/Views/ServiceYearMonthRow.swift:53` | Submit report | other (flow) | stay |
| `ServiceYear/Screens/ServiceYearView.swift:124` | Year picker popover | other | stay |
| `Overview/Screens/OverviewView.swift:110` | Add entry | form | stay |
| `Overview/Screens/OverviewView.swift:113` | Plan pace explanation | other (info) | stay |
| `Overview/Views/ReportReminderCard.swift:62` | Submit report | other (flow) | stay |
| `Overview/Views/OverviewListView.swift:74` | Entry detail | detail | **migrate, Step 2** |
| `Overview/Views/OverviewListView.swift:78` | Add entry | form | stay |
| `Overview/Views/OverviewListView.swift:286` | Carried-in breakdown (read only) | other (info) | stay |
| `Categories/Screens/CategoryPicker.swift:62` | Add category | form | stay |
| `Categories/Screens/CategoryDetailView.swift:78` | Symbol picker | picker | stay |
| `Categories/Screens/AddCategoryView.swift:78` | Symbol picker | picker | stay |
| `Categories/Screens/CategoryListView.swift:55` | Add category | form | stay |
| `Help/Views/HelpMenu.swift:31` | Help article | other (reading) | stay |
| `Reports/Screens/SubmitReportView.swift:204` | Report settings | other | stay |
| `Reports/Screens/SubmitReportView.swift:222` | Message composer | other (system) | stay |

(Rows are the call sites the grep prints. If the grep shows a line that is not in the
table, add it before starting and classify it.)

So only one call site is a detail that this plan migrates, and the Planner and Service
Year pieces belong to plan 154. The value of the plan is the reusable modifier. Do not
invent more migrations to make it bigger. Pushed details (`MonthEntriesSection`, `CategoryListView`)
are pushes, not sheets, and stay pushes.

## Design

One modifier in `Hugo/DesignSystem/Modifiers/AdaptiveDetail.swift`. It names no feature type and is
the only place that reads `horizontalSizeClass` for presentation.

```swift
extension View {
    func adaptiveDetail<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View
}
```

- Regular width: `.inspector(isPresented:)` where the `Bool` is derived from `item` (set to `false` clears the item). Keep the last item while the inspector animates closed, so the content does not go blank. Apply `.inspectorColumnWidth(min:ideal:max:)`.
- Compact width: `.sheet(item:)` with `.presentationDetents([.medium, .large])`, exactly as today.
- If plan 145 has landed and has a content-sized sheet modifier, use it for the compact branch instead of the fixed detents. Check `plans/README.md` and `Hugo/DesignSystem/Modifiers`. If it has not landed, use the detents above and do not wait for it.

The size class decision is a pure rule, so it can be tested: a small `nonisolated enum DetailPresentation { case inspector, sheet }`
with `static func presentation(for sizeClass: UserInterfaceSizeClass?) -> DetailPresentation` (`.regular` gives `.inspector`; `.compact` and `nil` give `.sheet`).

Rules from plan 152 that still hold: no new `NavigationStack` around the inspector, and
the content may keep the one stack `EntryDetailView` already owns, because an inspector
is a presentation like a sheet.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Inventory | `grep -rn '\.sheet(\|\.fullScreenCover(\|\.popover(\|\.inspector(' Hugo --include='*.swift'` | matches the table |

## Scope

**In scope**:

- `Hugo/DesignSystem/Modifiers/AdaptiveDetail.swift` (create)
- `HugoTests/DesignSystem/Modifiers/AdaptiveDetailTests.swift` (create)
- `Hugo/Features/Overview/Views/OverviewListView.swift` (the entry detail only)

**Out of scope**:

- Every form, picker and "other" row in the table.
- `PlannerDaySheet`, `PlannerMonthPage`, `MonthDetailView`, `ServiceYearMonthRow` (plan 154).
- Pushed screens, and fixing the nested stack in `MonthEntriesSection`.
- Any change to the iPhone presentation.

## Git workflow

- Work on `main`. Commit per step, Conventional Commits, for example `feat: add the adaptive detail modifier`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Write the modifier and the rule, with a test

Create `AdaptiveDetail.swift` with `DetailPresentation` and `adaptiveDetail(item:content:)` as above.
Create `HugoTests/DesignSystem/Modifiers/AdaptiveDetailTests.swift`: `regularMapsToInspector`,
`compactMapsToSheet`, `unknownMapsToSheet`.

**Verify**: `Scripts/verify.sh` exits 0, with 3 more tests.

### Step 2: Prototype on the Overview entry detail

Replace the `.sheet(item: $selectedEntry)` at `OverviewListView.swift:74` with
`.adaptiveDetail(item: $selectedEntry) { entry in EntryDetailView(entry: entry) }`.
Do not touch the other `.sheet` on that view. Apply the modifier on the view that
plan 152's detail stack shows, not on a row.

**Verify**: `Scripts/verify.sh` exits 0, and on iPhone the entry detail opens as the same sheet as before.

**Owner check on a real iPad. Stop here until the owner answers.** Ask them to check:

1. Tapping an entry in the Overview list opens the panel beside the list. The list stays tappable, and tapping another entry switches the panel.
2. The panel width is comfortable, in portrait and landscape.
3. Rotating with the panel open keeps it open, with the same entry.
4. In Split View at half width and in Slide Over (compact width) the same tap opens a sheet.
5. The panel's toolbar (the category title, the menu, the close button) is complete and not hidden under the navigation bar.
6. Deleting the entry from the panel closes the panel and does not crash.
7. VoiceOver can reach the panel, and the close control is announced.
8. The category picker sheet that `EntryDetailView` opens still works from inside the panel.

If 5 fails because the inspector sits under the stack's bar, try applying the
modifier one level higher or lower, once. If it still fails, STOP.

### Step 3: Confirm nothing else should migrate

Run the inventory grep. Compare it with the table. Confirm that no call site other
than `OverviewListView.swift:74` is a detail outside plan 154's screens. If the owner
wants a second migration (for example the plan pace sheet), add it as a new step
only after Step 2 is accepted.

**Verify**: the grep output matches the table, with `OverviewListView.swift:74` now `.adaptiveDetail`.

### Step 4: Record how to use it

Add one doc comment to `AdaptiveDetail.swift` that says: use it for read or edit
details of an existing item, never for forms or pickers. Do not edit `AGENTS.md`.

**Verify**: `swift-format lint --strict Hugo/DesignSystem/Modifiers/AdaptiveDetail.swift` exits 0.

## Test plan

- Three rule tests. The presentation itself is checked by the owner on an iPad in Step 2.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with 3 more tests
- [ ] `grep -rn "horizontalSizeClass" Hugo/DesignSystem/Modifiers` matches only `AdaptiveDetail.swift`
- [ ] Every `.sheet` in the table still exists except `OverviewListView.swift:74`
- [ ] The owner check in Step 2 is answered
- [ ] `git status --short` shows only in-scope files (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

## STOP conditions

Stop and report if:

- Plan 152 is not done, or the iPad detail has more than one `NavigationStack` per tab.
- The inspector cannot be shown without a new `NavigationStack` around the screen.
- A detail sheet is reachable on iPad at regular width from two screens at once (two inspectors in one hierarchy conflict).
- iPhone presentation would change.
- The owner says in Step 2 that the inspector feels wrong. Do not continue to other call sites.

## Maintenance notes

- New detail screens use `adaptiveDetail`. New forms and pickers use `.sheet`.
- Only one `.inspector` can be active in a view hierarchy. A second detail on the same screen needs a different design, not a second inspector.
- Plan 154 turns the Planner and Service Year into two columns. If it also wants an inspector for entry details there, it needs a separate decision, because a third column is tight on an 11 inch iPad.
