# Plan 163: Readable selected row in the iPad sidebar

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
- **Revisions**: original (mint, `15c7fd2`) was dropped by the owner on the iPad; Revision 1 (neutral gray, `5123aa9`); Revision 2 (one gray for the selection fill and the icons, `8a60518`); Revision 3 (mint again as a trial, `1d51620`), which the owner kept; Revision 4 (remove the gray). Revisions 1 and 2 were first written as plans 164 and 165 and folded in here on 2026-11-26.

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

## Revision 1 (2026-11-26): neutral gray instead of mint

Drift baseline for this revision: `15c7fd2`. Shipped as `5123aa9`.

### Why this matters

Plan 163 made the selected iPad sidebar row mint, because a `primary` tint drew
a white capsule with a white label in dark mode. The owner looked at the mint
capsule on the iPad and did not like it. They asked for a faded gray capsule
with a mint label.

SwiftUI cannot draw that. Its `TabView` sidebar has no API for the selected
row's style. In the iOS SDK's SwiftUI interface, the sidebar API is only
`tabViewSidebarHeader`, `tabViewSidebarFooter`, `tabViewSidebarBottomBar`,
`sectionActions`, badges and `tabViewCustomization`. The capsule is always
filled with the tint, and the label is drawn in white. A mint label would need
UIKit's `UITabSidebarItem` configuration on the `UITabBarController` that
SwiftUI creates, which breaks the SwiftUI-only rule in `AGENTS.md` and could
break with any iOS update.

Owner decision (2026-11-26): a neutral gray capsule with the system's white
label. In light mode the gray must be dark enough for white text, and in dark
mode it can be a soft dark gray.

### Current state

`Hugo/App/AppRootView.swift`, in `tabs` (from plan 163):

```swift
        .tabViewStyle(.sidebarAdaptable)
        // Mint selection in the iPad sidebar, where a primary (white in dark mode) capsule hides its label. Compact width keeps the iPhone tab bar as it was.
        .tint(isCompact ? Color.primary : Color.hugoAccent)
```

Each tab's `NavigationStack` has `.tint(.primary)` with the comment
`// The tab view's mint is for the sidebar selection only; content stays monochrome.`

`Hugo/DesignSystem/Theme/Theme.swift` has dynamic colors next to `hugoAccent`.
Follow this existing example:

```swift
    /// Progress track background that is white in light mode and the system's
    /// default fill in dark mode, for tracks that sit on a grouped background.
    nonisolated static var hugoLightTrack: Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? .quaternarySystemFill : .white
            })
    }
```

### Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict Hugo/App/AppRootView.swift Hugo/DesignSystem/Theme/Theme.swift` | exit 0 |

### Scope

**In scope**: `Hugo/DesignSystem/Theme/Theme.swift` (one color), `Hugo/App/AppRootView.swift` (one modifier and two comments).

**Out of scope**: everything else, including `HugoApp.swift` and any UIKit sidebar styling.

### Git workflow

- Work on `main`. One commit: `fix(app): show the selected iPad sidebar row in neutral gray`.
- Do not push.

### Steps

#### Step 1: Add the color

In `Theme.swift`, directly after `hugoLightTrack` in `extension Color`, add:

```swift
    /// Fill of the selected row in the iPad sidebar. The system draws that
    /// row's label in white, so the gray is dark enough for white text in light
    /// mode (about 5:1) and a soft dark gray in dark mode.
    nonisolated static var hugoSidebarSelection: Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.systemGray3.resolvedColor(with: traits)
                    : UIColor(white: 0.42, alpha: 1)
            })
    }
```

#### Step 2: Use it

In `AppRootView.swift`:

- Replace `.tint(isCompact ? Color.primary : Color.hugoAccent)` with `.tint(isCompact ? Color.primary : Color.hugoSidebarSelection)`.
- Replace its comment with: `// Neutral gray selection in the iPad sidebar, where a primary (white in dark mode) capsule hides its white label. Compact width keeps the iPhone tab bar as it was.`
- Change the `NavigationStack` comment to: `// The tab view's tint is for the sidebar selection only; content stays monochrome.`

**Verify**: `grep -n "hugoAccent" Hugo/App/AppRootView.swift` prints nothing. Lint exits 0. `Scripts/verify.sh` exits 0 with 653 tests.
Commit `fix(app): show the selected iPad sidebar row in neutral gray`.

### Test plan

- No unit test: a visual color. The owner check is the test.

### Done criteria

- [ ] `Scripts/verify.sh` exits 0, 653 tests
- [ ] Only the two in-scope files changed
- [ ] `plans/README.md` row updated

Owner check on the iPad, light and dark mode: the selected sidebar row is a gray
capsule with a readable white label. With the sidebar hidden, the top tab bar's
selection looks right. Content inside the tabs is still monochrome. The iPhone
is unchanged.

