# Plan 101: Show the selected category in its color in Add Entry

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 5a08f55..HEAD -- Hugo/Features/Entries/Screens/AddEntryView.swift`
> Expected: no output. Otherwise compare the excerpt below with the live file.
> A mismatch is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S + owner (look at it on a device)
- **Risk**: LOW. One view, no logic, no data.
- **Depends on**: plans 098-100 (DONE: `CategoryColor`, `CategoryColorStyle`, `Tracker.categoryColor`)
- **Category**: direction
- **Planned at**: commit `5a08f55`, 2026-11-10
- **Issue**: [SLN-310](https://linear.app/sebastianln/issue/SLN-310)

## Why this matters

In Add Entry, the row with the selected category is a `Button`, but it looks like plain text. Hugo's root tint is monochrome (`.primary`), so nothing tells the user they can tap it to change the category. The owner asked (2026-11-10) to draw the row's icon **and** name in the category's color, so it reads as a button and matches the Planner.

Some colors are light as text in light mode: green, orange and the teal accent sit near 2:1 against white, as Apple's own green and orange buttons do. Many of Hugo's users are older, so when iOS **Increase Contrast** is on (`colorSchemeContrast == .increased`), the name stays `.primary` and only the icon is tinted.

## Current state

`Hugo/Features/Entries/Screens/AddEntryView.swift:36-46` (inside the `Form`):

```swift
                Section {
                    Button {
                        form.isCategoryPickerPresented = true
                    } label: {
                        if let tracker = form.selectedTracker {
                            Label(tracker.name, systemImage: tracker.iconName)
                        } else {
                            Label("entry.add.tracker.none", systemImage: "circle")
                        }
                    }
                }
```

What you can use (from plans 098-100, already on `main`):

- `CategoryColorStyle(_ color: CategoryColor?)` in `Hugo/DesignSystem/Theme/CategoryColorStyle.swift`. It is a `ShapeStyle` that draws the category color for the current light or dark mode, and the teal accent `.hugoAccent` for `nil` (Automatic).
- `tracker.categoryColor` (`CategoryColor?`, nil for Automatic) in `Hugo/Features/Categories/Domain/TrackerCategoryColor.swift`.
- The same tinted-icon pattern in `Hugo/Features/Categories/Screens/CategoryPicker.swift`: `Image(systemName: tracker.iconName).foregroundStyle(CategoryColorStyle(tracker.categoryColor))`.

`form.selectedTracker` is a `Tracker?` on `AddEntryFormModel`. Do not change the model.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Full gate (before the commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

## Scope

**In scope**: `Hugo/Features/Entries/Screens/AddEntryView.swift` only.

**Out of scope**:

- `PlanFormView.swift` and `EntryDetailView.swift`. They have similar rows, but the owner asked for Add Entry only.
- `AddEntryFormModel`, `CategoryPicker`, `CategoryColorStyle`, `CategoryColor` and every other file.
- New strings. None are needed.
- `Hugo.xcodeproj/project.pbxproj`, `.claude/`, `plans/` and the owner's `Changelog/` changes. Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage the one file by path.
- One commit after `Scripts/verify.sh` exits 0: `feat: show the selected category in its color in Add Entry`.

## Steps

### Step 1: Tint the row

In `AddEntryView`:

1. Add `@Environment(\.colorSchemeContrast) private var colorSchemeContrast` next to the view's other properties.
2. Replace the button's `label:` content (the `if let ... else ...` with two `Label`s) with a call to a new private view property `categoryLabel`, and add it near the existing `bibleStudiesLabel` / `timeLabel` helpers:

```swift
    /// The selected category in its color, or "no category" in the accent
    /// color, so the row reads as a button. With Increase Contrast on, the
    /// name stays in the normal text color and only the icon is tinted.
    @ViewBuilder
    private var categoryLabel: some View {
        let style = CategoryColorStyle(form.selectedTracker?.categoryColor)
        let nameStyle =
            colorSchemeContrast == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(style)
        if let tracker = form.selectedTracker {
            Label {
                Text(tracker.name).foregroundStyle(nameStyle)
            } icon: {
                Image(systemName: tracker.iconName).foregroundStyle(style)
            }
        } else {
            Label {
                Text("entry.add.tracker.none").foregroundStyle(nameStyle)
            } icon: {
                Image(systemName: "circle").foregroundStyle(style)
            }
        }
    }
```

   `Text(tracker.name)` with a `String` variable shows the name as it is, as the old `Label(tracker.name, ...)` did. `Text("entry.add.tracker.none")` with a literal stays localized. Keep both behaviors.

**Verify**: `Scripts/verify.sh` exits 0 (lint, all tests, analyze). Then `git diff --stat` lists only `AddEntryView.swift` (plus the owner's untouched `Changelog/` changes, which you must not stage), and `git diff --check` exits 0. Commit.

## Test plan

This is a view-only style change with no logic, so no unit test fits; the existing suite must stay green. The owner checks it on a device (see Maintenance notes).

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `git show --stat HEAD` lists only `Hugo/Features/Entries/Screens/AddEntryView.swift`
- [ ] `grep -n "CategoryColorStyle\|colorSchemeContrast" Hugo/Features/Entries/Screens/AddEntryView.swift` shows the environment property and the new helper
- [ ] `plans/README.md` row for 101 updated

## STOP conditions

- The drift check shows changes and the excerpt no longer matches.
- The change seems to need a file other than `AddEntryView.swift`.
- `AnyShapeStyle(.primary)` or the `Label { } icon: { }` form does not compile, and one obvious fix doesn't solve it.

## Maintenance notes

- Owner device check: Add Entry in light and dark mode with a colored category, an Automatic one and no category. Then again with Settings → Accessibility → Display & Text Size → Increase Contrast turned on: the name should be in the normal text color and only the icon colored.
- `PlanFormView.swift:36-42` has the identical row. If the owner wants it there too, copy `categoryLabel` into that view. If a third place wants it, move it into a small view under `Hugo/Features/Categories/Views/` instead of copying it again.
