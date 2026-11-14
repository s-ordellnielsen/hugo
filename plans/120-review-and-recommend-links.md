# Plan 120: Add Write a Review and Recommend Hugo to Settings in the App Store build

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat d2d87d5..HEAD -- Hugo/Features/Settings/Screens/SettingsView.swift Hugo/Info.plist Configuration/Production.xcconfig README.md Hugo/Resources/Localizable.xcstrings`
> Expected: no output. Otherwise compare the excerpts below with the live
> files. A mismatch is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S + owner (the owner checks the rows in a Production build)
- **Risk**: LOW. Two rows behind a compile-time flag that only the App Store build turns on.
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `d2d87d5`, 2026-11-14
- **Issue**: [SLN-50](https://linear.app/sebastianln/issue/SLN-50), [SLN-51](https://linear.app/sebastianln/issue/SLN-51)

## Why this matters

Once Hugo is on the App Store, reviews and word of mouth are how other publishers find it. Settings has no way to leave a review or share the app. This plan adds two rows in one section: **Write a Review**, which opens the App Store's review page for Hugo, and **Recommend Hugo**, which opens the share sheet with a short message and the App Store link.

Owner decisions (2026-11-14):
- Hugo's Apple ID in App Store Connect is **6754619142**.
- The rows appear **only in the Production (App Store) build**. Before launch the App Store page isn't public, so the links would lead nowhere for testers. TestFlight keeps its existing Share TestFlight row.
- No automatic review prompt (`requestReview`): the issue warns against prompting at the wrong moment, and a tap in Settings is the user's own choice.

## Current state

Build-specific behavior uses compile-time flags, never the build's name (`AGENTS.md` section 8): "Check a flag with `#if SHOW_DEBUG_MENU`; never write `#if PRODUCTION`… A new flag goes in each file where it is on, and in the README table."

`Configuration/Production.xcconfig:17`:

```
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) SHOW_JOIN_BETA
```

`README.md:48-52`:

```markdown
| Flag | Debug | TestFlight | Production |
|---|---|---|---|
| `SHOW_DEBUG_MENU` | on | on | off |
| `SHOW_SHARE_TESTFLIGHT` | on | on | off |
| `SHOW_JOIN_BETA` | off | off | on |
```

`Hugo/Info.plist:7-10` (the TestFlight link is configured the same way the App Store ID will be):

```xml
	<key>SupportEmail</key>
	<string>$(SUPPORT_EMAIL)</string>
	<key>TestFlightURL</key>
	<string>https://testflight.apple.com/join/AdmsjW16</string>
```

`Hugo/Features/Settings/Screens/SettingsView.swift:30-39` reads it:

```swift
    private static var testFlightURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TestFlightURL") as? String,
            let url = URL(string: value),
            url.scheme == "https",
            !value.contains("REPLACE_WITH_INVITE_CODE")
        else {
            return nil
        }
        return url
    }
```

and lines 85-97 show the flag-guarded section pattern to copy, followed by Contact Us:

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

                if let supportEmailURL = Self.supportEmailURL {
```

Pure value logic goes in the feature's `Domain` folder, `nonisolated`. The exemplar is `Hugo/Features/Settings/Domain/SupportEmailLink.swift`, tested in `HugoTests/Features/Settings/Domain/SupportEmailLinkTests.swift`. Match their style.

Strings live in `Hugo/Resources/Localizable.xcstrings` (JSON, two-space indentation, keys in sorted position, both `en` and `da` with `"state" : "translated"`). Copy the shape of `settings.account.shareTestFlight`:

```json
    "settings.account.shareTestFlight" : {
      "comment" : "A button that lets users share the Hugo TestFlight invitation link.",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Del TestFlight"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Share TestFlight"
          }
        }
      }
    },
```

App Store URL formats: product page `https://apps.apple.com/app/id<ID>`; review page `https://apps.apple.com/app/id<ID>?action=write-review`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `xcrun swift-format lint --strict <changed Swift files>` | exit 0, no output |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |
| Plist | `plutil -lint Hugo/Info.plist` | `Hugo/Info.plist: OK` |
| Full gate | `Scripts/verify.sh > /tmp/verify120.log 2>&1; echo "exit $?"` | `exit 0` (about 5 minutes; 600000 ms timeout) |

## Scope

