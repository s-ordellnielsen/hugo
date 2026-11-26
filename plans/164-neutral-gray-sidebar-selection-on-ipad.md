# Plan 164: Show the selected iPad sidebar row in neutral gray

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 15c7fd2..HEAD -- Hugo/App Hugo/DesignSystem/Theme`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P1
- **Effort**: S + owner
- **Risk**: LOW. One color token and one changed line. The iPhone is unaffected (compact width keeps `primary`).
- **Depends on**: 163
- **Category**: ux
- **Planned at**: commit `15c7fd2`, 2026-11-26
- **Issue**: [SLN-341](https://linear.app/sebastianln/issue/SLN-341)

## Why this matters

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

## Current state

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

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict Hugo/App/AppRootView.swift Hugo/DesignSystem/Theme/Theme.swift` | exit 0 |

## Scope

**In scope**: `Hugo/DesignSystem/Theme/Theme.swift` (one color), `Hugo/App/AppRootView.swift` (one modifier and two comments).

**Out of scope**: everything else, including `HugoApp.swift` and any UIKit sidebar styling.

## Git workflow

- Work on `main`. One commit: `fix(app): show the selected iPad sidebar row in neutral gray`.
- Do not push.

## Steps

### Step 1: Add the color

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

### Step 2: Use it

In `AppRootView.swift`:

- Replace `.tint(isCompact ? Color.primary : Color.hugoAccent)` with `.tint(isCompact ? Color.primary : Color.hugoSidebarSelection)`.
- Replace its comment with: `// Neutral gray selection in the iPad sidebar, where a primary (white in dark mode) capsule hides its white label. Compact width keeps the iPhone tab bar as it was.`
- Change the `NavigationStack` comment to: `// The tab view's tint is for the sidebar selection only; content stays monochrome.`

**Verify**: `grep -n "hugoAccent" Hugo/App/AppRootView.swift` prints nothing. Lint exits 0. `Scripts/verify.sh` exits 0 with 653 tests.
Commit `fix(app): show the selected iPad sidebar row in neutral gray`.

## Test plan

- No unit test: a visual color. The owner check is the test.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, 653 tests
- [ ] Only the two in-scope files changed
- [ ] `plans/README.md` row updated

Owner check on the iPad, light and dark mode: the selected sidebar row is a gray
capsule with a readable white label. With the sidebar hidden, the top tab bar's
selection looks right. Content inside the tabs is still monochrome. The iPhone
is unchanged.

## STOP conditions

Stop and report if:

- The drift check shows changes.
- `AppRootView` no longer has the `.tint(isCompact ? Color.primary : Color.hugoAccent)` line.

## Maintenance notes

- A mint label on a gray capsule needs UIKit sidebar configuration (`UITabSidebarItem`). That was rejected on 2026-11-26. Revisit only if SwiftUI gains a sidebar selection style API.
- To tune the gray, change only `hugoSidebarSelection`. Keep white text readable: in light mode the fill must stay at least as dark as `UIColor(white: 0.45)`.
