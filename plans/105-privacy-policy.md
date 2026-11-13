# Plan 105: Add a Privacy Policy in English and Danish, shown in the app and published on the web

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 3055ae6..HEAD -- Hugo/Features/Settings/Screens/SettingsView.swift Hugo/Features/Help/Screens/HelpView.swift Hugo/Resources/Markdown Hugo/Resources/Localizable.xcstrings`
> Plan 102 runs before this plan and is **expected** to change
> `SettingsView.swift` and `Localizable.xcstrings` (see "Current state"). Any
> other change to these paths, or a `SettingsView.swift` that no longer has the
> support email section, is a STOP condition.

## Status

- **Priority**: P1 (App Store launch blocker: App Store Connect requires a privacy policy URL)
- **Effort**: S + owner (review the text, publish it, enter the URL in App Store Connect)
- **Risk**: LOW. Two new Markdown files, one Settings row, one test. No data or logic changes.
- **Depends on**: plan 102 (edits the same Settings screen first); plan 104 (the manifest and this policy must say the same thing)
- **Category**: docs
- **Planned at**: commit `3055ae6`, 2026-11-13
- **Issue**: [SLN-53](https://linear.app/sebastianln/issue/SLN-53)

## Why this matters

Every App Store app needs a public privacy policy URL, and Hugo has none. Hugo's users range from about 13 to 70 years old and many are not technical, so the policy has to be short and plain, and readable inside the app without a browser. The owner decided (2026-11-13) on a hybrid: the policy is written as Markdown in the project in English and Danish, the app shows it natively, and the owner publishes the same text at `https://hugo.ordellnielsen.com/privacy`, which is also the URL for App Store Connect. The bundled Markdown files are the single source of truth. The website copy is pasted from them.

## Current state

### The Markdown viewer to reuse

`Hugo/Features/Help/Screens/HelpView.swift` already does what this plan needs: it loads a localized `.md` file from the app bundle by name and renders it with MarkdownUI in a sheet with a close button. Its public surface:

```swift
struct HelpView: View {
    // ...
    init(
        for resourceName: String,
        bundle: Bundle = .main
    ) {
```

It finds the file with `bundle.url(forResource: resourceName, withExtension: "md")` and shows a "Unavailable" `ContentUnavailableView` when the file is missing. It wraps its content in its own `NavigationStack`, so present it as a **sheet**, never push it. Existing use, `Hugo/Features/Settings/Screens/ReportSettingsView.swift:54`:

```swift
        .sheet(isPresented: $showingHelp) { HelpView(for: "RoundingRule") }
```

Reuse `HelpView` unchanged. Do not write a second Markdown viewer and do not move `HelpView` into `DesignSystem`.

### How bundled Markdown is localized

```
Hugo/Resources/Markdown/Help/Base.lproj/RoundingRule.md   ← English (development region is `en`)
Hugo/Resources/Markdown/Help/da.lproj/RoundingRule.md     ← Danish
```

`Hugo/` is a file-system-synchronized group, so any file placed under `Hugo/Resources/` is part of the app target automatically. Do not edit `Hugo.xcodeproj/project.pbxproj`. Xcode copies `*.lproj` folders into the bundle root, so `Bundle.main.url(forResource: "RoundingRule", withExtension: "md")` picks the right language. Each file starts with a `# ` title line.

This plan adds a sibling folder `Hugo/Resources/Markdown/Legal/` with the same `Base.lproj` / `da.lproj` layout. `Scripts/check-layout.sh` does not check folders under `Hugo/Resources`. AGENTS.md section 7 says `Resources` holds "string catalogs, help Markdown and app icons", and a legal page is the same kind of file.

### The Settings screen

