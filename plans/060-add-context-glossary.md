# Plan 060: Add a CONTEXT.md domain glossary and point AGENTS.md at it

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 26e63f4..HEAD -- CONTEXT.md AGENTS.md`
> If either file changed since this plan was written, compare the "Current
> state" section against the live files before proceeding. On a mismatch,
> treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `26e63f4`, 2026-11-03

## Why this matters

Hugo has no shared glossary, so the same idea gets different names in different files, and one name covers different ideas. The clearest case is "actual": `ReportingLine.actualSeconds` is logged time, while `YearlyGoalProgress.actualSeconds` is mostly reported hours. Plans 061 to 066 rename and merge code around domain concepts, and they need fixed words to name things with. A root `CONTEXT.md` is the place agents and people look up what a term means. After this plan, every later plan can say "use the CONTEXT.md term" instead of re-explaining it.

## Current state

- `CONTEXT.md` does not exist. `git ls-files CONTEXT.md` prints nothing.
- `AGENTS.md` (repo root) holds coding rules. Section 5 starts like this (lines 82-85):

  ```markdown
  ## 5. Domain Vocabulary & Business Logic

  ### Theocratic Year Definition
  In this application, we use a custom calendar system called the **Theocratic Year**. You must respect this definition across all date calculations, database schemas, and UI layouts.
  ```

- A glossary has strict rules, and the content below follows them:
  - It defines domain terms only: no type names, no file paths, no implementation details.
  - Each definition is one or two sentences and says what the thing *is*.
  - When several words exist for one idea, one is chosen and the others go under `_Avoid_`.
  - It is a glossary, not a spec. Rules about code stay in `AGENTS.md`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| File exists | `test -f CONTEXT.md && echo ok` | `ok` |
| No implementation words | `grep -nE '\.swift|distantPast|SwiftData|@Model|struct |enum ' CONTEXT.md` | no output |
| Pointer added | `grep -n 'CONTEXT.md' AGENTS.md` | one line |

No Swift changes, so `Scripts/verify.sh` is not needed.

## Scope

**In scope**:

- `CONTEXT.md` (create)
- `AGENTS.md` (add two sentences)
- `plans/README.md` (status row)

**Out of scope**:

- Renaming any code to match the glossary. Plans 061 to 066 do that where it pays.
- Creating `docs/adr/`. Create it only when a real decision needs recording.
- Changing UI strings in `Hugo/Resources/Localizable.xcstrings`. The glossary is for people working on the code. The app may keep its own wording (for example "Counted toward goal").

## Git workflow

- Branch: `advisor/060-context-glossary`
- Conventional Commits, as in `git log`: for example `docs: add the CONTEXT.md domain glossary`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create `CONTEXT.md`

Create `CONTEXT.md` at the repo root with exactly this content:

```markdown
# Hugo

Hugo helps a Jehovah's Witness publisher log their ministry time, send the monthly report to their group overseer and follow their goal for the theocratic year.

## Time

**Entry**:
One piece of logged ministry time: a date, a duration, a category and optionally a number of Bible studies.
_Avoid_: Record, log, session

**Category**:
What an entry's time counts as, such as Field Service or Bethel. Every category is either a main category or a separate category.
_Avoid_: Tracker, type

**Main category**:
A category whose time is reported together on the Field Service line.
_Avoid_: Primary category

**Separate category**:
A category whose time is reported on its own line, apart from Field Service, such as Bethel or LDC.
_Avoid_: Other, secondary category

**Default category**:
The main category that new entries use unless the user picks another. A new install starts with one, named Field Service.

**Category snapshot**:
The name, icon and kind of an entry's category, copied onto the entry so the entry keeps its category if the category is renamed or deleted.

**Untracked entry**:
An entry that has neither a category nor a category snapshot.

**Logged time**:
The sum of entry durations, before any rounding.
_Avoid_: Actual time, raw time

**Month**:
One calendar month. A report always covers exactly one month.

**Theocratic year**:
The year from September 1 to August 31, written as both calendar years, for example 2026/2027.
_Avoid_: Service year, school year

## Reports

**Report**:
What the publisher sends the overseer for one month: whole hours for each reporting line and the number of Bible studies.

**Submitted report**:
Hugo's saved copy of a report that was sent, including when it was sent and which entries it covered.
_Avoid_: Monthly report

**Placeholder report**:
A saved report for a month that was never actually sent, left behind when older data was upgraded. It counts as not submitted.
_Avoid_: Sentinel, backfill

**Reporting line**:
One line of a report: Field Service, which holds all main time, or one separate category. Each line is rounded on its own.

