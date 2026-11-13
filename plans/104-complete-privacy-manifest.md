# Plan 104: Declare in the privacy manifest that Hugo tracks nothing and collects nothing

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 3055ae6..HEAD -- PrivacyInfo.xcprivacy`
> Expected: no output. Otherwise compare the excerpt below with the live file.
> A mismatch is a STOP condition.

## Status

- **Priority**: P1 (App Store launch blocker)
- **Effort**: S + owner (Privacy Report check on an archive)
- **Risk**: LOW. One plist file, no code.
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `3055ae6`, 2026-11-13
- **Issue**: [SLN-209](https://linear.app/sebastianln/issue/SLN-209)

## Why this matters

Apple reads `PrivacyInfo.xcprivacy` during App Review and builds the app's Privacy Report from it. Hugo's manifest only lists the UserDefaults API. It leaves out the keys that say Hugo does no tracking and collects no data. A missing key is not the same as a "no" answer, and Hugo is meant to be a privacy-first app, so the manifest should state its position explicitly. The Privacy Policy (plan 105) says the same thing in words, so the two must agree.

## Current state

`PrivacyInfo.xcprivacy` sits at the repo root, not under `Hugo/`. The project adds it to the app target's Copy Bundle Resources phase by hand (`Hugo.xcodeproj/project.pbxproj` lines 11, 25, 82 and 195). Do not move it and do not touch the project file.

Its full content today:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

The file uses tab indentation, like other plists Xcode writes. Keep tabs here. The repo's 4-space rule is for Swift files only.

### What the advisor checked (2026-11-13, at `3055ae6`)

**Required-reason APIs.** A grep of `Hugo/` found:

- UserDefaults: used widely (`@AppStorage` in 19 files, `UserDefaults.standard` in `AppBootstrapper` and `SubmitReportFormModel`). Hugo reads and writes only its own defaults; there is no app group. Reason `CA92.1` ("access info from the same app") is correct. Keep it.
- File timestamps (`creationDate`, `modificationDate`, `attributesOfItem`, `stat`): not used.
- System boot time (`systemUptime`, `mach_absolute_time`): not used.
- Disk space (`volumeAvailableCapacity`, `systemFreeSize`): not used.
- Active keyboards (`activeInputModes`): not used.

The only third-party dependency is `swift-markdown-ui` with its dependencies `NetworkImage` and `swift-cmark`. None of them uses a required-reason API, and none ships a privacy manifest. `NetworkImage` downloads images only when a Markdown file references a remote image, and Hugo's Markdown files don't.

**Data collection.** Apple defines "collect" as transmitting data off the device in a way that lets the developer or a third party access it longer than it takes to serve the request in real time. Hugo:

- has no server, no accounts, no analytics SDK, no ads and no tracking;
- stores entries, categories, plans and submitted reports in SwiftData, synced through CloudKit to the **user's private iCloud database** (`iCloud.com.ordellnielsen.Hugo`), which the developer cannot read;
- keeps settings, including the group overseer's name and phone number, in UserDefaults on the device;
- sends the monthly report through the system Messages composer (`MFMessageComposeViewController` in `Hugo/Features/Reports/Views/OverseerPicker.swift`) or copies it to the pasteboard. The user sends it, and it never reaches the developer;
- gets the overseer from `CNContactPickerViewController`, which runs outside the app and returns only the contact the user picks.

So nothing reaches the developer or a third party: `NSPrivacyCollectedDataTypes` is an empty array, and `NSPrivacyTracking` is `false` with no tracking domains. Crash reports that Apple passes on when the user opts in to "Share With App Developers" are Apple's collection, not the app's, and are not declared here.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Plist syntax | `plutil -lint PrivacyInfo.xcprivacy` | `PrivacyInfo.xcprivacy: OK` |
| Read back keys | `plutil -p PrivacyInfo.xcprivacy` | shows the four keys below |
| Full gate (before the commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

## Scope

**In scope**: `PrivacyInfo.xcprivacy` only.

**Out of scope**:

- `Hugo/Info.plist`. It has an `NSContactsUsageDescription` that the contact picker doesn't need. Removing it is a separate decision (see Maintenance notes).
- `Configuration/Hugo.entitlements`, including the unused `ubiquity-kvstore-identifier` entitlement.
- `Hugo.xcodeproj/project.pbxproj`. The manifest is already in the target.
- All Swift files, `.claude/`, `plans/` (except this plan's row in the README) and the owner's `Changelog/` changes. Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage the one file by path.
- One commit after `Scripts/verify.sh` exits 0: `fix: declare no tracking and no collected data in the privacy manifest`.

## Steps

### Step 1: Write the complete manifest

Replace the whole content of `PrivacyInfo.xcprivacy` with this (tabs for indentation):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

**Verify**:
- `plutil -lint PrivacyInfo.xcprivacy` prints `PrivacyInfo.xcprivacy: OK`.
- `plutil -p PrivacyInfo.xcprivacy` shows `"NSPrivacyTracking" => false`, `"NSPrivacyTrackingDomains" => []`, `"NSPrivacyCollectedDataTypes" => []` and the UserDefaults entry with `"CA92.1"`.

### Step 2: Re-check that no new required-reason API has appeared

Run:

```sh
grep -rnE "creationDate|modificationDate|contentModificationDate|attributesOfItem|fileModificationDate|systemUptime|mach_absolute_time|volumeAvailableCapacity|systemFreeSize|activeInputModes" Hugo
```

**Verify**: no output. If there is output, STOP (see STOP conditions).

### Step 3: Run the gate and commit

**Verify**: `Scripts/verify.sh` exits 0, `git diff --check` exits 0, and `git diff --stat` lists only `PrivacyInfo.xcprivacy` (plus the owner's untouched `Changelog/` changes, which you must not stage). Commit.

## Test plan

No unit test fits a plist that only Apple's tooling reads. `plutil -lint` checks the syntax, and the owner's Privacy Report check below confirms Apple's reading of it.

## Done criteria

- [ ] `plutil -lint PrivacyInfo.xcprivacy` prints `OK`
- [ ] `plutil -p PrivacyInfo.xcprivacy | grep -c "NSPrivacyTracking\|NSPrivacyCollectedDataTypes\|NSPrivacyAccessedAPIType"` prints `4` or more
- [ ] The Step 2 grep prints nothing
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git show --stat HEAD` lists only `PrivacyInfo.xcprivacy`
- [ ] `plans/README.md` row for 104 updated