`Hugo/Features/Settings/Screens/SettingsView.swift` at `3055ae6`, the part around the support email (lines 66-95):

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
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
```

**Plan 102 changes this file before you start.** Expect:

- the Share TestFlight section wrapped in `#if SHOW_SHARE_TESTFLIGHT ... #endif`;
- a new "Join the Beta" section wrapped in `#if SHOW_JOIN_BETA ... #endif`;
- the debug section wrapped in `#if SHOW_DEBUG_MENU ... #endif`;
- `supportEmailURL` now adding a subject with the app version and build number.

The support email section itself (`if let supportEmailURL = Self.supportEmailURL { Section { Button { openURL(supportEmailURL) } label: { Label("settings.contact.email", ...) } } }`) stays. You add the new section **right after the closing brace of that `if let supportEmailURL` block**, and before the debug section and its `#if SHOW_DEBUG_MENU` line. Find it with `grep -n "settings.contact.email" Hugo/Features/Settings/Screens/SettingsView.swift`.

The Settings rows use `Label` inside a `Button` or `NavigationLink`, and take the root monochrome tint. Match that.

### Strings

`Hugo/Resources/Localizable.xcstrings` is a JSON string catalog with keys in alphabetical order. Key style is dotted lower camel case, for example `settings.contact.email` ("Contact Us" / "Kontakt os"). Danish uses "os" for the developer. An existing entry, for the shape to copy:

```json
    "settings.contact.email" : {
      "comment" : "A button that opens a new email draft addressed to the developer for feedback.",
      "localizations" : {
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Kontakt os"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Contact Us"
          }
        }
      }
    },
```

The new key `settings.legal.privacyPolicy` goes between `"settings.group.settings.report"` and `"settings.report.greeting"`. If plan 102 added keys near there, keep the alphabetical order.

### Facts the policy text relies on (checked by the advisor at `3055ae6`)

