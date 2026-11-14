# Plan 119: Add the changelog for the build after 125 in English and Danish

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**: `ls Changelog/1.0.0` must list exactly
> `111.en.md`, `116.da.txt`, `116.en.txt`, `120.da.txt`, `120.en.txt`,
> `125.da.txt` and `125.en.txt`. Anything else is a STOP condition.

## Status

- **Priority**: P1 (testers need notes for the next TestFlight build)
- **Effort**: S + owner (the owner edits the text in Lettera before pasting it into App Store Connect)
- **Risk**: LOW. Two new text files.
- **Depends on**: 118 (the text announces settings sync). Run it last of 114-119.
- **Category**: docs
- **Planned at**: commit `7e3c4e9`, 2026-11-14
- **Issue**: [SLN-313](https://linear.app/sebastianln/issue/SLN-313)

## Why this matters

Testers get "What to Test" notes in Danish and English with every TestFlight build. The last notes (`Changelog/1.0.0/125.*.txt`) cover plans 080-095. Everything finished since then is missing: category colors, the explained carried-in time, the plan pace bar, rounding on the Year cards, the privacy policy and terms, the recovery screen, and (after plan 118) settings that sync between devices. Xcode Cloud assigns the build number when it builds, so the files get the placeholder names `next.en.txt` and `next.da.txt`. The owner renames them afterwards, as with build 125.

## Current state

- `Changelog/1.0.0/` holds `111.en.md`, `116.*.txt`, `120.*.txt` and `125.*.txt`. Files are named `<build number>.<language>.<ext>`. The `.txt` files are UTF-8, use LF line endings and have **no trailing newline**. Do not edit or rename them.
- House style, from the owner's own edit of `125.en.txt`: a short intro line, sections in capitals (`OVERVIEW`, `PLANNER`, `YEAR`, `SETTINGS`, `CHANGES`), bullets starting with `- `, full sentences ending in a period in every section except `CHANGES`, whose bullets have no final period. Danish section names: `OVERBLIK`, `PLANLÆG`, `TJENESTEÅR`, `INDSTILLINGER`, `ÆNDRINGER`.
- The advisor checked every line below against `git log 63f9aed..7e3c4e9` (features since the 125 notes were written), plans 098-113 and 118, and the English and Danish strings in `Hugo/Resources/Localizable.xcstrings`: "Egen farve", "Overblik", "Tjenesteår", "Planlæg", "Generelt", "Privatlivspolitik", "Brugsvilkår", "Kontakt os", "Fejlfinding", "Kopiér diagnostik", "Planlagt indtil i dag", "Planlagt indtil nu", "rundet op", "rundet ned" and "overført fra". Plans 114-117 change nothing users can see and are left out on purpose.

## Scope

**In scope** (create only):
- `Changelog/1.0.0/next.en.txt`
- `Changelog/1.0.0/next.da.txt`

**Out of scope**: every other file, including the existing changelog files. `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` has an uncommitted change by the owner. Never stage, commit, revert or stash it.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage `plans/`, `.claude/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage the two new files by explicit path.
- One commit: `docs(changelog): add the changelog for the build after 125`

## Steps

### Step 1: Create the English file

Create `Changelog/1.0.0/next.en.txt` with exactly the text between the `BEGIN-EN` and `END-EN` marker lines (not the marker lines themselves). Use UTF-8, straight quotes, LF line endings and NO trailing newline after the last character. Write it with a file-writing tool, then check the last byte.

```
BEGIN-EN
Hugo is back with a new update. Your categories get colors, your settings now follow you to all your devices, and transferred time is easier to understand. Let's dive in.

OVERVIEW
- Time transferred from last month now has its own line under your hours, for example "30 minutes transferred from October". Tap it to see which categories it came from.
- Transferred time no longer shows up as an entry in the month's list.
- Tap the line that says whether you are ahead of or behind your plan, and Hugo now shows your month's plan as a bar, with a marker for where you should be today and how much you have planned so far.
- The arrow next to that line moves gently again when you are far ahead or far behind.

CATEGORIES
- Give each category a color. Pick one of six colors, or choose Custom Color and mix your own.
- The Planner uses the color for the category, and so does its icon.
- When you add an entry, the category you picked is shown in its color.

YEAR
- The month cards show how many minutes were rounded up, rounded down or transferred.
- A month with less than an hour now shows its minutes instead of 0.

SETTINGS
- Your group overseer, your greeting and your settings under General now sync between your devices through iCloud. Set them up once, and your iPad or a new iPhone has them too.
- The Privacy Policy and the Terms of Use are now in Settings.
- When you write to us with Contact Us, the email now says which version of Hugo you use.
- For testers: Debugging has a new Copy Diagnostics button. Paste the result into your feedback, so we can see which build and device you use. It never includes your entries or names.

CHANGES
- Time without a category now counts as main time everywhere, also toward your yearly goal
- Text stays readable at the largest text sizes
- If Hugo can't open your data, it now shows a screen with Retry and Contact Us instead of closing
- General bug fixes and improvements
END-EN
```

**Verify**:
- `tail -c 1 Changelog/1.0.0/next.en.txt | xxd -p` prints `73` (the letter s, not `0a`).
- `grep -c "BEGIN\|END-" Changelog/1.0.0/next.en.txt` → `0`
- `grep -c "" Changelog/1.0.0/next.en.txt` → `28`
- `file Changelog/1.0.0/next.en.txt` mentions `UTF-8` or `ASCII`.

### Step 2: Create the Danish file

Create `Changelog/1.0.0/next.da.txt` the same way, with exactly the text between the markers:

```
BEGIN-DA
Hugo er tilbage med en ny opdatering. Dine kategorier får farver, dine indstillinger følger nu med på alle dine enheder, og overført tid er lettere at forstå. Lad os dykke ned i det.

OVERBLIK
- Tid, der er overført fra sidste måned, har nu sin egen linje under dine timer, for eksempel "30 minutter overført fra oktober". Tryk på den for at se, hvilke kategorier den kom fra.
- Overført tid vises ikke længere som en post i månedens liste.
- Tryk på linjen, der viser, om du er foran eller bagud i forhold til din plan, så viser Hugo nu månedens plan som en bjælke med en markering af, hvor du burde være i dag, og hvor meget du har planlagt indtil nu.
- Pilen ved linjen bevæger sig igen blødt, når du er langt foran eller langt bagud.

KATEGORIER
- Giv hver kategori en farve. Vælg en af seks farver, eller vælg Egen farve og bland din egen.
- Planlæg bruger farven til kategorien, og det gør dens ikon også.
- Når du tilføjer timer, vises den valgte kategori i sin farve.

TJENESTEÅR
- Månedskortene viser, hvor mange minutter der blev rundet op, rundet ned eller overført.
- En måned med under en time viser nu sine minutter i stedet for 0.

INDSTILLINGER
- Din gruppetjener, din hilsen og dine indstillinger under Generelt synkroniseres nu mellem dine enheder via iCloud. Indstil dem én gang, så har din iPad eller en ny iPhone dem også.
- Privatlivspolitik og Brugsvilkår ligger nu under Indstillinger.
- Når du skriver til os med Kontakt os, står der nu i mailen, hvilken version af Hugo du bruger.
- Til testere: Fejlfinding har en ny knap, Kopiér diagnostik. Sæt resultatet ind i din feedback, så vi kan se, hvilket build og hvilken enhed du bruger. Det indeholder aldrig dine registreringer eller navne.

ÆNDRINGER
- Tid uden kategori tæller nu som primær tid overalt, også mod dit årsmål
- Teksten kan stadig læses ved de største tekststørrelser
- Hvis Hugo ikke kan åbne dine data, vises nu en skærm med Prøv igen og Kontakt os i stedet for at appen lukker
- Generelle fejlrettelser og forbedringer
END-DA
```

**Verify**:
- `tail -c 1 Changelog/1.0.0/next.da.txt | xxd -p` prints `72` (the letter r).
- `grep -c "BEGIN\|END-" Changelog/1.0.0/next.da.txt` → `0`
- `grep -c "" Changelog/1.0.0/next.da.txt` → `28`
- `file Changelog/1.0.0/next.da.txt` mentions `UTF-8`.

### Step 3: Commit

Stage both files by path and commit with the message from "Git workflow".

**Verify**: `git show --stat HEAD` lists exactly the two new files. `git diff --stat 7e3c4e9..HEAD -- Changelog/1.0.0/111.en.md Changelog/1.0.0/116.da.txt Changelog/1.0.0/116.en.txt Changelog/1.0.0/120.da.txt Changelog/1.0.0/120.en.txt Changelog/1.0.0/125.da.txt Changelog/1.0.0/125.en.txt` prints nothing.

## Test plan

Text only, so there are no tests. The owner reads both files in Lettera (`rex do hugo_changelogs`) before pasting them into App Store Connect.

## Done criteria

- [ ] Both files exist and pass the checks in Steps 1 and 2
- [ ] One commit containing only the two files
- [ ] The existing changelog files are unchanged

## STOP conditions

- The drift check lists other files (for example a `next.*.txt` already exists).
- A line count or last-byte check fails twice.

## Owner checks

- Read both texts and edit freely. Two things to decide: whether the "For testers" line belongs in the notes, and whether build 125 already went out with category colors (then drop the CATEGORIES section).
- Rename the files to the build number once Xcode Cloud has built it.
- Before the build ships: deploy the CloudKit schema for V13 (`CD_colorHue` and `CD_colorTone` on `CD_Tracker`) to Production. Fill both fields on a Development record first, so the deploy creates them.

## Maintenance notes

- If more user-visible work lands before the build, add a line under the matching section in both files.
