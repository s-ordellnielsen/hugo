# Plan 102: Split builds into Debug, TestFlight and Production with feature flags, copy diagnostics from the debug menu, and put the version in support emails

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 3055ae6..HEAD -- Hugo.xcodeproj Configuration Scripts/verify.sh README.md AGENTS.md Hugo/Features/Settings HugoTests/Features/Settings`
> Expected: no output. If anything is listed, compare the excerpts below with the
> live files. A mismatch is a STOP condition.

## Status

- **Priority**: P1 (App Store launch blocker: the debug menu must not ship in the App Store build)
- **Effort**: M + owner (archive checks, Xcode Cloud workflow update)
- **Risk**: MED. The plan edits `project.pbxproj` and the shared schemes. A script with count checks does the pbxproj edit and refuses to write if the file is not exactly as expected.
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `3055ae6`, 2026-11-13
- **Issue**: [SLN-194](https://linear.app/sebastianln/issue/SLN-194)
- **Revision 1** (2026-11-13, after the first executor stopped at Step 4): the xcconfig files never applied. The project points at them through `baseConfigurationReferenceAnchor` on the synchronized `Hugo` folder plus a `../Configuration/...` path that leaves the folder, and Xcode ignores that silently (at `3055ae6`, `BUNDLE_IDENTIFIER`, which only the xcconfig sets, is missing from `-showBuildSettings`). The Step 2 script now also replaces those anchored references with normal file references (part 5), and Step 3 deletes the broken `INFOPLIST_KEY_TestFlightURL` lines. The advisor dry-ran the revised Steps 2-3 on a copy of `3055ae6` and got exactly Step 4's table.

## Why this matters

Today every build shows the Debug menu and the "Share TestFlight" button, including the build that will go to the App Store. The owner wants three builds with clear purposes:

- **Debug**: development in Xcode. Everything on.
- **TestFlight**: what beta testers install. It keeps the debug menu, so testers can help track down problems, and keeps "Share TestFlight".
- **Production**: the App Store build. No debug menu and no "Share TestFlight". It shows a "Join the Beta" link in their place.

The owner's rule: **code never checks which build it is.** Each build configuration turns named flags on or off in its `.xcconfig` file, and Swift checks the flag: `#if SHOW_DEBUG_MENU`, never `#if PRODUCTION` or `#if ENV_PROD`.

| Flag | Debug | TestFlight | Production |
|---|---|---|---|
| `SHOW_DEBUG_MENU` | on | on | off |
| `SHOW_SHARE_TESTFLIGHT` | on | on | off |
| `SHOW_JOIN_BETA` | off | off | on |
| `DEBUG` (Swift's usual flag, unchanged) | on | off | off |

The owner also accepted two small additions (2026-11-13):

1. **Copy Diagnostics** in the debug menu. One tap copies the app version and build, the iOS version, the device kind, the app language, the iCloud account status, the schema version and the number of entries and categories. Testers paste it into their bug report. It never includes names, category names, overseer details or anything else the user typed.
2. **Version in the support email subject.** "Contact Us" opens an email whose subject says the version and build, for example "Hugo feedback (1.0, build 125)", so the owner knows which build a message is about. This applies in every build.

## Current state

### Build configurations (`Hugo.xcodeproj/project.pbxproj`)

The project has three configurations: `Debug`, `Preview` and `Release`. Every one exists three times, at the project level and for the `Hugo` and `HugoTests` targets:

| Config | Project block ID | `Hugo` target block ID | `HugoTests` block ID |
|---|---|---|---|
| Debug | `E09054602E91E99A00254125` | `E090545E2E91E99A00254125` | `E09054912E951E2C00254125` |
| Preview | `E06222D82EC343E800566AD6` | `E06222D92EC343E800566AD6` | `E06222DA2EC343E800566AD6` |
| Release | `E09054612E91E99A00254125` | `E090545F2E91E99A00254125` | `E09054922E951E2C00254125` |

The three configuration lists (project, `Hugo`, `HugoTests`) each list Debug, Preview, Release, and each has `defaultConfigurationName = Release;`.

Relevant settings:

- Project Debug (`E09054602E91E99A00254125`) uses `baseConfigurationReferenceRelativePath = ../Configuration/Debug.xcconfig;` and sets
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited) ENV_$(HUGO_ENV)";`, `HUGO_ENV = DEV;`, `HUGO_BUNDLE_ID_SUFFIX = ".$(HUGO_ENV)";`.
- Project Release (`E09054612E91E99A00254125`) uses `../Configuration/Release.xcconfig` and sets
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "ENV_$(HUGO_ENV)";`, `HUGO_ENV = PROD;`, `HUGO_BUNDLE_ID_SUFFIX = "";`.
- `Hugo` target Debug sets `HUGO_BUNDLE_ID_SUFFIX = ".$(HUGO_ENV:lower)";` (so the bundle ID is `com.ordellnielsen.Hugo.dev`), `ASSETCATALOG_COMPILER_APPICON_NAME = AppIconDev;`, display name "Hugo Dev". `Hugo` target Release has `AppIcon`, display name "Hugo", and the bundle ID `com.ordellnielsen.Hugo`.
- Both targets use `PRODUCT_BUNDLE_IDENTIFIER = "com.ordellnielsen.Hugo$(HUGO_BUNDLE_ID_SUFFIX)";`, `CODE_SIGN_ENTITLEMENTS = Configuration/Hugo.entitlements;`, team `CAJA48GKTR`, automatic signing.
- **The xcconfig files do not apply today.** The two project-level blocks reference them like this:

  ```
  baseConfigurationReferenceAnchor = E09054512E91E99900254125 /* Hugo */;
  baseConfigurationReferenceRelativePath = ../Configuration/Debug.xcconfig;
  ```

  `E09054512E91E99900254125` is the synchronized `Hugo` folder (`path = Hugo`), and the relative path leaves that folder. Xcode ignores such a reference without a warning: at `3055ae6`, `xcodebuild -showBuildSettings` shows no `BUNDLE_IDENTIFIER`, although `Debug.xcconfig` sets it. Step 2 replaces both references with normal `PBXFileReference` entries (`baseConfigurationReference = <id>`), which Xcode does apply.
- **`INFOPLIST_KEY_TestFlightURL` in the xcconfig files is broken.** In an xcconfig file `//` starts a comment, so `INFOPLIST_KEY_TestFlightURL = https://testflight.apple.com/...` sets the value `https:`. It did no harm because the files never applied. The real URL is in `Hugo/Info.plist` (`TestFlightURL`). Step 3 deletes the line and its comment from every xcconfig, so applying the files cannot change the link.
- **Why the flags cannot simply go in the xcconfig files today (besides the reference problem):** a setting written in a pbxproj configuration block wins over the same setting in that block's base `.xcconfig`. The project Release block sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS` without `$(inherited)`, so anything an xcconfig adds is thrown away. Step 2 deletes both pbxproj `SWIFT_ACTIVE_COMPILATION_CONDITIONS` lines, so the xcconfig files own the setting.
- No Swift file reads `ENV_DEV`, `ENV_PROD` or `ENV_PREVIEW` (`grep -rn "ENV_" Hugo HugoTests` finds nothing). `HUGO_ENV` stays, because the Debug bundle ID suffix uses it, but no Swift code may ever check it.
- `Preview` is used by no scheme, script or document. Its `Hugo` target block uses the App Store bundle ID with Debug compiler settings, which is a trap. Xcode's SwiftUI canvas builds the scheme's Run configuration (Debug) and turns previews on by itself, so nothing depends on `Preview`. This plan deletes it. The owner confirmed deleting it (2026-11-13).

