# Plan 106: Add short Terms of Use that point to Apple's standard EULA

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 3055ae6..HEAD -- Hugo/Features/Settings/Screens/SettingsView.swift Hugo/Resources/Markdown Hugo/Resources/Localizable.xcstrings HugoTests/Resources`
> Plans 102 and 105 run before this one and are **expected** to change these
> paths. Before you start, confirm that plan 105 has landed: the `LegalPage`
> enum, the `settings.legal.privacyPolicy` row and
> `HugoTests/Resources/BundledMarkdownTests.swift` all exist (Step 0). If they
> don't, STOP.

## Status

- **Priority**: P2 (part of the App Store launch work; App Review doesn't require it, because Hugo has no subscriptions)
- **Effort**: S + owner (review the text, publish it)
- **Risk**: LOW. Two Markdown files, one Settings row, one test change.
- **Depends on**: plan 105 (adds the legal section, `LegalPage` and the bundle test this plan extends)
- **Category**: docs
- **Planned at**: commit `3055ae6`, 2026-11-13
- **Issue**: [SLN-52](https://linear.app/sebastianln/issue/SLN-52)

## Why this matters

Hugo is free and has no accounts, purchases or server, so it doesn't need full custom terms. Apple's standard Licensed Application EULA already covers the license, the missing warranty and the limit on liability, and it applies to every App Store app that doesn't upload its own. Two things are missing from it that matter for Hugo: Hugo is not an official app of Jehovah's Witnesses or JW.org, and the user is responsible for the report they send. The owner decided (2026-11-13) on a short Terms page, shown in the app and published at `https://hugo.ordellnielsen.com/terms`, that points to Apple's EULA and adds those two notes.

## Current state

After plan 105, `Hugo/Features/Settings/Screens/SettingsView.swift` has:

```swift
    /// A bundled Markdown page that the legal section opens in a sheet. The
    /// raw value is the resource name under `Hugo/Resources/Markdown/Legal`.
    private enum LegalPage: String, Identifiable {
        case privacyPolicy = "PrivacyPolicy"

        var id: String { rawValue }
    }

    @State private var legalPage: LegalPage?
```

a section right after the support email section:

```swift
                Section {
                    Button {
                        legalPage = .privacyPolicy
                    } label: {
                        Label("settings.legal.privacyPolicy", systemImage: "hand.raised")
                    }
                }
```

and on the `List`:

```swift
            .sheet(item: $legalPage) { page in
                HelpView(for: page.rawValue)
            }
```

`HelpView` (`Hugo/Features/Help/Screens/HelpView.swift`) loads `<name>.md` from the app bundle in the user's language and renders it with MarkdownUI. Localized Markdown lives in `Base.lproj` (English) and `da.lproj` (Danish) folders. Plan 105 created `Hugo/Resources/Markdown/Legal/Base.lproj/PrivacyPolicy.md` and `.../da.lproj/PrivacyPolicy.md`. If plan 105 had to use its fallback, they are in `Hugo/Resources/Markdown/Help/<lproj>/` instead. Put the new files next to wherever `PrivacyPolicy.md` actually is.

`HugoTests/Resources/BundledMarkdownTests.swift` (from plan 105) has:

```swift
    @Test(arguments: ["RoundingRule", "PrivacyPolicy"])
    func pageShipsInEnglishAndDanish(name: String) throws {
```

and a `privacyPolicyNamesItsPublishedCopy` test.

`Hugo/Resources/Localizable.xcstrings` is a JSON catalog with keys in alphabetical order. Plan 105 added `"settings.legal.privacyPolicy"` ("Privacy Policy" / "Privatlivspolitik") with this shape:

```json
    "settings.legal.privacyPolicy" : {
      "comment" : "A Settings button that opens Hugo's privacy policy in a sheet.",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Privatlivspolitik"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Privacy Policy"
          }
        }
      }
    },
```

