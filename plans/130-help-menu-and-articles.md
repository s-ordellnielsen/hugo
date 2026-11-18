# Plan 130: Put help in a toolbar Help menu and add the "Your target this month" and "Field Service and Credit" articles

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat c918888..HEAD -- Hugo/Features/Help Hugo/Features/Reports/Screens/SubmitReportView.swift Hugo/Features/Settings/Screens/ReportSettingsView.swift Hugo/Features/ServiceYear/Screens/ServiceYearView.swift Hugo/Features/Categories/Screens/CategoryListView.swift Hugo/Resources/Markdown HugoTests/Resources`
> Expected: no output. `ServiceYearDetailView.swift` and `AddCategoryView.swift`
> are also in scope and were changed by plans 127 and 129; that is expected.
> Confirm plans 127 and 129 landed:
> `grep -rn "YearlyGoalPacing" Hugo --include='*.swift'` → no output, and
> `grep -n "CategoryKindPicker(kind:" Hugo/Features/Categories/Screens/AddCategoryView.swift` → one match. If not, STOP.
> Also run `git status --short -- Hugo/Resources/Localizable.xcstrings` → no output, or STOP.

## Status

- **Priority**: P2
- **Effort**: M + owner (device check of the menus, VoiceOver, and the Danish articles)
- **Risk**: LOW. Moves two help links into the toolbar and adds two Markdown pages. No data changes.
- **Depends on**: 127 (the target article describes the only calculation left), 129 (the category article uses the Field Service and Credit names)
- **Category**: direction
- **Planned at**: commit `c918888`, 2026-11-18
- **Issue**: pending (to be created in Linear)

## Why this matters

Hugo has one help article today, "Rounding", opened by a "How does rounding work?" link inside Submit Report and inside Settings > Report. Users who don't know where the yearly goal target comes from, or what Field Service and Credit mean, have nowhere to look. The owner decided (2026-11-18):

- Help moves into a toolbar menu with a question mark. It lists the articles that fit the current screen and opens the chosen one in the existing `HelpView` sheet. It stays a menu even with one article, so help looks and works the same everywhere.
- Two new articles, in English and Danish: "Your target this month" (how the expected time is computed, with a worked example) and "Field Service and Credit" (the two category types). "Rounding rules" stays.
- The inline rounding links are removed.

## Current state

### `HelpView` (`Hugo/Features/Help/Screens/HelpView.swift`)

`HelpView(for resourceName: String, bundle: Bundle = .main, presentation: Presentation = .sheet)` loads `resourceName.md` from the bundle with `bundle.url(forResource: resourceName, withExtension: "md")` and renders it with MarkdownUI. As a sheet it wraps the page in a `NavigationStack` with a close button. A missing file shows "Unavailable". It is the only file in `Hugo/Features/Help` (folder `Screens`).

### Markdown files and bundling

```
Hugo/Resources/Markdown/Help/Base.lproj/RoundingRule.md
Hugo/Resources/Markdown/Help/da.lproj/RoundingRule.md
Hugo/Resources/Markdown/Legal/Base.lproj/PrivacyPolicy.md, TermsOfUse.md
Hugo/Resources/Markdown/Legal/da.lproj/PrivacyPolicy.md, TermsOfUse.md
```

`Hugo.xcodeproj/project.pbxproj` uses `objectVersion = 77` with a `PBXFileSystemSynchronizedRootGroup` for the whole `Hugo` folder; the only exception is `Info.plist`. Every file under `Hugo/` is in the app target automatically, and files in `Base.lproj`/`da.lproj` folders become localized resources. **New `.md` files need no project change.** File names must be unique across all `.lproj` folders, because the bundle flattens them.

`RoundingRule.md` format: a `# Title` first line, short paragraphs, `##` section headings, `-` bullet lists, `**bold**` for key numbers. No images (a test forbids `![`).

`HugoTests/Resources/BundledMarkdownTests.swift`:

```swift
/// Every Markdown page that `HelpView` shows must ship in English (Base) and
/// Danish. A missing file makes the sheet show "Unavailable".
struct BundledMarkdownTests {
    @Test(arguments: ["RoundingRule", "PrivacyPolicy", "TermsOfUse"])
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
```

