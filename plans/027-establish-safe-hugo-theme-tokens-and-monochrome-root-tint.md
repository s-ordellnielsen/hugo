# Plan 027: Establish safe Hugo theme tokens and a monochrome root tint

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving on. If anything in the STOP conditions section occurs, stop and report it rather than improvising. When complete, update Plan 027 in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat f15e122..HEAD -- Hugo/App/Theme.swift Hugo/App/HugoApp.swift Hugo/Assets.xcassets/AccentColor.colorset Hugo.xcodeproj/project.pbxproj plans/README.md`
>
> If an in-scope file changed since this plan was written, compare it with the current-state excerpts below. Treat a material mismatch as a STOP condition.

## Status

* **Priority**: P1
* **Effort**: S
* **Risk**: MED
* **Depends on**: none
* **Category**: tech-debt
* **Planned at**: commit `f15e122`, August 10, 2026

## Why this matters

Hugo currently compiles an Orange `AccentColor` asset as its global accent, while several views manually force `.primary` tint. That makes the app’s color behavior non-centralized and allows Orange to leak into controls that do not inherit a local override. The new baseline must make inherited SwiftUI chrome black in Light Mode and white in Dark Mode, while exposing a deliberate opt-in System Teal token for the very small set of branded surfaces defined in later plans.

The initially proposed two-extension token pattern has an overload-resolution trap: defining `Color.hugoAccent` as `.hugoAccent` recurses into itself. Swift 6 emits an infinite-recursion warning, and evaluating it crashes. The token implementation must therefore delegate in the opposite direction.

## Current state

* `Hugo/App/HugoApp.swift` is the app composition root. Its current `WindowGroup` injects only the SwiftData model container:

    @main
    struct HugoApp: App {
        let modelContainer: ModelContainer

        var body: some Scene {
            WindowGroup { AppRootView() }.modelContainer(modelContainer)
        }
    }

* `Hugo/App/Theme.swift` does not exist. New app-wide presentation primitives belong in `Hugo/App`, not the discouraged catch-all `Hugo/Views` directory.
* `Hugo/Assets.xcassets/AccentColor.colorset/Contents.json` currently declares `systemOrangeColor`.
* `Hugo.xcodeproj/project.pbxproj` assigns `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;` in the Preview, Debug, and Release app configurations.
* The `Hugo` source directory is a `PBXFileSystemSynchronizedRootGroup`. A new Swift file placed in `Hugo/App` is automatically compiled by the app target; do not add a manual `PBXBuildFile` entry.
* Project conventions from `AGENTS.md` apply: Swift 6, complete strict concurrency, iOS 26+, SwiftUI-first, and no legacy state-management APIs.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | Exit 0 with no lint diagnostics |
| Unit tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoThemeDerivedData CODE_SIGNING_ALLOWED=NO` | Exit 0; all tests pass |
| Full verification | `DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' DERIVED_DATA=/tmp/HugoThemeVerifyDerivedData Scripts/verify.sh` | Exit 0; formatter, tests, and analyzer pass |
| Find stale accent references | `rg -n 'AccentColor' Hugo Hugo.xcodeproj Configuration` | No output; command exits 1 because no matches remain |

## Scope

**In scope**:

* Create `Hugo/App/Theme.swift`.
* Modify `Hugo/App/HugoApp.swift`.
* Remove `Hugo/Assets.xcassets/AccentColor.colorset/`.
* Remove the three app-target `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` assignments from `Hugo.xcodeproj/project.pbxproj`.
* Update the Plan 027 status row in `plans/README.md` when complete.

**Out of scope**:

* Any feature-level use of `.hugoAccent`; Plans 028 and 029 own those migrations.
* Any new SwiftData schema, migration stage, Tracker field, or category-color editor.
* Changes to app icon assets, app icon configuration, CloudKit configuration, or deployment targets.
* Typography, corner radii, and layout changes.

## Git workflow

* Create branch `advisor/027-theme-tokens` unless the operator supplies a branch.
* Make one logical commit after all Plan 027 verification gates pass. Match the repository’s recent imperative subject style, for example: `Establish Hugo theme tokens`.
* Do not push, create a pull request, or modify unrelated working-tree changes.

## Steps

### Step 1: Add the safe, native-dot-notation theme token API

Create `Hugo/App/Theme.swift`. Keep the file limited to the Hugo color token and documentation. Declare the concrete `Color` token first, then make the constrained `ShapeStyle` overload explicitly return `Color.hugoAccent`.

Use this exact semantic shape:

    import SwiftUI

    // MARK: - Hugo Theme Tokens

    extension Color {
        /// Hugo's signature opt-in accent color (currently System Teal).
        /// Enables: `.tint(.hugoAccent)`, `Color.hugoAccent`.
        static var hugoAccent: Color { .teal }
    }

    extension ShapeStyle where Self == Color {
        /// Hugo's signature opt-in accent color (currently System Teal).
        /// Enables: `.foregroundStyle(.hugoAccent)`, `.background(.hugoAccent)`.
        static var hugoAccent: Color { Color.hugoAccent }
    }

