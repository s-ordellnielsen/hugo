# Plan 042: Label icon-only controls, fix the carried-in pill, and clean up the string catalog

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/Features/Settings/SettingsButton.swift Hugo/Features/Categories/DefaultCategoryButton.swift Hugo/Features/Overview Hugo/Features/Entries/AddEntry/AddEntryView.swift Hugo/Features/Reports/ReportingLineCard.swift Hugo/Resources/Localizable.xcstrings`
> Plans 037, 039 and 040 change `OverviewListView.swift` (whitespace, one
> detent line, `DateEntryRow`) and `OverviewMetrics.swift`. Those changes are
> expected. Any other change to an in-scope file is a mismatch: compare
> against the excerpts below and STOP if they differ.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/037-green-gate-and-serial-tests.md; run after plans/040-resolve-entry-category-in-one-place.md (both edit `OverviewListView.swift`)
- **Category**: bug (accessibility and localization)
- **Planned at**: commit `3f8d48b`, 2026-10-12
- **Issue**: [SLN-249](https://linear.app/sebastianln/issue/SLN-249)

## Why this matters

Hugo's users range from 13 to 70 years old, and AGENTS.md requires the app to "explain itself and make good use of accessibility features". Several controls fail that today:

- On iPhone, the only way into Settings is a toolbar button showing a bare "person" icon. VoiceOver announces "person", not "Settings".
- The default-category star in the category editor has no label and no selected state; whether a category is the default is shown only by color and fill.
- The Overview list-style picker (by date / by entry) has image-only segments and an empty title. Ready-made labels exist in `OverviewListStyle.accessibilityLabel` but are never used.
- The "Carried in from previous month" pill is a `Button` with an empty action. It also shows "0 min" in months with no carried time, because it renders unconditionally.
- With no categories, the add-entry screen shows the raw text `entry.add.tracker.none`. The key is missing from the catalog, and the `??` turns it into a plain string.
- VoiceOver users never hear their monthly goal, only "N hours this month".
- The catalog has two junk keys without Danish (`""` and `"↘"`), four Danish strings in `needs_review`, and two English strings in state `new`.

All fixes are labels, traits and strings. No logic or data changes.

## Current state

- `Hugo/Features/Settings/SettingsButton.swift:11-15`:

  ```swift
  Button {
      showAccount = true
  } label: {
      Image(systemName: "person.fill")
  }
  ```

- `Hugo/Features/Categories/DefaultCategoryButton.swift:11-23`:

  ```swift
  Button {
      do {
          try DefaultCategoryService(context: context).setDefault(tracker.isDefault ? nil : tracker)
      } catch {
          errorMessage = error.localizedDescription
      }
  } label: {
      Image(systemName: tracker.isDefault ? "star.fill" : "star")
          .foregroundStyle(tracker.isDefault ? .hugoAccent : .primary)
          .contentTransition(.symbolEffect(.replace))
          .motion(Motion.feedback, value: tracker.isDefault)
  }
  .errorAlert(message: $errorMessage)
  ```

- `Hugo/Features/Overview/Views/OverviewListStyleControl.swift:16-26`:

  ```swift
  var body: some View {
      Picker("", selection: $selection) {
          Image(systemName: OverviewListStyle.byEntry.iconName)
              .tag(OverviewListStyle.byEntry)
          Image(systemName: OverviewListStyle.byDate.iconName)
              .tag(OverviewListStyle.byDate)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
  }
  ```

  `Hugo/Features/Overview/Domain/OverviewListStyle.swift:21-26` defines `accessibilityLabel: LocalizedStringKey` returning `"a11y.overview.list-style.by-date"` / `"a11y.overview.list-style.by-entry"` (both translated in en and da).

- `Hugo/Features/Overview/Views/OverviewListView.swift:52` renders `OverviewCarriedEntriesView(entries: groups.carried)` unconditionally, and the view itself (bottom of the same file) is:

  ```swift
  var body: some View {
      Button {
      } label: {
          HStack(spacing: HugoLayout.Spacing.tight) {
              Text(
                  "overview.carried.summary.label"
              )
              Text(totalDuration.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                  .fontWeight(.semibold)
          }
          .font(.caption)
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color(.systemGray5))
          .foregroundStyle(.secondary)
          .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
      }
  }
  ```

  (Indentation fixed by plan 037.)

- `Hugo/Features/Entries/AddEntry/AddEntryView.swift:28-36`:

  ```swift
  Section {
      Button {
          form.isCategoryPickerPresented = true
      } label: {
          Label(
              form.selectedTracker?.name ?? "entry.add.tracker.none",
              systemImage: form.selectedTracker?.iconName ?? "circle")
      }
  }
  ```

- `Hugo/Features/Reports/ReportingLineCard.swift:70-72`:

  ```swift
  Text("↘")
      .accessibilityHidden(true)
  ```

- `Hugo/Features/Overview/MonthlyProgressCard.swift:35-37` (`monthlyGoal` is a `Double` property of the card; 0 means no goal):

  ```swift
  .accessibilityElement(children: .combine)
  .accessibilityLabel(Text("a11y.monthly_progress_card.label"))
  .accessibilityValue(Text("a11y.monthly_progress_card.value.\(Int(value))"))
  ```

- `Hugo/Features/Overview/CategoryProgressBreakdownView.swift:29-37`: a `GeometryReader` with colored `Rectangle`s that form a stacked bar. The rows under it already list each category's name and time as text.

- `Hugo/Resources/Localizable.xcstrings`: source language `en`, plus `da`. Keys needing attention:

  | Key | Problem |
  |---|---|
  | `""` | created by `Picker("")`; no translations |
  | `"↘"` | created by `Text("↘")`; no translations |
  | `overview.entries.empty.actions.add` | da `needs_review` ("Tilføj timer") |
  | `publisher.status.goal.description.monthly` | da `needs_review` ("%lld timer om måneden"), en `new` |
  | `publisher.status.goal.description.yearly` | da `needs_review` ("%lld timer om året"), en `new` |
  | `publisher.status.goal.description.none` | da `needs_review` ("Intet fast mål") |

  The file is JSON written by Xcode: 2-space indent, `" : "` separators, non-ASCII characters unescaped, empty objects written as `{` + blank line + `}`, and **no trailing newline**. The script below reproduces that format exactly (verified at `3f8d48b`: a load and save with no edits leaves the file byte-identical).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Catalog check | `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |
| Full gate | `Scripts/verify.sh` | exit 0 |

Catalog helper. Save it as `/tmp/xcstrings_edit.py` (outside the repo; do not commit it):

```python
import json
import re

PATH = "Hugo/Resources/Localizable.xcstrings"


def load():
    with open(PATH, encoding="utf-8") as f:
        return json.loads(f.read())


def save(data):
    out = json.dumps(data, indent=2, separators=(",", " : "), ensure_ascii=False)
    out = re.sub(r"^( *)(.*)\{\}", lambda m: f"{m.group(1)}{m.group(2)}{{\n\n{m.group(1)}}}", out, flags=re.M)
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(out)


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def entry(comment, en, da):
    return {"comment": comment, "localizations": {"da": unit(da), "en": unit(en)}}


def natural(key):
    # Xcode orders catalog keys case-insensitively with numbers compared by value.
    return [(0, int(t)) if t.isdigit() else (1, t.lower()) for t in re.split(r"(\d+)", key) if t != ""]


def insert_sorted(strings, key, value):
    items = list(strings.items())
    index = next((i for i, (k, _) in enumerate(items) if natural(k) > natural(key)), len(items))
    items.insert(index, (key, value))
    return dict(items)
```

`natural` reproduces the order Xcode uses (verified against the whole catalog at `3f8d48b`).

## Scope

**In scope**:

- `Hugo/Features/Settings/SettingsButton.swift`
- `Hugo/Features/Categories/DefaultCategoryButton.swift`
- `Hugo/Features/Overview/Views/OverviewListStyleControl.swift`
- `Hugo/Features/Overview/Views/OverviewListView.swift` (`OverviewCarriedEntriesView` and the line that renders it)
- `Hugo/Features/Overview/MonthlyProgressCard.swift` (accessibility value only)
- `Hugo/Features/Overview/CategoryProgressBreakdownView.swift` (one modifier)
- `Hugo/Features/Entries/AddEntry/AddEntryView.swift` (category label only)
- `Hugo/Features/Reports/ReportingLineCard.swift` (line 71 only)
- `Hugo/Resources/Localizable.xcstrings`
- `plans/README.md` (status row)

**Out of scope**:

- Visual styling: colors, fonts, spacing, corner radii. Follow the existing monochrome design. Do not change how anything looks except removing the empty-month pill.
- The duration text format ("01:30") and `DurationWheelPicker` unit labels. Separate findings.
- Turning the carried-in pill into navigation. It becomes a plain, non-interactive summary.
- Plural variations for `a11y.monthly_progress_card.value.%lld`. Its value uses Xcode's generated named-argument syntax (`%1$(value)lld`); leave it.

## Git workflow

- Branch: `advisor/042-a11y-l10n`
- Commit message style: short imperative sentence, for example `Label the Settings button for VoiceOver`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 0: Confirm the catalog helper is lossless

Run: `python3 -c "import sys; sys.path.insert(0, '/tmp'); import xcstrings_edit as x; x.save(x.load())"`.

**Verify**: `git diff --stat -- Hugo/Resources/Localizable.xcstrings` → prints nothing. If it prints a change, STOP (the helper does not match the file format).

### Step 1: Label the icon-only buttons

1. `SettingsButton.swift`: replace `Image(systemName: "person.fill")` with:

   ```swift
   Label("settings.title", systemImage: "person.fill")
       .labelStyle(.iconOnly)
   ```

2. `DefaultCategoryButton.swift`: replace the `Image(...)` label with a `Label` that keeps the same modifiers, and add a trait to the button:

   ```swift
   } label: {
       Label("tracker.options.use-as-default", systemImage: tracker.isDefault ? "star.fill" : "star")
           .labelStyle(.iconOnly)
           .foregroundStyle(tracker.isDefault ? .hugoAccent : .primary)
           .contentTransition(.symbolEffect(.replace))
           .motion(Motion.feedback, value: tracker.isDefault)
   }
   .accessibilityAddTraits(tracker.isDefault ? .isSelected : [])
   .errorAlert(message: $errorMessage)
   ```

   Both keys already exist in the catalog: `settings.title` ("Settings" / "Indstillinger") and `tracker.options.use-as-default` ("Use as Default" / "Brug som standard").

**Verify**: lint exits 0; `grep -n 'Label(' Hugo/Features/Settings/SettingsButton.swift Hugo/Features/Categories/DefaultCategoryButton.swift` → one match in each file.

Commit: `Label the Settings and default-category buttons`.

### Step 2: Label the list-style picker

In `OverviewListStyleControl.swift`:

```swift
Picker("overview.list-style.label", selection: $selection) {
    ForEach([OverviewListStyle.byEntry, .byDate], id: \.self) { style in
        Image(systemName: style.iconName)
            .accessibilityLabel(Text(style.accessibilityLabel))
            .tag(style)
    }
}
.pickerStyle(.segmented)
.labelsHidden()
.fixedSize()
```

Keep the segment order (by entry, then by date). Add the new key in Step 6.

**Verify**: `grep -n 'Picker("")' Hugo -r` → no matches.

### Step 3: Make the carried-in pill a plain summary, shown only when needed

1. In `OverviewListView.body`, render it only when there is carried time:

   ```swift
   if !groups.carried.isEmpty {
       OverviewCarriedEntriesView(entries: groups.carried)
   }
   ```

2. In `OverviewCarriedEntriesView.body`, remove the `Button { } label:` wrapper. Keep the `HStack` and every modifier on it exactly as they are, and add `.accessibilityElement(children: .combine)` as the last modifier.

**Verify**: `grep -n 'Button {$' -A1 Hugo/Features/Overview/Views/OverviewListView.swift | grep -c '} label:'` → `0` for the carried view (any remaining `Button` in the file must have a non-empty action).

Commit steps 2-3: `Label the list-style picker and simplify the carried-in summary`.

### Step 4: Fix the add-entry category placeholder and the arrow glyph

1. `AddEntryView.swift`: replace the `Label(...)` inside the category button with:

   ```swift
   if let tracker = form.selectedTracker {
       Label(tracker.name, systemImage: tracker.iconName)
   } else {
       Label("entry.add.tracker.none", systemImage: "circle")
   }
   ```

   The `else` branch uses the `LocalizedStringKey` initializer, so the key is translated. Add the key in Step 6.
2. `ReportingLineCard.swift:71`: change `Text("↘")` to `Text(verbatim: "↘")`.

**Verify**: lint exits 0.

### Step 5: Speak the goal on the progress card; hide the decorative bar

1. `MonthlyProgressCard.swift`: replace the `.accessibilityValue(...)` line with:

   ```swift
   .accessibilityValue(
       monthlyGoal > 0
           ? Text("a11y.monthly_progress_card.value.\(Int(value)).\(Int(monthlyGoal))")
           : Text("a11y.monthly_progress_card.value.\(Int(value))")
   )
   ```

2. `CategoryProgressBreakdownView.swift`: add `.accessibilityHidden(true)` to the `GeometryReader` that draws the stacked bar (after its `.frame(height:)`). The rows below already state each category and its time.

**Verify**: lint exits 0.

Commit steps 4-5: `Translate the empty category label and speak the monthly goal`.

### Step 6: Update the string catalog

Run this with the helper (one script; adjust nothing else):

```python
import sys
sys.path.insert(0, "/tmp")
import xcstrings_edit as x

data = x.load()
strings = data["strings"]

# 1. Remove the two junk keys (no longer referenced after Steps 2 and 4).
strings.pop("", None)
strings.pop("↘", None)

# 2. Approve the strings left for review.
for key in [
    "overview.entries.empty.actions.add",
    "publisher.status.goal.description.monthly",
    "publisher.status.goal.description.yearly",
    "publisher.status.goal.description.none",
]:
    for lang in ("da", "en"):
        unit = strings[key]["localizations"][lang]["stringUnit"]
        unit["state"] = "translated"

# 3. Add the new keys in Xcode's order.
strings = x.insert_sorted(strings, "a11y.monthly_progress_card.value.%lld.%lld", x.entry(
    "Accessibility value of the monthly progress card when a goal exists. First argument: hours so far. Second: the monthly goal in hours.",
    "%1$lld of %2$lld hours this month",
    "%1$lld af %2$lld timer denne måned",
))
strings = x.insert_sorted(strings, "entry.add.tracker.none", x.entry(
    "Placeholder on the add-entry screen when no category is selected.",
    "Choose Category",
    "Vælg kategori",
))
strings = x.insert_sorted(strings, "overview.list-style.label", x.entry(
    "Title of the segmented control that switches the Overview list between grouping by date and by entry.",
    "List Style",
    "Listevisning",
))

data["strings"] = strings
x.save(data)
```

**Verify**:

- Catalog check command → exit 0.
- `python3 -c "import json; s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings']; print([k for k,v in s.items() if v.get('localizations',{}).get('da',{}).get('stringUnit',{}).get('state')!='translated' and 'variations' not in v.get('localizations',{}).get('da',{})])"` → prints `[]`.
- `git diff --stat -- Hugo/Resources/Localizable.xcstrings` → one file changed.
- `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` → roughly 55 added and 15 removed lines. Hundreds of changed lines mean keys moved: reset with `git checkout -- Hugo/Resources/Localizable.xcstrings` and STOP.
- `Scripts/verify.sh` → exit 0.

Commit: `Clean up the string catalog and add missing keys`.

### Step 7 [owner]: Check with VoiceOver and in Danish

1. VoiceOver on, Overview tab: the toolbar button reads "Settings". The list-style segments read "Sort by Entry" / "Sort by Date". The progress card reads "Month Progress, 12 of 50 hours this month" with a goal set.
2. Category editor: the star reads "Use as Default", plus "Selected" when it is the default.
3. Delete every category, open Add Entry: the button reads "Choose Category" (Danish: "Vælg kategori").
4. A month without carried-in time shows no "Carried in" pill.
5. Review the four Danish strings approved in Step 6. In particular, "Tilføj timer" ("Add hours") is the empty-state button, while the toolbar button for the same action says "Tilføj til rapport".

## Test plan

These are view-level label and catalog changes with no logic to unit-test. The guards are the `grep` checks in each step, the catalog checks in Step 6, the full gate, and the owner VoiceOver pass in Step 7.

## Done criteria

- [ ] `grep -rn 'Picker("")' Hugo` prints nothing
- [ ] `grep -n 'Text("↘")' Hugo/Features/Reports/ReportingLineCard.swift` prints nothing
- [ ] The Step 6 Danish-state check prints `[]`
- [ ] `python3 -c "import json; s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings']; print('entry.add.tracker.none' in s, '' in s)"` prints `True False`
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 042 updated

## STOP conditions

Stop and report back if:

- Step 0 shows that the helper changes the catalog without edits.
- A key named in Step 6 is missing from the catalog (it was renamed or removed since this plan was written).
- `OverviewCarriedEntriesView` is used anywhere besides `OverviewListView` (`grep -rn 'OverviewCarriedEntriesView(' Hugo`).
- After Step 1, the star or Settings button visibly changes size or shows its title text. `.labelStyle(.iconOnly)` should prevent that; report rather than restyling.

## Maintenance notes

- New icon-only controls should use `Label(key, systemImage:)` with `.labelStyle(.iconOnly)`, so VoiceOver and Voice Control get a name for free.
- Never pass `""` or a decorative glyph to a `LocalizedStringKey` initializer. Use `Text(verbatim:)` for glyphs and give pickers a real title even when the label is hidden.
- `a11y.monthly_progress_card.value.%lld` still reads "1 hours this month" for exactly one hour. Fixing that needs a plural variation added from Xcode's string catalog editor, which keeps its generated argument names intact.