It has no `@testable import Hugo` today.

### Inline help to remove

`Hugo/Features/Reports/Screens/SubmitReportView.swift`:
- line 18: `@State private var showingRoundingHelp = false`
- lines 90-96:

```swift
                if model.results.contains(where: { $0.line.needsRule }) {
                    Button("report.rounding.help.link", systemImage: "questionmark.circle") {
                        showingRoundingHelp = true
                    }
                    .font(.subheadline)
                    .padding(.top, HugoLayout.Spacing.compact)
                }
```

- line 221: `.sheet(isPresented: $showingRoundingHelp) { HelpView(for: "RoundingRule") }`

Its toolbar (lines 164-190). The sheet's leading item is Cancel; the trailing items are the prominent send button (the screen's confirm action) and a More menu:

```swift
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("report.submit.send-message", systemImage: "arrow.up.message.fill") {
                    confirmIfNeeded(sendViaMessages)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .tint(.hugoAccent)
                .disabled(!model.canSend || !MessageComposeView.canSendText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("common.more", systemImage: "ellipsis") {
                    ...
                }
            }
        }
```

`Hugo/Features/Settings/Screens/ReportSettingsView.swift`:
- line 14: `@State private var showingHelp = false`
- lines 48-52: `Section { Button("report.rounding.help.link", systemImage: "questionmark.circle") { showingHelp = true } }`
- line 54: `.sheet(isPresented: $showingHelp) { HelpView(for: "RoundingRule") }`
- No toolbar of its own. It is pushed from Settings and also shown in a sheet from Submit Report, where the parent adds a leading Cancel button.

`report.rounding.help.link` ("How does rounding work?" / "Hvordan fungerer afrunding?") is used only in these two places.

### Toolbars of the other screens that get a menu

- `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift` (Year tab root): a `.principal` year title button and `ToolbarItem { SettingsButton(sizeClass: .compact) }`.
- `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift` (year details, pushed from the totals card): no toolbar; `.editorialNavigationTitle(report.year.displayName)` and `.navigationSubtitle("year.detail.subtitle")`.
- `Hugo/Features/Categories/Screens/CategoryListView.swift`: `ToolbarItem { Button { addTrackerSheetIsPresented = true } label: { Label("navigation.add", systemImage: "plus") } }`.
- `Hugo/Features/Categories/Screens/AddCategoryView.swift` (sheet): `ToolbarItem { Button(role: .confirm, action: submit) { Label("common.done", systemImage: "checkmark") } ... }`.

`ToolbarSpacer` is already used: `ToolbarSpacer()` in `CategoryDetailView.swift:103` and `ToolbarSpacer(.fixed, placement: .bottomBar)` in `SymbolPicker.swift:71`.

### Numbers for the target article (verified in code)

`YearlyGoalProgress.make` (after plan 127): every month of the theocratic year before the current month adds `monthlyGoalSeconds`; the current month adds `monthlyGoalSeconds * currentMonthFraction(now:calendar:)`, where the fraction is today's day number divided by the number of days in the month. The theocratic year starts on September 1 (`TheocraticYear.months`). The only status with a yearly goal is regular pioneer: 600 hours, monthly goal 50 (`PublisherStatus.all`). On November 15: 2 x 50 + 50 x 15/30 = 125 hours. Plan 127 added the test `midNovemberExpectsOneHundredTwentyFiveHours` that pins this.

### Numbers for the Field Service and Credit article (verified in code)

`YearlyGoalRule.creditedSeconds(main:separate:)`: `room = max(0, monthlyGoal + allowance - main)`, counted = `main + min(separate, room)`. Regular pioneer allowance: 5 hours. 45 hours of Field Service and 15 hours of LDC: room = 50 + 5 - 45 = 10, counted = 45 + 10 = 55. School credit counts like Field Service time, in full (`creditedSeconds(for:)` adds it to `main`).

### Vocabulary (`CONTEXT.md` after plan 129)

Field Service category / Credit category (UI: "Category Type" with options "Field Service" / "Credit", Danish "Forkyndelse" / "Godtgørelse"); Counted time (UI "Counted toward goal" / "Tæller med mod målet"); Credit allowance; School credit; Expected time. The Year tab is "Year" / "Tjenesteår"; the publisher status "Regular Pioneer" / "Almindelig Pioner"; the school "Pioneer Service School" / "Pionerskole".

