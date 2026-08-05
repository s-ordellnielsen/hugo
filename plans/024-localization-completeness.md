# Plan 024: Localization completeness — Danish gaps, stale keys, catalog audit

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 024
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Resources/Localizable.xcstrings`
> If the catalog changed, regenerate the audits in Steps 1–3 against the live
> file and treat any structural surprise as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/017-user-visible-correctness.md, plans/020-accessibility-foundation.md, plans/023-dead-code-and-api-hygiene.md
- **Category**: code-quality (user-facing correctness for a Danish-first app)
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

The app's source language is English and it ships Danish and English. Ten
catalog keys currently have **no Danish localization at all** — including five
user-facing `common.*` buttons (`common.add`, `common.dismiss`, `common.done`,
`common.error`, `common.retry`). With `useSFSymbolsKey` etc. absent, a Danish
user who hits an error alert sees English chrome. `entry.add.label` has been
parked at `needs_review` with a stale English source ("Add Event" — the app
calls them *entries*, never events; this is the only "Event" string in the
whole catalog). Plans 017 and 020 add new English-only keys whose Danish
translations belong here, and plan 023 deletes the last consumer of
`navigation.help`.

## Current state

`Hugo/Resources/Localizable.xcstrings` — 2,980 lines, 176 keys, languages
`da` + `en`, `sourceLanguage: en`, `version: 1.1`.

### A. Keys with no Danish localization (10)

| Key | Kind |
|---|---|
| `common.add` | user-facing button ("Add") |
| `common.dismiss` | user-facing button ("Dismiss") — used by plan 017's shared alert |
| `common.done` | user-facing button ("Done") |
| `common.error` | alert title ("Error") — used by plan 017's shared alert |
| `common.retry` | user-facing button ("Retry") — used by plan 017's shared alert |
| `' '` (single space) | junk extraction — **zero localizations**, not referenced in any Swift source |
| `%lld` | extraction artifact of `Text("\(Int(value))")` in `MonthlyProgressCard.swift:18` |
| `%lld %@` | extraction artifact of the two-arg `Text` in `SubmitReportView.swift:178`; its `en` unit is still `state: new` |
| `+%@` | extraction artifact of `Text("+\(...)")` rows in `SubmitReportView.swift:41,69,78` |
| `−%@` | extraction artifact of `Text("−\(...)")` at `SubmitReportView.swift:87` |

The five format-string artifacts are *technically resolvable* at runtime
(SwiftUI looks interpolated `Text` up in the catalog) but carry no linguistic
content; when a `da` unit is absent, SwiftUI falls back to the interpolation
itself, which renders identically.

### B. Stale state

- `entry.add.label` — `da: "Tilføj til rapport"`, `state: needs_review`;
  `en: "Add Event"`, `state: translated`.
- `%lld %@` — `en` unit `state: new` (never promoted).

### C. New English-only keys landing in earlier plans

- Plan 017 adds `entry.add.validation.invalid` with English
  ("Enter a duration and choose a category.").
- Plan 020 adds ~10 `a11y.*` keys with English values only (its Step 8
  explicitly defers Danish to this plan).

### D. Dead key after plan 023

- `navigation.help` (`en: "Help"`, `da: "Hjælp"`) — plan 023 Step 1 removes its
  only call site.

### Conventions

- Catalog is the single source of truth; Xcode does not auto-extract at build
  time here (keys are added by hand / were extracted historically).
- Existing Danish is high-quality and idiomatic (e.g. `report.hours.unit`:
  `en "h"` / `da "t"`). Match that register — terse, native, no anglicisms.
- The operator is a native Danish speaker who reviews localizations. **All
  Danish values proposed below are suggestions; the operator has final sign-off
  at review.** Do not treat review-time wording changes as plan failures.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Parse check | `python3 -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | silent exit 0 |
| Missing-da audit | `python3` audit snippet in Step 4 | 0 user-facing keys without `da` |
| Full gate | `Scripts/verify.sh` | exit 0 |
| Manual | Run app in Danish (scheme → Run → Options → App Language → Danish), open an error alert | Danish chrome |

