# Plan 059: Update the English build 116 changelog to match the new Danish text

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. Your reviewer maintains `plans/README.md`; do not edit it.
>
> **Drift check (run first)**: `git log --oneline -1 -- Changelog/1.0.0/116.en.txt` must show the commit
> "docs: add the build 116 changelog".

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (one text file)
- **Depends on**: plans/058-changelog-build-116.md (DONE)
- **Category**: docs
- **Planned at**: commit `177500d`, 2026-11-03

## Why this matters

The owner rewrote the Danish build 116 notes (shorter, a different structure with section headings, and a
direct question to testers). The English notes must say the same thing. The text below is the reviewed
English translation of the owner's Danish text.

## Current state

`Changelog/1.0.0/116.en.txt` holds the old bullet-list version. It has no trailing newline. The Danish
file `116.da.txt` is being edited by the owner in their own working tree: do NOT touch it.

## Scope

**In scope** (modify only): `Changelog/1.0.0/116.en.txt`

**Out of scope**: `116.da.txt`, `111.en.md`, everything else.

## Git workflow

One commit, message `docs: update the English build 116 changelog`, ending with the line
`Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Run `Scripts/install-hooks.sh` once.
Do NOT push or merge.

## Steps

### Step 1: Replace the file contents

Replace the whole contents of `Changelog/1.0.0/116.en.txt` with exactly the text between the `BEGIN-EN` and
`END-EN` marker lines below (not including the markers). UTF-8, straight quotes, LF line endings, NO trailing
newline (write with `printf '%s'` or equivalent).

```
BEGIN-EN
We're back with a new update for Hugo, and this update brings a feature many pioneers have been waiting for. Let's dive in.

YEARLY GOAL
Until now, Hugo has shown how many hours you have reported in total, but it has not taken into account that other kinds of service (like BEC and LDC) can affect your yearly goal.

Now Hugo takes this into account, with a completely new and updated Service Year page. In the new version, Hugo shows the total number of hours for the current service year that count toward your yearly goal. Below it you can see your total number of reported hours (if you don't see this, it means that all your reported hours count toward your yearly goal)

You will also see a new graphic that helps you get an overview of how your service year is going. Is the graphic easy to understand? Or do you have any ideas for how I can improve the feature?

CHANGES
- Minor bug fixes after the latest category-based split on the Overview page
- General bug fixes and improvements that make the app more stable
END-EN
```

**Verify**:
- `tail -c 3 Changelog/1.0.0/116.en.txt | xxd` -> `626c 65` (the letters "ble"), with no `0a` at the end.
- `grep -c "BEGIN\|END-" Changelog/1.0.0/116.en.txt` -> `0`.
- `wc -l Changelog/1.0.0/116.en.txt` -> `11` (11 newline characters, 12 lines, last line without newline).
- `git diff --stat` shows only `116.en.txt`.

## Done criteria

- [ ] The checks above pass
- [ ] Only `Changelog/1.0.0/116.en.txt` is in the commit

## STOP conditions

- `116.en.txt` is missing, or the drift check does not match.
- You cannot write the file without a trailing newline.