### Conventions

- AGENTS.md section 7, DesignSystem admission rule: a file belongs in `DesignSystem` only if it names no feature type. `HelpMenu` names `HelpArticle`, a type of the Help feature, so it goes in `Hugo/Features/Help/Views/`, and `HelpArticle` in `Hugo/Features/Help/Domain/`. Other features may use it ("A feature may use another feature's types when it has to"). Help uses no other feature, so there is no cycle.
- Preview strings get extracted into the catalog. In previews use `Text(verbatim:)` for placeholder text so the build adds no keys.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `Scripts/verify.sh` | exit 0 |
| Build | `xcodebuild build -project Hugo.xcodeproj -scheme Debug -destination 'generic/platform=iOS Simulator' -quiet 2>&1 \| grep -c "error:"` | `0` |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Debug -configuration Debug -destination 'platform=iOS Simulator,name=Hugo Verify iOS 26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/HelpArticleTests -only-testing:HugoTests/BundledMarkdownTests` | `** TEST SUCCEEDED **` |
| Bundled files | `find /tmp/HugoVerifyDerivedData/Build/Products -path "*Hugo.app/*" -name "TargetThisMonth.md" -o -path "*Hugo.app/*" -name "FieldServiceAndCredit.md"` (after a test run) | 4 paths (Base.lproj and da.lproj for each) |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |

Do not run the focused tests while `Scripts/verify.sh` runs; both use the same simulator.

## Scope

**In scope:**
- `Hugo/Features/Help/Domain/HelpArticle.swift` (create)
- `Hugo/Features/Help/Views/HelpMenu.swift` (create)
- `Hugo/Resources/Markdown/Help/Base.lproj/TargetThisMonth.md` (create)
- `Hugo/Resources/Markdown/Help/da.lproj/TargetThisMonth.md` (create)
- `Hugo/Resources/Markdown/Help/Base.lproj/FieldServiceAndCredit.md` (create)
- `Hugo/Resources/Markdown/Help/da.lproj/FieldServiceAndCredit.md` (create)
- `Hugo/Features/Reports/Screens/SubmitReportView.swift`
- `Hugo/Features/Settings/Screens/ReportSettingsView.swift`
- `Hugo/Features/ServiceYear/Screens/ServiceYearView.swift`
- `Hugo/Features/ServiceYear/Screens/ServiceYearDetailView.swift` (toolbar only)
- `Hugo/Features/Categories/Screens/CategoryListView.swift`
- `Hugo/Features/Categories/Screens/AddCategoryView.swift` (toolbar only)
- `HugoTests/Features/Help/Domain/HelpArticleTests.swift` (create)
- `HugoTests/Resources/BundledMarkdownTests.swift`
- `Hugo/Resources/Localizable.xcstrings` (add 4 keys, delete 1)

**Out of scope:**
- `RoundingRule.md` text, and `HelpView` itself.
- `Hugo.xcodeproj/project.pbxproj`. Synchronized folders pick up the new files.
- Screens that get no menu, with the reason:
  - `CategoryDetailView`: its toolbar already has the default star and Delete, and plan 129's cards and footer explain the type on that screen.
  - `ServiceYearMonthRow` (the `…` menu on each month card): that menu holds actions for one month. Help there would repeat on every card; the Year tab's toolbar menu covers the page.
  - `MonthDetailView`: its toolbar holds the add menu; the month's numbers are explained by the Year tab's articles one level up.
  - Planner, Overview, Settings root: no article fits yet. The Planner's "target" is the Monthly target, a different concept, so "Your target this month" there would confuse.
- Plan 131's goal bar. Its "Target today" marker is explained by the "Your target this month" article listed on the Year tab; 131 needs no help changes.

## Git workflow

- Work on `main` directly. No branch, no worktree.
- One commit after `Scripts/verify.sh` exits 0: `feat: move help into a toolbar Help menu and add target and category articles`.
- Never stage `.claude/`, `plans/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Do not push.

## Steps

### Step 1: `HelpArticle`

Create `Hugo/Features/Help/Domain/HelpArticle.swift`:

```swift
import Foundation

