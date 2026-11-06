# Plan 096: Add the changelog for the build after 120 in English and Danish

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `ls Changelog/1.0.0` must list exactly
> `111.en.md`, `116.da.txt`, `116.en.txt`, `120.da.txt` and `120.en.txt`. Anything else is a STOP condition.

## Status

- **Priority**: P1 (blocks the next TestFlight build)
- **Effort**: S
- **Risk**: LOW (two new text files)
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `68ec362`, 2026-11-06
- **Issue**: [SLN-305](https://linear.app/sebastianln/issue/SLN-305)

## Why this matters

Testers need "What to Test" notes in Danish and English for the next TestFlight build. Xcode Cloud assigns the build number when it builds, so the files use the placeholder names `next.en.txt` and `next.da.txt`. Plan 097 renames them to the build number afterwards (the same flow as plans 078 and 079 for build 120).

## Current state

- `Changelog/1.0.0/` holds `111.en.md`, `116.da.txt`, `116.en.txt`, `120.da.txt` and `120.en.txt`. Files are named `<build number>.<language>.<ext>`. The `.txt` files are UTF-8, use LF line endings, and have **no trailing newline**. Do not edit or rename them.
- The notes cover what changed on `main` since build 120, which shipped from commit `e643bd3`. The reviewer checked every line below against `git log --oneline --no-merges e643bd3..main` and the English and Danish strings in `Hugo/Resources/Localizable.xcstrings` (for example "Kan tilføje bibelstudier", "Planlæg", "Tjenesteår", "Generelt", "Planlæg %@ mere for at nå dit mål"). The owner reviewed the text before this plan ran.

## Scope

**In scope** (create only):
- `Changelog/1.0.0/next.en.txt`
- `Changelog/1.0.0/next.da.txt`

**Out of scope**: every other file, including the existing changelog files.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage, edit, stash or discard files under `plans/` or `.claude/`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage the two new files by explicit path.
- One commit: `docs: add the changelog for the build after 120`

## Steps

### Step 1: Create the Danish file

Create `Changelog/1.0.0/next.da.txt` with exactly the text between the `BEGIN-DA` and `END-DA` marker lines (not the marker lines themselves). Use UTF-8, straight quotes, LF line endings, and NO trailing newline after the last character. Write it with `printf '%s' "$(cat <<'TXT' ... TXT)"` or with a file-writing tool, and then check the last byte.

```
BEGIN-DA
Hugo er tilbage med en ny opdatering. Denne gang handler det om finpudsning: en masse små forbedringer ud fra jeres tilbagemeldinger på Planlæg. Lad os dykke ned i det.

OVERBLIK
- Tryk på linjen under dine timer, der viser, om du er foran eller bagud i forhold til din plan, så viser Hugo tallene bag.
- Hvis du ikke har et månedligt mål, fyldes cirklen nu op i forhold til den tid, du har planlagt for måneden.
- Cirklen fyldes også mere præcist, så halvdelen af dine timer nu farver halvdelen af cirklen.
- Rapporten, der åbnede, når du trykkede på cirklen, er fjernet. Fanen Tjenesteår viser de samme tal.
- I listen sorteret efter dato kan du nu trykke på en post for at åbne og ændre den. Posterne viser nu også bibelstudier.

PLANLÆG
- Toppen af Planlæg er roligere og lettere at læse. Den viser nu, hvor meget mere du skal planlægge for at nå dit mål, og cirka hvor meget det er om dagen.
- Tid, der er overført fra forrige måned, vises ikke længere som tid udført den 1. Den tæller stadig med i måneden.

TJENESTEÅR
- Tryk på året øverst for at skifte til et andet tjenesteår.
- Årets samlede tid har nu sin tekst under tallet.

INDSTILLINGER
- Planlæg og Tjenesteår ligger nu under Indstillinger → Generelt.
- Begge sider forklarer, hvad hver mulighed gør, med en bjælke, der viser effekten på dine egne tal.

Er det nemt at skifte mellem tjenesteår? Og er du nogensinde kommet til at åbne den forkerte post, når du trykkede i listen sorteret efter dato?

ÆNDRINGER
- Varigheder vises nu som "23 timer 15 min"
- Når "Kan tilføje bibelstudier" er slået fra for en kategori, kan du ikke længere tilføje bibelstudier til nye poster i den kategori
- VoiceOver læser timer og minutter op på varighedshjulet
- Generelle fejlrettelser og forbedringer
END-DA
```

**Verify**:
- `tail -c 1 Changelog/1.0.0/next.da.txt | xxd -p` prints `72` (the letter r, not `0a`).
- `grep -c "BEGIN\|END-" Changelog/1.0.0/next.da.txt` → `0`
- `file Changelog/1.0.0/next.da.txt` mentions `UTF-8`.
- `grep -c "" Changelog/1.0.0/next.da.txt` → `28` (28 lines, the last one without a newline).

### Step 2: Create the English file

Create `Changelog/1.0.0/next.en.txt` the same way, with exactly the text between the markers:

```
BEGIN-EN
Hugo is back with a new update. This one is all about polish: lots of small improvements based on your feedback on the Planner. Let's dive in.

OVERVIEW
- Tap the line under your hours that says whether you are ahead of or behind your plan, and Hugo shows you the numbers behind it.
- If you don't have a monthly goal, the circle now fills up against the time you have planned for the month.
- The circle also fills more accurately, so half of your hours now color half of the circle.
- The report that opened when you tapped the circle is gone. The Year tab shows the same totals.
- In the list sorted by date, tap an entry to open and edit it. Entries now also show their Bible studies.

PLANNER
- The top of the Planner is calmer and easier to read. It now tells you how much more to plan to reach your target, and about how much that is per day.
- Time carried in from the previous month no longer shows as time logged on the 1st. It still counts toward the month.

YEAR
- Tap the year at the top to jump to another service year.
- The year's total now has its label below the number.

SETTINGS
- Planner and Service Year are now under Settings → General.
- Both pages explain what each option does, with a bar that shows the effect on your own numbers.

Is it easy to jump between service years? And have you ever opened the wrong entry when you tapped in the list sorted by date?

CHANGES
- Durations now read "23 hours, 15 min"
- When "Can add Bible Studies" is off for a category, you can no longer add Bible studies to new entries in that category
- VoiceOver reads hours and minutes on the duration wheel
- General bug fixes and improvements
END-EN
```

**Verify**:
- `tail -c 1 Changelog/1.0.0/next.en.txt | xxd -p` prints `73` (the letter s).
- `grep -c "BEGIN\|END-" Changelog/1.0.0/next.en.txt` → `0`
- `grep -c "" Changelog/1.0.0/next.en.txt` → `28`

### Step 3: Commit

Stage both files by path and commit with the message from "Git workflow".

**Verify**: `git show --stat HEAD` lists exactly the two new files. `git diff --stat 68ec362..HEAD -- Changelog/1.0.0/111.en.md Changelog/1.0.0/116.da.txt Changelog/1.0.0/116.en.txt Changelog/1.0.0/120.da.txt Changelog/1.0.0/120.en.txt` prints nothing.

## Test plan

Text only, so there are no tests. The owner reads both files again before pasting them into App Store Connect (plan 097).

## Done criteria

- [ ] Both files exist and pass the checks in Steps 1 and 2
- [ ] One commit containing only the two files
- [ ] The existing changelog files are unchanged

## STOP conditions

- `Changelog/1.0.0/next.*` files already exist, or a build number newer than 120 already has files.
- You cannot write a file without a trailing newline.
- The line counts don't match after a second attempt.

## Maintenance notes

- Plan 097 renames `next.*.txt` to `<build>.*.txt` once Xcode Cloud has assigned the build number.
- If the owner rewrites the Danish, update the English to match.
