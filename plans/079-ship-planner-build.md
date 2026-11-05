# Plan 079: Check and ship the Planner build to TestFlight

> **Executor instructions**: Follow this plan step by step. Steps marked
> **[agent]** are yours; steps marked **[owner]** need the app's owner, who
> has the Apple accounts and the devices. Do agent steps 1–3, then report back
> and wait. Do step 6 only once the owner has given you the build number. If
> anything in the "STOP conditions" section occurs, stop and report. Do not
> improvise. When done, update the status row for this plan in
> `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git log --oneline 34395b4..HEAD` must list the
> commits of plans 077 and 078 (`fix: correct the Danish plan status and Planner target wording`
> and `docs: add the Planner build changelog`). If either is missing, STOP: this plan runs after both.

## Status

- **Priority**: P1
- **Effort**: S + owner
- **Risk**: MED (first build with schema V12 on testers' real data)
- **Depends on**: plans/077-planner-danish-wording.md, plans/078-changelog-planner-build.md
- **Category**: dx
- **Planned at**: commit `34395b4`, 2026-11-05
- **Issue**: [SLN-282](https://linear.app/sebastianln/issue/SLN-282)

## Why this matters

This build is the first with the Planner and with schema V12, which adds the synced `Plan` model. Testers will install it over build 116 (schema V11) with months of real entries and submitted reports, so the V11 → V12 migration runs once on data the tests can't fully reproduce. The CloudKit schema with `CD_Plan` is already deployed to Production (owner, 2026-11-05), so plans can sync for TestFlight users. What's left: prove the build is healthy, make it, attach the notes, and check the upgrade on a real device before inviting testers.

## Current state

- Version: `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` in `Hugo.xcodeproj/project.pbxproj`. Xcode Cloud assigns the real build number (workflow manifest: `Hugo.xcodeproj/xcshareddata/xcodecloud/manifest.json`). The last TestFlight build is 116.
- Branches: `testflight` points at `26e63f4`, the commit build 116 was made from; it is an ancestor of `main`. `production` exists too. The owner knows which branch the Xcode Cloud workflow builds from; this plan does not assume it.
- Migration coverage exists: `HugoTests/Persistence/SchemaMigrationTests.swift` has `migratingV11StoreKeepsEntriesAndStartsWithoutPlans` (line ~1011) and `migratesFullChainFromV1ToCurrentSchemaWithoutThrowing` (line ~1030).
- Entitlements (`Configuration/Hugo.entitlements`): `aps-environment` is `development`; Xcode switches it to production when it exports for TestFlight, so leave it.
- Release notes: `Changelog/1.0.0/next.da.txt` and `next.en.txt` (plan 078). They get renamed to the build number in step 6.
- Same procedure as plan 036, which shipped the V11 build (SLN-245).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes) |
| Release build | `xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/HugoRelease CODE_SIGNING_ALLOWED=NO` | ends with `** BUILD SUCCEEDED **` |

If the simulator reports "Busy" before any test runs, wait 20 seconds and run the same command again; that is not a failure.

## Scope

**In scope (agent)**: running the commands above; in step 6 only, renaming `Changelog/1.0.0/next.da.txt` and `Changelog/1.0.0/next.en.txt`.

**Out of scope**: every source file, the Xcode project, entitlements, the `testflight` and `production` branches, pushing anything, App Store Connect and the CloudKit Console. If a check fails, report it; do not fix code in this plan.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push, and do not move or push the `testflight` or `production` branches; the owner does that.
- Never stage, edit, stash or discard files under `plans/` or `.claude/`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`.
- Step 6 makes one commit: `docs: name the Planner build changelog after build <N>`.

## Steps

### Step 1 [agent]: Confirm the blockers landed

**Verify**:
- `grep -c '"value" : "Bagud"' Hugo/Resources/Localizable.xcstrings` → `1` (plan 077)
- `grep -ci "måltal" Hugo/Resources/Localizable.xcstrings` → `0` (plan 077)
- `ls Changelog/1.0.0/next.da.txt Changelog/1.0.0/next.en.txt` lists both files (plan 078)
- `git status --short -- Hugo HugoTests Hugo.xcodeproj` prints nothing (no uncommitted app changes would sneak into the build).

### Step 2 [agent]: Run the full gate

Run `Scripts/verify.sh`.

**Verify**: exit 0. In the test output, `migratingV11StoreKeepsEntriesAndStartsWithoutPlans` passed.

### Step 3 [agent]: Build the Release configuration

Run the Release build command from the table.

**Verify**: the output ends with `** BUILD SUCCEEDED **`.

Then report back to the owner: steps 1–3 passed, plus the output of `git log --oneline --no-merges testflight..main | grep -v " docs:"` so the owner sees what the build contains.

### Step 4 [owner]: Upgrade check on a device with real data

Do this before inviting testers.

1. On a device that has build 116 from TestFlight with real data (entries in several months, at least one submitted month, ideally one with transferred minutes), install this build over it from Xcode with the Release configuration, or as an internal TestFlight build.
2. Check:
   - The app launches, with no crash or reset.
   - The Overview shows the same hours as before the upgrade for the current month.
   - The Year page shows the same year total and the same submitted months.
   - Categories and the carried-in entries in the month after a transfer are unchanged.
3. Add a plan in the Planner. On a second device signed in to the same Apple Account, with this build, check that the plan appears within a few minutes.
4. With the device in Danish: the Overview circle in a planned month fits the new labels ("Langt foran planen", "Bagud"), and the tab bar, the Planner screen subtitle and the Settings row say "Planlæg", and the Planner header and Settings → Planlæg say "Mål".

### Step 5 [owner]: Make the build and add the notes

1. Make the build the way build 116 was made: move the branch Xcode Cloud builds from to `main` and push it (for example `git push origin main:testflight` if the workflow builds `testflight`), or archive in Xcode and upload.
2. Note the build number App Store Connect shows. It must be higher than 116.
3. Paste `Changelog/1.0.0/next.da.txt` into the Danish "What to Test" and `next.en.txt` into the English one.
4. Tell the agent (or do it yourself) the build number for step 6.

### Step 6 [agent, after the owner gives the build number N]: Name the changelog after the build

```bash
git mv Changelog/1.0.0/next.da.txt Changelog/1.0.0/N.da.txt
git mv Changelog/1.0.0/next.en.txt Changelog/1.0.0/N.en.txt
git commit -m "docs: name the Planner build changelog after build N"
```

(Replace `N` with the number.)

**Verify**: `ls Changelog/1.0.0` lists `111.en.md 116.da.txt 116.en.txt N.da.txt N.en.txt` and no `next.*`. `git show --stat HEAD` shows two renames with no content change (`100%` similarity).

## Test plan

Automated: steps 2 and 3. The migration from V11 is covered by `migratingV11StoreKeepsEntriesAndStartsWithoutPlans`. Manual: step 4 on real data, which tests can't replace.

## Done criteria

- [ ] Steps 1–3 pass (agent)
- [ ] Owner confirms steps 4 and 5
- [ ] Step 6 commit exists and no `next.*` file remains
- [ ] `plans/README.md` row 079 updated, and SLN-282 moved to Done

## STOP conditions

- Step 1 shows plan 077 or 078 missing, or uncommitted app changes.
- `Scripts/verify.sh` fails. Report the failing step and test; do not try to fix it in this plan.
- The Release build fails.
- In step 4 the app crashes on launch, or hours, submitted months or categories differ from before the upgrade. Do not send the build to testers; report what differs and in which month.
- In step 4.3 the plan doesn't reach the second device after 15 minutes while other changes do. Check in the CloudKit Console that `CD_Plan` exists in Production before going further.

## Maintenance notes

- Each new schema version needs the same steps: deploy the CloudKit schema to Production before the TestFlight build, then an upgrade check over the previous TestFlight build on real data.
- `testflight` should end up at the commit this build was made from, as it did for build 116, so the next changelog can list `testflight..main`.
- Not in this plan on purpose: SLN-194 (the Debug screen is reachable in Release builds) and SLN-172 (a failed migration crashes on every launch). Both affect testers, but both were already true for build 116 and neither blocks this build. They belong to the App Store launch work (SLN-284).
