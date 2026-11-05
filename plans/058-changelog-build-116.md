# Plan 058: Add the build 116 changelog in English and Danish

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. Your reviewer maintains `plans/README.md`; do not edit it.
>
> **Drift check (run first)**: `ls Changelog/1.0.0` must list `111.en.md` and no `116.*` file.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (text files only)
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `7a243e7`, 2026-11-03
- **Issue**: [SLN-261](https://linear.app/sebastianln/issue/SLN-261)

## Why this matters

The owner is sending build 116 to external TestFlight and needs "What to Test" notes in English and
Danish. `Changelog/1.0.0/111.en.md` is the existing example: one intro line, a bullet list, a closing
paragraph, first person, casual. The new files differ from it in two ways the owner asked for: they are
`.txt`, and there is a Danish version beside the English one.

## Current state

- `Changelog/1.0.0/111.en.md` is the only changelog file. Files are named `<build number>.<language>.<ext>`.
  It has no trailing newline. Do not edit or rename it.
- The notes cover everything on `main` since the `testflight` branch (build 111's content plus the yearly
  goal header work).

## Scope

**In scope** (create only):
- `Changelog/1.0.0/116.en.txt`
- `Changelog/1.0.0/116.da.txt`

**Out of scope**: every other file, including `111.en.md`.

## Git workflow

One commit, message `docs: add the build 116 changelog`, ending with the line
`Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Run `Scripts/install-hooks.sh` once.
Do NOT push or merge.

## Steps

### Step 1: Create the English file

Create `Changelog/1.0.0/116.en.txt` with exactly the text between the `BEGIN`/`END` marker lines below
(not including the marker lines). UTF-8, straight quotes, LF line endings, and NO trailing newline after the last
character (write it with `printf '%s'` or an equivalent; do not use an editor that appends a newline).

```
BEGIN-EN
Hugo is back with another update and this time there's quite a bit of changes. Let's dive in:

- New header on the Year page for regular pioneers: it now shows the hours that count toward your yearly goal, with a bar showing whether you are ahead of or behind pace. Tap the header to see the details, including how each month counts. If you also have time in other categories, your actual total is shown below the counted hours
- New setting under General: choose how much of the current month you should have done by today when comparing with your yearly goal
- Durations on the Year page and in the monthly totals now read as hours (for example "152 hours") instead of 152:00
- Updated submission flow lets you manually select whether you want to round or transfer extra minutes for each category when submitting your report
- New submit screen
- Carried-in entries now have their own section
- Hugo now warns you when a month you already submitted has changed, and before you submit a month again
- New default list type in Overview: Grouped by date, this list style groups entries together for a simpler view. This style is perfect if you add multiple entries on the same days. Try it out and see how it feels (if the new style doesn't fit you, it is possible to change it back to the old view)
- Removed the status line below month totals in Overview, this will return in a later update when I figure out the correct implementation of the feature
- Entry durations are now edited with a wheel picker
- Fixes for duplicate categories and reports that could appear after syncing between devices
- Smaller UI updates that (might) make the experience more pleasant

This update is quite huge and allows me to add new features easier in the future. While I've been careful, this update might have a higher risk of glitches and bugs, please reach out or submit feedback if you experience any issues :)
END-EN
```

### Step 2: Create the Danish file

Create `Changelog/1.0.0/116.da.txt` the same way (exact text between the markers, no trailing newline):

```
BEGIN-DA
Hugo er tilbage med en ny opdatering, og denne gang er der en del ændringer. Lad os dykke ned i det:

- Ny overskrift på Tjenesteår-siden for almindelige pionerer: den viser nu de timer, der tæller med mod dit årsmål, og en bjælke viser, om du ligger foran eller bagud i forhold til tempoet. Tryk på overskriften for at se detaljerne, blandt andet hvordan hver måned tæller med. Hvis du også har tid i andre kategorier, vises din faktiske total under de timer, der tæller med
- Ny indstilling under Generelt: vælg, hvor meget af den aktuelle måned du skal have nået i dag, når du sammenligner med dit årsmål
- Varigheder på Tjenesteår-siden og i månedens totaler vises nu som timer (for eksempel "152 timer") i stedet for 152:00
- Opdateret indsendelsesflow, hvor du selv kan vælge, om du vil runde op eller overføre ekstra minutter for hver kategori, når du indsender din rapport
- Ny skærm til indsendelse
- Overførte poster har nu deres egen sektion
- Hugo advarer dig nu, når en måned, du allerede har indsendt, er blevet ændret, og inden du indsender en måned igen
- Ny standardvisning i Overblik: Grupperet efter dato. Denne visning samler poster i grupper og giver et enklere overblik. Den er perfekt, hvis du tilføjer flere poster på de samme dage. Prøv den og se, hvordan den føles (hvis den nye visning ikke passer til dig, kan du skifte tilbage til den gamle)
- Fjernet statuslinjen under månedens totaler i Overblik. Den vender tilbage i en senere opdatering, når jeg har fundet den rigtige løsning
- Varigheden på en post redigeres nu med en hjulvælger
- Rettelser til dobbelte kategorier og rapporter, der kunne opstå efter synkronisering mellem enheder
- Mindre designændringer, der (forhåbentlig) gør oplevelsen mere behagelig

Denne opdatering er ret stor og gør det nemmere for mig at tilføje nye funktioner fremover. Jeg har været omhyggelig, men der er en højere risiko for fejl i denne opdatering. Kontakt mig eller send feedback, hvis du oplever problemer :)
END-DA
```

**Verify**:
- `tail -c 3 Changelog/1.0.0/116.en.txt | xxd` -> ends with `3a 29` after the space, that is the bytes of `:)`, and the file does not end in `0a`.
- Same check on `116.da.txt`.
- `grep -c "BEGIN\|END-" Changelog/1.0.0/116.*.txt` -> `0` for both files (no marker lines leaked in).
- `file Changelog/1.0.0/116.da.txt` reports UTF-8 text, and `grep -c "ø\|å\|æ" Changelog/1.0.0/116.da.txt` is at least 1.

## Done criteria

- [ ] Both files exist and pass the checks above
- [ ] `git status` shows only the two new files in the commit
- [ ] `Changelog/1.0.0/111.en.md` is unchanged (`git diff --stat` shows no change to it)

## STOP conditions

- `116.*` files already exist, or `111.en.md` is missing.
- You cannot write a file without a trailing newline.

## Maintenance notes

Future builds: one `<build>.en.txt` and `<build>.da.txt` pair per build in the version folder. The reviewer
checked the bullet claims against the git log of `main` since `testflight` (see commit subjects for yearly goal header, hours wording, submit flow, carried-in section, re-submit warning, wheel picker, sync merge fixes).