/// A help page that `HelpView` shows. The raw value is the Markdown file's
/// name without `.md`; each file ships in
/// `Hugo/Resources/Markdown/Help/Base.lproj` and `da.lproj`.
nonisolated enum HelpArticle: String, CaseIterable, Identifiable, Sendable {
    case targetThisMonth = "TargetThisMonth"
    case fieldServiceAndCredit = "FieldServiceAndCredit"
    case roundingRules = "RoundingRule"

    var id: String { rawValue }

    var resourceName: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .targetThisMonth:
            LocalizedStringResource(
                "help.article.targetThisMonth", defaultValue: "Your target this month",
                comment: "Help menu item and article title: how the time expected by today is worked out.")
        case .fieldServiceAndCredit:
            LocalizedStringResource(
                "help.article.fieldServiceAndCredit", defaultValue: "Field Service and Credit",
                comment: "Help menu item and article title: the two category types.")
        case .roundingRules:
            LocalizedStringResource(
                "help.article.roundingRules", defaultValue: "Rounding rules",
                comment: "Help menu item: the article about rounding a report line's minutes.")
        }
    }

    var systemImage: String {
        switch self {
        case .targetThisMonth: "target"
        case .fieldServiceAndCredit: "tag"
        case .roundingRules: "plusminus"
        }
    }

    // MARK: Articles per screen

    /// The Year tab and the year details screen.
    static let year: [HelpArticle] = [.targetThisMonth, .fieldServiceAndCredit]

    /// The Submit Report sheet: rounding first, because a line can't be sent
    /// without a rule; the types explain the report's lines.
    static let submitReport: [HelpArticle] = [.roundingRules, .fieldServiceAndCredit]

    /// Settings > Report.
    static let reportSettings: [HelpArticle] = [.roundingRules]

    /// Settings > Categories and the Add Category sheet.
    static let categories: [HelpArticle] = [.fieldServiceAndCredit]
}
```

Why rounding is not on the Year tab: the month cards show rounded and transferred minutes, but the rule is chosen on Submit Report, where its help is. Two items keep the Year tab's menu short.

**Verify**: build → `0`.

### Step 2: `HelpMenu`

Create `Hugo/Features/Help/Views/HelpMenu.swift`:

```swift
import SwiftUI

/// A question mark in the toolbar that lists the help articles for the
/// current screen and opens the chosen one in a sheet. It stays a menu even
/// with one article, so help looks and works the same on every screen.
struct HelpMenu: View {
    let articles: [HelpArticle]

    @State private var presentedArticle: HelpArticle?

    var body: some View {
        Menu {
            ForEach(articles) { article in
                Button {
                    presentedArticle = article
                } label: {
                    Label {
                        Text(article.title)
                    } icon: {
                        Image(systemName: article.systemImage)
                    }
                }
            }
        } label: {
            Label {
                Text("help.menu.label")
            } icon: {
                Image(systemName: "questionmark.circle")
            }
        }
        .sheet(item: $presentedArticle) { article in
            HelpView(for: article.resourceName)
        }
    }
}

#Preview {
    NavigationStack {
        Text(verbatim: "Screen")
            .toolbar {
                ToolbarItem {
                    HelpMenu(articles: HelpArticle.year)
                }
            }
    }
}
```

In a toolbar the label shows only the symbol; VoiceOver reads "Help" / "Hjælp" from the `Label` text and announces it as a button that opens a menu.

**Verify**: build → `0`.

### Step 3: Put the menu in the toolbars and remove the inline help

The rule for every screen: the Help menu is the first item of the trailing group. When other trailing items follow, a `ToolbarSpacer(.fixed)` with the same placement separates them, so the question mark gets its own glass group and never merges with the screen's main action.

1. `ServiceYearView.swift` (Year tab): in `.toolbar`, before `ToolbarItem { SettingsButton(sizeClass: .compact) }`, add:

```swift
                ToolbarItem {
                    HelpMenu(articles: HelpArticle.year)
                }
                ToolbarSpacer(.fixed)
```

2. `ServiceYearDetailView.swift`: after `.navigationSubtitle("year.detail.subtitle")`, add:

```swift
        .toolbar {
            ToolbarItem {
                HelpMenu(articles: HelpArticle.year)
            }
        }