- Synced data (SwiftData + CloudKit private database `iCloud.com.ordellnielsen.Hugo`, schema V13): entries (date, duration, Bible studies, category), categories (name, icon, color, type), plans (date, duration, start time, category), submitted reports (month, totals, reporting lines). Entries have no free-text notes field.
- Local only (UserDefaults, `Hugo/Domain/UserDefaultsKeys.swift`): publisher status, goal pacing, Planner target, duration step, overseer full name, first and last name, phone number, greeting template, list style. These do not sync today.
- Overseer: `CNContactPickerViewController` (`Hugo/Features/Reports/Views/OverseerPicker.swift`). The app receives only the picked contact and keeps its name and first phone number.
- Sending a report: `MFMessageComposeViewController` (Messages). When Messages is unavailable, the report text is copied (`copyReport` in `Hugo/Features/Reports/Screens/SubmitReportView.swift`).
- No server, analytics, ads, tracking or accounts. The only network library is `NetworkImage` (inside MarkdownUI), which loads images that Markdown references. **The legal Markdown must contain no images**, so the app makes no network request when showing it.
- Support email: `app@ordellnielsen.com` (`SUPPORT_EMAIL` build setting).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Catalog is valid JSON | `python3 -c "import json; json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Full gate (lint, layout, tests, analyze) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

`Scripts/verify.sh` runs the tests serially on the iPhone 17 Pro simulator (iOS 26.5). Use it as the test command. It takes several minutes.

## Scope

**In scope**:

- `Hugo/Resources/Markdown/Legal/Base.lproj/PrivacyPolicy.md` (create)
- `Hugo/Resources/Markdown/Legal/da.lproj/PrivacyPolicy.md` (create)
- `Hugo/Features/Settings/Screens/SettingsView.swift`
- `Hugo/Resources/Localizable.xcstrings` (one new key)
- `HugoTests/Resources/BundledMarkdownTests.swift` (create)

**Out of scope**:

- `HelpView.swift`. Reuse it as it is.
- Terms of Use. Plan 106 adds them to the same section afterwards.
- `PrivacyInfo.xcprivacy` (plan 104), `Hugo/Info.plist`, entitlements and `project.pbxproj`.
- Any website code. The owner publishes the page.
- The Share TestFlight, Join the Beta and debug sections that plan 102 owns. Don't move or change them.
- `.claude/`, `plans/` (except this plan's row in the README) and the owner's `Changelog/` changes. Never stage them.

## Git workflow

- Work on `main`. No branch, no worktree, no push. Stage files by path.
- One commit after `Scripts/verify.sh` exits 0: `feat: add the privacy policy in English and Danish`.

## Steps

### Step 1: Add the English policy

Create `Hugo/Resources/Markdown/Legal/Base.lproj/PrivacyPolicy.md` with exactly this content (the outer four-backtick fence is not part of the file):

````markdown
# Privacy Policy

Last updated: November 13, 2026

Hugo helps you keep track of your ministry time and send your monthly report. This policy explains what happens to the information you put into Hugo.

In short: Hugo doesn't collect anything about you. What you enter stays on your devices and in your own iCloud, and we can't see it.

## Who we are

Hugo is made by Sebastian Ordell Nielsen, an independent developer. In this policy, "we" means the developer of Hugo.

## What we collect

Nothing. Hugo has no accounts, no server, no analytics, no ads and no tracking. We never receive your time, your reports or anything else you enter.

## What Hugo stores, and where

Hugo stores what you enter in the app:

- your entries: date, time spent, category and Bible studies
- your categories, plans and submitted reports
- your settings, such as your publisher status, your goals and your group overseer's name and phone number

All of it is stored on your device.

If you're signed in to iCloud and iCloud is turned on for Hugo, your entries, categories, plans and submitted reports are also saved in your private iCloud database, so they stay the same on all your devices. Apple keeps this data under your Apple Account, and we can't access it. Apple's privacy policy covers how Apple handles iCloud.

Your settings, including your group overseer's name and phone number, stay on the device where you entered them.

## Your contacts

When you choose your group overseer from your contacts, iOS shows you your contact list. Hugo only receives the contact you pick, and saves that person's name and phone number on your device. Hugo can't see your other contacts.

## Sending your report

When you send your monthly report, Hugo opens Messages with the report filled in, and you send it yourself. If Messages isn't available, Hugo copies the report so you can paste it where you want. Your report goes straight from you to the person you send it to. It never passes through us.

## Crash reports

If you have turned on Share With App Developers in iOS (Settings > Privacy & Security > Analytics & Improvements), Apple may share crash reports and usage statistics with us. They don't contain your entries or reports, and they don't tell us who you are. If you test Hugo through TestFlight, Apple also gives us crash reports and any feedback you choose to send.

## Emailing us

If you email us, we receive your email address and your message. We use them only to answer you, and we delete them when we no longer need them.

## Deleting your data

- To delete a single entry, category, plan or report, delete it in Hugo. If iCloud is on, it's deleted on your other devices too.
- To delete everything on one device, delete the Hugo app.
- To delete Hugo's data from iCloud, go to Settings > [your name] > iCloud > Manage Account Storage, choose Hugo and delete its data.

## Children

Hugo can be used by people of all ages. Because Hugo collects nothing, this policy is the same for everyone.

## Changes to this policy

If we change this policy, we update it in the app and at https://hugo.ordellnielsen.com/privacy, and change the date at the top.

## Contact

If you have questions about your privacy in Hugo, email us at [app@ordellnielsen.com](mailto:app@ordellnielsen.com).
````

**Verify**: `head -1 Hugo/Resources/Markdown/Legal/Base.lproj/PrivacyPolicy.md` prints `# Privacy Policy`, and `grep -c "!\[" Hugo/Resources/Markdown/Legal/Base.lproj/PrivacyPolicy.md` prints `0` (no images).

### Step 2: Add the Danish policy

Create `Hugo/Resources/Markdown/Legal/da.lproj/PrivacyPolicy.md` with exactly this content:

````markdown
# Privatlivspolitik

Senest opdateret: 13. november 2026

Hugo hjælper dig med at holde styr på din tid i tjenesten og sende din månedlige rapport. Denne politik forklarer, hvad der sker med de oplysninger, du skriver i Hugo.