**Remainder**:
The minutes on a reporting line beyond its whole hours.

**Rounding rule**:
What happens to a reporting line's remainder: round up, round down or transfer. The user picks one per line when submitting.

**Transfer**:
The rounding rule that moves a reporting line's remainder into the next month.
_Avoid_: Carry over (as the rule's name)

**Carried-in entry**:
An entry Hugo creates on the 1st of the next month to hold minutes that were transferred.
_Avoid_: Generated entry, carry entry

**Reported hours**:
The whole hours on a submitted report's lines.
_Avoid_: Submitted time

**Unreported change**:
A difference between a submitted month and its entries now: an entry added after the report was sent, or totals that no longer match the report. A month with an unreported change should be submitted again.

**Due month**:
The month whose report the Overview currently reminds the user to send.

**Overseer**:
The group overseer who receives the publisher's reports.

**Greeting template**:
The user's own opening text that Hugo puts at the top of each report message.

## Goals

**Publisher status**:
The user's role, which sets their goal: publisher, auxiliary pioneer or regular pioneer.

**Monthly goal**:
The hours the publisher status expects in one month. A yearly goal is split evenly into twelve monthly goals.

**Yearly goal**:
The hours the publisher status expects in one theocratic year. Only statuses with a yearly goal get yearly goal progress.

**Year total**:
For one theocratic year: the reported hours of every submitted month plus the logged time of every month not yet submitted.
_Avoid_: Actual total

**Credited time**:
The part of a month's time that counts toward the yearly goal: all main time, plus separate time until the month reaches its monthly goal plus the separate allowance. The app shows it as "Counted toward goal".
_Avoid_: Counted time

**Separate allowance**:
The hours of separate-category time that may count beyond the monthly goal in one month.

**Expected time**:
The credited time the user should have by now to reach the yearly goal at an even pace.

**Pacing**:
How expected time is worked out for the current month: in proportion to the days passed, counting only completed months, or counting the whole current month.

## Sync

**Sync duplicate**:
Two copies of the same row that two devices each created before they synced. Hugo merges them and keeps one, the survivor.
_Avoid_: Conflict

**Canonical report**:
The one submitted report Hugo uses for a month when sync duplicates or placeholder reports leave more than one.

## Flagged ambiguities

- "Actual" has meant logged time in some places and year total in others. Say logged time, reported hours, year total or credited time instead.
- "Field Service" names both the default category and the reporting line that holds all main time. Say "the Field Service line" for the line.
```

**Verify**:

- `test -f CONTEXT.md && echo ok` → `ok`
- `grep -nE '\.swift|distantPast|SwiftData|@Model|struct |enum ' CONTEXT.md` → no output
- `grep -c '^\*\*' CONTEXT.md` → `33`

### Step 2: Point `AGENTS.md` at the glossary

In `AGENTS.md`, directly under the heading `## 5. Domain Vocabulary & Business Logic` and before `### Theocratic Year Definition`, add one blank line and this paragraph:

```markdown
Domain terms are defined in `CONTEXT.md` at the repo root. Use those words in type names, comments and plans, and add a term there in the same change when you introduce a new domain concept.
```

**Verify**: `grep -n 'CONTEXT.md' AGENTS.md` → exactly one line, inside section 5 (line number between 82 and 86).

Commit: `docs: add the CONTEXT.md domain glossary`.

## Test plan

No code changes, so there are no tests. The verification commands above check the result.

## Done criteria

- [ ] `test -f CONTEXT.md && echo ok` prints `ok`
- [ ] `grep -nE '\.swift|distantPast|SwiftData|@Model' CONTEXT.md` prints nothing
- [ ] `grep -c 'CONTEXT.md' AGENTS.md` prints `1`
- [ ] `git status --porcelain` lists only `CONTEXT.md`, `AGENTS.md` and `plans/README.md`
- [ ] `plans/README.md` row for 060 updated

## STOP conditions

Stop and report back if:

- `CONTEXT.md` or a `CONTEXT-MAP.md` already exists. Someone started a glossary, and it must be merged, not overwritten.
- `AGENTS.md` section 5 no longer starts with `### Theocratic Year Definition`.

## Maintenance notes

- Later plans add terms: plan 061 adds "Service month". Each plan that names a new domain concept should add it to `CONTEXT.md` in the same commit.
- Keep the file a glossary. Rules such as "Persistence names remain `Tracker` even where the UI says Category" belong in `AGENTS.md`, not here.
- Whether an untracked entry counts as main time is inconsistent in the code today: reporting lines count it as Field Service time, but month summaries leave it out of main time. The glossary therefore says only what an untracked entry is. Decide the rule before writing it down.
