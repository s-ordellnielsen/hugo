# Plan 043: Make the rounding help reachable where users choose a rounding rule

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/Features/Reports/SubmitReportView.swift Hugo/Features/Settings/Screens/ReportSettingsView.swift Hugo/Features/Help Hugo/Resources/Markdown/Help`
> If any of these changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding. On a mismatch,
> treat it as a STOP condition. (`Localizable.xcstrings` is expected to change
> in plan 042; this plan only adds one key to it.)

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/037-green-gate-and-serial-tests.md; run after plans/042-accessibility-and-localization-fixes.md (both edit `Localizable.xcstrings`)
- **Category**: direction (usability)
- **Planned at**: commit `3f8d48b`, 2026-10-12

## Why this matters

When submitting a monthly report, users pick one of three rules for leftover minutes: round up, round down, or transfer to next month. For a user base aged 13 to 70, this is the hardest choice in the app. A finished help page explains it in English and Danish (`RoundingRule.md`), and a `HelpView` renders it. But nothing opens the help page: its last entry point was removed when the default-rule setting was dropped (commit `30b7e08`), which also left an unused `showingHelp` state in `ReportSettingsView`. The English page still tells users to pick a default rule in Settings, which no longer exists, and the Danish page stops mid-sentence. After this plan, the submit screen and the report settings both link to an accurate help page.

## Current state

- `Hugo/Features/Help/Screens/HelpView.swift`: a complete sheet. `HelpView(for: "RoundingRule")` loads `RoundingRule.md` from the main bundle (localized `.lproj` folders), renders it with MarkdownUI inside its own `NavigationStack`, and has a close button. Its only use is its `#Preview` (line 117). Do not modify it.
- `Hugo/Resources/Markdown/Help/Base.lproj/RoundingRule.md:40-44` (English):

  ```markdown
  ## Which rule should I choose?

  Choose the rule that fits your needs the best, only you know how you report your time.

  You can select your default rule in settings and can be customized on a per report basis when submitting a report.
  ```

- `Hugo/Resources/Markdown/Help/da.lproj/RoundingRule.md:40-44` (Danish; the file ends after "Du" with no newline):

  ```markdown
  ## Hvilken regel skal jeg vælge?

  Vælg den regel, der passer bedst til den måde, du rapporterer din tid på.

  Du kan vælge din standardregel i Indstillinger. Du
  ```

- How rules work today: the user picks a rule per report line in `ReportingLineCard` (the "handle extra minutes" menu). When the user re-submits a month, `SubmitReportFormModel.load` pre-selects the rules stored on the previous submission (`SubmitReportFormModel.swift:59-65`). A "transfer" creates an entry dated the 1st of the next month, shown on the Overview as "Carried in from previous month".

- `Hugo/Features/Reports/SubmitReportView.swift:71-82` (the cards on the submit screen):

  ```swift
  ForEach(orderedResults) { result in
      ReportingLineCard(
          result: result,
          rule: Binding(
              get: { model.rule(for: result.id) },
              set: { model.setRule($0, for: result.id) }
          ),
          monthName: { $0.monthName() }
      )
  }

  Spacer(minLength: HugoLayout.Spacing.section)
  ```

  The view already holds sheet state as `@State private var ... = false` properties (lines 13-16) and presents sheets with `.sheet(isPresented:)` (lines 171-182).

- `Hugo/Features/Settings/Screens/ReportSettingsView.swift:10-49`: a `List` with one `Section` (overseer and greeting rows), and an unused `@State private var showingHelp = false` at line 14.

- `Hugo/Resources/Localizable.xcstrings`: Xcode-written JSON (2-space indent, `" : "` separators, unescaped non-ASCII, empty objects as `{` + blank line + `}`, no trailing newline, keys ordered case-insensitively with numbers compared by value). Use the helper below to add a key without reformatting the file.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 |

Catalog helper. Save as `/tmp/xcstrings_edit.py` (do not commit). If plan 042's executor left it there, reuse it.

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
    return [(0, int(t)) if t.isdigit() else (1, t.lower()) for t in re.split(r"(\d+)", key) if t != ""]


def insert_sorted(strings, key, value):
    items = list(strings.items())
    index = next((i for i, (k, _) in enumerate(items) if natural(k) > natural(key)), len(items))
    items.insert(index, (key, value))
    return dict(items)