### STOP conditions

Stop and report if:

- The drift check shows changes.
- `AppRootView` no longer has the `.tint(isCompact ? Color.primary : Color.hugoAccent)` line.

### Maintenance notes

- A mint label on a gray capsule needs UIKit sidebar configuration (`UITabSidebarItem`). That was rejected on 2026-11-26. Revisit only if SwiftUI gains a sidebar selection style API.
- To tune the gray, change only `hugoSidebarSelection`. Keep white text readable: in light mode the fill must stay at least as dark as `UIColor(white: 0.45)`.

## Revision 2 (2026-11-26): one gray for the selection fill and the icons

Drift baseline for this revision: `5123aa9`. Shipped as `8a60518`.

### Why this matters

After plan 164 the owner saw, in dark mode on the iPad, that the selected
sidebar row is fine but the icons of the unselected rows (Overview, Planner,
Service Year) are very faint.

The iPad sidebar uses the `TabView`'s tint twice. It fills the selected row's
capsule, with a white icon and label on top. It also colors the icons of
unselected rows, as Apple's Mail, Notes and Files sidebars show their icons in
the accent color. Plan 164's dark-mode value, `systemGray3` (about 28% white),
reads well as a capsule behind white text, but as an icon color on the dark
sidebar it nearly disappears.

One gray must therefore pass two contrast checks in both appearances:

- White label on the gray capsule: at least 4.5:1 (WCAG AA for text).
- Gray icon on the sidebar background (about `#1C1C1E` in dark mode, `#F2F2F7` in light mode): at least 3:1 (WCAG for graphics).

A single gray of 44% white passes all four. With relative luminance about 0.162:
white text gives about 4.9:1, a dark sidebar gives about 3.4:1, and a light
sidebar gives about 4.4:1. Plan 164's light value (42%) was already close to
this, so light mode barely changes.

### Current state

`Hugo/DesignSystem/Theme/Theme.swift`, in `extension Color`:

```swift
    /// Fill of the selected row in the iPad sidebar. The system draws that
    /// row's label in white, so the gray is dark enough for white text in light
    /// mode (about 5:1) and a soft dark gray in dark mode.
    nonisolated static var hugoSidebarSelection: Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.systemGray3.resolvedColor(with: traits)
                    : UIColor(white: 0.42, alpha: 1)
            })
    }
```

`Hugo/App/AppRootView.swift` uses it as
`.tint(isCompact ? Color.primary : Color.hugoSidebarSelection)` with the comment
`// Neutral gray selection in the iPad sidebar, where a primary (white in dark mode) capsule hides its white label. Compact width keeps the iPhone tab bar as it was.`

### Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict Hugo/App/AppRootView.swift Hugo/DesignSystem/Theme/Theme.swift` | exit 0 |

### Scope

**In scope**: `Hugo/DesignSystem/Theme/Theme.swift` (`hugoSidebarSelection` only) and the one comment in `Hugo/App/AppRootView.swift`.

**Out of scope**: everything else. Keep the token's name, so `AppRootView`'s code line does not change.

### Git workflow

- Work on `main`. One commit: `fix(app): use one sidebar gray that reads as icon color too`.
- Do not push.

### Steps

#### Step 1: Replace the color

Replace `hugoSidebarSelection` (doc comment and body) with:

```swift
    /// Tint of the iPad sidebar. The sidebar fills the selected row with it
    /// (white icon and label on top) and draws the other rows' icons in it, so
    /// one gray must pass both: white text on it is about 4.9:1, and as an
    /// icon it is about 3.4:1 on the dark sidebar and 4.4:1 on the light one.
    nonisolated static var hugoSidebarSelection: Color {
        Color(white: 0.44)
    }
```

#### Step 2: Update the comment

In `AppRootView.swift`, replace the tint's comment with:
`// Neutral gray sidebar tint: it fills the selected row (white label) and colors the other rows' icons, where primary (white in dark mode) hid the selected label. Compact width keeps the iPhone tab bar as it was.`

**Verify**: lint exits 0; `Scripts/verify.sh` exits 0 with 653 tests.
Commit `fix(app): use one sidebar gray that reads as icon color too`.

### Done criteria

- [ ] `Scripts/verify.sh` exits 0, 653 tests
- [ ] Only the token body, its doc comment and one comment in `AppRootView` changed
- [ ] `plans/README.md` row updated

Owner check on the iPad, light and dark mode: the unselected sidebar icons are
clearly visible, and the selected row is a gray capsule with a readable white
label.

### STOP conditions

Stop and report if:

- The drift check shows changes.
- `Color(white:)` does not compile in a `nonisolated static var` (then use `Color(uiColor: UIColor(white: 0.44, alpha: 1))`, and note it).