### Schemes (`Hugo.xcodeproj/xcshareddata/xcschemes/`)

- `Hugo.xcscheme`: Test, Launch and Analyze use `Debug`; Profile and Archive use `Release`. The Test action sets the environment variable `HUGO_TEST_MODE=1`.
- `Production.xcscheme`: identical except all five actions use `Release`.
- `Hugo.xcodeproj/xcshareddata/xcodecloud/manifest.json` shows Xcode Cloud is set up. Its workflows live in App Store Connect and refer to schemes by name, so renaming a scheme can break a workflow (owner step 9).

### xcconfig files (`Configuration/`)

`Configuration/Debug.xcconfig` (comments trimmed):

```
BUNDLE_IDENTIFIER = com.ordellnielsen.Hugo.dev
ASSETCATALOG_COMPILER_APPICON_NAME = AppIconDev

// TestFlight public invite link. Replace this value with the current invite URL.
INFOPLIST_KEY_TestFlightURL = https://testflight.apple.com/join/AdmsjW16
```

`Configuration/Release.xcconfig` (comments trimmed):

```
BUNDLE_IDENTIFIER = com.ordellnielsen.Hugo
ICLOUD_CONTAINER_IDENTIFIER = iCloud.com.ordellnielsen.Hugo
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon

// TestFlight public invite link. Replace this value with the current invite URL.
INFOPLIST_KEY_TestFlightURL = https://testflight.apple.com/join/AdmsjW16
```

`BUNDLE_IDENTIFIER` and `ICLOUD_CONTAINER_IDENTIFIER` are not read anywhere. Leave them as they are.

### `Scripts/verify.sh` and `README.md`

`Scripts/verify.sh` lines 11 and 13 call `xcodebuild test ... -scheme Hugo -configuration Debug` and `xcodebuild analyze ... -scheme Hugo -configuration Debug`. `README.md` line 17 shows the same `-scheme Hugo`. `AGENTS.md` does not mention schemes.

### Settings (`Hugo/Features/Settings/Screens/SettingsView.swift`)

Lines 12-22 build the support email link:

```swift
    private static var supportEmailURL: URL? {
        guard let email = Bundle.main.object(forInfoDictionaryKey: "SupportEmail") as? String,
            !email.isEmpty
        else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        return components.url
    }
```

Lines 24-33 read `testFlightURL` from the Info.plist key `TestFlightURL`. Lines 66-95 inside the `List`:

```swift
                if let testFlightURL = Self.testFlightURL {
                    Section {
                        ShareLink(item: testFlightURL) {
                            Label("settings.account.shareTestFlight", systemImage: "person.crop.circle.badge.plus")
                        }
                    } footer: {
                        Text("settings.account.shareTestFlight.description")
                    }
                }

                if let supportEmailURL = Self.supportEmailURL {
                    Section {
                        Button {
                            openURL(supportEmailURL)
                        } label: {
                            Label("settings.contact.email", systemImage: "envelope")
                        }
                    }
                }

                Section {
                    NavigationLink(destination: DebugSettingsView()) {
                        Label("debug.title", systemImage: "ant.fill")
                            .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("debug.disclaimer")
                }
```

`Hugo/Features/Settings/Screens/DebugSettingsView.swift` (whole file):

```swift
import SwiftUI

struct DebugSettingsView: View {
    @AppStorage(UserDefaultsKeys.isOnboarding) var isOnboarding: Bool = true

    var body: some View {
        List {
            Button("debug.action.reset-onboarding", systemImage: "arrow.counterclockwise") {
                isOnboarding = true
            }
        }
        .navigationTitle("debug.title")
    }
}

#Preview {
    DebugSettingsView()
}
```

### Facts the new code uses

- The current schema: `typealias CurrentSchema = SchemaV13` in `Hugo/Persistence/AppSchema.swift`, with `static let versionIdentifier = Schema.Version(10, 0, 0)`. Model aliases: `Entry`, `Tracker` (UI name: category), `SubmittedReport`, `Plan`.
- CloudKit: `Hugo/App/CloudTrackerLookup.swift` already calls `CKContainer.default()` on every non-test launch. `CKContainer.default()` raises an Objective-C exception in an unsigned test host, so **never call it from unit tests**. The diagnostics collector is not unit-tested for this reason; its formatting is.
- The project's default actor isolation is `MainActor` (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). Pure value types are marked `nonisolated`, for example `nonisolated struct CurrentMonthCalculation: Sendable` in `Hugo/Features/Settings/Domain/CurrentMonthCalculation.swift`.
- `UIKit` is already imported in feature code where needed (`Hugo/Features/Planner/Screens/PlannerView.swift:4`).
- Strings with arguments use dotted keys, for example `a11y.monthly_progress_card.value.%lld.%lld` with English `%1$lld of %2$lld hours this month`. With `String`/`%@` arguments the key ends in `.%@.%@` and values use `%1$@` and `%2$@`.
- The Danish word for entries in the app is "registreringer" (`year.empty.title`: "Ingen registreringer endnu"); categories are "kategorier".
- Feature folder rules (AGENTS.md section 7, enforced by `Scripts/check-layout.sh`): files live in `Screens`, `Views`, `State`, `Domain` or `Services`. `Hugo/Features/Settings/Services/` does not exist yet; create it with its first file. Tests mirror the source path.