**In scope**:
- `Hugo/Features/Settings/Domain/AppStoreLinks.swift` (create)
- `HugoTests/Features/Settings/Domain/AppStoreLinksTests.swift` (create)
- `Hugo/Features/Settings/Screens/SettingsView.swift`
- `Hugo/Info.plist` (one key)
- `Configuration/Production.xcconfig` (one flag)
- `README.md` (one table row)
- `Hugo/Resources/Localizable.xcstrings` (four new keys)

**Out of scope**:
- `Configuration/Debug.xcconfig` and `Configuration/TestFlight.xcconfig`. The flag stays off there.
- The Share TestFlight and Join the Beta rows.
- Any `StoreKit` review prompt.
- `Hugo.xcodeproj` and `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (uncommitted change by the owner; never stage, commit, revert or stash it).

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage `plans/`, `.claude/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage files by explicit path.
- One commit: `feat: add Write a Review and Recommend Hugo to Settings in the App Store build`

## Steps

### Step 1: Add the URL builder and its tests

Create `Hugo/Features/Settings/Domain/AppStoreLinks.swift`:

```swift
import Foundation

/// The App Store links for Hugo, built from its Apple ID in App Store Connect
/// (the `AppStoreID` key in Info.plist).
nonisolated struct AppStoreLinks: Equatable {
    /// Hugo's page on the App Store, for sharing.
    let productURL: URL
    /// The App Store page that opens the review form directly.
    let reviewURL: URL

    /// Returns nil unless `appleID` is a non-empty string of digits.
    init?(appleID: String?) {
        guard let appleID, !appleID.isEmpty, appleID.allSatisfy(\.isASCII), appleID.allSatisfy(\.isNumber),
            let productURL = URL(string: "https://apps.apple.com/app/id\(appleID)"),
            let reviewURL = URL(string: "https://apps.apple.com/app/id\(appleID)?action=write-review")
        else {
            return nil
        }
        self.productURL = productURL
        self.reviewURL = reviewURL
    }
}
```

Create `HugoTests/Features/Settings/Domain/AppStoreLinksTests.swift`:

```swift
import Foundation
import Testing

@testable import Hugo

struct AppStoreLinksTests {
    @Test
    func buildsTheProductAndReviewPages() throws {
        let links = try #require(AppStoreLinks(appleID: "6754619142"))

        #expect(links.productURL.absoluteString == "https://apps.apple.com/app/id6754619142")
        #expect(links.reviewURL.absoluteString == "https://apps.apple.com/app/id6754619142?action=write-review")
    }

    @Test(arguments: [nil, "", "abc", "675 4619142", "$(APP_STORE_ID)"] as [String?])
    func rejectsMissingOrMalformedIDs(appleID: String?) {
        #expect(AppStoreLinks(appleID: appleID) == nil)
    }
}
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Settings/Domain/AppStoreLinks.swift HugoTests/Features/Settings/Domain/AppStoreLinksTests.swift` → exit 0.

### Step 2: Add the Apple ID and the flag

1. In `Hugo/Info.plist`, add directly before `<key>SupportEmail</key>`:

```xml
	<key>AppStoreID</key>
	<string>6754619142</string>
```

2. In `Configuration/Production.xcconfig`, line 17 becomes:

```
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) SHOW_JOIN_BETA SHOW_APP_STORE_LINKS
```

3. In `README.md`, add a row after the `SHOW_JOIN_BETA` row:

```markdown
| `SHOW_APP_STORE_LINKS` | off | off | on |
```

**Verify**:
- `plutil -lint Hugo/Info.plist` → `Hugo/Info.plist: OK`
- `grep -c SHOW_APP_STORE_LINKS Configuration/Production.xcconfig README.md` → `Configuration/Production.xcconfig:1` and `README.md:1`
- `grep -c SHOW_APP_STORE_LINKS Configuration/Debug.xcconfig Configuration/TestFlight.xcconfig` → `0` for both

### Step 3: Add the strings

Add four keys to `Hugo/Resources/Localizable.xcstrings`, each in its sorted position, with the shape shown above:

| Key | English | Danish | Comment |
|---|---|---|---|
| `settings.appStore.footer` | Do you like Hugo? A review on the App Store helps other publishers find it. | Kan du lide Hugo? En anmeldelse i App Store hjælper andre forkyndere med at finde appen. | Footer under the Write a Review and Recommend Hugo rows in Settings. |
| `settings.appStore.recommend` | Recommend Hugo | Anbefal Hugo | A button that opens the share sheet with a link to Hugo on the App Store. |
| `settings.appStore.recommend.message` | I use Hugo to keep track of my ministry time and send my monthly report. | Jeg bruger Hugo til at holde styr på min tjenestetid og sende min månedsrapport. | Message shared together with the App Store link when the user recommends Hugo. |
| `settings.appStore.review` | Write a Review | Skriv en anmeldelse | A button that opens Hugo's review page on the App Store. |

