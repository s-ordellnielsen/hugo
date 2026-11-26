# Plan 165: One sidebar gray that works as both selection fill and icon color

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 5123aa9..HEAD -- Hugo/App Hugo/DesignSystem/Theme`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). This plan adds no strings. Never stage that file.

## Status

- **Priority**: P1
- **Effort**: S + owner
- **Risk**: LOW. One color value and its doc comment.
- **Depends on**: 164
- **Category**: ux, accessibility
- **Planned at**: commit `5123aa9`, 2026-11-26
- **Issue**: [SLN-341](https://linear.app/sebastianln/issue/SLN-341)

## Why this matters

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

## Current state

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

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict Hugo/App/AppRootView.swift Hugo/DesignSystem/Theme/Theme.swift` | exit 0 |

## Scope

**In scope**: `Hugo/DesignSystem/Theme/Theme.swift` (`hugoSidebarSelection` only) and the one comment in `Hugo/App/AppRootView.swift`.

**Out of scope**: everything else. Keep the token's name, so `AppRootView`'s code line does not change.

## Git workflow

- Work on `main`. One commit: `fix(app): use one sidebar gray that reads as icon color too`.
- Do not push.

## Steps

### Step 1: Replace the color

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

### Step 2: Update the comment

In `AppRootView.swift`, replace the tint's comment with:
`// Neutral gray sidebar tint: it fills the selected row (white label) and colors the other rows' icons, where primary (white in dark mode) hid the selected label. Compact width keeps the iPhone tab bar as it was.`

**Verify**: lint exits 0; `Scripts/verify.sh` exits 0 with 653 tests.
Commit `fix(app): use one sidebar gray that reads as icon color too`.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, 653 tests
- [ ] Only the token body, its doc comment and one comment in `AppRootView` changed
- [ ] `plans/README.md` row updated

Owner check on the iPad, light and dark mode: the unselected sidebar icons are
clearly visible, and the selected row is a gray capsule with a readable white
label.

## STOP conditions

Stop and report if:

- The drift check shows changes.
- `Color(white:)` does not compile in a `nonisolated static var` (then use `Color(uiColor: UIColor(white: 0.44, alpha: 1))`, and note it).

## Maintenance notes

- Tuning: between 0.40 and 0.48 white, all four checks stay at least 3:1, and the text check stays at least 4.5:1 up to 0.46. Lighter grays make the icons stronger and the white label weaker.