Kort sagt: Hugo indsamler ikke noget om dig. Det, du skriver, bliver på dine enheder og i din egen iCloud, og vi kan ikke se det.

## Hvem vi er

Hugo er lavet af Sebastian Ordell Nielsen, en selvstændig udvikler. I denne politik betyder "vi" udvikleren af Hugo.

## Hvad vi indsamler

Ingenting. Hugo har ingen konti, ingen server, ingen analyse, ingen reklamer og ingen sporing. Vi modtager aldrig din tid, dine rapporter eller noget andet, du skriver.

## Hvad Hugo gemmer, og hvor

Hugo gemmer det, du skriver i appen:

- dine registreringer: dato, brugt tid, kategori og bibelstudier
- dine kategorier, planer og indsendte rapporter
- dine indstillinger, for eksempel din forkynderstatus, dine mål og din gruppetjeners navn og telefonnummer

Det hele gemmes på din enhed.

Hvis du er logget ind på iCloud, og iCloud er slået til for Hugo, gemmes dine registreringer, kategorier, planer og indsendte rapporter også i din private iCloud-database, så de er de samme på alle dine enheder. Apple opbevarer disse data under din Apple-konto, og vi har ikke adgang til dem. Apples privatlivspolitik beskriver, hvordan Apple håndterer iCloud.

Dine indstillinger, også din gruppetjeners navn og telefonnummer, bliver på den enhed, hvor du skrev dem.

## Dine kontakter

Når du vælger din gruppetjener blandt dine kontakter, viser iOS dig din kontaktliste. Hugo modtager kun den kontakt, du vælger, og gemmer personens navn og telefonnummer på din enhed. Hugo kan ikke se dine andre kontakter.

## Når du sender din rapport

Når du sender din månedlige rapport, åbner Hugo Beskeder med rapporten udfyldt, og du sender den selv. Hvis Beskeder ikke er tilgængelig, kopierer Hugo rapporten, så du kan sætte den ind, hvor du vil. Din rapport går direkte fra dig til den, du sender den til. Den kommer aldrig forbi os.

## Nedbrudsrapporter

Hvis du har slået Del med appudviklere til i iOS (Indstillinger > Anonymitet & sikkerhed > Analyse & forbedringer), kan Apple dele nedbrudsrapporter og brugsstatistik med os. De indeholder ikke dine registreringer eller rapporter, og de fortæller os ikke, hvem du er. Hvis du tester Hugo gennem TestFlight, giver Apple os også nedbrudsrapporter og den feedback, du vælger at sende.

## Når du skriver til os

Hvis du sender os en e-mail, modtager vi din e-mailadresse og din besked. Vi bruger dem kun til at svare dig, og vi sletter dem, når vi ikke længere har brug for dem.

## Sådan sletter du dine data

- Slet en enkelt registrering, kategori, plan eller rapport i Hugo. Hvis iCloud er slået til, bliver den også slettet på dine andre enheder.
- Slet alt på én enhed ved at slette Hugo-appen.
- Slet Hugos data i iCloud under Indstillinger > [dit navn] > iCloud > Administrer kontolagring. Vælg Hugo, og slet dataene.

## Børn

Hugo kan bruges af alle aldre. Fordi Hugo ikke indsamler noget, gælder denne politik på samme måde for alle.

## Ændringer i politikken

Hvis vi ændrer politikken, opdaterer vi den i appen og på https://hugo.ordellnielsen.com/privacy og ændrer datoen øverst.

## Kontakt

Har du spørgsmål om dit privatliv i Hugo, så skriv til os på [app@ordellnielsen.com](mailto:app@ordellnielsen.com).
````

**Verify**: `head -1 Hugo/Resources/Markdown/Legal/da.lproj/PrivacyPolicy.md` prints `# Privatlivspolitik`, and `grep -c "!\[" Hugo/Resources/Markdown/Legal/da.lproj/PrivacyPolicy.md` prints `0`.

