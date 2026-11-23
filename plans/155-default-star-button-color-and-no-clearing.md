# Plan 155: Make the default star button yellow and stop it from clearing the default

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat b980d57..HEAD -- Hugo/Features/Categories/Views/DefaultCategoryButton.swift Hugo/Features/Categories/Screens/CategoryDetailView.swift`
> Expected: no output. If a file changed, compare it with "Current state" and STOP on a mismatch.
> `git status --short` may show `M Hugo/Resources/Localizable.xcstrings` (the
> owner's own edit). Never touch, stage or commit it.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW. One small button. The color fix cannot be seen from the command line, so the owner checks it on a device.
- **Depends on**: plans 143 and 144 (done)
- **Category**: bug
- **Planned at**: commit `b980d57`, 2026-11-23
- **Issue**: [SLN-325](https://linear.app/sebastianln/issue/SLN-325) (reopened after the owner's device check of plan 144)

## Why this matters

The owner tried plan 144 on a device. Two problems:

1. The star in the category list is yellow, but the star button in the toolbar
   of a category's page is not yellow when the category is the default. The
   plan set `.foregroundStyle(isDefault ? .yellow : .primary)` on the label,
   and a toolbar button ignores a foreground style set on its label. A toolbar
   button takes its color from its tint.
2. Tapping the star of the category that is already the default clears the
   default, because the button calls `setDefault(isDefault ? nil : tracker)`.
   Then no category is the default and new entries start without a category.
   The owner called this a bug. A default category should always exist, so the
   only way to change it is to make another category the default.

After this plan: the filled star on the category page is yellow; tapping it
when the category is already the default does nothing; tapping the outline star
makes this category the default.

## Current state

`Hugo/Features/Categories/Views/DefaultCategoryButton.swift` (whole body):

```swift
struct DefaultCategoryButton: View {
    @AppStorage(UserDefaultsKeys.defaultCategoryID) private var defaultCategoryID: String?
    @Query private var trackers: [Tracker]

    var tracker: Tracker

    private var isDefault: Bool {
        DefaultCategory.resolve(storedID: defaultCategoryID, in: trackers)?.id == tracker.id
    }

    var body: some View {
        Button {
            DefaultCategoryService().setDefault(isDefault ? nil : tracker)
        } label: {
            Label("tracker.options.use-as-default", systemImage: isDefault ? "star.fill" : "star")
                .labelStyle(.iconOnly)
                .foregroundStyle(isDefault ? .yellow : .primary)
                .contentTransition(.symbolEffect(.replace))
                .motion(Motion.feedback, value: isDefault)
        }
        .accessibilityAddTraits(isDefault ? .isSelected : [])
    }
}
```

It is shown from `CategoryDetailView.swift:92` as `ToolbarItem { DefaultCategoryButton(tracker: tracker) }`.

`DefaultCategoryService.setDefault(_ tracker: Tracker?)` stays as it is. Its
`nil` case is still used by `DefaultCategoryServiceTests` and by
`DefaultCategory.resolve` (`""` means no default). Do not remove either. The
button simply never passes `nil` any more.

Rules from `AGENTS.md` that apply: SwiftUI only; keep accessibility traits;
the app must stay easy to use for ages 13 to 70.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Whole gate | `Scripts/verify.sh` | exit 0 |
| Format check | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/Categories/Views/DefaultCategoryButton.swift`

**Out of scope**:

- `DefaultCategoryService`, `DefaultCategory`, the settings key, the list star, `AddCategoryView`.
- Any string. No text changes.

## Git workflow

- Work on `main`. One commit, for example `fix(categories): color the default star yellow and keep a default`.
- Do not push. Never stage `Hugo/Resources/Localizable.xcstrings`.

## Steps

### Step 1: Stop the button from clearing the default

Change the button action to:

```swift
Button {
    if !isDefault { DefaultCategoryService().setDefault(tracker) }
} label: {
```

Do not use `.disabled(isDefault)`: a disabled button draws dimmed, and the
yellow star must stay bright. Keep `.accessibilityAddTraits(isDefault ? .isSelected : [])`.

**Verify**: `grep -n "setDefault" Hugo/Features/Categories/Views/DefaultCategoryButton.swift` shows one call, with `tracker` as the argument and no `nil`.

### Step 2: Color the toolbar star with the button's tint

A toolbar button takes its icon color from `.tint`. Remove the `.foregroundStyle(isDefault ? .yellow : .primary)` line from the label and add to the `Button` (after the accessibility trait):

```swift
.tint(isDefault ? .yellow : .primary)
```

Keep `.contentTransition` and `.motion` on the label. The outline star must stay
the primary color, as plan 144 required.

You cannot see the toolbar from the command line (there is no way to tap through
to the category page), so do not try to screenshot it. Make sure it compiles and
the gate passes, and say in NOTES that the color is unverified.

If `.tint(isDefault ? .yellow : .primary)` does not type-check, write
`.tint(isDefault ? Color.yellow : Color.primary)`.

**Verify**: `Scripts/verify.sh` exits 0.

## Test plan

No new unit test: the change is in a view and the service is untouched.
`DefaultCategoryServiceTests` and `DefaultCategoryTests` must keep passing.

Owner check on a device:

- Category page for the default category: the toolbar star is filled and yellow.
- Tap it: nothing happens, and the star stays yellow and filled. The default category is still set (open Add Entry and confirm the category is preselected).
- Category page for another category: the star is the outline in the primary color. Tap it: it turns yellow and filled, and the previous default's star in the list goes away.
- VoiceOver on the toolbar button: reads the label and "selected" for the default.

If the star is still not yellow on the device, report it. Other options, to try
in a follow-up plan, are `Image(systemName:).foregroundStyle(.yellow)` as the
button's label content and `.symbolRenderingMode(.multicolor)`.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `grep -n "nil" Hugo/Features/Categories/Views/DefaultCategoryButton.swift` shows no `setDefault(nil)` or `? nil :`
- [ ] `.accessibilityAddTraits(isDefault ? .isSelected : [])` is still in the file
- [ ] `git status --short` shows only the in-scope file (plus the owner's `Localizable.xcstrings`, unstaged)
- [ ] `plans/README.md` row updated

## STOP conditions

Stop and report if:

- `DefaultCategoryButton` no longer matches "Current state".
- Making the star yellow seems to need a change outside the button.

## Maintenance notes

- A default category always exists. Nothing in the UI sets `""` any more. Do not add a "no default" control.
- Toolbar items take their icon color from `.tint`, not from a foreground style on the label. Other colored toolbar icons should do the same.