## Commands you will need

Run every `xcodebuild` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` in front, as `Scripts/verify.sh` does.

| Purpose | Command | Expected on success |
|---|---|---|
| Is Xcode open? | `pgrep -x Xcode` | no output (exit 1) |
| pbxproj syntax | `plutil -lint Hugo.xcodeproj/project.pbxproj` | `... OK` |
| Configs and schemes | `xcodebuild -list -project Hugo.xcodeproj` | see Step 4 |
| Build settings | `xcodebuild -project Hugo.xcodeproj -target Hugo -configuration <Config> -showBuildSettings 2>/dev/null \| grep -E '^ +(SWIFT_ACTIVE_COMPILATION_CONDITIONS\|PRODUCT_BUNDLE_IDENTIFIER\|ASSETCATALOG_COMPILER_APPICON_NAME) = '` | see Step 4 |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Layout | `Scripts/check-layout.sh` | exit 0 |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |
| Full gate (before each commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

## Scope

**In scope** (the only files you may change, create, rename or delete):

- `Hugo.xcodeproj/project.pbxproj` (only through the script in Step 2)
- `Hugo.xcodeproj/xcshareddata/xcschemes/Hugo.xcscheme` (renamed to `Debug.xcscheme`)
- `Hugo.xcodeproj/xcshareddata/xcschemes/Production.xcscheme`
- `Hugo.xcodeproj/xcshareddata/xcschemes/TestFlight.xcscheme` (create)
- `Configuration/Debug.xcconfig`
- `Configuration/Release.xcconfig` (renamed to `Configuration/Production.xcconfig`)
- `Configuration/TestFlight.xcconfig` (create)
- `Scripts/verify.sh`, `README.md`, `AGENTS.md`
- `Hugo/Features/Settings/Screens/SettingsView.swift`
- `Hugo/Features/Settings/Screens/DebugSettingsView.swift`
- `Hugo/Features/Settings/Domain/AppVersion.swift` (create)
- `Hugo/Features/Settings/Domain/SupportEmailLink.swift` (create)
- `Hugo/Features/Settings/Domain/DiagnosticsReport.swift` (create)
- `Hugo/Features/Settings/Services/DiagnosticsCollector.swift` (create)
- `HugoTests/Features/Settings/Domain/AppVersionTests.swift` (create)
- `HugoTests/Features/Settings/Domain/SupportEmailLinkTests.swift` (create)
- `HugoTests/Features/Settings/Domain/DiagnosticsReportTests.swift` (create)
- `Hugo/Resources/Localizable.xcstrings` (only the keys in Steps 6 and 8)

**Out of scope** (do not touch):

- `Configuration/Hugo.entitlements`, every `CODE_SIGN_*`, `DEVELOPMENT_TEAM`, `PRODUCT_BUNDLE_IDENTIFIER`, `HUGO_ENV` and `HUGO_BUNDLE_ID_SUFFIX` setting, and the iCloud container. TestFlight must keep the App Store bundle ID and container, because it uploads to the same App Store Connect app.
- `Hugo/Info.plist`, `Hugo.xcodeproj/xcshareddata/xcodecloud/manifest.json` and the app icons. A separate beta icon is deferred (see Maintenance notes).
- Unused xcconfig values (`BUNDLE_IDENTIFIER`, `ICLOUD_CONTAINER_IDENTIFIER`). Leave them.
- Any Swift check on a build or environment name (`#if PRODUCTION`, `#if ENV_PROD`, `#if DEBUG` for these features). Only the three flags above.
- More debug menu actions than Copy Diagnostics. Nothing destructive.
- `.claude/` (including `.claude/worktrees/`, which holds old copies of `Configuration/`), `plans/` and the owner's `Changelog/` changes. Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage files by path.
- Three commits, each after `Scripts/verify.sh` exits 0 (match the repo's Conventional Commits style, e.g. `chore: sync string catalog comments`):
  1. After Step 5: `build: split builds into Debug, TestFlight and Production with feature flags`
  2. After Step 7: `feat: show the debug menu and TestFlight rows only in the builds that want them`
  3. After Step 10: `feat: copy diagnostics from the debug menu and put the version in support emails`
- Renames must be `git mv`, so history follows the files.

## Steps

### Step 1: Make sure Xcode is closed

Xcode rewrites `project.pbxproj` and the schemes when it has the project open, and would undo or corrupt the edits in Steps 2-3.

**Verify**: `pgrep -x Xcode` prints nothing. If it prints a process ID, STOP and ask the owner to quit Xcode.

### Step 2: Edit `project.pbxproj` with the script

Do not edit `project.pbxproj` by hand. Run this script from the repo root. It checks the exact number of every string it changes and exits without writing anything if a count is wrong. It:

1. deletes the three `Preview` blocks and their list entries,
2. renames `Release` to `Production` (block comments, `name =`, `defaultConfigurationName =`, and the xcconfig path),
3. deletes the two `SWIFT_ACTIVE_COMPILATION_CONDITIONS` lines so the xcconfig files own that setting,
4. adds a `TestFlight` copy of each `Production` block with a new ID and `../Configuration/TestFlight.xcconfig`, listed between Debug and Production,
5. replaces the three anchored xcconfig references (Debug, TestFlight, Production) with normal file references, so Xcode applies the files.

```sh
python3 -I - <<'EOF'
import pathlib, sys

path = pathlib.Path("Hugo.xcodeproj/project.pbxproj")
text = path.read_text()
BLOCK_END = "\n\t\t};\n"

def expect(count, needle, label):
    actual = text.count(needle)
    if actual != count:
        sys.exit(f"STOP: expected {count} x {label}, found {actual}. Nothing was written.")

PREVIEW_IDS = ["E06222D82EC343E800566AD6", "E06222D92EC343E800566AD6", "E06222DA2EC343E800566AD6"]
TESTFLIGHT_IDS = {  # Production block ID -> new TestFlight block ID
    "E09054612E91E99A00254125": "E0F1E5702EC6000000000001",  # project
    "E090545F2E91E99A00254125": "E0F1E5702EC6000000000002",  # Hugo target
    "E09054922E951E2C00254125": "E0F1E5702EC6000000000003",  # HugoTests target
}
for new_id in TESTFLIGHT_IDS.values():
    expect(0, new_id, f"new ID {new_id}")

# 1. Delete Preview.
expect(6, "/* Preview */", "Preview references")
for pid in PREVIEW_IDS:
    header = f"\t\t{pid} /* Preview */ = {{\n"
    expect(1, header, f"Preview block {pid}")
    start = text.index(header)
    end = text.index(BLOCK_END, start) + len(BLOCK_END)
    text = text[:start] + text[end:]
    entry = f"\t\t\t\t{pid} /* Preview */,\n"
    expect(1, entry, f"Preview list entry {pid}")
    text = text.replace(entry, "")
expect(0, "/* Preview */", "leftover Preview references")
expect(0, "name = Preview;", "leftover Preview names")

# 2. Rename Release to Production.
expect(6, "/* Release */", "Release comments")
expect(3, "name = Release;", "Release names")
expect(3, "defaultConfigurationName = Release;", "default configuration names")
expect(1, "../Configuration/Release.xcconfig", "Release xcconfig path")
text = text.replace("/* Release */", "/* Production */")
text = text.replace("name = Release;", "name = Production;")
text = text.replace("defaultConfigurationName = Release;", "defaultConfigurationName = Production;")
text = text.replace("../Configuration/Release.xcconfig", "../Configuration/Production.xcconfig")
expect(0, "Release", "leftover Release")

# 3. Let the xcconfig files own SWIFT_ACTIVE_COMPILATION_CONDITIONS.
debug_line = '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited) ENV_$(HUGO_ENV)";\n'
prod_line = '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "ENV_$(HUGO_ENV)";\n'
expect(1, debug_line, "Debug compilation conditions")
expect(1, prod_line, "Production compilation conditions")
text = text.replace(debug_line, "").replace(prod_line, "")
expect(0, "SWIFT_ACTIVE_COMPILATION_CONDITIONS", "leftover compilation conditions")

# 4. Add TestFlight as a copy of each Production block.
for source_id, new_id in TESTFLIGHT_IDS.items():
    header = f"\t\t{source_id} /* Production */ = {{\n"
    expect(1, header, f"Production block {source_id}")
    start = text.index(header)
    end = text.index(BLOCK_END, start) + len(BLOCK_END)
    block = text[start:end]
    copy = (
        block.replace(source_id, new_id)
        .replace("/* Production */", "/* TestFlight */")
        .replace("name = Production;", "name = TestFlight;")
        .replace("../Configuration/Production.xcconfig", "../Configuration/TestFlight.xcconfig")
    )
    text = text[:end] + copy + text[end:]
    entry = f"\t\t\t\t{source_id} /* Production */,\n"
    expect(1, entry, f"Production list entry {source_id}")
    text = text.replace(entry, f"\t\t\t\t{new_id} /* TestFlight */,\n" + entry)

expect(3, "name = Debug;", "Debug configurations")
expect(3, "name = TestFlight;", "TestFlight configurations")
expect(3, "name = Production;", "Production configurations")
expect(1, "../Configuration/TestFlight.xcconfig", "TestFlight xcconfig path")
expect(1, "../Configuration/Production.xcconfig", "Production xcconfig path")

# 5. Reference the xcconfig files with normal file references. Xcode ignores
#    an anchored reference whose path leaves the synchronized Hugo folder.
XCCONFIG_REFS = {
    "Debug": "E0F1E5702EC6000000000011",
    "TestFlight": "E0F1E5702EC6000000000012",
    "Production": "E0F1E5702EC6000000000013",
}
for ref in XCCONFIG_REFS.values():
    expect(0, ref, f"new ID {ref}")
expect(3, "baseConfigurationReferenceAnchor", "anchored xcconfig references")
section = "/* Begin PBXFileReference section */\n"
expect(1, section, "file reference section")
file_refs = "".join(
    f'\t\t{ref} /* {name}.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
    f'name = {name}.xcconfig; path = Configuration/{name}.xcconfig; sourceTree = "<group>"; }};\n'
    for name, ref in XCCONFIG_REFS.items()
)
text = text.replace(section, section + file_refs)
children = "\t\t\t\tE09054512E91E99900254125 /* Hugo */,\n\t\t\t\tE090548B2E951E2C00254125 /* HugoTests */,\n"
expect(1, children, "main group children")
text = text.replace(
    children,
    "".join(f"\t\t\t\t{ref} /* {name}.xcconfig */,\n" for name, ref in XCCONFIG_REFS.items()) + children,
)
for name, ref in XCCONFIG_REFS.items():
    old = (
        "\t\t\tbaseConfigurationReferenceAnchor = E09054512E91E99900254125 /* Hugo */;\n"
        f"\t\t\tbaseConfigurationReferenceRelativePath = ../Configuration/{name}.xcconfig;\n"
    )
    expect(1, old, f"anchored reference to {name}.xcconfig")
    text = text.replace(old, f"\t\t\tbaseConfigurationReference = {ref} /* {name}.xcconfig */;\n")
expect(0, "baseConfigurationReferenceAnchor", "leftover anchored references")
expect(0, "baseConfigurationReferenceRelativePath", "leftover relative paths")
expect(3, "baseConfigurationReference = ", "xcconfig file references")
path.write_text(text)
print("project.pbxproj updated")
EOF
```

**Verify**: the script prints `project.pbxproj updated`, and `plutil -lint Hugo.xcodeproj/project.pbxproj` prints `... OK`. If the script prints a line starting with `STOP:`, stop and report it (nothing was written).

### Step 3: Rename and add the xcconfig files and schemes

0. In `Configuration/Debug.xcconfig` and `Configuration/Release.xcconfig`, delete the two lines `// TestFlight public invite link. Replace this value with the current invite URL.` and `INFOPLIST_KEY_TestFlightURL = https://testflight.apple.com/join/AdmsjW16` (see "Current state": `//` starts a comment, so the value is broken, and `Hugo/Info.plist` already holds the real URL). Delete the blank line before them too, if one is left at the end of the file.
1. `git mv Configuration/Release.xcconfig Configuration/Production.xcconfig`. In it, change the header line `//  Release.xcconfig` to `//  Production.xcconfig`, and append at the end:

   ```
   // The App Store build.
   // Feature flags. Swift code checks these names with `#if`, never the name of
   // the build. A flag that is not listed is off. See "Builds" in README.md.
   SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) SHOW_JOIN_BETA
   ```

2. Create `Configuration/TestFlight.xcconfig` as a copy of the new `Production.xcconfig`. Change the header line to `//  TestFlight.xcconfig` and replace the appended block with:

   ```
   // The build for beta testers. It uses the App Store bundle ID and iCloud
   // container, because it uploads to the same App Store Connect app.
   // Feature flags. Swift code checks these names with `#if`, never the name of
   // the build. A flag that is not listed is off. See "Builds" in README.md.
   SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) SHOW_DEBUG_MENU SHOW_SHARE_TESTFLIGHT
   ```

3. Append to `Configuration/Debug.xcconfig`:

   ```
   // Development in Xcode.
   // Feature flags. Swift code checks these names with `#if`, never the name of
   // the build. A flag that is not listed is off. See "Builds" in README.md.
   SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) DEBUG SHOW_DEBUG_MENU SHOW_SHARE_TESTFLIGHT
   ```

4. Schemes, in `Hugo.xcodeproj/xcshareddata/xcschemes/`:
   - `git mv Hugo.xcscheme Debug.xcscheme`. In `Debug.xcscheme`, change the ProfileAction's `buildConfiguration = "Release"` to `"Production"` and the ArchiveAction's `buildConfiguration = "Release"` to `"Debug"`. An archive from the Debug scheme has the `.dev` bundle ID, so an accidental upload fails loudly instead of shipping the wrong build.
   - In `Production.xcscheme`, change all five `buildConfiguration = "Release"` to `buildConfiguration = "Production"`.
   - Create `TestFlight.xcscheme` as a copy of the edited `Production.xcscheme`, with all five `buildConfiguration = "Production"` changed to `buildConfiguration = "TestFlight"`. Change nothing else.

**Verify**:

- `grep -o 'buildConfiguration = "[A-Za-z]*"' Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` prints, in order: `Debug`, `Debug`, `Production`, `Debug`, `Debug`.
- `grep -c 'buildConfiguration = "Production"' Hugo.xcodeproj/xcshareddata/xcschemes/Production.xcscheme` prints `5`.
- `grep -c 'buildConfiguration = "TestFlight"' Hugo.xcodeproj/xcshareddata/xcschemes/TestFlight.xcscheme` prints `5`.
- `grep -rn "Release" Hugo.xcodeproj/xcshareddata/xcschemes Configuration/*.xcconfig` prints nothing.
- `grep -rn "INFOPLIST_KEY_TestFlightURL" Configuration` prints nothing.

### Step 4: Check that Xcode sees three builds and that the flags take effect

1. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list -project Hugo.xcodeproj` lists exactly these Build Configurations, in this order: `Debug`, `TestFlight`, `Production`. Schemes: `Debug`, `Production`, `TestFlight`, plus `MarkdownUI` (the Swift package's own scheme, which was there before). The line about the default configuration names `Production`. (The advisor dry-ran the revised Step 2 script and Step 3's xcconfig edits on a copy at `3055ae6`: `plutil` said OK, `xcodebuild -list` showed these three configurations, and the build settings matched the table below.)
2. Run the build-settings command from "Commands you will need" once per configuration, with `BUNDLE_IDENTIFIER` and `INFOPLIST_KEY_TestFlightURL` added to its `grep -E` list. Expected (leading spaces and the order of lines may differ):

| Config | `SWIFT_ACTIVE_COMPILATION_CONDITIONS` | `PRODUCT_BUNDLE_IDENTIFIER` | `ASSETCATALOG_COMPILER_APPICON_NAME` |
|---|---|---|---|
| Debug | `DEBUG SHOW_DEBUG_MENU SHOW_SHARE_TESTFLIGHT` | `com.ordellnielsen.Hugo.dev` | `AppIconDev` |
| TestFlight | `SHOW_DEBUG_MENU SHOW_SHARE_TESTFLIGHT` | `com.ordellnielsen.Hugo` | `AppIcon` |
| Production | `SHOW_JOIN_BETA` | `com.ordellnielsen.Hugo` | `AppIcon` |

Also: `BUNDLE_IDENTIFIER` appears for every configuration (`com.ordellnielsen.Hugo.dev` for Debug, `com.ordellnielsen.Hugo` for the others). That proves the xcconfig files now apply. `INFOPLIST_KEY_TestFlightURL` does not appear.

**Verify**: every value matches. No `ENV_` appears in any `SWIFT_ACTIVE_COMPILATION_CONDITIONS` value. If `SWIFT_ACTIVE_COMPILATION_CONDITIONS` or `BUNDLE_IDENTIFIER` is missing, STOP.

### Step 5: Point the verify script and docs at the Debug scheme

1. `Scripts/verify.sh`: change both `-scheme Hugo` to `-scheme Debug`. Change nothing else.
2. `README.md` line 17: `-scheme Hugo` becomes `-scheme Debug`. Then add this section after the "Pre-commit format hook" section and before "## Architecture":

   ```markdown
   ## Builds

   Hugo has three build configurations, each with a scheme of the same name:

   * **Debug**: development in Xcode. Bundle ID `com.ordellnielsen.Hugo.dev`.
   * **TestFlight**: what beta testers install. Archive with the `TestFlight` scheme.
   * **Production**: the App Store build. Archive with the `Production` scheme.

   TestFlight and Production share the App Store bundle ID and iCloud container. Each configuration turns feature flags on in its `Configuration/*.xcconfig` file, and Swift code checks the flag, never the build's name:

   | Flag | Debug | TestFlight | Production |
   |---|---|---|---|
   | `SHOW_DEBUG_MENU` | on | on | off |
   | `SHOW_SHARE_TESTFLIGHT` | on | on | off |
   | `SHOW_JOIN_BETA` | off | off | on |

   The App Store build must be its own Production archive. A TestFlight archive contains the debug menu and must not be sent to App Review.
   ```

3. `AGENTS.md`, section "8. Verification and testing": add this bullet after the `Scripts/verify.sh` bullet:

   ```markdown
   - Build-specific behavior uses flags, never the build's name. `Configuration/Debug.xcconfig`, `TestFlight.xcconfig` and `Production.xcconfig` set `SWIFT_ACTIVE_COMPILATION_CONDITIONS` (see "Builds" in `README.md`). Check a flag with `#if SHOW_DEBUG_MENU`; never write `#if PRODUCTION`, `#if ENV_PROD` or a check on `DEBUG` for a product feature. A new flag goes in each file where it is on, and in the README table.
   ```

**Verify**: `Scripts/verify.sh` exits 0 (this proves the `Debug` scheme works for tests and analysis). `git status --short` shows only the in-scope files of Steps 2-5 (plus the owner's untouched `Changelog/` changes). Commit 1.

### Step 6: Gate the Settings rows and add "Join the Beta"

In `SettingsView.swift`, inside the `List`:

1. Wrap the existing Share TestFlight `if let testFlightURL ... { Section { ShareLink ... } }` block in `#if SHOW_SHARE_TESTFLIGHT` / `#endif`.
2. Directly after that `#endif`, add:

   ```swift
                   #if SHOW_JOIN_BETA
                       if let testFlightURL = Self.testFlightURL {
                           Section {
                               Link(destination: testFlightURL) {
                                   Label("settings.account.joinBeta", systemImage: "testtube.2")
                               }
                           } footer: {
                               Text("settings.account.joinBeta.description")
                           }
                       }
                   #endif
   ```

3. Wrap the debug `Section { NavigationLink(destination: DebugSettingsView()) ... } footer: { Text("debug.disclaimer") }` in `#if SHOW_DEBUG_MENU` / `#endif`.

Let `swift-format` decide the indentation of the `#if` lines (run `xcrun swift-format format --in-place Hugo/Features/Settings/Screens/SettingsView.swift`, then lint).

Add these keys to `Hugo/Resources/Localizable.xcstrings` with the same JSON shape as `settings.account.shareTestFlight` (English and Danish `stringUnit`s with `"state" : "translated"`, plus a `comment`). Keep the catalog's key order (alphabetical) and its `" : "` spacing:

| Key | English | Danish | Comment |
|---|---|---|---|
| `settings.account.joinBeta` | Join the Beta | Bliv betatester | A link in Settings that opens the public TestFlight invitation. Shown only in the App Store build. |
| `settings.account.joinBeta.description` | Want to try new features before they come out? Join the Hugo beta on TestFlight and help find problems early. Seats are limited, so the beta might be full. | Vil du prøve nye funktioner, før de udkommer? Bliv betatester af Hugo via TestFlight, og hjælp med at finde fejl tidligt. Der er et begrænset antal pladser, så betaen kan være fyldt. | Footer under the Join the Beta link in Settings. |

**Verify**: lint and the catalog JSON check exit 0. `grep -c "#if SHOW_" Hugo/Features/Settings/Screens/SettingsView.swift` prints `3`.

### Step 7: Compile the debug menu only where its flag is on

In `DebugSettingsView.swift`, put `#if SHOW_DEBUG_MENU` on the line after `import SwiftUI` and `#endif` at the very end of the file, so the struct and its `#Preview` exist only in builds with the flag. The imports stay outside.

Then prove the flags work in optimized builds without signing (these builds are for the simulator and need no certificates):

```sh
for config in TestFlight Production; do
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
    -project Hugo.xcodeproj -scheme "$config" -configuration "$config" \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "/tmp/Hugo102-$config" CODE_SIGNING_ALLOWED=NO -quiet || exit 1
done
for config in TestFlight Production; do
  bin="/tmp/Hugo102-$config/Build/Products/$config-iphonesimulator/Hugo.app/Hugo"
  echo "$config debug=$(strings -a "$bin" | grep -c DebugSettingsView) share=$(strings -a "$bin" | grep -c settings.account.shareTestFlight) join=$(strings -a "$bin" | grep -c settings.account.joinBeta)"
done
```

**Verify**: both builds succeed, and the last loop prints:

- for TestFlight: `debug` and `share` are 1 or more, `join` is 0;
- for Production: `debug` and `share` are 0, `join` is 1 or more.

Then `Scripts/verify.sh` exits 0. Commit 2.

### Step 8: Add `AppVersion` and `SupportEmailLink`, and put the version in the email subject

Create `Hugo/Features/Settings/Domain/AppVersion.swift`:

```swift
import Foundation

/// The app's version and build number, read from an Info.plist dictionary,
/// for the support email subject and the debug menu's diagnostics.
nonisolated struct AppVersion: Equatable, Sendable {
    let marketingVersion: String
    let buildNumber: String

    init(infoDictionary: [String: Any]) {
        marketingVersion = infoDictionary["CFBundleShortVersionString"] as? String ?? "?"
        buildNumber = infoDictionary["CFBundleVersion"] as? String ?? "?"
    }

    /// The running app's version.
    static var current: AppVersion {
        AppVersion(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    /// For example "1.0 (125)".
    var displayString: String {
        "\(marketingVersion) (\(buildNumber))"
    }
}
```

Create `Hugo/Features/Settings/Domain/SupportEmailLink.swift`:

```swift
import Foundation

/// Builds the `mailto:` link behind Settings' Contact Us button.
nonisolated enum SupportEmailLink {
    /// A `mailto:` URL for `address` with `subject` filled in, or nil when
    /// there is no address.
    static func url(address: String, subject: String) -> URL? {
        guard !address.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }
}
```

In `SettingsView.swift`, replace the body of `supportEmailURL` so it reads:

```swift
    private static var supportEmailURL: URL? {
        guard let email = Bundle.main.object(forInfoDictionaryKey: "SupportEmail") as? String
        else {
            return nil
        }
        let version = AppVersion.current
        let subject = String(
            localized: "settings.contact.email.subject.\(version.marketingVersion).\(version.buildNumber)")
        return SupportEmailLink.url(address: email, subject: subject)
    }
```

Add this key to the catalog (same shape as above):

| Key | English | Danish | Comment |
|---|---|---|---|
| `settings.contact.email.subject.%@.%@` | Hugo feedback (%1$@, build %2$@) | Feedback på Hugo (%1$@, build %2$@) | Subject of the support email. First argument: the app version, for example 1.0. Second: the build number. |

**Verify**: lint, layout and the catalog JSON check exit 0.

### Step 9: Add `DiagnosticsReport` and `DiagnosticsCollector`

Create `Hugo/Features/Settings/Domain/DiagnosticsReport.swift`:

```swift
import Foundation

/// The text the debug menu copies for a bug report. It holds versions,
/// device facts and record counts only. Never add names, category names,
/// overseer details or anything else the user typed.
nonisolated struct DiagnosticsReport: Equatable, Sendable {
    var appVersion: AppVersion
    /// For example "iOS 26.1".
    var systemVersion: String
    /// "iPhone" or "iPad".
    var deviceModel: String
    /// The app language in use, for example "da".
    var language: String
    var iCloudStatus: String
    /// For example "SchemaV13".
    var schemaName: String
    /// For example "10.0.0".
    var schemaVersion: String
    /// Nil when the count could not be read.
    var entryCount: Int?
    var categoryCount: Int?

    /// English on purpose: the developer reads it.
    var text: String {
        [
            "Hugo \(appVersion.displayString)",
            "\(systemVersion), \(deviceModel)",
            "Language: \(language)",
            "iCloud: \(iCloudStatus)",
            "Schema: \(schemaName) (\(schemaVersion))",
            "Entries: \(entryCount.map(String.init) ?? "unknown")",
            "Categories: \(categoryCount.map(String.init) ?? "unknown")",
        ].joined(separator: "\n")
    }
}
```

Create `Hugo/Features/Settings/Services/DiagnosticsCollector.swift`:

```swift
import CloudKit
import SwiftData
import UIKit

/// Gathers the facts for the debug menu's Copy Diagnostics button. It reads
/// counts, never record contents. Do not call it from unit tests: CloudKit
/// raises an exception in an unsigned test host (see `CloudKitTrackerLookup`).
struct DiagnosticsCollector {
    let modelContext: ModelContext
    var bundle: Bundle = .main

    func collect() async -> DiagnosticsReport {
        let version = CurrentSchema.versionIdentifier
        return DiagnosticsReport(
            appVersion: AppVersion(infoDictionary: bundle.infoDictionary ?? [:]),
            systemVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            deviceModel: UIDevice.current.model,
            language: bundle.preferredLocalizations.first ?? "unknown",
            iCloudStatus: await iCloudStatus(),
            schemaName: String(describing: CurrentSchema.self),
            schemaVersion: "\(version.major).\(version.minor).\(version.patch)",
            entryCount: try? modelContext.fetchCount(FetchDescriptor<Entry>()),
            categoryCount: try? modelContext.fetchCount(FetchDescriptor<Tracker>())
        )
    }

    private func iCloudStatus() async -> String {
        do {
            switch try await CKContainer.default().accountStatus() {
            case .available: return "available"
            case .noAccount: return "no account"
            case .restricted: return "restricted"
            case .temporarilyUnavailable: return "temporarily unavailable"
            case .couldNotDetermine: return "could not determine"
            @unknown default: return "unknown"
            }
        } catch {
            return "error \((error as NSError).code)"
        }
    }
}
```

`DiagnosticsCollector` is not wrapped in `#if`: only the debug menu calls it, and Release builds strip unused code. If the compiler rejects `try?` inside the argument list, compute both counts into `let` constants first.

**Verify**: lint and `Scripts/check-layout.sh` exit 0.

### Step 10: Add Copy Diagnostics to the debug menu

Replace the body of `DebugSettingsView` (inside the `#if SHOW_DEBUG_MENU` from Step 7) so the file reads:

```swift
import SwiftData
import SwiftUI
import UIKit

#if SHOW_DEBUG_MENU
    struct DebugSettingsView: View {
        @AppStorage(UserDefaultsKeys.isOnboarding) var isOnboarding: Bool = true
        @Environment(\.modelContext) private var modelContext
        @State private var didCopyDiagnostics = false

        var body: some View {
            List {
                Button("debug.action.reset-onboarding", systemImage: "arrow.counterclockwise") {
                    isOnboarding = true
                }

                Section {
                    Button(copyTitle, systemImage: didCopyDiagnostics ? "checkmark" : "doc.on.doc") {
                        Task { await copyDiagnostics() }
                    }
                } footer: {
                    Text("debug.action.copy-diagnostics.description")
                }
            }
            .navigationTitle("debug.title")
            .sensoryFeedback(.success, trigger: didCopyDiagnostics)
        }

        private var copyTitle: LocalizedStringKey {
            didCopyDiagnostics ? "debug.action.copy-diagnostics.done" : "debug.action.copy-diagnostics"
        }

        private func copyDiagnostics() async {
            let report = await DiagnosticsCollector(modelContext: modelContext).collect()
            UIPasteboard.general.string = report.text
            didCopyDiagnostics = true
        }
    }

    #Preview {
        NavigationStack {
            DebugSettingsView()
        }
        .modelContainer(.preview)
    }
#endif
```

Use whatever indentation `swift-format` produces for the `#if` block.

Add these keys to the catalog (same shape as above):

| Key | English | Danish | Comment |
|---|---|---|---|
| `debug.action.copy-diagnostics` | Copy Diagnostics | Kopiér diagnostik | Debug menu button that copies app and device facts for a bug report. |
| `debug.action.copy-diagnostics.done` | Copied | Kopieret | The Copy Diagnostics button's title after it copied. |
| `debug.action.copy-diagnostics.description` | Copies the app version, iOS version, iCloud status and how many entries and categories you have. It never includes names or anything you wrote. Paste it into your message to the developer. | Kopierer appversion, iOS-version, iCloud-status og hvor mange registreringer og kategorier du har. Navne og tekst, du har skrevet, kommer aldrig med. Indsæt det i din besked til udvikleren. | Footer under the Copy Diagnostics button in the debug menu. |

Write the tests from the Test plan, then run the gate.

**Verify**: the catalog JSON check exits 0, `Scripts/verify.sh` exits 0 including the new tests, `git diff --check` exits 0. Commit 3.

### Step 11 (owner, not the executor): device and upload checks

Report these to the owner as open items:

1. **Xcode Cloud.** In App Store Connect (or Xcode → Report navigator → Cloud), open each Xcode Cloud workflow and pick the new scheme: `TestFlight` for beta builds, `Production` for App Store builds. A workflow that used the old `Hugo` scheme fails until this is done. Do this before pushing these commits.
2. **TestFlight archive.** Archive with the `TestFlight` scheme and install it through TestFlight. Settings shows Debugging and Share TestFlight, and no Join the Beta. Copy Diagnostics pastes text with the right version and build, iCloud "available", and the entry and category counts, and nothing personal.
3. **Production archive.** Archive with the `Production` scheme and install it through internal TestFlight. Settings shows Join the Beta with its footer, and no Debugging or Share TestFlight. Join the Beta opens the TestFlight invitation.
4. **Contact Us** in any build opens Mail with the subject "Hugo feedback (1.0, build N)" in English, or "Feedback på Hugo (1.0, build N)" in Danish.
5. Review the Danish wording of the new strings.

## Test plan

Model the files after `HugoTests/Features/Settings/Domain/CurrentMonthCalculationTests.swift` (`import Testing`, `@testable import Hugo`, a `struct` with `@Test` functions, `#expect`).

- `HugoTests/Features/Settings/Domain/AppVersionTests.swift`
  - reads `CFBundleShortVersionString` and `CFBundleVersion`: `displayString == "1.0 (125)"`.
  - a missing key gives `"?"` for that part: `AppVersion(infoDictionary: [:]).displayString == "? (?)"`.
- `HugoTests/Features/Settings/Domain/SupportEmailLinkTests.swift`
  - an empty address returns nil.
  - `url(address: "app@example.com", subject: "Feedback på Hugo (1.0, build 125)")`: the scheme is `mailto`, `URLComponents(url:resolvingAgainstBaseURL:)` gives `path == "app@example.com"` and the `subject` query item's value equals the subject exactly (Danish letter included), and `absoluteString` contains no space character.
- `HugoTests/Features/Settings/Domain/DiagnosticsReportTests.swift`
  - a full report's `text` equals exactly these seven lines joined by `\n`: `Hugo 1.0 (125)`, `iOS 26.1, iPhone`, `Language: da`, `iCloud: available`, `Schema: SchemaV13 (10.0.0)`, `Entries: 412`, `Categories: 5`.
  - nil counts print `Entries: unknown` and `Categories: unknown`.

Do not test `DiagnosticsCollector` (CloudKit and `UIDevice`).

**Verify**: `Scripts/verify.sh` exits 0, with 7 new tests.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `xcodebuild -list -project Hugo.xcodeproj` shows configurations `Debug`, `TestFlight`, `Production` and schemes `Debug`, `Production`, `TestFlight` (plus the package's `MarkdownUI`), and nothing else
- [ ] Step 4's build-settings table matches for all three configurations
- [ ] Step 7's `strings` check: TestFlight has `DebugSettingsView` and `shareTestFlight` but not `joinBeta`; Production has `joinBeta` only
- [ ] `grep -rn "ENV_\|#if PRODUCTION\|#if TESTFLIGHT" Hugo HugoTests Configuration` prints nothing
- [ ] `grep -c "SWIFT_ACTIVE_COMPILATION_CONDITIONS" Hugo.xcodeproj/project.pbxproj` prints `0`
- [ ] `grep -c "baseConfigurationReferenceAnchor" Hugo.xcodeproj/project.pbxproj` prints `0` and `grep -c "baseConfigurationReference = " Hugo.xcodeproj/project.pbxproj` prints `3`
- [ ] `git log --oneline -3` shows the three commits from "Git workflow", and none of them contains `Changelog/`, `.claude/` or `plans/`
- [ ] `plans/README.md` row for 102 updated

## STOP conditions

- Xcode is running (Step 1).
- The Step 2 script prints a `STOP:` line, or `plutil -lint` fails afterwards. Restore the file with `git checkout -- Hugo.xcodeproj/project.pbxproj` and report.
- `xcodebuild -list` or `-showBuildSettings` does not match Step 4. In particular, if TestFlight or Production does not use `com.ordellnielsen.Hugo`, or a flag is missing: do not fix it by adding settings to the pbxproj by hand.
- Anything would require changing signing (`CODE_SIGN_*`, `DEVELOPMENT_TEAM`, provisioning), the entitlements file, the iCloud container or a bundle ID. These are owner decisions.
- A build or test asks for a signing certificate or a provisioning profile even though `CODE_SIGNING_ALLOWED=NO` is passed.
- Do not archive or upload anything. Archives and uploads are owner steps (Step 11).
- `Scripts/verify.sh` fails with "scheme Debug not found" or a similar scheme error after Step 5.
- The `#if` blocks inside `List { }` do not compile, and one obvious fix doesn't solve it.

## Maintenance notes

- **The App Store build is its own archive.** A TestFlight archive contains the debug menu and must never go to App Review, so the release binary is not the exact one testers ran. Install the Production archive through internal TestFlight before submitting it.
- **Adding a flag**: list it in `SWIFT_ACTIVE_COMPILATION_CONDITIONS` in each xcconfig where it is on, add a README row, and check it with `#if NAME`. Keep the pbxproj free of `SWIFT_ACTIVE_COMPILATION_CONDITIONS`; if Xcode ever writes that setting back into the pbxproj (for example after someone edits it in the Build Settings editor), the xcconfig flags stop working. `grep -c SWIFT_ACTIVE_COMPILATION_CONDITIONS Hugo.xcodeproj/project.pbxproj` must stay `0`.
- **Destructive debug actions** (wiping data, seeding sample data) do not belong under `SHOW_DEBUG_MENU`, because testers have that menu. Give them a new flag that is on in Debug only.
- **String catalog**: after Xcode builds Production, it may mark `debug.*` and `settings.account.shareTestFlight*` keys as stale, because that build's code doesn't use them. Stale keys still ship and work. Do not delete them.
- **Deferred**: a separate beta app icon for the TestFlight build (owner: maybe later). It is one line, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIconBeta` in `Configuration/TestFlight.xcconfig`, plus the icon asset. Note that the `Hugo` target's pbxproj block sets `ASSETCATALOG_COMPILER_APPICON_NAME` too and wins over the xcconfig, so that line must be removed from the TestFlight block at the same time.
- **xcconfig references**: keep the xcconfig files referenced through `baseConfigurationReference` to a `PBXFileReference`. Xcode silently ignores an anchored reference (`baseConfigurationReferenceAnchor`) whose path leaves the synchronized `Hugo` folder, which is why the files did nothing before this plan. If you set a build's base configuration again in Xcode, pick the file from the project's top level, not from inside the `Hugo` folder.
- `HUGO_ENV` now only feeds the Debug bundle ID suffix. It must not come back as a Swift compilation condition.
- Reviewers: check the pbxproj diff is only the Preview removal, the rename, the two deleted lines, three new TestFlight blocks with list entries, and three xcconfig file references replacing the anchored ones; check that no `#if` in Swift names a build.
