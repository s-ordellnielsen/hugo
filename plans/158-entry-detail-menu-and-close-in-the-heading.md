# Plan 158: Put the entry detail's More menu and a close button in its heading

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 9be08a0..HEAD -- Hugo/Features/Entries/Screens/EntryDetailView.swift Hugo/DesignSystem/Modifiers/AdaptiveDetail.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW to MEDIUM. It changes the iPhone sheet's top area too, and the result can only be judged on a device.
- **Depends on**: plans 153 (done as a prototype) and 156 (done)
- **Category**: bug
- **Planned at**: commit `9be08a0`, 2026-11-23
- **Issue**: [SLN-334](https://linear.app/sebastianln/issue/SLN-334) (found in the owner's iPad check of plan 153)

## Why this matters

The owner tried the inspector from plan 153 on an iPad:

1. The More menu is not shown in the inspector. The menu is a toolbar item of
   `EntryDetailView`'s own `NavigationStack`, and an inspector draws no
   navigation bar for it.
2. In landscape the inspector cannot be closed once it is open. A column
   inspector has no dimmed area to tap, and the view has no close control.

The fix is to stop depending on a navigation bar. The heading of the sheet
(which plan 156 already moved into the content) gets two controls at its
trailing edge: the More menu and a close button. The same view then looks and
works the same in an inspector and in an iPhone sheet, and the close button is
an explicit control, which also helps older users.

## Current state

`Hugo/Features/Entries/Screens/EntryDetailView.swift` (after plan 156):

```swift
NavigationStack {
    Form {
        Section {
            DurationWheelPicker( ... )
        } header: {
            titleHeader
        }
        ...
    }
    .contentMargins(.top, 0, for: .scrollContent)
    .toolbar {
        ToolbarItem {
            Menu {
                Button("entry.action.tracker.change", systemImage: "checklist") { selectTrackerIsPresented = true }
                Button("entry.delete.label", systemImage: "trash", role: .destructive) { deleteConfirmationShown = true }
            } label: { Label("common.more", systemImage: "ellipsis") }
            .confirmationDialog("entry.delete.confirmation.label", isPresented: $deleteConfirmationShown) { ... dismiss() ... }
        }
    }
    .sheet(isPresented: $selectTrackerIsPresented) { CategoryPicker( ... ) }
    .errorAlert(message: $deletionError)
}

private var titleHeader: some View {
    VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
        Label { Text(category.name)... } icon: { Image(systemName: category.iconName)... }
        ...
        Text("entry.duration.label")...
    }
    .textCase(nil)
    .padding(.bottom, HugoLayout.Spacing.compact)
}
```

`@Environment(\.dismiss) var dismiss` is already used after a delete. For a view
shown by `.sheet(item:)` and by `.inspector(isPresented:)`, `dismiss()` closes
the sheet or the inspector (the inspector's `isPresented` is set to false, see
`AdaptiveDetail.swift`).

`HelpView.swift:56` already uses the native close button:
`Button(role: .close) { ... }`. Use the same.

Rules from `AGENTS.md` that apply: SwiftUI only; accessible to ages 13 to 70
(explicit labelled controls, Dynamic Type safe, at least 44 pt targets); vanilla
native feel; no new strings if an existing one fits (`common.more` and
`common.dismiss` exist; `Button(role: .close)` supplies its own label).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/Entries/Screens/EntryDetailView.swift`

**Out of scope**:

- `AdaptiveDetail.swift`, the form rows, `CategoryPicker`, every other screen.
- New strings: do not edit the string catalog (the owner has uncommitted edits there).

## Git workflow

- Work on `main`. One commit, for example `fix(entries): put the menu and close button in the entry heading`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Move the menu and add a close button into the heading

1. Remove the `.toolbar { ... }` from the `Form`. Keep the `confirmationDialog` working: attach it (and the `.sheet(isPresented: $selectTrackerIsPresented)` and `.errorAlert`) to the same view as before, not to a view that is removed.
2. Make the heading a row: the existing title block on the left, the controls on the right.

```swift
private var titleHeader: some View {
    HStack(alignment: .top, spacing: HugoLayout.Spacing.regular) {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
            // the existing Label and the "Duration" Text, unchanged
        }
        Spacer(minLength: HugoLayout.Spacing.regular)
        headerControls
    }
    .textCase(nil)
    .padding(.bottom, HugoLayout.Spacing.compact)
}

private var headerControls: some View {
    HStack(spacing: HugoLayout.Spacing.compact) {
        Menu { /* the two existing buttons, unchanged */ } label: {
            Label("common.more", systemImage: "ellipsis").labelStyle(.iconOnly)
        }
        Button(role: .close) { dismiss() }
    }
    .buttonStyle(.glass)
    .buttonBorderShape(.circle)
    .controlSize(.regular)
}
```

If `.buttonStyle(.glass)` with `.buttonBorderShape(.circle)` does not compile for
the `Menu`, use `.buttonStyle(.bordered)` with the same shape. Keep the
`confirmationDialog` on the `Menu` or on the `Form`, wherever it works. The
heading text must still wrap for a long category name, so the title block takes
the remaining width (`layoutPriority(1)` if it gets squeezed by the controls) and
the controls never shrink. Keep `.accessibilityAddTraits(.isHeader)` on the title
label only. Use `Color.primary` for text (section header trap from plan 148).

3. The view no longer needs a `NavigationStack` for a toolbar. Remove the
`NavigationStack` wrapper if nothing else in the view needs one. If the
`CategoryPicker` sheet or the form's pickers need a stack for their own title,
that stack is inside the sheet already. Check by building. Keep the form
scrolling and the top content margin behavior from plan 156.

**Verify**: `grep -n "toolbar\|ToolbarItem" Hugo/Features/Entries/Screens/EntryDetailView.swift` returns nothing, `Scripts/verify.sh` exits 0, and `xcrun swift-format lint --strict` on the file exits 0.

### Step 2: Look at it

If you can drive a throwaway iPad simulator (see the repo memory for the signed
build recipe, `-isOnboarding NO`, and a temporary never-committed debug hook that
seeds one entry and selects it), take a landscape-width or portrait screenshot
of the inspector and check that the More button and the close button are
visible at the trailing edge of the heading, and that a long category name
wraps beside them. Remove the hook before committing.

## Test plan

No logic changed, so no unit test. Owner check on the iPad (inspector) and iPhone (sheet):

- The heading shows the category icon and name on the left and two round buttons on the right: More (ellipsis) and Close (x).
- Landscape: the inspector closes with the close button. Portrait: it closes with the button and by tapping the dimmed area.
- More shows "Change category" and "Delete". Delete asks for confirmation, then closes the inspector or sheet and removes the entry. Change category opens the picker sheet, and the heading updates afterwards.
- iPhone: the sheet shows the same heading with both buttons, a long name wraps, and the sheet still dismisses by swiping down.
- Largest text size: the buttons stay at least 44 pt, the name wraps, nothing is cut off.
- VoiceOver reads "More" and "Close" buttons.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "toolbar\|ToolbarItem" Hugo/Features/Entries/Screens/EntryDetailView.swift` returns nothing
- [ ] `git status --short` shows only the in-scope file (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

## STOP conditions

Stop and report if:

- `EntryDetailView` no longer matches "Current state".
- The delete confirmation or the category picker cannot be presented without the removed `NavigationStack`.
- You need to change a file outside the scope.

## Maintenance notes

- A view that is shown in a sheet, a pushed screen and an inspector must not depend on a navigation bar for its controls. Put the controls in the content, as here.
- Plan 154's day and month columns follow the same rule (content views carry no toolbar).