## STOP conditions

- The drift check shows changes and the excerpt no longer matches.
- The Step 2 grep finds a required-reason API. Report the file and line, and don't guess a reason code.
- A new Swift package has been added to the project since `3055ae6` (`grep -n repositoryURL Hugo.xcodeproj/project.pbxproj` shows more than `swift-markdown-ui`). Its data use has not been reviewed.
- The project now sends data anywhere other than CloudKit's private database (for example a `URLSession` call to a web service: `grep -rn "URLSession\|URLRequest" Hugo` has output). Then "collects nothing" is no longer true.

## Maintenance notes

- **Owner check**: archive the app (Product > Archive), then in the Organizer right-click the archive and choose **Generate Privacy Report**. The report should show "No tracking", no collected data types, and the UserDefaults API with reason CA92.1. In App Store Connect, the App Privacy answer should be **Data Not Collected**, matching this manifest.
- Revisit this file when Hugo starts sending data anywhere new: an analytics or crash SDK, a web service, or shared data the developer can read (for example a CloudKit public or shared database). Each of those may need a collected data type and a matching change to the Privacy Policy (plan 105).
- SLN-289 plans to sync report settings (including the overseer's name and phone number) to the user's other devices. If it uses the private CloudKit database or iCloud key-value storage, the developer still can't read the data, so this manifest stays the same. The Privacy Policy's sentence that settings stay on the device must change, though.
- `Hugo/Info.plist` has an `NSContactsUsageDescription` that the app doesn't need, because `CNContactPickerViewController` asks for no permission. Removing it is safe and a small privacy win. It's left out of this plan because it changes a different file. Pick it up separately if the owner wants it.
