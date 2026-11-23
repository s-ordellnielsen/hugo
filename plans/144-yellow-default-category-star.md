# Plan 144: Draw the default category star in yellow

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 07d4c61..HEAD -- Hugo/Features/Categories/Views/DefaultCategoryButton.swift Hugo/Features/Categories/Screens/CategoryListView.swift Hugo/Features/Categories/Screens/CategoryDetailView.swift`
> Expected after plan 143 lands: changes to the first two files only (the star state now comes from the setting). Compare with "Current state". STOP on any other mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW. A color change on two views. The one real concern is contrast, which the owner checks on a device.
- **Depends on**: plan 143 (`plans/143-store-default-category-as-one-setting.md`)
- **Category**: ui
- **Planned at**: commit `07d4c61`, 2026-11-23
- **Issue**: [SLN-325](https://linear.app/sebastianln/issue/SLN-325)

## Why this matters

The filled favorite star uses `.hugoAccent`. That is the same color as other
tinted controls, so a star does not read as "favorite". Yellow is the color
people expect for a starred item. After this plan the filled star is `.yellow`
everywhere it shows.

## If plan 143 has not landed

This plan is written for the state after plan 143: the star state is
`isDefault`, a computed property that compares the category with
`DefaultCategory.resolve(storedID:in:)`. Check with
`grep -n "DefaultCategory.resolve" Hugo/Features/Categories/Views/DefaultCategoryButton.swift`.
If there is no match, plan 143 has not landed. The color change is still the
same single line in each file, but the condition there is `tracker.isDefault`.
In that case do the steps below with `tracker.isDefault` in place of `isDefault`, and
tell the reviewer that 143 will conflict on those lines. Do not do any of 143's work here.

## Current state

`Hugo/Features/Categories/Views/DefaultCategoryButton.swift` (before 143):

```swift
Label("tracker.options.use-as-default", systemImage: tracker.isDefault ? "star.fill" : "star")
    .labelStyle(.iconOnly)
    .foregroundStyle(tracker.isDefault ? .hugoAccent : .primary)
    .contentTransition(.symbolEffect(.replace))
    .motion(Motion.feedback, value: tracker.isDefault)
...
.accessibilityAddTraits(tracker.isDefault ? .isSelected : [])
```

After 143, `tracker.isDefault` is replaced by the local computed property `isDefault`.

`Hugo/Features/Categories/Screens/CategoryListView.swift` around line 28:

```swift
if tracker.isDefault {
    Image(systemName: "star.fill")
        .font(.callout)
        .foregroundStyle(.hugoAccent)
}
```

After 143 the condition compares the row with the resolved default id.

`Hugo/Features/Categories/Screens/CategoryDetailView.swift:92` shows
`DefaultCategoryButton(tracker: tracker)` in the toolbar. It needs no change.

Rules from `AGENTS.md` that apply: the app must be easy to read for users from
13 to 70, so keep accessibility traits; vanilla SwiftUI feel (the owner wants
extremely native with small tasteful touches). Use the system `.yellow`, not a
custom color.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Find leftovers | `grep -rn "star.fill" Hugo --include='*.swift'` | each match uses `.yellow` or is not the default star |

## Scope

**In scope**:

- `Hugo/Features/Categories/Views/DefaultCategoryButton.swift`
- `Hugo/Features/Categories/Screens/CategoryListView.swift`

**Out of scope**:

- Any other use of `star` or `star.fill` that is not the default category star (check the grep in Step 3).
- The `.hugoAccent` color definition.
- Logic, the setting, and the strings.

## Git workflow

- Work on `main`. One commit, for example `feat(categories): draw the default category star in yellow`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: The detail toolbar button

In `DefaultCategoryButton.swift` change only the `.foregroundStyle` line:

```swift
.foregroundStyle(isDefault ? Color.yellow : Color.primary)
```

The symbol stays `star.fill` when the category is the default and `star`
otherwise, and the outline star keeps the primary color. Keep
`.accessibilityAddTraits(isDefault ? .isSelected : [])`, `.contentTransition` and `.motion` unchanged.
Use `Color.yellow` and `Color.primary` explicitly so both branches of the ternary have one type
(the original compiled with `.hugoAccent : .primary` through `ShapeStyle`, so a bare
`.yellow : .primary` also works. If it does, keep the shorter form).

**Verify**: `grep -n "hugoAccent" Hugo/Features/Categories/Views/DefaultCategoryButton.swift` returns nothing.

### Step 2: The category list star

In `CategoryListView.swift` change `.foregroundStyle(.hugoAccent)` on the `star.fill` image to `.foregroundStyle(.yellow)`. Keep the rest of the row as it is. The star is decorative, so do not add a label. If the row already
announces the default some other way, leave that alone. If it does not, do not add anything: that is outside this plan.

**Verify**: `grep -n "hugoAccent" Hugo/Features/Categories/Screens/CategoryListView.swift` returns nothing, unless the match is on a line other than the star.

### Step 3: Check for other default stars

Run `grep -rn "star.fill" Hugo --include='*.swift'`. If another view draws the
default category star with `.hugoAccent`, change it the same way. Unrelated
stars stay untouched.

**Verify**: `Scripts/verify.sh` exits 0.

## Test plan

No new test. Color is not asserted in this repo, and the existing tests do not
touch these views. `Scripts/verify.sh` must still exit 0.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] No default star uses `.hugoAccent` (`grep -rn "hugoAccent" Hugo/Features/Categories` shows none on a star line)
- [ ] `.accessibilityAddTraits(... .isSelected ...)` is still in `DefaultCategoryButton.swift`
- [ ] `git status --short` shows only the in-scope files (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

Owner check on a device, on the category detail screen and the category list:

- Light mode: the filled star is yellow and readable on the background, the outline star is the primary color.
- Dark mode: the same.
- Settings, Accessibility, Display, Increase Contrast on: the star is still clearly visible, and the outline star is still distinguishable from the filled one by shape.
- VoiceOver on the toolbar button reads the label and "selected" when the category is the default.

## STOP conditions

Stop and report if:

- `DefaultCategoryButton` or `CategoryListView` no longer matches "Current state" in a way other than plan 143's changes.
- The yellow star is hard to see on the light background. Report it and do not pick another color without asking.
- Making the change seems to need logic changes in the button or the list.

## Maintenance notes

- Yellow is the system `.yellow`, so it adapts to light, dark and increased contrast. Do not replace it with a fixed RGB.
- Any new place that shows the default category should use the same yellow filled star.