### Step 3: Add the Settings string

In `Hugo/Resources/Localizable.xcstrings`, insert this entry in alphabetical order (after `"settings.group.settings.report"`, before `"settings.report.greeting"`), using the same indentation as its neighbors:

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

**Verify**: the JSON check in "Commands you will need" exits 0, and `grep -c '"settings.legal.privacyPolicy"' Hugo/Resources/Localizable.xcstrings` prints `1`.

### Step 4: Add the legal section to Settings

In `Hugo/Features/Settings/Screens/SettingsView.swift`:

1. Inside `struct SettingsView`, below the existing `@Environment(\.openURL) private var openURL`, add:

```swift
    /// A bundled Markdown page that the legal section opens in a sheet. The
    /// raw value is the resource name under `Hugo/Resources/Markdown/Legal`.
    private enum LegalPage: String, Identifiable {
        case privacyPolicy = "PrivacyPolicy"

        var id: String { rawValue }
    }

    @State private var legalPage: LegalPage?
```

2. Right after the closing brace of the `if let supportEmailURL = Self.supportEmailURL { ... }` block, and before the debug section (and before its `#if SHOW_DEBUG_MENU` line if plan 102 added one), add:

```swift
                Section {
                    Button {
                        legalPage = .privacyPolicy
                    } label: {
                        Label("settings.legal.privacyPolicy", systemImage: "hand.raised")
                    }
                }
```

3. After `.navigationBarTitleDisplayMode(.inline)` on the `List`, add:

```swift
            .sheet(item: $legalPage) { page in
                HelpView(for: page.rawValue)
            }
```

**Verify**: `xcrun swift-format lint --strict --recursive Hugo HugoTests` exits 0. Then `grep -n "settings.contact.email\|settings.legal.privacyPolicy\|debug.title" Hugo/Features/Settings/Screens/SettingsView.swift` shows the three lines in that order (email, then privacy policy, then debug).

### Step 5: Add the bundle test