The legal Markdown must contain no images. MarkdownUI loads images over the network, and the policy promises that Hugo makes no requests.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Catalog is valid JSON | `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Full gate (lint, layout, tests, analyze) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

## Scope

**In scope**:

- `Hugo/Resources/Markdown/Legal/Base.lproj/TermsOfUse.md` (create)
- `Hugo/Resources/Markdown/Legal/da.lproj/TermsOfUse.md` (create)
- `Hugo/Features/Settings/Screens/SettingsView.swift` (one enum case, one row)
- `Hugo/Resources/Localizable.xcstrings` (one new key)
- `HugoTests/Resources/BundledMarkdownTests.swift`

**Out of scope**:

- The privacy policy files and their text (plan 105).
- `HelpView.swift`, `PrivacyInfo.xcprivacy`, `Info.plist` and `project.pbxproj`.
- A custom EULA in App Store Connect. Hugo keeps Apple's standard one.
- `.claude/`, `plans/` (except this plan's row in the README) and the owner's `Changelog/` changes. Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage files by path.
- One commit after `Scripts/verify.sh` exits 0: `feat: add terms of use that point to Apple's standard EULA`.

## Steps

### Step 0: Confirm plan 105 has landed

Run:

```sh
grep -n "enum LegalPage\|settings.legal.privacyPolicy" Hugo/Features/Settings/Screens/SettingsView.swift
find Hugo/Resources/Markdown -name PrivacyPolicy.md
ls HugoTests/Resources/BundledMarkdownTests.swift
```

**Verify**: the grep shows both lines, `find` lists two files (Base and da), and `ls` finds the test file. Otherwise STOP.

### Step 1: Add the English terms

Create `TermsOfUse.md` in the same `Base.lproj` folder as `PrivacyPolicy.md`, with exactly this content (the outer fence is not part of the file):

````markdown
# Terms of Use

Last updated: November 13, 2026

## Your license

Hugo is licensed to you under Apple's standard Licensed Application End User License Agreement (EULA). It sets out how you may use the app. You can read it at https://www.apple.com/legal/internet-services/itunes/dev/stdeula/.

Two more points apply to Hugo:

## Hugo is an independent app

Hugo is made by an independent developer. It isn't an official app of Jehovah's Witnesses or JW.org, and they don't endorse it.

## You're responsible for your report

Hugo helps you count your time and prepare your monthly report, but you send the report yourself. Check your hours and Bible studies before you send it.

## Privacy

The Privacy Policy explains how Hugo handles your information. You can find it in Hugo's Settings and at https://hugo.ordellnielsen.com/privacy.

## Contact

If you have questions about these terms, email us at [app@ordellnielsen.com](mailto:app@ordellnielsen.com).
````

**Verify**: `head -1` of the new file prints `# Terms of Use`, and `grep -c "!\["` on it prints `0`.

### Step 2: Add the Danish terms

Create `TermsOfUse.md` in the matching `da.lproj` folder:

````markdown
# Brugsvilkår

Senest opdateret: 13. november 2026

## Din licens

Hugo er licenseret til dig under Apples standardlicensaftale for slutbrugere (Licensed Application End User License Agreement, EULA). Den beskriver, hvordan du må bruge appen. Du kan læse den på engelsk på https://www.apple.com/legal/internet-services/itunes/dev/stdeula/.

Derudover gælder to ting for Hugo:

## Hugo er en selvstændig app

Hugo er lavet af en selvstændig udvikler. Appen er ikke en officiel app fra Jehovas Vidner eller JW.org, og den er ikke godkendt af dem.

## Du har selv ansvaret for din rapport

Hugo hjælper dig med at tælle din tid og gøre din månedlige rapport klar, men du sender selv rapporten. Tjek dine timer og bibelstudier, før du sender den.

## Privatliv

Privatlivspolitikken forklarer, hvordan Hugo håndterer dine oplysninger. Du finder den under Indstillinger i Hugo og på https://hugo.ordellnielsen.com/privacy.

## Kontakt

Har du spørgsmål til vilkårene, så skriv til os på [app@ordellnielsen.com](mailto:app@ordellnielsen.com).
````

**Verify**: `head -1` prints `# Brugsvilkår`, and `grep -c "!\["` prints `0`.

### Step 3: Add the Settings string

In `Hugo/Resources/Localizable.xcstrings`, insert directly after the `"settings.legal.privacyPolicy"` entry (alphabetical order):

```json
    "settings.legal.termsOfUse" : {
      "comment" : "A Settings button that opens Hugo's terms of use in a sheet.",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Brugsvilkår"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Terms of Use"
          }
        }
      }
    },
```

