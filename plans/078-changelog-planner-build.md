# Plan 078: Add the Planner build changelog in English and Danish

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `ls Changelog/1.0.0` must list exactly
> `111.en.md`, `116.da.txt` and `116.en.txt`. Anything else is a STOP condition.

## Status

- **Priority**: P1 (blocks the next TestFlight build)
- **Effort**: S
- **Risk**: LOW (two new text files)
- **Depends on**: plans/077-planner-danish-wording.md (the Danish text says "mål" for the target, which plan 077 introduces in the app)
- **Category**: docs
- **Planned at**: commit `34395b4`, 2026-11-05
- **Issue**: [SLN-280](https://linear.app/sebastianln/issue/SLN-280)

## Why this matters

The next TestFlight build is the first with the Planner, and testers need "What to Test" notes in Danish and English that explain what the Planner is and how to use it. The build number is not known yet, because Xcode Cloud assigns it when it builds. The owner decided to use placeholder file names, `next.en.txt` and `next.da.txt`, and to rename them once the build number is known (plan 079 does that).

## Current state

- `Changelog/1.0.0/` holds `111.en.md`, `116.da.txt` and `116.en.txt`. Files are named `<build number>.<language>.<ext>`. The `116.*.txt` files are UTF-8, use LF line endings, and have **no trailing newline**. Do not edit or rename them.
- Style of `116.da.txt` (the owner's own wording; match its tone): a short welcome, a section with an UPPERCASE heading, plain paragraphs, a question asking testers for feedback, then an `ÆNDRINGER` / `CHANGES` section with `- ` bullets.
- The notes cover what changed on `main` since the `testflight` branch (commit `26e63f4`, build 116). The reviewer checked the content below against `git log --oneline --no-merges testflight..main`: the Planner tab, plans, Log, the month header and target setting, plan pace on the Overview, carried-in time under its category on every screen (`6c07478`), and the changed-month banner no longer claiming new entries after an edit (`9a44c2e`). Everything else in that range is refactoring with no visible change.
- Facts the text relies on, checked in code: the Planner pages through the current month and the next 11 (`PlannerMonth.reachableMonths`, 12 months); the Log button is "Registrér" / "Log"; Add Entry is titled "Tilføj til rapport" / "Add Entry"; the target setting is under Settings → "Planlægger" / "Planner".

## Scope

**In scope** (create only):
- `Changelog/1.0.0/next.en.txt`
- `Changelog/1.0.0/next.da.txt`

**Out of scope**: every other file, including the existing changelog files.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage, edit, stash or discard files under `plans/` or `.claude/`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage the two new files by explicit path.
- One commit: `docs: add the Planner build changelog`

## Steps

### Step 1: Create the Danish file

Create `Changelog/1.0.0/next.da.txt` with exactly the text between the `BEGIN-DA` and `END-DA` marker lines (not the marker lines themselves). UTF-8, straight quotes, LF line endings, and NO trailing newline after the last character. Write it with `printf '%s'` from a quoted heredoc variable, or with a file-writing tool, and then check the last byte.

```
BEGIN-DA
Hugo er tilbage med en ny opdatering, og denne gang med en helt ny funktion: Planlæggeren. Lad os dykke ned i det.

PLANLÆGGER
Planlæggeren er en ny fane mellem Overblik og Tjenesteår. Her kan du planlægge, hvor meget tid du vil bruge i tjenesten hver dag, og se din plan for denne måned og de næste 11 måneder.

- Tryk på en dag for at tilføje en plan. En plan har en varighed, en kategori og eventuelt et starttidspunkt. Du kan have flere planer på samme dag.
- Hver plan vises som en bjælke i kalenderen, der fyldes op, efterhånden som du registrerer tid.
- Tryk på "Registrér" ved en plan for at åbne "Tilføj til rapport", hvor planens tid og kategori allerede er udfyldt. En plan bliver aldrig til tid i din rapport af sig selv.
- Øverst kan du se, hvor langt din plan bringer dig mod dit mål for måneden. Du kan ændre målet under Indstillinger → Planlægger.

Overblik viser nu også, om du ligger foran eller bagud i forhold til din plan. Det vises kun i måneder, hvor du har lagt en plan.

Er Planlæggeren nem at forstå? Eller har du idéer til, hvordan jeg kan gøre den bedre?

ÆNDRINGER
- Tid, der er overført fra forrige måned, vises nu under den samme kategori på alle skærme
- Når du ændrer en post i en måned, du allerede har indsendt, skriver Hugo ikke længere, at der er nye poster
- Generelle fejlrettelser og forbedringer
END-DA
```

**Verify**:
- `tail -c 12 Changelog/1.0.0/next.da.txt` prints `forbedringer` and `tail -c 1 Changelog/1.0.0/next.da.txt | xxd -p` prints `72` (the letter r, not `0a`).
- `grep -c "BEGIN\|END-" Changelog/1.0.0/next.da.txt` → `0`
- `file Changelog/1.0.0/next.da.txt` mentions `UTF-8`.
- `grep -c "" Changelog/1.0.0/next.da.txt` → `18` (18 lines, the last one without a newline).

### Step 2: Create the English file

Create `Changelog/1.0.0/next.en.txt` the same way, with exactly the text between the markers:

```
BEGIN-EN
Hugo is back with a new update, and this time it brings a whole new feature: the Planner. Let's dive in.

PLANNER
The Planner is a new tab between Overview and Year. Here you can plan how much time you want to spend in service each day, and see your plan for this month and the next 11 months.

- Tap a day to add a plan. A plan has a duration, a category and, if you like, a start time. You can have several plans on the same day.
- Each plan shows as a bar in the calendar that fills up as you log time.
- Tap "Log" on a plan to open Add Entry with the plan's time and category already filled in. A plan never turns into time in your report on its own.
- At the top you can see how far your plan gets you toward your target for the month. You can change the target under Settings → Planner.

The Overview now also shows whether you are ahead of or behind your plan. It only appears in months where you have made a plan.

Is the Planner easy to understand? Or do you have ideas for how I can make it better?

CHANGES
- Time carried in from the previous month now shows under the same category on every screen
- When you edit an entry in a month you already submitted, Hugo no longer says there are new entries
- General bug fixes and improvements
END-EN
```

**Verify**:
- `tail -c 12 Changelog/1.0.0/next.en.txt` prints `improvements` and `tail -c 1 Changelog/1.0.0/next.en.txt | xxd -p` prints `73`.
- `grep -c "BEGIN\|END-" Changelog/1.0.0/next.en.txt` → `0`
- `grep -c "" Changelog/1.0.0/next.en.txt` → `18`

### Step 3: Commit

Stage both files by path and commit with the message from "Git workflow".

**Verify**: `git show --stat HEAD` lists exactly the two new files. `git diff --stat 34395b4..HEAD -- Changelog/1.0.0/111.en.md Changelog/1.0.0/116.da.txt Changelog/1.0.0/116.en.txt` prints nothing.

## Test plan

Text only; no tests. The owner reads both files before pasting them into App Store Connect (plan 079) and may rewrite the Danish, as happened for build 116 (plans 058 and 059). If the Danish changes, the English should be updated to match.

## Done criteria

- [ ] Both files exist and pass the checks in Steps 1 and 2
- [ ] One commit containing only the two files
- [ ] The existing changelog files are unchanged
- [ ] `plans/README.md` row 078 updated (unless your reviewer maintains it)

## STOP conditions

- `Changelog/1.0.0/next.*` files already exist, or a build number newer than 116 already has files.
- You cannot write a file without a trailing newline.
- The line counts in the checks don't match after a second attempt.

## Maintenance notes

- Plan 079 renames `next.*.txt` to `<build>.*.txt` once Xcode Cloud has assigned the build number. Until then the placeholder name tells everyone that these notes belong to the build that hasn't shipped yet.
- If more user-visible commits land on `main` before the build is made, add a bullet for each under ÆNDRINGER / CHANGES. Check with `git log --oneline --no-merges testflight..main`.
