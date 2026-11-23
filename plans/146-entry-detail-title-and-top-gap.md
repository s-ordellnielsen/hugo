# Plan 146: Left-align the entry detail title and remove the gap under the toolbar

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/Features/Entries/Screens/EntryDetailView.swift Hugo/DesignSystem/Modifiers/EditorialNavigationTitle.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it. This plan adds no strings.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW. One view's navigation bar. The risk is a long category name colliding with the More button, and a content margin that behaves differently across iOS versions.
- **Depends on**: none
- **Category**: ui
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-327](https://linear.app/sebastianln/issue/SLN-327)

## Why this matters

On the entry detail sheet, the category icon and name are centered in the
navigation bar, and the form leaves a gap below it before the first section.
The title should sit on the left, and the first section should start right
under the bar.

## Current state

`Hugo/Features/Entries/Screens/EntryDetailView.swift`, inside `NavigationStack { Form { ... } }`:

```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        HStack {
            Image(systemName: category.iconName)
            Text(category.name).font(.headline).fontDesign(.serif)
        }
    }
    ToolbarItem {
        Menu { ... } label: { Label("common.more", systemImage: "ellipsis") }
        ...
    }
}
```

There is no `navigationTitle` and no display mode. `EntryDetailView` is shown
in two places: from the Overview list (`OverviewListView`, `.sheet(item: $selectedEntry)`)
and from the Planner day sheet (`PlannerDaySheet`, `.sheet(item: $selectedEntry)`).
Both use `.presentationDetents([.medium, .large])`. Test both after the change.

The app's serif title style is `editorialNavigationTitle` in
`Hugo/DesignSystem/Modifiers/EditorialNavigationTitle.swift`. It puts the title
in a `.principal` item, so it is centered. It is not suitable here.

Rules from `AGENTS.md` that apply: SwiftUI only; keep the serif design; Simplicity.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/Entries/Screens/EntryDetailView.swift`

**Out of scope**:

- `EditorialNavigationTitle.swift` and every other screen.
- What the form shows.

## Git workflow

- Work on `main`. One commit, for example `fix(entries): left-align the entry detail title`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Left-align the title (try the primary approach first)

Primary approach: a leading toolbar item instead of the principal one.

```swift
ToolbarItem(placement: .topBarLeading) {
    Label {
        Text(category.name).font(.system(.headline, design: .serif, weight: .bold))
    } icon: {
        Image(systemName: category.iconName)
    }
    .labelStyle(.titleAndIcon)
    .lineLimit(1)
}
.sharedBackgroundVisibility(.hidden)
```

`.sharedBackgroundVisibility(.hidden)` removes the glass capsule so the title
looks like a title, not a button. Keep the existing More `ToolbarItem` as is.
Do NOT add `.navigationTitle` or a display mode: an inline navigation title
is drawn centered in the bar, so it would show the category name a second time
next to the leading item (the reviewer found this on the first run). The
leading item carries the name, and `.accessibilityAddTraits(.isHeader)` on it
gives VoiceOver the heading.

Judge it: the icon and name sit on the left, in serif, in one line; a long name
(for example "Theocratic Ministry School Assistance") truncates with an ellipsis and
never overlaps the More button; the large Dynamic Type sizes do not break the bar.

Fallback, only if the primary approach shows a capsule you cannot remove or the title clips:
use `.navigationTitle(category.name)` with `.navigationBarTitleDisplayMode(.inline)`,
drop the custom item, and accept the
system title style. Then apply the serif font only if SwiftUI allows it without
a custom item. If it does not, report that the serif title and left alignment conflict, and stop.

**Verify**: build succeeds.

### Step 2: Remove the gap under the toolbar

Add to the `Form`:

```swift
.contentMargins(.top, 0, for: .scrollContent)
```

Judge it: the first section header ("Duration") sits close under the bar, with
about the spacing a plain `Form` has when pushed with an inline title. It must
not touch the bar and must not be cut off when scrolled.

If `.contentMargins` has no visible effect, the gap may come from the form's
section header inset. Then try `.listSectionSpacing(.compact)` on the `Form`. Do not use negative padding or a fixed offset.

**Verify**: `Scripts/verify.sh` exits 0.

## Test plan

Pure layout. No unit test. The gate is a build plus the owner check below.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] Title is left-aligned, serif, with the category icon
- [ ] The first section starts right under the toolbar
- [ ] `git status --short` shows only `EntryDetailView.swift` (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

Owner check on device: open an entry from the Overview and from a Planner day,
in light and dark mode, at default and largest Dynamic Type, with a very long
category name, an entry with no category (untracked), and after changing the
category from the menu (the title updates).

## STOP conditions

Stop and report if:

- Neither approach gives a left-aligned serif title without a capsule.
- Removing the top margin makes the first section collide with the toolbar.
- You need to edit `EditorialNavigationTitle.swift`.

## Maintenance notes

- Other screens keep the centered `editorialNavigationTitle`. This view differs on purpose because its title is the entry's category, not a screen name.