Create `HugoTests/Resources/BundledMarkdownTests.swift`. It mirrors `Hugo/Resources`. Tests run inside the app (the test target's `TEST_HOST` is `Hugo.app`), so `Bundle.main` is the app bundle.

```swift
import Foundation
import Testing

/// Every Markdown page that `HelpView` shows must ship in English (Base) and
/// Danish. A missing file makes the sheet show "Unavailable".
struct BundledMarkdownTests {
    @Test(arguments: ["RoundingRule", "PrivacyPolicy"])
    func pageShipsInEnglishAndDanish(name: String) throws {
        for localization in ["Base", "da"] {
            let url = try #require(
                Bundle.main.url(
                    forResource: name, withExtension: "md", subdirectory: nil, localization: localization),
                "\(name).md is missing for \(localization)")
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(text.hasPrefix("# "))
            #expect(!text.contains("!["), "\(name).md must not load images")
        }
    }

    @Test(arguments: ["Base", "da"])
    func privacyPolicyNamesItsPublishedCopy(localization: String) throws {
        let url = try #require(
            Bundle.main.url(
                forResource: "PrivacyPolicy", withExtension: "md", subdirectory: nil,
                localization: localization))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("https://hugo.ordellnielsen.com/privacy"))
        #expect(text.contains("app@ordellnielsen.com"))
    }
}
```

**Verify**: `Scripts/verify.sh` exits 0, and its output includes the new tests passing (`pageShipsInEnglishAndDanish` for 2 arguments, `privacyPolicyNamesItsPublishedCopy` for 2 arguments).

If the build fails with "Multiple commands produce" for a `Base.lproj` or `da.lproj` path, move both `PrivacyPolicy.md` files into the existing `Hugo/Resources/Markdown/Help/Base.lproj/` and `Hugo/Resources/Markdown/Help/da.lproj/` folders, delete the empty `Legal` folder, re-run, and say so in your report. This is the only allowed layout fallback.

### Step 6: Commit

**Verify**: `git diff --check` exits 0, and `git status --short` shows only the in-scope files (plus the owner's untouched `Changelog/` changes, which you must not stage). Commit.

## Test plan

- `HugoTests/Resources/BundledMarkdownTests.swift` (new) checks that `RoundingRule` and `PrivacyPolicy` ship in Base and Danish, start with a title, load no images, and that the policy names its web address and the support email.
- The Settings row is a plain button that opens an existing, already-tested view in a sheet, so it gets no unit test. The owner checks it on a device.
- The structure follows other Swift Testing files, for example `HugoTests/Features/Settings/Domain/CurrentMonthCalculationTests.swift` (`import Testing`, `@Test(arguments:)`, `#expect`, `#require`).

## Done criteria

- [ ] Both `PrivacyPolicy.md` files exist and their first lines are `# Privacy Policy` and `# Privatlivspolitik`
- [ ] `grep -rc "!\[" Hugo/Resources/Markdown/Legal` prints `0` for each file
- [ ] `grep -c '"settings.legal.privacyPolicy"' Hugo/Resources/Localizable.xcstrings` prints `1`
- [ ] `grep -n "HelpView(for: page.rawValue)" Hugo/Features/Settings/Screens/SettingsView.swift` has one match
- [ ] `Scripts/verify.sh` exits 0, including the 4 new test cases
- [ ] `git show --stat HEAD` lists only the in-scope files
- [ ] `plans/README.md` row for 105 updated

## STOP conditions

- `SettingsView.swift` no longer has the support email section, or it has changes other than plan 102's (see "Current state").
- `HelpView` no longer has `init(for resourceName: String, bundle: Bundle = .main)`, or no longer loads `.md` files from the bundle.
- The `localization: "Base"` lookup returns nil for `RoundingRule` too, which already ships. Then the lookup itself is wrong, not your new file. Report it instead of changing the test logic.
- The app now sends data off the device in a way the policy text doesn't describe (`grep -rn "URLSession\|URLRequest" Hugo` has output, or a new Swift package appears in `project.pbxproj`). Then the text is no longer true.
- A step's verification fails twice after one reasonable fix.

## Maintenance notes

**Owner checks before submitting to the App Store:**

1. Read both texts. Confirm the name under "Who we are", and set "Last updated" to the date you publish. Change the date in both files, in the app and on the web.
2. Check the two iOS menu paths on an iOS 26 device, in English and in Danish: "Settings > Privacy & Security > Analytics & Improvements > Share With App Developers" and "Settings > [your name] > iCloud > Manage Account Storage" (Danish: "Anonymitet & sikkerhed > Analyse & forbedringer > Del med appudviklere" and "iCloud > Administrer kontolagring"). Fix any wording that differs in both the Markdown and on the web.
3. Publish the English text at `https://hugo.ordellnielsen.com/privacy`. The Danish text can live at the same address with a language switch, or at a second address. The bundled files are the source, so copy from them.
4. Enter `https://hugo.ordellnielsen.com/privacy` as the Privacy Policy URL in App Store Connect (App Information).
5. On a device, open Settings > Privacy Policy in English and Danish. The sheet shows the policy, the email link opens Mail, and the close button works.

**Keep the policy true.** It describes what the app does today. Update both languages, and republish the web copy, when:

- SLN-289 syncs report settings (the overseer's name and phone number) to other devices. The sentence "Your settings ... stay on the device where you entered them" must change.
- Hugo adds any analytics, crash SDK, web service or remote content. Update plan 104's manifest at the same time.
- The way reports are sent changes (for example a share sheet or Mail in addition to Messages).

**Layout.** If more bundled pages arrive (plan 106 adds Terms of Use next), they go in `Hugo/Resources/Markdown/Legal/` and get a case in `LegalPage`. If `HelpView` ends up showing more legal pages than help pages, consider renaming it to something like `MarkdownPageView` in its own small plan.