### Maintenance notes

- Tuning: between 0.40 and 0.48 white, all four checks stay at least 3:1, and the text check stays at least 4.5:1 up to 0.46. Lighter grays make the icons stronger and the white label weaker.

## Revision 3 (2026-11-26): mint again, for a second look

Drift baseline for this revision: `8a60518`. Run first:
`git diff --stat 8a60518..HEAD -- Hugo/App Hugo/DesignSystem/Theme`. Expected: no output; STOP on a mismatch.

### Why

After Revision 2 the owner asked why white text on a white pill happened at all.
The answer: the sidebar takes one tint, fills the selected row with it and
draws the other rows' icons in it, always with a white label on the selected
row. `.primary` is white in dark mode, so it collided. A real accent color, as
in the original version of this plan, is how the sidebar is meant to be used.
With that explained, the owner wants to see mint (`Color.hugoAccent`) on the
iPad once more: a mint selected pill with a white label, mint icons on the other
rows, and monochrome screens. This is a trial. The owner will choose between
mint and the 44% gray after seeing it.

### Current state

`Hugo/App/AppRootView.swift`, in `tabs`:

```swift
        // Neutral gray sidebar tint: it fills the selected row (white label) and colors the other rows' icons, where primary (white in dark mode) hid the selected label. Compact width keeps the iPhone tab bar as it was.
        .tint(isCompact ? Color.primary : Color.hugoSidebarSelection)
```

Each tab's `NavigationStack` keeps `.tint(.primary)`. Do not change that.

### Scope

In scope: that one modifier and its comment in `Hugo/App/AppRootView.swift`.
Out of scope: everything else. Keep `Color.hugoSidebarSelection` in `Theme.swift`
unchanged and unused for now, so the owner can switch back with one line. Once
the owner decides, the losing option is removed in a Revision 4.

### Steps

#### Step 1

Replace the two lines above with:

```swift
        // Mint sidebar tint (trial, plan 163 Revision 3): the sidebar fills the selected row with it (white label) and draws the other rows' icons in it. Screens inside the tabs reset to primary. Compact width keeps the iPhone tab bar as it was.
        .tint(isCompact ? Color.primary : Color.hugoAccent)
```

**Verify**: `xcrun swift-format lint --strict Hugo/App/AppRootView.swift` exits 0, and
`Scripts/verify.sh` exits 0 with 653 tests. Commit `feat(app): try mint as the iPad sidebar tint again`.

### Done criteria

- [ ] `Scripts/verify.sh` exits 0, 653 tests
- [ ] Only `AppRootView.swift` changed (one line and its comment)

Owner check on the iPad, light and dark mode: mint selected pill with a white
label, mint icons on the other rows, and monochrome screens inside the tabs.
Then the owner chooses mint or gray.

### STOP conditions

- The drift check shows changes.
- The `.tint(isCompact ? Color.primary : Color.hugoSidebarSelection)` line is not there.

## Revision 4 (2026-11-26): keep mint, remove the gray

Drift baseline for this revision: `1d51620`. Run first:
`git diff --stat 1d51620..HEAD -- Hugo/App Hugo/DesignSystem/Theme`. Expected: no output; STOP on a mismatch.

### Why

The owner saw Revision 3 on the iPad and chose mint. The 44% gray
(`Color.hugoSidebarSelection`) is now unused, and the tint's comment still calls
mint a trial.

### Steps

#### Step 1

- In `Hugo/DesignSystem/Theme/Theme.swift`, delete `hugoSidebarSelection` with its doc comment (the whole `nonisolated static var hugoSidebarSelection: Color { Color(white: 0.44) }` block). Leave the blank-line layout of `extension Color` as the neighbors have it.
- In `Hugo/App/AppRootView.swift`, replace the comment above `.tint(isCompact ? Color.primary : Color.hugoAccent)` with:
  `// Mint sidebar tint: the sidebar fills the selected row with it (white label) and draws the other rows' icons in it; primary (white in dark mode) hid the selected label. Screens inside the tabs reset to primary. Compact width keeps the iPhone tab bar as it was.`

**Verify**: `grep -rn "hugoSidebarSelection" Hugo HugoTests` prints nothing. Lint both files with
`xcrun swift-format lint --strict`, exit 0. `Scripts/verify.sh` exits 0 with 653 tests.
Commit `refactor(app): keep mint as the iPad sidebar tint and drop the gray`.

### Done criteria

- [ ] `Scripts/verify.sh` exits 0, 653 tests
- [ ] Only `Theme.swift` (one token removed) and `AppRootView.swift` (one comment) changed

No owner check: the app looks exactly like Revision 3.

### STOP conditions

- The drift check shows changes.
- `hugoSidebarSelection` is used anywhere besides its own definition.