```

3. `SubmitReportView.swift`:
   - Delete `@State private var showingRoundingHelp = false`.
   - Delete the whole `if model.results.contains(where: { $0.line.needsRule }) { Button("report.rounding.help.link", ...) ... }` block.
   - Delete `.sheet(isPresented: $showingRoundingHelp) { HelpView(for: "RoundingRule") }`.
   - In `.toolbar`, right after the Cancel `ToolbarItem(placement: .topBarLeading)`, add:

```swift
            ToolbarItem(placement: .topBarTrailing) {
                HelpMenu(articles: HelpArticle.submitReport)
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
```

   The trailing order becomes: Help, a gap, then the prominent send button and More as before. The send button stays the screen's confirm action; nothing about it changes.

4. `ReportSettingsView.swift`:
   - Delete `@State private var showingHelp = false`, the `Section { Button("report.rounding.help.link", ...) }` and `.sheet(isPresented: $showingHelp) { HelpView(for: "RoundingRule") }`.
   - After `.navigationTitle("settings.group.settings.report")`, add:

```swift
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HelpMenu(articles: HelpArticle.reportSettings)
            }
        }
```

5. `CategoryListView.swift`: in `.toolbar`, before the add `ToolbarItem`, add:

```swift
            ToolbarItem {
                HelpMenu(articles: HelpArticle.categories)
            }
            ToolbarSpacer(.fixed)
```

6. `AddCategoryView.swift`: in `.toolbar`, before the confirm `ToolbarItem`, add the same two lines as in item 5.

**Verify**: build → `0`. `grep -rn "showingRoundingHelp\|showingHelp\|report.rounding.help.link\|HelpView(for: \"RoundingRule\")" Hugo --include='*.swift' | grep -v "Help/Screens/HelpView.swift"` → no output. `grep -rn "HelpMenu(articles:" Hugo --include='*.swift' | wc -l` → `7` (six screens plus the `#Preview` in `HelpMenu.swift`).

### Step 4: The articles

Create the four files with exactly this content (UTF-8, ending with one newline). Keep the straight quotes.

`Hugo/Resources/Markdown/Help/Base.lproj/TargetThisMonth.md`:

```markdown
# Your target this month

If you have a yearly goal, for example as a regular pioneer, the Year tab shows how many hours count toward your goal and whether you are ahead or behind. Hugo compares those hours with your target for today.

## How Hugo works out your target

Hugo splits your yearly goal evenly into twelve monthly goals. The theocratic year starts on September 1.

- Each month that is over adds its whole monthly goal.
- The current month adds a little every day. Its monthly goal is spread across the days of the month, and today counts as a whole day.

So your target grows a little each day and reaches the full monthly goal on the last day of the month.

## An example

You are a regular pioneer. Your yearly goal is 600 hours, so your monthly goal is 50 hours. Today is November 15.

- September and October are over: 2 × 50 = **100 hours**.
- November has 30 days, and today is day 15: 50 × 15 ÷ 30 = **25 hours**.
- Your target today is 100 + 25 = **125 hours**.

If 130 hours count toward your goal, you are 5 hours ahead. If 120 hours count, you are 5 hours behind. On November 30 your target is 150 hours.

## Which hours count

All your Field Service time and school credit count. Credit time counts up to a limit each month. Read "Field Service and Credit" to learn more.

When the theocratic year is over, your target is the whole yearly goal.
```

`Hugo/Resources/Markdown/Help/da.lproj/TargetThisMonth.md`:

```markdown
# Dit mål i denne måned

Hvis du har et årsmål, fx som almindelig pioner, viser fanen Tjenesteår, hvor mange timer der tæller med mod målet, og om du er foran eller bagud. Hugo sammenligner de timer med dit mål for i dag.

## Sådan regner Hugo dit mål ud

Hugo deler dit årsmål ligeligt ud på tolv månedsmål. Tjenesteåret begynder 1. september.

- Hver måned, der er slut, lægger hele sit månedsmål til.
- Den nuværende måned lægger lidt til hver dag. Månedsmålet bliver fordelt over månedens dage, og dagen i dag tæller som en hel dag.

Dit mål vokser altså lidt hver dag og når hele månedsmålet på månedens sidste dag.

## Et eksempel

Du er almindelig pioner. Dit årsmål er 600 timer, så dit månedsmål er 50 timer. I dag er det den 15. november.

- September og oktober er slut: 2 × 50 = **100 timer**.
- November har 30 dage, og i dag er dag 15: 50 × 15 ÷ 30 = **25 timer**.
- Dit mål i dag er 100 + 25 = **125 timer**.

Hvis 130 timer tæller med mod målet, er du 5 timer foran. Hvis 120 timer tæller med, er du 5 timer bagud. Den 30. november er dit mål 150 timer.

## Hvilke timer tæller med?

Al din tid i forkyndelse og dine timer fra skoler tæller med. Godtgørelse tæller med op til en grænse hver måned. Læs mere i "Forkyndelse og godtgørelse".

Når tjenesteåret er slut, er dit mål hele årsmålet.
```

`Hugo/Resources/Markdown/Help/Base.lproj/FieldServiceAndCredit.md`:

```markdown
# Field Service and Credit

Every category in Hugo has one of two types: Field Service or Credit. You choose the type when you add a category.

## Field Service

Use Field Service for the time you spend preaching and teaching, for example house to house, return visits and public witnessing.

- All Field Service time is added together and sent as one line on your report.
- All of it counts toward your yearly goal.
- You can add Bible studies to Field Service entries.

## Credit

Use Credit for hours you may report as credit for other approved work, for example LDC or Bethel.

- Each Credit category is sent on its own line, with the category's name.
- Credit counts toward your yearly goal until the month reaches your monthly goal plus a few extra hours. For a regular pioneer that is 50 + 5 = **55 hours**.
- You can't add Bible studies to Credit entries. An entry that already has Bible studies keeps them.

### An example

You are a regular pioneer. In March you have 45 hours of Field Service and 15 hours of LDC. The first 10 hours of LDC bring the month to 55 hours, so **55 hours** count toward your goal. The other 5 hours are still sent on your report, but they don't count toward the goal.

## School credit

Hours from a school, such as Pioneer Service School, are credit too. You add them to a month on the Year tab, not with a category. They count in full toward your yearly goal and are sent on a line of their own.

## Which type should I choose?

If you are not sure whether an activity may be reported as credit, ask the elders in your congregation.

You can change a category's type later in Settings > Categories. Hugo then counts all of its time the new way, also in months you have already reported. Those months may then show that they changed since you sent the report.
```

`Hugo/Resources/Markdown/Help/da.lproj/FieldServiceAndCredit.md`:

```markdown
# Forkyndelse og godtgørelse

Alle kategorier i Hugo har en af to typer: Forkyndelse eller Godtgørelse. Du vælger typen, når du opretter en kategori.

## Forkyndelse

Brug Forkyndelse til den tid, du bruger på at forkynde og undervise, fx fra hus til hus, genbesøg og offentlig forkyndelse.

- Al tid i forkyndelse bliver lagt sammen og sendt som dine timer i rapporten.
- Det hele tæller med mod dit årsmål.
- Du kan tilføje bibelstudier til registreringer i forkyndelse.

## Godtgørelse

Brug Godtgørelse til timer, du må rapportere som godtgørelse for andet godkendt arbejde, fx LDC eller Betel.

- Hver kategori med godtgørelse bliver sendt på sin egen linje med kategoriens navn.
- Godtgørelse tæller med mod dit årsmål, indtil måneden når dit månedsmål plus nogle få ekstra timer. For en almindelig pioner er det 50 + 5 = **55 timer**.
- Du kan ikke tilføje bibelstudier til registreringer med godtgørelse. En registrering, der allerede har bibelstudier, beholder dem.

### Et eksempel

Du er almindelig pioner. I marts har du 45 timer i forkyndelse og 15 timer i LDC. De første 10 timer i LDC bringer måneden op på 55 timer, så **55 timer** tæller med mod dit mål. De sidste 5 timer bliver stadig sendt med din rapport, men de tæller ikke med mod målet.

## Timer fra skoler

Timer fra en skole, fx Pionerskolen, er også godtgørelse. Du tilføjer dem til en måned under Tjenesteår, ikke med en kategori. De tæller fuldt ud med mod dit årsmål og bliver sendt på deres egen linje.

## Hvilken type skal jeg vælge?

Hvis du er i tvivl om, hvorvidt en aktivitet må rapporteres som godtgørelse, så spørg de ældste i din menighed.

Du kan ændre en kategoris type senere under Indstillinger > Kategorier. Så tæller Hugo al kategoriens tid på den nye måde, også i måneder, du allerede har rapporteret. De måneder kan så vise, at de er ændret, siden du sendte rapporten.
```

