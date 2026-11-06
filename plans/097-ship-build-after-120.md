# Plan 097: Check and ship the build after 120 to TestFlight

> **Executor instructions**: Follow this plan step by step. Steps marked
> **[agent]** are yours. Steps marked **[owner]** need the app's owner, who
> has the Apple accounts and the devices. Do agent steps 1–3, then report back
> and wait. Do step 6 only once the owner has given you the build number. If
> anything in the "STOP conditions" section occurs, stop and report. Do not
> improvise. When done, update the status row for this plan in
> `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git log --oneline 68ec362..HEAD` must list the
> plan 096 commit `docs: add the changelog for the build after 120`. If it is missing, STOP: this plan runs after 096.

## Status

- **Priority**: P1
- **Effort**: S + owner
- **Risk**: LOW (no schema, entitlement or project change since build 120)
- **Depends on**: plans/096-changelog-build-after-120.md
- **Category**: dx
- **Planned at**: commit `68ec362`, 2026-11-06
- **Issue**: [SLN-307](https://linear.app/sebastianln/issue/SLN-307)

## Why this matters

Everything scheduled for the next TestFlight build is done and checked on a device by the owner (Linear Todo is empty, 2026-11-06). What's left is to prove the build is healthy, make it, attach the notes, and check that it installs over build 120 without touching testers' data.

This build is lower risk than build 120. `git diff --stat e643bd3..main -- Hugo/Persistence Hugo.xcodeproj Configuration` prints nothing, so there is no new schema version, no migration and no CloudKit schema to deploy. The changes are UI, wording and Planner/Overview logic.

## Current state

- Version: `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` in `Hugo.xcodeproj/project.pbxproj`. Xcode Cloud assigns the real build number. The last TestFlight build is 120, made from commit `e643bd3` (plan 079).
- Branches: the local `testflight` branch still points at `26e63f4` (build 116). It was not moved for build 120. The owner knows which branch the Xcode Cloud workflow builds from, so this plan assumes nothing about it.
- `main` is 50+ commits ahead of `origin/main`. Nothing has been pushed this session.
- Release notes: `Changelog/1.0.0/next.da.txt` and `next.en.txt` (plan 096). Step 6 renames them to the build number.
- String catalog: every user-facing string has Danish. The only two keys without Danish ("A longer goal label", "Change values") are in a `#Preview` in `Hugo/DesignSystem/Components/MarkedProgressBar.swift` and never ship to users.
- Same procedure as plans 036 and 079.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |
| Release build | `xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/HugoRelease CODE_SIGNING_ALLOWED=NO` | ends with `** BUILD SUCCEEDED **` |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again. That is not a failure.

## Scope

**In scope (agent)**: running the commands above, and in step 6 only, renaming `Changelog/1.0.0/next.da.txt` and `Changelog/1.0.0/next.en.txt`.

**Out of scope**: every source file, the Xcode project, entitlements, the `testflight` and `production` branches, pushing anything, App Store Connect and the CloudKit Console. If a check fails, report it. Do not fix code in this plan.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push, and do not move or push the `testflight` or `production` branches. The owner does that.
- Never stage, edit, stash or discard files under `plans/` or `.claude/`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`.
- Step 6 makes one commit: `docs: name the changelog after build <N>`.

## Steps

### Step 1 [agent]: Confirm the build is ready

**Verify**:
- `ls Changelog/1.0.0/next.da.txt Changelog/1.0.0/next.en.txt` lists both files (plan 096).
- `git status --short -- Hugo HugoTests Hugo.xcodeproj Configuration` prints nothing (no uncommitted app changes would sneak into the build).
- `git diff --stat e643bd3..HEAD -- Hugo/Persistence Hugo.xcodeproj Configuration` prints nothing. If it prints anything, STOP: this plan assumes no schema or project change.

### Step 2 [agent]: Run the full gate

Run `Scripts/verify.sh`.

**Verify**: exit 0, with `** TEST SUCCEEDED **` and `** ANALYZE SUCCEEDED **` in the output.

### Step 3 [agent]: Build the Release configuration

Run the Release build command from the table.

**Verify**: the output ends with `** BUILD SUCCEEDED **`.

Then report back: steps 1–3 passed, plus the output of `git log --oneline --no-merges e643bd3..main | grep -v " docs"` so the owner sees what the build contains.

### Step 4 [owner]: Upgrade check on a device with real data

Do this before inviting testers.

1. On a device that has build 120 from TestFlight with real data (entries in several months, at least one submitted month, ideally one with transferred minutes, and some plans), install this build over it. Use Xcode with the Release configuration, or an internal TestFlight build.
2. Check:
   - The app launches, with no crash or reset.
   - The Overview shows the same hours as before the upgrade for the current month.
   - The Year page shows the same year total and the same submitted months.
   - Categories, plans and carried-in entries are unchanged.

### Step 5 [owner]: Make the build and add the notes

1. Push `main` to GitHub and make the build the way build 120 was made (Xcode Cloud from the branch its workflow builds, or archive in Xcode and upload). If the workflow builds `testflight`, move it too, for example with `git push origin main:testflight`.
2. Note the build number App Store Connect shows. It must be higher than 120.
3. Paste `Changelog/1.0.0/next.da.txt` into the Danish "What to Test" and `next.en.txt` into the English one.
4. Give the agent the build number for step 6.

### Step 6 [agent, after the owner gives the build number N]: Name the changelog after the build

```bash
git mv Changelog/1.0.0/next.da.txt Changelog/1.0.0/N.da.txt
git mv Changelog/1.0.0/next.en.txt Changelog/1.0.0/N.en.txt
git commit -m "docs: name the changelog after build N"
```

(Replace `N` with the number.)

**Verify**: `ls Changelog/1.0.0` lists `111.en.md 116.da.txt 116.en.txt 120.da.txt 120.en.txt N.da.txt N.en.txt` and no `next.*`. `git show --stat HEAD` shows two renames with no content change (`100%` similarity).

## Test plan

Automated: steps 2 and 3. Manual: step 4 on real data, which tests can't replace.

## Done criteria

- [ ] Steps 1–3 pass (agent)
- [ ] Owner confirms steps 4 and 5
- [ ] Step 6 commit exists and no `next.*` file remains

## STOP conditions

- Step 1 shows plan 096 missing, uncommitted app changes, or a schema or project change since `e643bd3`.
- `Scripts/verify.sh` fails. Report the failing step and test. Do not try to fix it in this plan.
- The Release build fails.
- In step 4 the app crashes on launch, or hours, submitted months, categories or plans differ from before the upgrade. Do not send the build to testers. Report what differs and in which month.

## Maintenance notes

- Move `testflight` to the commit each build is made from, so the next changelog can list `testflight..main`. It has lagged since build 116.
- The changelog asks testers whether they ever open the wrong entry in the date list (27 pt rows, plan 095). If anyone says yes, raise the row padding back to `HugoLayout.Spacing.compact` in `DateEntryRow`.
- Not in this plan on purpose: SLN-194 (the Debug screen is reachable in Release builds) and SLN-172 (a failed migration crashes on every launch). They belong to the App Store launch work (SLN-284).