**Verify**: `python3 -I -c "import json;d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print(sorted(k for k in d if k.startswith('settings.appStore')))"` → `['settings.appStore.footer', 'settings.appStore.recommend', 'settings.appStore.recommend.message', 'settings.appStore.review']`.

### Step 4: Add the rows to Settings

In `SettingsView.swift`:

1. After the `testFlightURL` property (after line 39), add:

```swift

    private static var appStoreLinks: AppStoreLinks? {
        AppStoreLinks(appleID: Bundle.main.object(forInfoDictionaryKey: "AppStoreID") as? String)
    }
```

2. Directly after the `#if SHOW_JOIN_BETA … #endif` block and before `if let supportEmailURL = Self.supportEmailURL {`, add:

```swift

                #if SHOW_APP_STORE_LINKS
                    if let appStoreLinks = Self.appStoreLinks {
                        Section {
                            Link(destination: appStoreLinks.reviewURL) {
                                Label("settings.appStore.review", systemImage: "star")
                            }
                            ShareLink(
                                item: appStoreLinks.productURL,
                                message: Text("settings.appStore.recommend.message")
                            ) {
                                Label("settings.appStore.recommend", systemImage: "square.and.arrow.up")
                            }
                        } footer: {
                            Text("settings.appStore.footer")
                        }
                    }
                #endif
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Settings/Screens/SettingsView.swift` → exit 0. `grep -c "SHOW_APP_STORE_LINKS" Hugo/Features/Settings/Screens/SettingsView.swift` → `1`.

### Step 5: Check that the Production build compiles the rows

The gate builds Debug only, where the flag is off. Compile the Production configuration once so the new code is type-checked:

```sh
xcodebuild build -project Hugo.xcodeproj -scheme Production -configuration Production \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/hugo-120-production \
    CODE_SIGNING_ALLOWED=NO > /tmp/build120-production.log 2>&1; echo "exit $?"
```

**Verify**: `exit 0` and `grep -c "BUILD SUCCEEDED" /tmp/build120-production.log` → `1`. If the scheme or configuration names differ, run `xcodebuild -list -project Hugo.xcodeproj` and report. Don't guess.

### Step 6: Run the gate and commit

**Verify**: `Scripts/verify.sh > /tmp/verify120.log 2>&1; echo "exit $?"` → `exit 0`, and `grep -E "AppStoreLinksTests|buildsTheProductAndReviewPages" /tmp/verify120.log` shows passes.

Commit the seven in-scope files by path.

## Test plan

- New: `AppStoreLinksTests`: the two URLs for the real ID, and nil for nil, empty, letters, a space and an unexpanded build variable.
- The rows themselves are behind a flag that only Production sets. Step 5 compiles them, and the owner looks at them.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with `AppStoreLinksTests` passing
- [ ] The Production build in Step 5 succeeds
- [ ] `SHOW_APP_STORE_LINKS` appears in `Production.xcconfig` and the README table, and not in `Debug.xcconfig` or `TestFlight.xcconfig`
- [ ] `git show --stat HEAD` lists exactly the seven in-scope files

## STOP conditions

- The drift check shows changes and the excerpts don't match.
- `git status --short` shows `Hugo/Resources/Localizable.xcstrings` as modified before you start. Your commit would then include someone else's change.
- The Production build fails for a reason outside the lines this plan adds.
- `Scripts/verify.sh` fails twice. Report the failing test names.

## Owner check

Run the `Production` scheme on a simulator. Settings shows a section with Write a Review and Recommend Hugo, plus the footer, in English and Danish. Recommend Hugo opens the share sheet with the message and the link. The links themselves only work once Hugo is live on the App Store. Check them again then. Debug and TestFlight builds don't show the section.

## Maintenance notes

- After launch, Share TestFlight (TestFlight builds) and Recommend Hugo (Production) sit in different builds on purpose. Don't turn both on in one build.
- If Hugo ever needs a second App Store ID (a separate app record), change `AppStoreID` in `Info.plist`. Nothing else holds the number.