Do not add these files to `project.pbxproj`; the synchronized `Hugo` folder bundles them.

**Verify**: `ls Hugo/Resources/Markdown/Help/Base.lproj Hugo/Resources/Markdown/Help/da.lproj` → each lists `FieldServiceAndCredit.md  RoundingRule.md  TargetThisMonth.md`. `grep -c "125" Hugo/Resources/Markdown/Help/*/TargetThisMonth.md` → `1` for each file.

### Step 5: Strings

Use the catalog helper from plan 129 Step 4 (save it as `/tmp/xcstrings_edit.py` if it is missing; it has `load`, `save`, `entry` and `insert_sorted`). Confirm it is lossless first (`x.save(x.load())` leaves `git diff` empty). Then:

- Delete `report.rounding.help.link`.
- Add these keys with `insert_sorted`, `en` and `da` both `"state" : "translated"`. The English values and comments must match the Swift `defaultValue` and `comment` in Step 1 exactly.

| Key | English | Danish | Comment |
|---|---|---|---|
| `help.menu.label` | Help | Hjælp | The question-mark menu in the toolbar that lists help articles. VoiceOver reads it. |
| `help.article.targetThisMonth` | Your target this month | Dit mål i denne måned | Help menu item and article title: how the time expected by today is worked out. |
| `help.article.fieldServiceAndCredit` | Field Service and Credit | Forkyndelse og godtgørelse | Help menu item and article title: the two category types. |
| `help.article.roundingRules` | Rounding rules | Afrundingsregler | Help menu item: the article about rounding a report line's minutes. |

**Verify**:
- `python3 -I -c "import json;s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];k=['help.menu.label','help.article.targetThisMonth','help.article.fieldServiceAndCredit','help.article.roundingRules'];print(all(k2 in s for k2 in k), 'report.rounding.help.link' in s)"` → `True False`.
- `git diff --numstat -- Hugo/Resources/Localizable.xcstrings` → about 72 added and 18 removed lines.

### Step 6: Tests

1. Create `HugoTests/Features/Help/Domain/HelpArticleTests.swift`:

```swift
import Foundation
import Testing

@testable import Hugo

struct HelpArticleTests {
    private let screens: [[HelpArticle]] = [
        HelpArticle.year, HelpArticle.submitReport, HelpArticle.reportSettings, HelpArticle.categories,
    ]

    @Test
    func everyScreenListsAtLeastOneArticleWithoutRepeats() {
        for articles in screens {
            #expect(!articles.isEmpty)
            #expect(Set(articles).count == articles.count)
        }
    }

    @Test
    func everyArticleIsListedOnSomeScreen() {
        let listed = Set(screens.flatMap { $0 })
        #expect(listed == Set(HelpArticle.allCases))
    }

    @Test
    func screensListTheAgreedArticles() {
        #expect(HelpArticle.year == [.targetThisMonth, .fieldServiceAndCredit])
        #expect(HelpArticle.submitReport == [.roundingRules, .fieldServiceAndCredit])
        #expect(HelpArticle.reportSettings == [.roundingRules])
        #expect(HelpArticle.categories == [.fieldServiceAndCredit])
    }

    @Test
    func roundingKeepsItsExistingFile() {
        #expect(HelpArticle.roundingRules.resourceName == "RoundingRule")
    }
}
```

2. In `HugoTests/Resources/BundledMarkdownTests.swift`, add `@testable import Hugo` under `import Testing` (with a blank line between, as in other test files), and change the arguments of `pageShipsInEnglishAndDanish` to:

```swift
    @Test(arguments: HelpArticle.allCases.map(\.resourceName) + ["PrivacyPolicy", "TermsOfUse"])
```