Do not write `static var hugoAccent: Color { .hugoAccent }` inside `extension Color`; that expression resolves to the same property and infinitely recurses. Do not add an asset color, hex literal, or custom `UIColor` bridge.

**Verify**: `xcrun swift-format lint --strict Hugo/App/Theme.swift` → exit 0 with no diagnostics.

### Step 2: Install the inherited monochrome tint at the composition root

Rewrite the `WindowGroup` body in `Hugo/App/HugoApp.swift` into multiline modifier form. Apply `.tint(.primary)` directly to `AppRootView()` before or after the model-container modifier, while preserving the existing `modelContainer` injection.

The resulting hierarchy must be equivalent to:

    WindowGroup {
        AppRootView()
            .tint(.primary)
            .modelContainer(modelContainer)
    }

This is the only global tint authority. Later plans remove redundant feature-level `.tint(.primary)` modifiers rather than adding new local baseline overrides.

**Verify**: `rg -n -C 2 '\.tint\(\.primary\)' Hugo/App/HugoApp.swift` → one result within the `WindowGroup` content.

### Step 3: Remove the stale Orange global-accent fallback

Delete `Hugo/Assets.xcassets/AccentColor.colorset/` entirely. Then remove only the three `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;` assignments from the app target’s Preview, Debug, and Release build configurations in `Hugo.xcodeproj/project.pbxproj`.

Do not alter `ASSETCATALOG_COMPILER_APPICON_NAME`, `AppIcon`, `AppIconDev`, filesystem-synchronized group configuration, or any unrelated build setting. Hugo now gets its visual tint explicitly from `HugoApp`, so retaining a differently colored compiled fallback would undermine the monochrome contract.

**Verify**: `if rg -n 'AccentColor' Hugo Hugo.xcodeproj Configuration; then exit 1; fi` → exit 0 and no matching output.

### Step 4: Verify inherited tint behavior manually

Run the app on the designated simulator in both Light and Dark appearances. Visit Overview, Year, Settings, Add Entry, Category Picker, and Onboarding.

Confirm all of the following:

* Untokenized navigation, selection, and standard control chrome is black in Light Mode and white in Dark Mode.
* No Orange accent appears in any standard app control.
* Tabs, sheets, and nested navigation stacks inherit the root tint.
* There is no runtime recursion or crash when a later compiled use resolves `.hugoAccent`.

**Verify**: `DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' DERIVED_DATA=/tmp/HugoThemeVerifyDerivedData Scripts/verify.sh` → exit 0.

## Test plan

No unit test should be added solely to compare `SwiftUI.Color` values; `Color` rendering is environment-dependent and the critical regression here is compile-time overload resolution plus app composition. The app target compilation exercises the public token API, and later plans compile its three intended forms: `Color.hugoAccent`, `.foregroundStyle(.hugoAccent)`, and `.tint(.hugoAccent)`.

* Run the full test suite to protect model-container startup and existing feature behavior.
* Perform the manual Light/Dark smoke test in Step 4 because root tint propagation is a visual environment behavior.

## Done criteria

* [ ] `Hugo/App/Theme.swift` defines a nonrecursive `Color.hugoAccent` returning `.teal` and a constrained `ShapeStyle` overload returning `Color.hugoAccent`.
* [ ] `Hugo/App/HugoApp.swift` applies `.tint(.primary)` directly below `AppRootView()`.
* [ ] `AccentColor.colorset` and all three global-accent build-setting assignments are absent.
* [ ] `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0.
* [ ] The designated `xcodebuild test` command exits 0.
* [ ] `Scripts/verify.sh` exits 0.
* [ ] No files outside the in-scope list are modified, except the required `plans/README.md` status update.

## STOP conditions

Stop and report rather than improvising if:

* `Hugo/App/HugoApp.swift` no longer has the shown `WindowGroup` composition or the app root moved to another file.
* Adding the corrected token triggers an infinite-recursion warning, ambiguity error, or a crash when `Color.hugoAccent` is evaluated.
* Removing the accent asset causes an Xcode asset-compilation failure or reveals another target that depends on the named asset.
* The visual smoke test reveals a system control that does not inherit `.tint(.primary)` and requires UIKit appearance-proxy changes.
* A required fix appears to need a SwiftData migration or a file outside the declared scope.

## Maintenance notes

* Change only `Color.hugoAccent` when the brand color changes in the future; all planned branded surfaces use this token instead of raw `.teal`.
* Treat `.primary` root tint as default chrome, not as a substitute for intentional semantic or data color.
* Any new asset accent must have a documented purpose. Do not silently reintroduce a global colored fallback.