**Verify**: the JSON check exits 0, and `grep -c '"settings.legal.termsOfUse"' Hugo/Resources/Localizable.xcstrings` prints `1`.

### Step 4: Add the row

In `SettingsView.swift`:

1. Add a case to `LegalPage`, below `privacyPolicy`:

```swift
        case termsOfUse = "TermsOfUse"
```

2. In the legal section, below the Privacy Policy button and inside the same `Section`, add:

```swift
                    Button {
                        legalPage = .termsOfUse
                    } label: {
                        Label("settings.legal.termsOfUse", systemImage: "doc.plaintext")
                    }
```

Also update the doc comment on `LegalPage` if it names only the privacy policy. The `.sheet(item:)` modifier needs no change.

**Verify**: `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0, and `grep -n "settings.legal" Hugo/Features/Settings/Screens/SettingsView.swift` shows the privacy row before the terms row.

### Step 5: Extend the bundle test

In `HugoTests/Resources/BundledMarkdownTests.swift`:

1. Change the arguments of `pageShipsInEnglishAndDanish` to `["RoundingRule", "PrivacyPolicy", "TermsOfUse"]`.
2. Add:

```swift
    @Test(arguments: ["Base", "da"])
    func termsPointToAppleEULAAndThePrivacyPolicy(localization: String) throws {
        let url = try #require(
            Bundle.main.url(
                forResource: "TermsOfUse", withExtension: "md", subdirectory: nil,
                localization: localization))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"))
        #expect(text.contains("https://hugo.ordellnielsen.com/privacy"))
        #expect(text.contains("JW.org"))
    }
```

**Verify**: `Scripts/verify.sh` exits 0, with `pageShipsInEnglishAndDanish` now running 3 arguments and the new test running 2.

### Step 6: Commit

**Verify**: `git diff --check` exits 0, and `git status --short` shows only in-scope files (plus the owner's untouched `Changelog/` changes, which you must not stage). Commit.

## Test plan

- `pageShipsInEnglishAndDanish` gains `TermsOfUse`: both languages exist, start with a title and load no images.
- The new `termsPointToAppleEULAAndThePrivacyPolicy` checks that both languages link Apple's EULA and the privacy policy and include the non-affiliation note.
- The row is a plain button into an existing view, so it gets no unit test. The owner checks it on a device.

## Done criteria

- [ ] Both `TermsOfUse.md` files exist next to `PrivacyPolicy.md`, with first lines `# Terms of Use` and `# Brugsvilkår`
- [ ] `grep -c '"settings.legal.termsOfUse"' Hugo/Resources/Localizable.xcstrings` prints `1`
- [ ] `grep -n "case termsOfUse" Hugo/Features/Settings/Screens/SettingsView.swift` has one match
- [ ] `Scripts/verify.sh` exits 0, including the new and extended tests
- [ ] `git show --stat HEAD` lists only the in-scope files
- [ ] `plans/README.md` row for 106 updated

## STOP conditions

- Step 0 fails: plan 105 has not landed.
- The legal section or `LegalPage` looks different from the excerpts in a way that would need more than adding a case and a row.
- A step's verification fails twice after one reasonable fix.

## Maintenance notes

**Owner checks:**

1. Read both texts and set "Last updated" to the date you publish, in both files and on the web.
2. Publish the English text at `https://hugo.ordellnielsen.com/terms`, copied from the bundled file. The website stays English only for now (owner decision, 2026-11-13); the Danish text ships in the app only.
3. In App Store Connect, leave the License Agreement on Apple's standard EULA. Don't upload a custom one. Hugo has no subscriptions, so no Terms link is required in the metadata. You may still add the terms URL to the description if you want.
4. On a device, open Settings > Terms of Use in English and Danish. The Apple link opens in Safari, the email link opens Mail, and the close button works.

**Future changes:**

- If Hugo ever adds a subscription or other in-app purchase, App Review requires a functional link to the Terms of Use (EULA) in the app and in the App Store metadata. Revisit these terms then.
- If the owner later uploads a custom EULA in App Store Connect, the "Your license" section must point to it instead of Apple's standard EULA.