```

## Scope

**In scope**:

- `Hugo/Features/Reports/SubmitReportView.swift`
- `Hugo/Features/Settings/Screens/ReportSettingsView.swift`
- `Hugo/Resources/Markdown/Help/Base.lproj/RoundingRule.md`
- `Hugo/Resources/Markdown/Help/da.lproj/RoundingRule.md`
- `Hugo/Resources/Localizable.xcstrings` (one new key)
- `plans/README.md` (status row)

**Out of scope**:

- `HelpView.swift` and the MarkdownUI package. Removing or replacing the dependency is a separate decision.
- `ReportingLineCard.swift`. Do not add a button to every card; one link per screen is enough and keeps the cards simple.
- Any other section of the two help files.

## Git workflow

- Branch: `advisor/043-rounding-help`
- Commit message style: short imperative sentence, for example `Link the rounding help from the submit screen`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Fix the help text

1. English file: replace the last paragraph (line 44) with:

   ```markdown
   You choose a rule for each line when you submit a report. If you submit the same month again, Hugo starts with the rules you chose last time.

   When you transfer minutes, Hugo adds them to the next month as an entry dated the 1st. You will see it on the Overview as time carried in from the previous month.
   ```

2. Danish file: replace the unfinished line 44 with:

   ```markdown
   Du vælger en regel for hver linje, når du indsender en rapport. Hvis du indsender den samme måned igen, starter Hugo med de regler, du valgte sidst.

   Når du overfører minutter, lægger Hugo dem til den næste måned med datoen den 1. Du kan se dem på Overblik som tid overført fra forrige måned.
   ```

   End both files with a single newline.

**Verify**: `grep -c 'default rule\|standardregel' Hugo/Resources/Markdown/Help/*/RoundingRule.md` → `0` for both files. `tail -c 1 Hugo/Resources/Markdown/Help/da.lproj/RoundingRule.md | od -c` shows `\n`.

Commit: `Update rounding help for per-line rules`.

### Step 2: Add the link text to the catalog

```python
import sys
sys.path.insert(0, "/tmp")
import xcstrings_edit as x

data = x.load()
data["strings"] = x.insert_sorted(data["strings"], "report.rounding.help.link", x.entry(
    "Button that opens the help page explaining the rounding rules for leftover minutes.",
    "How does rounding work?",
    "Hvordan fungerer afrunding?",
))
x.save(data)
```

**Verify**: `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` → about 18 added lines and 0 removed.

### Step 3: Link the help from the submit screen

In `SubmitReportView`:

1. Add `@State private var showingRoundingHelp = false` next to the other `@State` properties.
2. Directly after the `ForEach(orderedResults)` block (before the following `Spacer`), add a link that appears only when some line has leftover minutes:

   ```swift
   if model.results.contains(where: { $0.line.needsRule }) {
       Button("report.rounding.help.link", systemImage: "questionmark.circle") {
           showingRoundingHelp = true
       }
       .font(.subheadline)
       .padding(.top, HugoLayout.Spacing.compact)
   }
   ```

3. Next to the other `.sheet` modifiers add `.sheet(isPresented: $showingRoundingHelp) { HelpView(for: "RoundingRule") }`.

**Verify**: lint exits 0.

### Step 4: Link the help from the report settings

In `ReportSettingsView`, use the existing `showingHelp` state. Add a second `Section` after the existing one:

```swift
Section {
    Button("report.rounding.help.link", systemImage: "questionmark.circle") {
        showingHelp = true
    }
}
```

and attach `.sheet(isPresented: $showingHelp) { HelpView(for: "RoundingRule") }` to the `List`.

**Verify**: `grep -rn 'HelpView(for:' Hugo | grep -v '#Preview' | grep -vc 'HelpView.swift'` → `2`. `Scripts/verify.sh` → exit 0.

Commit steps 2-4: `Link the rounding help from the submit screen and report settings`.

### Step 5 [owner]: Check both languages

1. Open the submit sheet for a month whose total has leftover minutes. Tap "How does rounding work?". The help page opens, and its last section matches Step 1.
2. Switch the simulator language to Danish and repeat. The page is Danish and ends with a complete sentence.
3. Settings → Report: the same link opens the same page.
4. Review the new Danish sentences for tone.

## Test plan

No unit tests: the change adds two buttons that open an existing view, plus text. `HelpView`'s loader already has an "unavailable" state if the resource is missing. Verification is the grep in Step 4, the full gate, and the owner check in Step 5.

## Done criteria

- [ ] `grep -c 'standardregel\|default rule' Hugo/Resources/Markdown/Help/*/RoundingRule.md` prints `0` for both files
- [ ] `python3 -c "import json; print('report.rounding.help.link' in json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'])"` prints `True`
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 043 updated

## STOP conditions

Stop and report back if:

- `HelpView(for:)` no longer exists or its initializer changed.
- `showingHelp` is no longer in `ReportSettingsView` or is now used for something else.
- `model.results` or `ReportingLine.needsRule` no longer exist under those names.
- The help page shows "unavailable" in the simulator (the `.md` files are not in the app bundle). Report it; do not move the files.

## Maintenance notes

- Later help topics (for example "carried-in entries") can reuse the same pattern: a `.md` file in both `.lproj` folders and a `HelpView(for:)` sheet.
- If the rounding rules change, update both language files in the same commit. The Danish file went out of date once already.
- The MarkdownUI package exists only for `HelpView`. If help stays this small, rendering with `AttributedString(markdown:)` could replace it, but that is a separate decision.
