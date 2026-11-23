# Plan 156: Show the entry detail title in the content, not in a clipped toolbar item

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat b980d57..HEAD -- Hugo/Features/Entries/Screens/EntryDetailView.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW. One view. The look can only be checked on a device.
- **Depends on**: plan 146 (done)
- **Category**: bug
- **Planned at**: commit `b980d57`, 2026-11-23
- **Issue**: [SLN-327](https://linear.app/sebastianln/issue/SLN-327) (reopened after the owner's device check of plan 146)

## Why this matters

Plan 146 moved the category icon and name into a `.topBarLeading` toolbar item.
On a device the owner sees it left-aligned but massively clipped: sometimes only
half a letter of the name is visible. A leading toolbar item is sized by the
navigation bar, and the bar gives it very little width next to the More menu.
There is no reliable modifier to widen it, and the owner cannot check each guess
from the command line.

After this plan the title is not a toolbar item. It is the first thing in the
content, left-aligned, in serif, at the top of the form, like a large title. The
toolbar keeps only the More menu. Nothing can clip it, because the content has
the full width and the title may wrap to a second line.

## Current state

`Hugo/Features/Entries/Screens/EntryDetailView.swift` (after plan 146):

```swift
NavigationStack {
    Form {
        Section("entry.duration.label") {
            DurationWheelPicker( ... )
        }
        Section { DatePicker( ... ) }
        if BibleStudiesRule.showsControl( ... ) { Section { Stepper( ... ) } }
    }
    .contentMargins(.top, 0, for: .scrollContent)
    .toolbar {
        ToolbarItem(placement: .topBarLeading) {
            Label {
                Text(category.name).font(.system(.headline, design: .serif, weight: .bold))
            } icon: {
                Image(systemName: category.iconName)
            }
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem {
            Menu { ... } label: { Label("common.more", systemImage: "ellipsis") }
            ...
        }
    }
    ...
}
```

`category` is `entry.resolvedCategory()` (an `EntryCategory` with `name` and
`iconName`).

There is a precedent for a custom header in a form: `MonthDetailView.swift`
(`private var header`, used as the section's `header:` with `.textCase(nil)`).
Note from plan 148: text styled with the hierarchical `.primary` inside a
section header renders gray, because the header supplies its own secondary
foreground. Use `Color.primary` explicitly.

Rules from `AGENTS.md` that apply: SwiftUI only; Dynamic Type safe; keep it
vanilla and native; no catch-all folders. This view is used from the Overview
list and from the Planner day sheet.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/Entries/Screens/EntryDetailView.swift`

**Out of scope**:

- The More menu, the form rows, the category picker, `EditorialNavigationTitle`, every other screen.
- Strings. No text changes.

## Git workflow

- Work on `main`. One commit, for example `fix(entries): show the entry detail title in the content`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Remove the leading toolbar item

Delete the whole `ToolbarItem(placement: .topBarLeading) { ... }` and its
`.sharedBackgroundVisibility(.hidden)`. Keep the More `ToolbarItem` exactly as it is.

### Step 2: Add the title as the header of the first section

Give the first `Section` (the duration one) a custom header, and keep the
"Duration" label inside that header as a small secondary line under the heading
(so it is not lost). The section's content stays as it is:

```swift
Section {
    DurationWheelPicker( ... )   // unchanged
} header: {
    titleHeader
}
```

This replaces the `Section("entry.duration.label") { ... }` form of the initializer.

and add, as a private computed property of the view:

```swift
private var titleHeader: some View {
    VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
        Label {
            Text(category.name)
                .font(.system(.title2, design: .serif, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: category.iconName)
                .font(.system(.title2, weight: .semibold))
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(Color.primary)
        .accessibilityAddTraits(.isHeader)
        Text("entry.duration.label")
            .font(.subheadline)
            .foregroundStyle(Color.secondary)
    }
    .textCase(nil)
    .padding(.bottom, HugoLayout.Spacing.compact)
}
```

The name may wrap to a second line: do not add `.lineLimit(1)`. Both the
`Label` text and icon are `.primary`, written as `Color.primary`, not `.primary`.
If `HugoLayout.Spacing.compact` does not exist, use the spacing token
`MonthDetailView` uses for its header. Leave `.contentMargins(.top, 0, for: .scrollContent)` as it is.

If using `Label` with `.titleAndIcon` puts the icon and text on different
baselines, use `HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact)`
with the `Image` and the `Text` instead. Say which you used in NOTES.

**Verify**: `grep -n "topBarLeading\|sharedBackgroundVisibility" Hugo/Features/Entries/Screens/EntryDetailView.swift` returns nothing, and `Scripts/verify.sh` exits 0.

You cannot tap through to this sheet from the command line, so do not try to
screenshot it. Say in NOTES that the look is unverified.

## Test plan

No logic changed, so no unit test. Owner check on a device (from the Overview
list and from a Planner day):

- The category name and icon sit at the top left of the sheet, in serif, fully visible, not clipped.
- A long category name (for example "Theocratic Ministry School Assistance") wraps to a second line instead of being cut off.
- Largest Dynamic Type size: the heading wraps and nothing is cut off.
- The toolbar shows only the More menu, with no empty glass capsule on the left.
- Light and dark mode: the heading is solid black or white, not gray.
- VoiceOver: the heading is read as a heading, followed by "Duration".
- Changing the category from the More menu updates the heading.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "topBarLeading\|sharedBackgroundVisibility" Hugo/Features/Entries/Screens/EntryDetailView.swift` returns nothing
- [ ] `git status --short` shows only the in-scope file (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

## STOP conditions

Stop and report if:

- `EntryDetailView` no longer matches "Current state".
- The header makes the first section collide with the toolbar or need an offset.
- You need to change a file outside the scope.

## Maintenance notes

- Navigation-bar toolbar items are sized by the bar and can clip a title. Put titles that can be long in the content.
- Header text in a `Form` needs `Color.primary` and `.textCase(nil)` to look like a title.
