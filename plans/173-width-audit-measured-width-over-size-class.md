# Plan 173: Width audit: layout decisions on measured width, size class only where the system decides

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `grep -rln "horizontalSizeClass\|userInterfaceIdiom\|UIScreen" Hugo | sort`
> Expected: exactly these three files, in this order, and no others:
> `Hugo/App/AppRootView.swift`, `Hugo/DesignSystem/Components/SelectableOptionRow.swift`,
> `Hugo/Features/Settings/Views/SettingsButton.swift`. A fourth file: STOP and
> report it, so the reviewer can add it to the audit. (Plans 166–172 add no
> size-class use, so this holds at dispatch. The seven lines inside these three
> files are listed under "Current state"; line numbers may differ.)
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P3
- **Effort**: S + owner
- **Risk**: LOW. Comments and one paragraph in `AGENTS.md`; no behavior change. The value of the plan is the audit result and the owner's check matrix.
- **Depends on**: 168 (names `TwoColumnBreakpoint` in `AGENTS.md`); run last of plans 166–173
- **Category**: dx, ux
- **Planned at**: commit `16b697c`, 2026-11-26
- **Issue**: [SLN-346](https://linear.app/sebastianln/issue/SLN-346)

## Why this matters

iPadOS 26 windows can be any width. Layout that branches on the horizontal size
class can be wrong between the size-class steps. For example, a regular-width
window can still be too narrow for two columns. Plans 159, 162, 168 and 169
therefore decide layout from measured width (`ReadableWidthGeometry`,
`TwoColumnBreakpoint`). This plan audits what is left.

Audit result (done while planning, at `16b697c`): every remaining size-class use
is correct, because each one mirrors a decision the system itself makes by size
class. None of them is a width-based layout choice in disguise. There is
nothing to convert, so this plan does not invent a change. It:

1. writes down why each use stays, next to the code, so nobody "fixes" it later;
2. adds the rule to `AGENTS.md`;
3. gives the owner one check matrix to run on the iPad across window sizes, covering everything plans 159–172 changed.

| Use | Decision | Why |
|---|---|---|
| `AppRootView.isCompact` (tab visibility, plan 161's Settings command, the sidebar tint) | Keep | `TabView(.sidebarAdaptable)` switches between tab bar and sidebar by size class. The Settings tab exists only in regular width (`TabPlacement.sidebarOnly`), so every decision about it must use the same signal. |
| `SettingsButton(sizeClass: .compact)` on the Overview, Planner and Service Year toolbars | Keep | It shows the toolbar's Settings button exactly when the Settings tab is hidden, which is a size-class decision of the `TabView`. A width check could show both or neither. |
| `SelectableOptionRow` (value beside or under the title) | Keep | Compact width on iPad means a window of about 320–500 points (Slide Over, a narrow split), where the value belongs under the title. Regular width means a sheet or page of 540 points or more, where it fits beside it. The size class tracks the row's real width here, and switching to a measured width would add a layout pass for no visible gain. |

Other width-dependent code found and left alone: `containerRelativeFrame(.horizontal)`
in the Planner and Service Year pagers (correct: a page is one container wide),
five `ViewThatFits` uses (already width-based), and no `UIScreen` or
`userInterfaceIdiom`.

## Current state

`grep -rn "horizontalSizeClass\|userInterfaceIdiom\|UIScreen" Hugo` at `16b697c`
prints seven lines in three files (grep may print the files in another order):

```
Hugo/App/AppRootView.swift:9:    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
Hugo/App/AppRootView.swift:32:    private var isCompact: Bool { horizontalSizeClass == .compact }
Hugo/DesignSystem/Components/SelectableOptionRow.swift:11:    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
Hugo/DesignSystem/Components/SelectableOptionRow.swift:22:                    if let value, dynamicTypeSize.isAccessibilitySize || horizontalSizeClass == .compact {
Hugo/DesignSystem/Components/SelectableOptionRow.swift:28:                if let value, !dynamicTypeSize.isAccessibilitySize, horizontalSizeClass != .compact {
Hugo/Features/Settings/Views/SettingsButton.swift:4:    @Environment(\.horizontalSizeClass) var horizontalSizeClass
Hugo/Features/Settings/Views/SettingsButton.swift:10:        if sizeClass == nil || sizeClass == horizontalSizeClass {
```

`SettingsButton.swift` starts like this (line 10, above, is the `if` in its body):

```swift
struct SettingsButton: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var showAccount: Bool = false

    var sizeClass: UserInterfaceSizeClass? = nil
```

`AGENTS.md` section 3 is "## 3. SwiftUI & State Guidelines" with one subsection,
"### State Management", which ends with a fenced Swift example, followed by
"## 4. Previews".

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict <files>` | exit 0 |
| Format fix | `xcrun swift-format format -i <files>` | then re-run lint; use when `lint --strict` fails on formatting only |

## Scope

**In scope**: comments in `AppRootView.swift`, `SettingsButton.swift`, `SelectableOptionRow.swift`; one new subsection in `AGENTS.md`.

**Out of scope**: any behavior change. If you believe a use should change, STOP and report instead.

## Git workflow

- Work on `main`. One commit: `docs: record why the remaining size-class checks stay`. Do not push.

## Steps

### Step 1: Comments at each use

- `AppRootView.swift`, directly above `private var isCompact: Bool`:
  `/// The tab view's own signal: .sidebarAdaptable shows a tab bar in compact width and a sidebar in regular width. The sidebar-only Settings tab and the sidebar tint must follow it too.`
- `SettingsButton.swift`, directly above `@Environment(\.horizontalSizeClass)`:
  `/// Size class on purpose: the toolbar button stands in for the Settings tab, which the tab view hides in compact width. Measuring width could show both or neither.`
- `SelectableOptionRow.swift`, directly above `@Environment(\.horizontalSizeClass)`:
  `/// Compact width on iPad is a narrow window (about 320–500 points) where the value fits under the title; regular width is a sheet or page wide enough to show it beside the title. Kept as size class after the 2026-11-26 width audit (plan 173).`

### Step 2: The rule in `AGENTS.md`

Insert this subsection in section 3, after the "State Management" subsection's
closing code fence and before "## 4. Previews":

```markdown
### Width and size class

iPad windows can be any width. Decide layout from measured width: `readableContentWidth()` / `readableListWidth()` for text columns, `TwoColumnBreakpoint` and `AdaptiveTwoColumnStack` for side-by-side layouts. Use `horizontalSizeClass` only to mirror a decision the system makes by size class, such as the `TabView` switching between tab bar and sidebar. Every current use has a comment saying why.
```

**Verify**: lint the three Swift files; `Scripts/verify.sh` exits 0 with the same
test count; `git diff --stat` shows only the four files with comment and text
additions. Commit `docs: record why the remaining size-class checks stay`.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, same test count
- [ ] Only comments and `AGENTS.md` changed
- [ ] `plans/README.md` row updated

Owner check matrix on the iPad (Sean), after plans 166–172 are installed. Run
each row in light mode at the default text size, and repeat the rows marked *
at the largest accessibility size. Mark each cell OK or describe the problem.

| Window | Overview | Planner | Service Year | Settings (tab or sheet) | Sheets: Add Entry, Submit Report, a Planner day |
|---|---|---|---|---|---|
| Full screen, landscape, sidebar shown* | | | | | |
| Full screen, landscape, sidebar hidden | | | | | |
| Full screen, portrait* | | | | | |
| Half split next to another app (landscape) | | | | | |
| Narrow window, Slide Over size (about 320 pt) | | | | | |
| Window dragged slowly from narrow to full width | | | | | |

What to look for in each cell:
- Nothing slides under the sidebar or past the window edge.
- Text columns stay readable: not edge to edge on a wide window, not cramped in a narrow one.
- Two columns appear only when both fit (plans 168 and 169), and one column at accessibility sizes.
- The toolbar Settings button shows exactly when the sidebar's Settings tab does not.
- Popovers (plan 160) point at what you tapped, and narrow windows show sheets instead.
- Resizing the window does not close an open sheet or reset a list.

On the iPhone (Mona): one pass through the same columns at the default size.

## STOP conditions

Stop and report if:

- The drift check finds a use that is not in the table above.
- You think any of the three uses should change behavior. That is a decision for the reviewer and the owner, not for this plan.

## Maintenance notes

- New size-class checks need the same kind of comment, or they should be measured width instead.
- Problems found in the owner's matrix become revisions of the plan that caused them (159, 160, 162, 168 or 169), not new plans.