## Scope

**In scope**:
- `Hugo/Resources/Localizable.xcstrings` — only file modified by this plan.

**Out of scope** (do NOT touch):
- Any Swift source. If a key turns out to be needed but missing from Swift, the
  owning plan (017/020) adds it there — report instead of patching Swift here.
- Extraction/mechanics of the `.xcstrings` format beyond the JSON edits below.
- The `%lld`-style *call sites* in Swift (`MonthlyProgressCard`,
  `SubmitReportView`). Replacing interpolated `Text` with keyed strings is a
  code change; it is listed under "Maintenance notes" as a follow-up, not done
  here.

## Git workflow

- Branch: `advisor/024-localization-completeness`
- One commit per step, message style: `` `024` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 1: Danish for the five `common.*` keys

Add `da` units (`state: translated`) to the existing keys. Suggested values —
idiomatic, terse, consistent with `common.delete → "Slet"` and
`common.filter → "Filtrer"` already in the catalog:

| Key | Suggested `da` |
|---|---|
| `common.add` | `Tilføj` |
| `common.dismiss` | `Afvis` |
| `common.done` | `Færdig` |
| `common.error` | `Fejl` |
| `common.retry` | `Prøv igen` |

Note for reviewer: Apple's own Danish HIG uses "Afvis" for Dismiss in alert
contexts; if the app ever uses `common.dismiss` for a sheet (rather than an
alert), "Luk" is the better word. At audit time the only consumer is plan 017's
error alert, so "Afvis" is correct.

**Verify**: parse check passes; each of the five keys shows both `da` and `en`.

### Step 2: Resolve `entry.add.label`

The flag exists because the English source is wrong, not the Danish. Fix both:

- `en`: `Add Event` → `Add Entry` (matches the app's "entry" vocabulary used
  everywhere else — `EntriesView`, `entry.list.empty`, etc.).
- `da`: keep `Tilføj til rapport` **only if** that is the wording the operator
  wants; the literal Danish for the new English is `Tilføj post`. The existing
  "Tilføj til rapport" is arguably *better* UX (it says where the entry goes).
  **Default: keep `Tilføj til rapport`.** Either way, set `state: translated`.

**Verify**: `grep -c "needs_review" Hugo/Resources/Localizable.xcstrings` → 0.
`grep -c "Add Event" Hugo/Resources/Localizable.xcstrings` → 0.

### Step 3: Danish for keys added by plans 017 and 020

Run first: `python3` one-liner printing every key that has `en` but no `da` —
that is the authoritative list at execution time (plans 017/020 may have landed
with slightly different key names than drafted). Expected set:

| Key | Suggested `da` |
|---|---|
| `entry.add.validation.invalid` | `Angiv en varighed og vælg en kategori.` |
| `a11y.card.month-progress.hint` | `Åbner den detaljerede rapport` |
| `a11y.card.month-report.hint` | `Åbner månedens poster` |
| `a11y.card.month-empty.hint` | `Tilføjer en post til denne måned` |
| remaining `a11y.card.*` labels/values | mirror the English structure; Danish word order: `%@ - fremgang`, `%lld timer denne måned`, `%@ - ingen poster`, `%@ - rapport` |
| `a11y.entry.bible-studies.%lld` | `%lld bibelstudier` |
| `a11y.breakdown.bar` (label) + its value string | e.g. label `Kategorifordeling`; value `%@: %lld timer` — confirm against plan 020's landed key names |

Add each `da` unit with `state: translated`. If plan 020 landed format-style
keys with placeholders, keep placeholder order identical to English.

**Verify**: the audit prints **zero** keys with `en` but no `da`, excluding
only the four format-artifact keys handled in Step 4 and `' '`.

### Step 4: Purge junk and dead keys

Delete from the catalog (JSON entries, whole `"key": { … }` objects):