**Verify**: focused tests command → `** TEST SUCCEEDED **`; `pageShipsInEnglishAndDanish` runs 5 cases. Then the "Bundled files" command → 4 paths.

### Step 7: Full gate and commit

Run `Scripts/verify.sh`. After it, `git diff -- Hugo/Resources/Localizable.xcstrings` must show only the 4 added and 1 removed keys. Commit the in-scope files with the message from "Git workflow".

## Test plan

- New `HelpArticleTests` (4 tests): each screen's list is non-empty and has no repeats; every article is listed somewhere; the agreed lists; the rounding file name.
- `BundledMarkdownTests.pageShipsInEnglishAndDanish` now covers every `HelpArticle` (5 cases): each file ships in Base and Danish, starts with `# ` and loads no images.
- The numbers in the target article are pinned by plan 127's `midNovemberExpectsOneHundredTwentyFiveHours`.
- `Scripts/verify.sh` → exit 0.

Owner checks on a device (record results in the plan's status row):
1. Year tab: a question mark left of Settings opens a menu with "Your target this month" and "Field Service and Credit"; each opens its article in a sheet with a close button. Same on the year details screen.
2. Submit Report: the question mark sits left of the send button, in its own group; the send button still looks and works the same. The menu lists "Rounding rules" first. The old "How does rounding work?" link is gone.
3. Settings > Report: a question mark at the top right with "Rounding rules"; the old row is gone. Also open Report settings from Submit Report's settings sheet.
4. Settings > Categories and Add Category: a question mark with "Field Service and Credit".
5. VoiceOver says "Help, button" (Danish "Hjælp") on the question mark.
6. Danish: read both new articles in Danish and confirm the wording, especially "Godtgørelse", "Pionerskolen" and "spørg de ældste i din menighed".

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] `test -f Hugo/Features/Help/Views/HelpMenu.swift && test -f Hugo/Features/Help/Domain/HelpArticle.swift` → exit 0
- [ ] `ls Hugo/Resources/Markdown/Help/*/ | grep -c ".md"` → `6`
- [ ] `grep -rln "HelpMenu(articles:" Hugo/Features --include='*.swift' | sort` lists `AddCategoryView.swift`, `CategoryListView.swift`, `HelpMenu.swift`, `ReportSettingsView.swift`, `ServiceYearDetailView.swift`, `ServiceYearView.swift`, `SubmitReportView.swift`
- [ ] `grep -rn "report.rounding.help.link\|showingRoundingHelp" Hugo` → no output
- [ ] `git diff --stat c918888..HEAD -- Hugo.xcodeproj/project.pbxproj` shows no change from this plan
- [ ] `git status --short` shows no modified files outside the in-scope list, except the owner's `Debug.xcscheme`

## STOP conditions

- Plans 127 or 129 have not landed (drift check).
- The new Markdown files are not in the built app (the "Bundled files" command finds fewer than 4 paths). Do not edit `project.pbxproj`; report it.
- `ToolbarSpacer(.fixed, placement:)` does not compile with the toolbar placement used. Report the error; do not merge Help into the More menu instead.
- The Help sheet does not open from a toolbar menu on a screen that is itself a sheet (Submit Report, Add Category) when you try it in the simulator. Report it instead of moving the sheet.

## Maintenance notes

- A new article: add a case to `HelpArticle`, the two Markdown files, a title key in the catalog, and the case to the lists of the screens that need it. `BundledMarkdownTests` and `HelpArticleTests` then cover it.
- Plan 131 adds a "Target today" marker to the Year tab's goal bar. The "Your target this month" article explains the same number in words; if the article gets a sentence about the bar, keep "Target today" / "Mål i dag" as the wording.
- If the owner renames the Danish kinds again, update `FieldServiceAndCredit.md` (da), the Danish `TargetThisMonth.md` "Hvilke timer tæller med?" section, and `help.article.fieldServiceAndCredit` together with the keys listed in plan 129.
- If the yearly goal rule changes (another status gets a yearly goal, or the allowance changes), update the numbers in both articles.
- A reviewer should check that the Submit Report send button is still the prominent trailing action, and that each new article reads well in Danish.
