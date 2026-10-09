# Plan 036: Verify and ship the V11 build to TestFlight

> **Executor instructions**: Steps marked **[owner]** need App Store Connect,
> CloudKit Console, or a physical device and must be done by the owner. An
> agent executor does the remaining steps and reports which owner steps are
> pending. Update `plans/README.md` when done.
>
> **Drift check (run first)**: `git diff --stat dc0b7f6..HEAD -- Hugo/Features/Overview/Views/OverviewListView.swift Hugo/Resources/Localizable.xcstrings Configuration`

## Status

- **Priority**: P1
- **Effort**: S (agent part) + owner checklist
- **Risk**: HIGH if skipped (data loss or sync failure for testers)
- **Depends on**: plans 031–035
- **Category**: migration
- **Planned at**: commit `dc0b7f6`, 2026-10-09

## Why this matters

This build ships Schema V11, a custom migration that creates entries, plus new CloudKit fields. TestFlight builds use the **Production** CloudKit environment, which rejects fields that were never deployed from Development, so sync breaks silently for testers. The migration also runs once on real tester data that tests can't fully reproduce.

## Current state

- `Configuration/Release.xcconfig`: `BUNDLE_IDENTIFIER = com.ordellnielsen.Hugo`, container `iCloud.com.ordellnielsen.Hugo`. Debug uses bundle `com.ordellnielsen.Hugo.dev` with the **same** iCloud container (entitlements in `Configuration/Hugo.entitlements`).
- `CURRENT_PROJECT_VERSION = 1`, `MARKETING_VERSION = 1.0` in all configurations. An Xcode Cloud workflow exists (`Hugo.xcodeproj/xcshareddata/xcodecloud/manifest.json`, untracked). Xcode Cloud assigns build numbers itself.
- New V11 CloudKit fields: on `Entry`, `sourceSubmission`, `sourceReportingLineID`, `sourceReportYear`, `sourceReportMonth`; on `SubmittedReport`, `reportingLines` and the `generatedEntries` inverse.
- `aps-environment` is `development` in the entitlements; Xcode switches it to production when exporting for App Store/TestFlight.
- Untranslated user-visible string: `Text("Total")` in `Hugo/Features/Overview/Views/OverviewListView.swift:132`.

## Scope

**In scope (agent):** `OverviewListView.swift` (the one string), `Localizable.xcstrings`, committing the Xcode Cloud manifest **only if the owner confirms**.

**Out of scope:** version or build-number edits, signing settings, schema files.

## Steps

### Step 1: Localize the last literal

Replace `Text("Total")` with `Text("overview.day.total")`. Add the key with en "Total" and da "I alt".

**Verify:** the strings check from plan 034 prints at most `['']`.

### Step 2: Gate on a clean tree

`git status --porcelain -- Hugo HugoTests` prints nothing, and `Scripts/verify.sh` exits 0.

### Step 3: Release build compiles

```bash
xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/HugoRelease CODE_SIGNING_ALLOWED=NO
```

**Expected:** `** BUILD SUCCEEDED **`.

### Step 4 [owner]: Upgrade test on real data

1. Install the **currently shipped** TestFlight build on a device that has real data, including at least one month submitted with "Transfer".
2. Install this build over it from Xcode (Release scheme).
3. Check:
   - The app launches.
   - The transferred minutes appear once in the following month.
   - Re-opening that following month's report shows them as `↘ … transferred from …`, not doubled.
   - Year totals match the submitted hours.

### Step 5 [owner]: Deploy the CloudKit schema

1. Run a Debug build that submits a report with a transfer, so the Development schema gains the V11 record fields.
2. In CloudKit Console, open `iCloud.com.ordellnielsen.Hugo` → Development → confirm that `CD_Entry` has the `source*` fields and `CD_SubmittedReport` has `reportingLines`.
3. Choose **Deploy Schema Changes** to Production.

### Step 6 [owner]: Archive and distribute

Push to the branch Xcode Cloud builds from, or archive in Xcode and upload. Confirm the build number in App Store Connect is higher than the last TestFlight build. Add TestFlight "What to Test" notes covering the new per-line rounding and transfers.

## Done criteria

- [ ] Steps 1–3 pass (agent)
- [ ] Owner confirms steps 4–6
- [ ] `plans/README.md` row updated

## STOP conditions

- Step 4 shows doubled or missing minutes. Do not distribute; report the month and values.
- CloudKit Console doesn't show the V11 fields in Development after step 5.1.

## Maintenance notes

Every future schema version repeats steps 4–5. Consider keeping this file as a checklist.
