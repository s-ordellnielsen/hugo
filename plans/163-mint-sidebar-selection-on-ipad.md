# Plan 163: Show the selected iPad sidebar row in mint

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat b198210..HEAD -- Hugo/App`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P1 (the selected sidebar row is unreadable in dark mode)
- **Effort**: S + owner
- **Risk**: LOW. One file. The iPhone must look exactly as before; the plan keeps the tab bar tint as is in compact width.
- **Depends on**: none
- **Category**: bug, ux
- **Planned at**: commit `b198210`, 2026-11-26
- **Issue**: [SLN-341](https://linear.app/sebastianln/issue/SLN-341)

## Why this matters

On the iPad with the sidebar shown in dark mode, the selected row is a white
pill with white text: the owner saw an empty white capsule where "Settings"
should be. The app sets `.tint(.primary)` on its root (`HugoApp.swift`, since
the first theme commit), and the sidebar draws the selected row's capsule in
the tint. `primary` is white in dark mode, and the selected label is white.

Owner decision (2026-11-26): tint the sidebar's selection with Hugo's mint
accent (`Color.hugoAccent`), as Apple's sidebars use the app's accent color.
Everything inside the tabs keeps the monochrome `primary` tint, and the iPhone
tab bar stays as it is.

## Current state

`Hugo/App/HugoApp.swift` applies `.tint(.primary)` to `AppRootView` (and to
`StoreLoadFailureView`).

`Hugo/App/AppRootView.swift`:

```swift
private var isCompact: Bool { horizontalSizeClass == .compact }
...
private var tabs: some View {
    TabView(selection: tabSelection) {
        ForEach(visibleTabs) { tab in
            Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                NavigationStack {
                    tabDestination(for: tab, yearResetToken: yearResetToken, plannerResetToken: plannerResetToken)
                }
            }
            .defaultVisibility(tab.placement.showsInTabBar ? .automatic : .hidden, for: .tabBar)
        }
    }
    .tabViewStyle(.sidebarAdaptable)
    .onChange(of: isCompact) { _, compact in
        ...
    }
}
```

`Color.hugoAccent` is defined in `Hugo/DesignSystem/Theme/Theme.swift` (`.mint`).

Tint is an environment value. A `.tint` on the `TabView` reaches the sidebar
and the tab bar, and also every view inside the tabs, so the tab content must
set `.tint(.primary)` again. Sheets presented from `AppRootView` itself (onboarding,
Add Entry, Settings from the menu bar) sit outside the `TabView` and keep the
root's `primary` tint.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict Hugo/App/AppRootView.swift` | exit 0 |

## Scope

**In scope**: `Hugo/App/AppRootView.swift` (the `tabs` property only).

**Out of scope**: `HugoApp.swift`, `Theme.swift`, every feature view, the compact (iPhone) tab bar's look.

## Git workflow

- Work on `main`. One commit: `fix(app): show the selected iPad sidebar row in mint`.
- Do not push.

## Steps

### Step 1: Tint the tab view in regular width, keep the content monochrome

In `tabs`:

1. On the `NavigationStack` inside each `Tab`, add `.tint(.primary)`, with the comment
   `// The tab view's mint is for the sidebar selection only; content stays monochrome.`
2. After `.tabViewStyle(.sidebarAdaptable)`, add
   `.tint(isCompact ? Color.primary : Color.hugoAccent)`, with the comment
   `// Mint selection in the iPad sidebar, where a primary (white in dark mode) capsule hides its label. Compact width keeps the iPhone tab bar as it was.`

Change nothing else.

**Verify**: lint exits 0; `Scripts/verify.sh` exits 0 with the same test count as before.
Commit `fix(app): show the selected iPad sidebar row in mint`.

## Test plan

- No unit test: this is a visual environment change. The owner check is the test.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, same test count
- [ ] Only `AppRootView.swift` changed, two added modifiers plus their comments
- [ ] `plans/README.md` row updated

Owner check on the iPad, light and dark mode:

1. Sidebar shown: the selected row is a mint capsule with a readable label, for each of Overview, Planner, Service Year and Settings.
2. Sidebar hidden (tab bar at the top): the selected tab looks right; report how it looks, since it is now mint too.
3. Inside the tabs, buttons, toggles and links look as before (monochrome), for example the Overview + button, a Settings toggle and the Planner.
4. A sheet opened inside a tab (a Planner day, Submit Report) looks as before.

Owner check on the iPhone: the tab bar and everything else look exactly as before.

## STOP conditions

Stop and report if:

- The drift check shows changes.
- `tabs` no longer has one `NavigationStack` per `Tab`.

## Maintenance notes

- If the iPad's top tab bar (sidebar hidden) looks wrong in mint, the alternative is a neutral color such as `Color(.systemGray)` for the same modifier.
- Any new view placed directly inside the `TabView` but outside a tab's `NavigationStack` will inherit mint.