1. `' '` — no localizations, no references. Pure noise.
2. `navigation.help` — consumer removed by plan 023 Step 1. First confirm:
   `grep -rn "navigation.help" Hugo` → no matches in Swift. If a match exists,
   **keep the key** and note it (plan 023 didn't fully land); do not delete.
3. Promote `%lld %@`'s `en` unit from `state: new` to `state: translated`
   (value unchanged) so the catalog has zero non-translated states. Do **not**
   delete `%lld`, `%lld %@`, `+%@`, `−%@` — they are runtime-resolvable format
   keys; deleting them changes nothing user-visible but also removes the
   translator's only hook for reordering (e.g. unit-before-number). They stay,
   documented in "Maintenance notes".

**Verify**: parse check passes; `grep -c '" "'` on the exact key line → 0;
`grep -c "navigation.help"` → 0 (or the STOP note above); no `state: new` or
`needs_review` anywhere.

### Step 5: Full audit + gate

Run the audit script below and paste its output into the commit message body:

```sh
python3 - <<'PY'
import json
d = json.load(open("Hugo/Resources/Localizable.xcstrings"))["strings"]
missing_da = sorted(k for k, v in d.items() if "da" not in v.get("localizations", {}))
missing_en = sorted(k for k, v in d.items() if "en" not in v.get("localizations", {}))
stale = sorted((k, l, u.get("stringUnit", {}).get("state"))
               for k, v in d.items() for l, u in v.get("localizations", {}).items()
               if u.get("stringUnit", {}).get("state") not in (None, "translated"))
print("missing da:", missing_da)
print("missing en:", missing_en)
print("non-translated states:", stale)
PY
```

Expected: `missing da` lists exactly the four format artifacts (`%lld`,
`%lld %@`, `+%@`, `−%@`); `missing en` is empty; `non-translated states` is
empty.

Then `Scripts/verify.sh` → exit 0 (the catalog is compiled; a malformed edit
fails the build here).

## Test plan

No unit tests — the catalog has no test target coverage and adding one is out
of scope. Verification is: JSON parse, the audit script, the full gate, and one
manual Danish run. Commit message must include the Step 5 audit output.

## Done criteria

ALL must hold:

- [ ] Catalog parses as JSON (`python3` load silent)
- [ ] Every user-facing key has both `da` and `en` units at `state: translated`
- [ ] Only `da`-less keys are the four documented format artifacts
- [ ] Zero `needs_review` / `new` states in the file
- [ ] `' '` and `navigation.help` removed (or `navigation.help` retained with a note if plan 023's grep found a live reference)
- [ ] `Add Event` no longer appears anywhere in the catalog
- [ ] `Scripts/verify.sh` exits 0
- [ ] Manual Danish run: error alert (from plan 017) shows Danish title/buttons
- [ ] `plans/README.md` row for 024 updated

## STOP conditions

Stop and report if:

- The Step 3 audit surfaces keys **not** traceable to plans 017/020 (means an
  unrelated change added keys between audit and execution — re-plan instead of
  guessing translations).
- `grep -rn "navigation.help" Hugo` finds a live Swift reference after plan 023.
- Any key exists in Swift but not in the catalog at all (a missing-key bug, not
  a translation gap — report it; do not silently invent the English source).
- The operator rejects a suggested Danish value at review — record the chosen
  wording; that is a review outcome, not a failure.

## Maintenance notes

- The four format-artifact keys (`%lld`, `%lld %@`, `+%@`, `−%@`) are the
  visible symptom of interpolated `Text("\(...)")`. The real fix is replacing
  those call sites with keyed strings (e.g. `report.hours-carried.%@`) — a code
  change deliberately left out of this plan. Until then, leave the artifacts
  alone.
- New-key rule going forward: a key is not "done" until it has `da` + `en` at
  `state: translated`. Any future plan that adds keys should list this plan as
  the place their Danish lands, or include Danish itself.
- The `a11y.*` namespace added by plan 020 + translated here is now the pattern
  for accessibility strings: keep labels, values and hints as separate keys
  rather than baking sentences into code.
- If a third language is ever added, the Step 5 audit script is the checklist.
