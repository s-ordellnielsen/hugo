# Plan 123: Redesign onboarding with a welcome list and setup pages of its own

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat f1797ca..HEAD -- Hugo/Features/Onboarding HugoTests/Features/Onboarding Hugo/Features/Settings/Screens/OverseerSettingsView.swift Hugo/DesignSystem/Theme/Theme.swift Hugo/DesignSystem/Motion/Motion.swift Hugo/Features/PublisherStatus Hugo/Features/Reports/Views/OverseerPicker.swift Hugo/App/AppRootView.swift Hugo/Resources/Localizable.xcstrings`
> Expected: no output. If the only file listed is `Hugo/Resources/Localizable.xcstrings`, run
> `git diff f1797ca..HEAD -- Hugo/Resources/Localizable.xcstrings | grep -E '^[-+]    "(onboarding|splash)\.'`.
> No output means other plans only added their own keys: continue. Any other
> output, or any other file in the first list, is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: L + owner (walk through it on a device in English and Danish, at the largest text size, with VoiceOver and Reduce Motion, and on a second device)
- **Risk**: MED. Every new user sees this first. `AppRootView` still opens onboarding the same way, and no stored setting changes. The advisor compiled this exact code at `f1797ca` in a scratch copy of the repo before writing the plan: `xcodebuild build-for-testing` succeeded, `swift-format lint --strict` and `Scripts/check-layout.sh` passed, the four `OnboardingStepTests` passed, and simulator screenshots looked right in English, in Danish and at the largest text size.
- **Depends on**: none. It replaces the onboarding pages from plan 122.
- **Category**: direction
- **Planned at**: commit `f1797ca`, 2026-11-15
- **Issue**: [SLN-314](https://linear.app/sebastianln/issue/SLN-314)

## Why this matters

Onboarding is the first thing every new user sees, and Hugo's users are between about 13 and 70 years old. Today it works but looks plain. The welcome page is three sentences of text. The publisher status page is a list of cards. The group overseer page is the Settings screen with an introduction on top, so it looks like Settings rather than part of a welcome flow. The step counter sits in the bottom bar and counts the welcome page as a step. A user on a second device sees their status and overseer already filled in, with nothing saying where they came from.

After this plan:

1. **Welcome**: "Welcome to Hugo", the subtitle, then four rows with a symbol each. Log your time, Plan your month, Send your report, Follow your goal. A privacy line at the bottom. The rows fade in one after another.
2. **Step 1 of 2, publisher status**: required, as today.
3. **Step 2 of 2, group overseer**: a card with the chosen overseer, or "No group overseer selected", and a button that opens Contacts. Skip for Now while no one is chosen, as today.

Pages 2 and 3 share one layout: the step above a serif title, a short explanation, then the choice. When iCloud already filled a setting in and the user hasn't changed it here, the page says "Filled in from your other devices through iCloud."

### Decisions

Owner (2026-11-15):

- The welcome page is a feature list: four rows and a privacy line. Not a visual tour, which would need screenshots in two languages that go stale.
- The publisher status and group overseer get onboarding pages of their own, in one shared layout. They save the same settings (`UserDefaultsKeys`) as Settings, and the overseer page uses the same contact picker (`OverseerContactPicker`), so every value still lives in one place. The Settings screens stay as they are, and `OverseerSettingsView` loses the `introduction` parameter that plan 122 added for onboarding.
- On a second device all pages still show (plan 122 Revision 1: never skip pages). A page whose setting is already filled in, and which the user hasn't changed during this onboarding, shows one line: "Filled in from your other devices through iCloud." Continue works straight away.

Advisor defaults, taken from the codebase (the owner can change them in review):

- Pages still push in a `NavigationStack`: a back button and swipe back, as today. Hugo adds no page animation of its own, so the change of page is the system's, which follows the user's Motion settings. Inside the pages, motion uses the existing `Motion` tokens through the `.motion(_:value:)` modifier, which respects Reduce Motion.
- The counter counts only the setup pages ("Step 1 of 2", "Step 2 of 2") and moves from the bottom bar to just above the title, styled like the month names on the Year page. The welcome page has no counter.
- The buttons use the app's main button style (`.buttonStyle(.glassProminent)`, `.tint(.hugoAccent)`, `.controlSize(.large)`), like the bottom button of Submit Report. They sit in a `safeAreaBar` (iOS 26), so the page scrolls under them behind the system's edge effect.
- The four `splash.*` strings that nothing uses after this plan are deleted, so Xcode doesn't mark them stale. The English subtitle's opening quote is the wrong character (`”` instead of `"`); it becomes a straight quote like the closing one.

## Current state

### How onboarding opens (unchanged by this plan)

`Hugo/App/AppRootView.swift:12` and `:102`:

```swift
    @AppStorage(UserDefaultsKeys.isOnboarding) private var needsOnboarding = true
```

```swift
        .sheet(isPresented: $needsOnboarding) { OnboardingView { needsOnboarding = false } }
```

The debug menu (`DebugSettingsView`, behind `SHOW_DEBUG_MENU`) sets `isOnboarding` back to `true` to show onboarding again. Keep `OnboardingView(onComplete:)` exactly as it is, so neither file changes.

### The onboarding feature today

`Hugo/Features/Onboarding/Domain/OnboardingStep.swift` (whole file, 16 lines):

```swift
/// One page of the first-run setup, in order.
nonisolated enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case publisherStatus
    case overseer

    /// The step's position for "Step 2 of 3", starting at 1.
    var number: Int { rawValue + 1 }

    static var count: Int { allCases.count }

    /// The page after this one, or nil after the last page.
    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
```

`Hugo/Features/Onboarding/Views/OnboardingStepBar.swift:5-39` (the counter and a hand-made mint button with white text):

```swift
struct OnboardingStepBar: View {
    let step: OnboardingStep
    let isLast: Bool
    var canContinue = true
    var onSkip: (() -> Void)? = nil
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: HugoLayout.Spacing.compact) {
            Text("onboarding.step.\(step.number).\(OnboardingStep.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(action: onContinue) {
                Label(
                    isLast ? "splash.action.complete" : "onboarding.action.continue",
                    systemImage: "arrow.right"
                )
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.hugoAccent)
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.compactCard))
            }
            .disabled(!canContinue)
            ...
        }
        .padding()
        .background(.bar)
    }
}
```

`Hugo/Features/Onboarding/Screens/OnboardingView.swift` (102 lines) builds every page inside one file. Its overseer case, lines 51-62, embeds the Settings screen:

```swift
        case .overseer:
            OverseerSettingsView(introduction: "onboarding.overseer.introduction")
                .safeAreaInset(edge: .bottom) {
                    OnboardingStepBar(
                        step: step,
                        isLast: isLast,
                        canContinue: !overseerFullName.isEmpty,
                        onSkip: overseerFullName.isEmpty ? { advance(from: step) } : nil
                    ) {
                        advance(from: step)
                    }
                }
```

Its `welcomePage` (lines 66-79) shows `splash.subtitle`, `splash.description.1` and `splash.description.2` under the navigation title `splash.title`. Its `publisherStatusPage` (lines 81-97) shows `splash.section.publisherStatus.description` and `PublisherStatusOptionsView(selection: $currentStatus, rowStyle: .card)` under the title `splash.section.publisherStatus.title`.

`HugoTests/Features/Onboarding/Domain/OnboardingStepTests.swift` has two tests, `everyStepFollowsTheOneBefore` and `numbersCountFromOne` (which checks `number` and `count`).

### The Settings overseer screen

`Hugo/Features/Settings/Screens/OverseerSettingsView.swift:11-24`, the parts plan 122 added for onboarding:

```swift
    /// Text shown above the screen's content, used when onboarding embeds it.
    var introduction: LocalizedStringKey? = nil

    var body: some View {
        List {
            if let introduction {
                Section {
                } header: {
                    Text(introduction)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
```

Settings calls `OverseerSettingsView()` (in `ReportSettingsView.swift:19`) and never passes an introduction. The screen saves four keys when a contact is picked: `UserDefaultsKeys.overseerFullName`, `.overseerPhoneNumber`, `.overseerFirstName` and `.overseerLastName`. The contact picker is `OverseerContactPicker` in `Hugo/Features/Reports/Views/OverseerPicker.swift`. Its callback gives `(fullName, phoneNumber, firstName, lastName)`. Use it unchanged.

### Reused without changes

- `PublisherStatusOptionsView(selection: Binding<String>, rowStyle: .card)` in `Hugo/Features/PublisherStatus/Screens/PublisherStatusOptionsView.swift` lists the three statuses as cards with a checkmark.
- `Motion` in `Hugo/DesignSystem/Motion/Motion.swift`: `Motion.presence` is `.smooth(duration: 0.3)` for "elements entering or leaving the layout". `.motion(_:value:)` applies an animation, and with Reduce Motion on it swaps in `.easeInOut(duration: 0.2)`.
- Tokens in `Hugo/DesignSystem/Theme/Theme.swift`: `HugoLayout.Spacing` (`tight` 4, `compact` 8, `regular` 12, `spacious` 16, `roomy` 20, `card` 24, `section` 32), `HugoLayout.CornerRadius.card` (32), `HugoLayout.Size.minimumHitTarget` (44), `HugoLayout.Typography.eyebrowTracking` (1.5), and the accent `.hugoAccent`.

### Patterns this plan copies

- Main button in a bottom bar, `Hugo/Features/Reports/Screens/SubmitReportView.swift:165-181`: `.buttonStyle(.glassProminent)`, `.tint(.hugoAccent)`, `.controlSize(.large)`, label `.frame(maxWidth: .infinity)`.
- Layout that stacks at accessibility text sizes, `Hugo/Features/Overview/Views/ReportReminderCard.swift:17-23`: an `AnyLayout` that is a `VStackLayout` when `dynamicTypeSize.isAccessibilitySize` and an `HStackLayout` otherwise.
- Serif heading marked as a header, `Hugo/Features/Overview/Screens/CarriedInBreakdownSheet.swift:17-19`: `.font(.system(.title2, design: .serif, weight: .bold))` and `.accessibilityAddTraits(.isHeader)`.
- Small uppercase label above a value, `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift:74-81`: `.font(.caption)`, `.textCase(.uppercase)`, `.tracking(HugoLayout.Typography.eyebrowTracking)`, `.fontWeight(.semibold)`, `.foregroundStyle(.secondary)`.

### Rules that apply (`AGENTS.md` sections 3, 6, 7 and 8)

- iOS 26+, Swift 6 with complete concurrency checking and main-actor default isolation. SwiftUI only. No `ObservableObject`, `@Published`, `@StateObject` or `@ObservedObject`.
- "The app should always explain itself" (users from about 13 to 70).
- Every Swift file in a feature lives in a role folder. `Screens` are destinations (pushed pages count). `Views` are components embedded in screens. `Domain` holds value types and logic, `nonisolated` where possible. A feature may use another feature's types (Onboarding uses `PublisherStatusOptionsView` and `OverseerContactPicker`), but Settings and Reports must never use Onboarding.
- `DesignSystem` names no feature type. The new token `rowSymbolWidth` is generic.
- Tests mirror the source folders and use Swift Testing (`import Testing`, `@Test`, `#expect`).
- Four-space indentation, lines up to 120 characters (`.swift-format`). Tabs fail the lint.
- The project uses synchronized folders: new files in `Hugo/` and `HugoTests/` join their targets without touching `Hugo.xcodeproj`.

### The string catalog

`Hugo/Resources/Localizable.xcstrings` is JSON that Xcode keeps sorted. Loading it with Python's `json` module and writing it back with `json.dumps(catalog, indent=2, separators=(",", " : "), ensure_ascii=False)`, keys in their existing order and no trailing newline, gives back the file byte for byte (the advisor checked this). The script in Step 1 relies on that.

Strings this plan keeps and uses: `splash.title` (Welcome to Hugo / Velkommen til Hugo), `splash.subtitle` (Danish: Din nye forkyndermakker), `splash.action.complete` (Let's Get Started / Lad os komme i gang!), `onboarding.action.continue`, `onboarding.action.skip`, `onboarding.step.%lld.%lld` (Step %1$lld of %2$lld / Trin %1$lld af %2$lld), `onboarding.overseer.introduction` (owner-approved 2026-11-15, unchanged), `report.overseer.pick` (Choose Group Overseer / Vælg gruppetjener) and `report.overseer.empty` (No group overseer selected / Ingen gruppetjener valgt).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict <files>` | exit 0, no output |
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Compile | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing -project Hugo.xcodeproj -scheme Debug -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/HugoBuild123 CODE_SIGNING_ALLOWED=NO > /tmp/build123.log 2>&1; echo "exit $?"` | `exit 0` (a few minutes) |
| Full gate | `Scripts/verify.sh > /tmp/verify123.log 2>&1; echo "exit $?"` | `exit 0` (about 5 minutes; use a 600000 ms timeout) |

Don't point the compile command or any other test run at the `Hugo Verify iOS 26.5` simulator. Only `Scripts/verify.sh` uses it.

## Suggested executor toolkit

- If the `write-swift` skill is available, use it for questions about Swift 6 concurrency or SwiftUI APIs. The code below already compiles, so you should not need it unless a STOP condition comes up.

## Scope

**In scope** (the only files you may change or create):

- `Hugo/Resources/Localizable.xcstrings` (14 keys added, 4 removed, 2 changed, by the script in Step 1)
- `Hugo/DesignSystem/Theme/Theme.swift` (one token)
- `Hugo/Features/Onboarding/Domain/OnboardingStep.swift` (rewrite)
- `HugoTests/Features/Onboarding/Domain/OnboardingStepTests.swift` (rewrite)
- `Hugo/Features/Onboarding/Views/OnboardingStepBar.swift` (rewrite)
- `Hugo/Features/Onboarding/Views/OnboardingPageLayout.swift` (create)
- `Hugo/Features/Onboarding/Views/OnboardingFeatureRow.swift` (create)
- `Hugo/Features/Onboarding/Screens/OnboardingWelcomePage.swift` (create)
- `Hugo/Features/Onboarding/Screens/OnboardingPublisherStatusPage.swift` (create)
- `Hugo/Features/Onboarding/Screens/OnboardingOverseerPage.swift` (create)
- `Hugo/Features/Onboarding/Screens/OnboardingView.swift` (rewrite)
- `Hugo/Features/Settings/Screens/OverseerSettingsView.swift` (remove the onboarding introduction)

**Out of scope** (do not touch, even though they look related):

- `Hugo/App/AppRootView.swift` and `DebugSettingsView.swift`. Onboarding still opens as a sheet through `OnboardingView(onComplete:)`.
- `UserDefaultsKeys.swift`, `SyncedSettings.swift` and `SettingsSyncService.swift`. No setting is added, renamed or synced differently.
- `PublisherStatusOptionsView.swift`, `PublisherStatusOptionRow.swift` and `OverseerPicker.swift`. They are reused as they are.
- `GreetingTemplateView.swift` and `ReportSettingsView.swift`.
- `Motion.swift`. No new motion token.
- `CONTEXT.md`. No new domain term.
- `Hugo.xcodeproj`, including `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`, which may show as modified by the owner. Never stage, commit, revert or stash it.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Stage files by explicit path. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Never stage anything under `plans/` or `.claude/`.
- One commit, in the repo's Conventional Commits style, ending with the trailer the recent commits use:

  ```
  feat: redesign onboarding with a welcome list and setup pages of its own

  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

## Steps

### Step 0: Preflight

1. Run the drift check at the top of this plan.
2. Run `git status --short`. Expected: no output, or only ` M Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Anything else, especially a modified `Hugo/Resources/Localizable.xcstrings`, is a STOP condition.

The project doesn't compile between Step 3 and Step 6, because the old `OnboardingStepBar` uses `OnboardingStep.number`, which Step 3 removes. Run only the lint checks until Step 7.

### Step 1: Update the string catalog

Save this script to a file outside the repository, for example `/tmp/catalog123.py`:

```python
import json
import sys

PATH = sys.argv[1] if len(sys.argv) > 1 else "Hugo/Resources/Localizable.xcstrings"

NEW = {
    "onboarding.cloudNote": (
        "Note on an onboarding setup page when its setting came from the user's other devices through iCloud.",
        "Filled in from your other devices through iCloud.",
        "Udfyldt fra dine andre enheder via iCloud.",
    ),
    "onboarding.overseer.change": (
        "Button on the onboarding group overseer page that opens Contacts to choose a different overseer.",
        "Choose Someone Else",
        "Vælg en anden",
    ),
    "onboarding.overseer.title": (
        "Title of the group overseer page in onboarding.",
        "Your group overseer",
        "Din gruppetjener",
    ),
    "onboarding.publisherStatus.explanation": (
        "Explanation under the title of the publisher status page in onboarding.",
        "Your status decides your hour goal, if you have one. Choose your status to continue. "
        "You can change it later in Settings.",
        "Din status bestemmer dit timemål, hvis du har et. Vælg din status for at fortsætte. "
        "Du kan ændre den senere i Indstillinger.",
    ),
    "onboarding.publisherStatus.title": (
        "Title of the publisher status page in onboarding.",
        "Your publisher status",
        "Din forkynderstatus",
    ),
    "onboarding.welcome.goal.detail": (
        'Sentence under "Follow your goal" on the onboarding welcome page.',
        "See how close you are to your goal, for the month and for the whole year.",
        "Se, hvor tæt du er på dit mål, både for måneden og for hele året.",
    ),
    "onboarding.welcome.goal.title": (
        "Title of the row about goals on the onboarding welcome page.",
        "Follow your goal",
        "Følg dit mål",
    ),
    "onboarding.welcome.log.detail": (
        'Sentence under "Log your time" on the onboarding welcome page.',
        "Add your time in service in a few taps, along with your Bible studies.",
        "Tilføj din tid i tjenesten med få tryk, sammen med dine bibelstudier.",
    ),
    "onboarding.welcome.log.title": (
        "Title of the row about logging time on the onboarding welcome page.",
        "Log your time",
        "Registrer din tid",
    ),
    "onboarding.welcome.plan.detail": (
        'Sentence under "Plan your month" on the onboarding welcome page.',
        "Choose the days you want to go out, and see how the month is going.",
        "Vælg de dage, hvor du vil i tjenesten, og se, hvordan måneden går.",
    ),
    "onboarding.welcome.plan.title": (
        "Title of the row about the Planner on the onboarding welcome page.",
        "Plan your month",
        "Planlæg din måned",
    ),
    "onboarding.welcome.privacy": (
        "Privacy line at the bottom of the onboarding welcome page. Matches the summary at the top of the "
        "privacy policy.",
        "Hugo doesn't collect anything about you. What you enter stays on your devices and in your own iCloud.",
        "Hugo indsamler ikke noget om dig. Det, du skriver, bliver på dine enheder og i din egen iCloud.",
    ),
    "onboarding.welcome.report.detail": (
        'Sentence under "Send your report" on the onboarding welcome page.',
        "When the month ends, Hugo writes your report, and you send it to your group overseer.",
        "Når måneden er slut, skriver Hugo din rapport, og du sender den til din gruppetjener.",
    ),
    "onboarding.welcome.report.title": (
        "Title of the row about sending the report on the onboarding welcome page.",
        "Send your report",
        "Send din rapport",
    ),
}

REMOVED = [
    "splash.description.1",
    "splash.description.2",
    "splash.section.publisherStatus.description",
    "splash.section.publisherStatus.title",
]

with open(PATH, encoding="utf-8") as f:
    catalog = json.load(f)
strings = catalog["strings"]

missing = [key for key in REMOVED if key not in strings]
existing = [key for key in NEW if key in strings]
subtitle = strings["splash.subtitle"]["localizations"]["en"]["stringUnit"]
if missing or existing or subtitle["value"] != "The app that *”Helps U Go Out”*":
    sys.exit(f"STOP: catalog differs from the plan. missing={missing} existing={existing} subtitle={subtitle['value']!r}")

for key in REMOVED:
    del strings[key]
strings["onboarding.step.%lld.%lld"]["comment"] = (
    'Step counter above the title of each onboarding setup page, for example "Step 1 of 2".'
)
subtitle["value"] = 'The app that *"Helps U Go Out"*'


def entry(comment, english, danish):
    return {
        "comment": comment,
        "localizations": {
            "da": {"stringUnit": {"state": "translated", "value": danish}},
            "en": {"stringUnit": {"state": "translated", "value": english}},
        },
    }


# Xcode keeps the keys sorted. Every other key keeps its place; the onboarding
# keys, old and new, are sorted (ignoring case) where the old ones were.
onboarding = sorted([key for key in strings if key.startswith("onboarding.")] + list(NEW), key=str.lower)
merged = {}
for key, value in strings.items():
    if not key.startswith("onboarding."):
        merged[key] = value
    elif not any(k in merged for k in onboarding):
        for k in onboarding:
            merged[k] = entry(*NEW[k]) if k in NEW else strings[k]
catalog["strings"] = merged

with open(PATH, "w", encoding="utf-8") as f:
    f.write(json.dumps(catalog, indent=2, separators=(",", " : "), ensure_ascii=False))
print("catalog updated:", len(NEW), "added,", len(REMOVED), "removed")
```

From the repository root, run `python3 -I /tmp/catalog123.py` once.

- Expected output: `catalog updated: 14 added, 4 removed`.
- If it prints a line starting with `STOP:`, the catalog has drifted. STOP and report the line. The script checks before it writes, so the file is unchanged.
- Don't run it a second time. A second run prints `STOP:` because the keys already exist.

**Verify**:

1. `git diff --shortstat Hugo/Resources/Localizable.xcstrings` → `1 file changed, 240 insertions(+), 74 deletions(-)`.
2. Run:

   ```sh
   python3 -I -c "import json;s=json.load(open('Hugo/Resources/Localizable.xcstrings',encoding='utf-8'))['strings'];print(sorted(k for k in s if k.startswith('onboarding.')));print([k for k in s if k.startswith('splash.')]);print(s['splash.subtitle']['localizations']['en']['stringUnit']['value'])"
   ```

   Expected, three lines:

   ```
   ['onboarding.action.continue', 'onboarding.action.skip', 'onboarding.cloudNote', 'onboarding.overseer.change', 'onboarding.overseer.introduction', 'onboarding.overseer.title', 'onboarding.publisherStatus.explanation', 'onboarding.publisherStatus.title', 'onboarding.step.%lld.%lld', 'onboarding.welcome.goal.detail', 'onboarding.welcome.goal.title', 'onboarding.welcome.log.detail', 'onboarding.welcome.log.title', 'onboarding.welcome.plan.detail', 'onboarding.welcome.plan.title', 'onboarding.welcome.privacy', 'onboarding.welcome.report.detail', 'onboarding.welcome.report.title']
   ['splash.action.complete', 'splash.subtitle', 'splash.title']
   The app that *"Helps U Go Out"*
   ```

If the shortstat differs only because other plans changed the catalog since `f1797ca` (the drift check allowed that), the key lists are what counts.

### Step 2: Add the symbol-column token

In `Hugo/DesignSystem/Theme/Theme.swift`, find this line inside `enum Size`:

```swift
        static let prominentSymbol: CGFloat = 64
```

and add these three lines directly after it:

```swift
        /// Width of the symbol column in rows of a symbol, a title and a
        /// sentence, so the text of stacked rows lines up.
        static let rowSymbolWidth: CGFloat = 40
```

**Verify**: `git diff --shortstat Hugo/DesignSystem/Theme/Theme.swift` → `1 file changed, 3 insertions(+)`. `xcrun swift-format lint --strict Hugo/DesignSystem/Theme/Theme.swift` → exit 0.

### Step 3: The steps and the cloud-note rule (Domain), with tests

Replace the whole of `Hugo/Features/Onboarding/Domain/OnboardingStep.swift` with exactly this content:

```swift
/// One page of the first-run setup, in order.
nonisolated enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case publisherStatus
    case overseer

    /// The page's number in "Step 1 of 2". The welcome page has none.
    var setupNumber: Int? {
        self == .welcome ? nil : rawValue
    }

    /// How many pages show "Step N of …": every page except the welcome page.
    static var setupCount: Int {
        allCases.filter { $0.setupNumber != nil }.count
    }

    /// The page after this one, or nil after the last page.
    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// Whether this page says that its setting came from the user's other
    /// devices through iCloud: the setting is filled in, and the user hasn't
    /// changed it during this onboarding. On a new install, a setting the user
    /// didn't enter can only have come from iCloud.
    func showsCloudNote(hasValue: Bool, changedSteps: Set<OnboardingStep>) -> Bool {
        hasValue && !changedSteps.contains(self)
    }
}
```

Replace the whole of `HugoTests/Features/Onboarding/Domain/OnboardingStepTests.swift` with exactly this content:

```swift
import Testing

@testable import Hugo

struct OnboardingStepTests {
    @Test
    func everyStepFollowsTheOneBefore() {
        #expect(OnboardingStep.welcome.next == .publisherStatus)
        #expect(OnboardingStep.publisherStatus.next == .overseer)
        #expect(OnboardingStep.overseer.next == nil)
    }

    @Test
    func onlyTheSetupPagesAreNumbered() {
        #expect(OnboardingStep.allCases.map(\.setupNumber) == [nil, 1, 2])
        #expect(OnboardingStep.setupCount == 2)
    }

    @Test
    func aFilledInSettingTheUserHasNotChangedShowsTheCloudNote() {
        #expect(OnboardingStep.publisherStatus.showsCloudNote(hasValue: true, changedSteps: []))
        #expect(OnboardingStep.overseer.showsCloudNote(hasValue: true, changedSteps: [.publisherStatus]))
    }

    @Test
    func anEmptyOrChangedSettingShowsNoCloudNote() {
        #expect(!OnboardingStep.publisherStatus.showsCloudNote(hasValue: false, changedSteps: []))
        #expect(!OnboardingStep.overseer.showsCloudNote(hasValue: true, changedSteps: [.overseer]))
    }
}
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Onboarding/Domain/OnboardingStep.swift HugoTests/Features/Onboarding/Domain/OnboardingStepTests.swift` → exit 0.

### Step 4: The shared views

Replace the whole of `Hugo/Features/Onboarding/Views/OnboardingStepBar.swift` with exactly this content. The counter leaves the bar, and the button uses the app's main button style:

```swift
import SwiftUI

/// The buttons at the bottom of every onboarding page: the main button and,
/// on optional steps, a skip button. `OnboardingView` puts it in a
/// `safeAreaBar`, so the page scrolls under it.
struct OnboardingStepBar: View {
    let isLast: Bool
    var canContinue = true
    var onSkip: (() -> Void)? = nil
    let onContinue: () -> Void

    private var continueTitle: LocalizedStringKey {
        isLast ? "splash.action.complete" : "onboarding.action.continue"
    }

    var body: some View {
        VStack(spacing: HugoLayout.Spacing.compact) {
            Button(action: onContinue) {
                Text(continueTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.hugoAccent)
            .controlSize(.large)
            .disabled(!canContinue)

            if let onSkip {
                Button("onboarding.action.skip", action: onSkip)
                    .frame(minHeight: HugoLayout.Size.minimumHitTarget)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, HugoLayout.Spacing.compact)
    }
}

#Preview {
    VStack {
        Spacer()
        OnboardingStepBar(isLast: false, canContinue: false, onSkip: {}, onContinue: {})
    }
}
```

Create `Hugo/Features/Onboarding/Views/OnboardingPageLayout.swift` with exactly this content:

```swift
import SwiftUI

/// The layout every onboarding page shares: the step counter (setup pages
/// only), a serif title, a short explanation, a note when the setting came
/// from iCloud, then the page's own content. It scrolls, so the pages work at
/// the largest text sizes. `OnboardingView` puts the buttons in a bar below it.
struct OnboardingPageLayout<Content: View>: View {
    private let step: OnboardingStep
    private let title: LocalizedStringKey
    private let explanation: LocalizedStringKey
    private let showsCloudNote: Bool
    private let content: Content

    init(
        step: OnboardingStep,
        title: LocalizedStringKey,
        explanation: LocalizedStringKey,
        showsCloudNote: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.step = step
        self.title = title
        self.explanation = explanation
        self.showsCloudNote = showsCloudNote
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.card) {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                    if let number = step.setupNumber {
                        Text("onboarding.step.\(number).\(OnboardingStep.setupCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                            .tracking(HugoLayout.Typography.eyebrowTracking)
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text(explanation)
                }

                if showsCloudNote {
                    Label("onboarding.cloudNote", systemImage: "icloud")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }

                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .motion(Motion.presence, value: showsCloudNote)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        OnboardingPageLayout(
            step: .publisherStatus,
            title: "onboarding.publisherStatus.title",
            explanation: "onboarding.publisherStatus.explanation",
            showsCloudNote: true
        ) {
            Text(verbatim: "Content")
        }
    }
}
```

Create `Hugo/Features/Onboarding/Views/OnboardingFeatureRow.swift` with exactly this content:

```swift
import SwiftUI

/// One row of the onboarding welcome page: a symbol, a short title and one
/// sentence. VoiceOver reads the row as one item. At accessibility text sizes
/// the symbol moves above the text, so the text keeps the full width.
struct OnboardingFeatureRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var symbolWidth: CGFloat = HugoLayout.Size.rowSymbolWidth

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: HugoLayout.Spacing.compact))
            : AnyLayout(HStackLayout(alignment: .center, spacing: HugoLayout.Spacing.spacious))
    }

    var body: some View {
        layout {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(.hugoAccent)
                .frame(width: symbolWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingFeatureRow(
        symbol: "calendar",
        title: "onboarding.welcome.plan.title",
        detail: "onboarding.welcome.plan.detail"
    )
    .padding()
}
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Onboarding/Views/OnboardingStepBar.swift Hugo/Features/Onboarding/Views/OnboardingPageLayout.swift Hugo/Features/Onboarding/Views/OnboardingFeatureRow.swift` → exit 0.

### Step 5: The pages

Create `Hugo/Features/Onboarding/Screens/OnboardingWelcomePage.swift` with exactly this content:

```swift
import SwiftUI

/// The first onboarding page: what Hugo does, in four rows, and that Hugo
/// collects nothing. The rows fade in one after another when the page opens.
/// With Reduce Motion on, they fade in together without moving.
struct OnboardingWelcomePage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingRows = false

    var body: some View {
        OnboardingPageLayout(step: .welcome, title: "splash.title", explanation: "splash.subtitle") {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.roomy) {
                appearing(0) {
                    OnboardingFeatureRow(
                        symbol: "clock",
                        title: "onboarding.welcome.log.title",
                        detail: "onboarding.welcome.log.detail"
                    )
                }
                appearing(1) {
                    OnboardingFeatureRow(
                        symbol: "calendar",
                        title: "onboarding.welcome.plan.title",
                        detail: "onboarding.welcome.plan.detail"
                    )
                }
                appearing(2) {
                    OnboardingFeatureRow(
                        symbol: "arrow.up.message",
                        title: "onboarding.welcome.report.title",
                        detail: "onboarding.welcome.report.detail"
                    )
                }
                appearing(3) {
                    OnboardingFeatureRow(
                        symbol: "target",
                        title: "onboarding.welcome.goal.title",
                        detail: "onboarding.welcome.goal.detail"
                    )
                }
                appearing(4) {
                    Label("onboarding.welcome.privacy", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // The setup pages start below their back button. This page has none,
        // so it gets the same space above its title.
        .contentMargins(.top, HugoLayout.Spacing.section, for: .scrollContent)
        .onAppear { isShowingRows = true }
    }

    /// Fades a row in after the rows above it, and slides it up a little
    /// unless Reduce Motion is on.
    private func appearing<Row: View>(_ index: Int, @ViewBuilder row: () -> Row) -> some View {
        row()
            .opacity(isShowingRows ? 1 : 0)
            .offset(y: isShowingRows || reduceMotion ? 0 : HugoLayout.Spacing.regular)
            .motion(Motion.presence.delay(Double(index) * 0.06), value: isShowingRows)
    }
}

#Preview {
    NavigationStack {
        OnboardingWelcomePage()
    }
}
```

Create `Hugo/Features/Onboarding/Screens/OnboardingPublisherStatusPage.swift` with exactly this content:

```swift
import SwiftUI

/// Onboarding step 1 of 2: the publisher status, which sets the user's goal.
/// `OnboardingView` keeps Continue off until a status is chosen.
struct OnboardingPublisherStatusPage: View {
    /// Whether to say that the status came from the user's other devices.
    let showsCloudNote: Bool
    /// Called when the user picks a status on this page.
    let onChange: () -> Void

    @AppStorage(UserDefaultsKeys.publisherStatus) private var currentStatus = ""

    /// The stored status. Setting it also calls `onChange`.
    private var selection: Binding<String> {
        Binding(
            get: { currentStatus },
            set: { newValue in
                currentStatus = newValue
                onChange()
            }
        )
    }

    var body: some View {
        OnboardingPageLayout(
            step: .publisherStatus,
            title: "onboarding.publisherStatus.title",
            explanation: "onboarding.publisherStatus.explanation",
            showsCloudNote: showsCloudNote
        ) {
            VStack(spacing: HugoLayout.Spacing.compact) {
                PublisherStatusOptionsView(selection: selection, rowStyle: .card)
            }
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingPublisherStatusPage(showsCloudNote: true, onChange: {})
    }
}
```

Create `Hugo/Features/Onboarding/Screens/OnboardingOverseerPage.swift` with exactly this content:

```swift
import SwiftUI

/// Onboarding step 2 of 2: the group overseer, chosen from Contacts. It saves
/// the same settings as Settings → Report → Group Overseer
/// (`OverseerSettingsView`). `OnboardingView` offers Skip for Now while no
/// overseer is chosen.
struct OnboardingOverseerPage: View {
    /// Whether to say that the overseer came from the user's other devices.
    let showsCloudNote: Bool
    /// Called when the user picks an overseer on this page.
    let onChange: () -> Void

    @AppStorage(UserDefaultsKeys.overseerFullName) private var fullName = ""
    @AppStorage(UserDefaultsKeys.overseerPhoneNumber) private var phoneNumber = ""
    @AppStorage(UserDefaultsKeys.overseerFirstName) private var firstName = ""
    @AppStorage(UserDefaultsKeys.overseerLastName) private var lastName = ""

    @State private var isPickingContact = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var pickTitle: LocalizedStringKey {
        fullName.isEmpty ? "report.overseer.pick" : "onboarding.overseer.change"
    }

    /// The symbol beside the name normally, and above it at accessibility
    /// text sizes, so the name keeps the card's full width.
    private var nameLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: HugoLayout.Spacing.compact))
            : AnyLayout(HStackLayout(alignment: .center, spacing: HugoLayout.Spacing.regular))
    }

    var body: some View {
        OnboardingPageLayout(
            step: .overseer,
            title: "onboarding.overseer.title",
            explanation: "onboarding.overseer.introduction",
            showsCloudNote: showsCloudNote
        ) {
            card
        }
        .sheet(isPresented: $isPickingContact) {
            OverseerContactPicker { pickedFullName, pickedPhone, pickedFirst, pickedLast in
                fullName = pickedFullName
                phoneNumber = pickedPhone
                firstName = pickedFirst
                lastName = pickedLast
                isPickingContact = false
                onChange()
            }
            .ignoresSafeArea()
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.spacious) {
            nameLayout {
                Image(systemName: fullName.isEmpty ? "person.crop.circle" : "person.crop.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(fullName.isEmpty ? Color.secondary : Color.hugoAccent)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                    Text(fullName.isEmpty ? String(localized: "report.overseer.empty") : fullName)
                        .font(.headline)
                    if !fullName.isEmpty, !phoneNumber.isEmpty {
                        Text(phoneNumber)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            Button {
                isPickingContact = true
            } label: {
                Text(pickTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .padding(HugoLayout.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        .motion(Motion.presence, value: fullName)
    }
}

#Preview {
    NavigationStack {
        OnboardingOverseerPage(showsCloudNote: false, onChange: {})
    }
}
```

Replace the whole of `Hugo/Features/Onboarding/Screens/OnboardingView.swift` with exactly this content:

```swift
import SwiftUI

/// The first-run setup: a welcome page, then one page per setting, pushed in
/// a navigation stack so the user can go back.
struct OnboardingView: View {
    let onComplete: () -> Void

    @AppStorage(UserDefaultsKeys.publisherStatus) private var currentStatus = ""
    @AppStorage(UserDefaultsKeys.overseerFullName) private var overseerFullName = ""

    @State private var path: [OnboardingStep] = []
    /// The steps whose setting the user changed during this onboarding. It
    /// lives here, not in the pages, because going back and forward again
    /// creates a page anew.
    @State private var changedSteps: Set<OnboardingStep> = []

    var body: some View {
        NavigationStack(path: $path) {
            page(for: .welcome)
                .navigationDestination(for: OnboardingStep.self) { step in
                    page(for: step)
                }
        }
        .interactiveDismissDisabled(true)
    }

    private func advance(from step: OnboardingStep) {
        if let next = step.next {
            path.append(next)
        } else {
            onComplete()
        }
    }

    private func markChanged(_ step: OnboardingStep) {
        changedSteps.insert(step)
    }

    @ViewBuilder
    private func page(for step: OnboardingStep) -> some View {
        let isLast = step.next == nil
        switch step {
        case .welcome:
            OnboardingWelcomePage()
                .safeAreaBar(edge: .bottom) {
                    OnboardingStepBar(isLast: isLast) { advance(from: step) }
                }
        case .publisherStatus:
            OnboardingPublisherStatusPage(
                showsCloudNote: step.showsCloudNote(hasValue: !currentStatus.isEmpty, changedSteps: changedSteps),
                onChange: { markChanged(step) }
            )
            .safeAreaBar(edge: .bottom) {
                OnboardingStepBar(isLast: isLast, canContinue: !currentStatus.isEmpty) {
                    advance(from: step)
                }
            }
        case .overseer:
            OnboardingOverseerPage(
                showsCloudNote: step.showsCloudNote(hasValue: !overseerFullName.isEmpty, changedSteps: changedSteps),
                onChange: { markChanged(step) }
            )
            .safeAreaBar(edge: .bottom) {
                OnboardingStepBar(
                    isLast: isLast,
                    canContinue: !overseerFullName.isEmpty,
                    onSkip: overseerFullName.isEmpty ? { advance(from: step) } : nil
                ) {
                    advance(from: step)
                }
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
```

Notes for the executor:

- `safeAreaBar(edge:)` is iOS 26 API and replaces the old `safeAreaInset(edge:)`. Keep it. It gives the system's scroll edge effect under the buttons.
- `changedSteps` lives in `OnboardingView` on purpose. If a page kept it, going back and forward again would forget it, and the page would wrongly claim that a value the user just picked came from iCloud.
- The welcome page's `.contentMargins(.top, …)` is there because iOS hides an empty navigation bar. The other pages get their top space from the bar that holds their back button.

**Verify**:

- `xcrun swift-format lint --strict Hugo/Features/Onboarding/Screens/OnboardingWelcomePage.swift Hugo/Features/Onboarding/Screens/OnboardingPublisherStatusPage.swift Hugo/Features/Onboarding/Screens/OnboardingOverseerPage.swift Hugo/Features/Onboarding/Screens/OnboardingView.swift` → exit 0.
- `grep -c "OnboardingView {" Hugo/App/AppRootView.swift` → `1` (the call site is unchanged).
- `grep -rn "safeAreaInset\|splash.description\|splash.section\|\.number\b\|OnboardingStep.count" Hugo/Features/Onboarding` → no output.

### Step 6: Remove the onboarding introduction from the Settings screen

Replace the whole of `Hugo/Features/Settings/Screens/OverseerSettingsView.swift` with exactly this content. It is the file as it was before plan 122:

```swift
import SwiftUI

struct OverseerSettingsView: View {
    @AppStorage(UserDefaultsKeys.overseerFullName) private var fullName = ""
    @AppStorage(UserDefaultsKeys.overseerPhoneNumber) private var phoneNumber = ""
    @AppStorage(UserDefaultsKeys.overseerFirstName) private var firstName = ""
    @AppStorage(UserDefaultsKeys.overseerLastName) private var lastName = ""

    @State private var isPickingContact = false

    var body: some View {
        List {
            if !fullName.isEmpty {
                Section {
                    Label(fullName, systemImage: "person.crop.circle")
                    Label(phoneNumber, systemImage: "phone")
                }
            }

            Section {
                Button("report.overseer.pick") {
                    isPickingContact = true
                }

                if !fullName.isEmpty {
                    Button("report.overseer.clear", role: .destructive) {
                        fullName = ""
                        phoneNumber = ""
                        firstName = ""
                        lastName = ""
                    }
                }
            }
        }
        .navigationTitle("settings.report.overseer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPickingContact) {
            OverseerContactPicker { pickedFullName, pickedPhone, pickedFirst, pickedLast in
                fullName = pickedFullName
                phoneNumber = pickedPhone
                firstName = pickedFirst
                lastName = pickedLast
                isPickingContact = false
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    NavigationStack {
        OverseerSettingsView()
    }
}
```

**Verify**:

- `git diff --shortstat Hugo/Features/Settings/Screens/OverseerSettingsView.swift` → `1 file changed, 13 deletions(-)` (only lines removed).
- `grep -rn "introduction" Hugo --include='*.swift'` → exactly one line, in `OnboardingOverseerPage.swift`: `explanation: "onboarding.overseer.introduction",`.
- `xcrun swift-format lint --strict Hugo/Features/Settings/Screens/OverseerSettingsView.swift` → exit 0.

### Step 7: Compile and check the layout

**Verify**:

- `Scripts/check-layout.sh` → exit 0, no output.
- The compile command from "Commands you will need" → `exit 0`. Then `grep -c "error:" /tmp/build123.log` → `0`.

If the compile fails, read the first `error:` line in `/tmp/build123.log`. A typo against the code in this plan is yours to fix. Anything else is a STOP condition.

### Step 8: Run the gate and commit

**Verify**: `Scripts/verify.sh > /tmp/verify123.log 2>&1; echo "exit $?"` → `exit 0`. `grep -E "Suite OnboardingStepTests|Test run with" /tmp/verify123.log` → `OnboardingStepTests` passed, and the test run passed with no failures.

Then commit the twelve in-scope files by path:

```sh
git add Hugo/Resources/Localizable.xcstrings Hugo/DesignSystem/Theme/Theme.swift \
    Hugo/Features/Onboarding/Domain/OnboardingStep.swift \
    HugoTests/Features/Onboarding/Domain/OnboardingStepTests.swift \
    Hugo/Features/Onboarding/Views/OnboardingStepBar.swift \
    Hugo/Features/Onboarding/Views/OnboardingPageLayout.swift \
    Hugo/Features/Onboarding/Views/OnboardingFeatureRow.swift \
    Hugo/Features/Onboarding/Screens/OnboardingWelcomePage.swift \
    Hugo/Features/Onboarding/Screens/OnboardingPublisherStatusPage.swift \
    Hugo/Features/Onboarding/Screens/OnboardingOverseerPage.swift \
    Hugo/Features/Onboarding/Screens/OnboardingView.swift \
    Hugo/Features/Settings/Screens/OverseerSettingsView.swift
git commit -m "feat: redesign onboarding with a welcome list and setup pages of its own" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

The pre-commit hook formats staged Swift files. The code above is already formatted, so it should change nothing.

**Verify**: `git show --stat --format= HEAD` lists exactly those 12 files. `git status --short` shows nothing, or only the owner's `Debug.xcscheme`.

## Test plan

- `OnboardingStepTests` (rewritten, four tests):
  - `everyStepFollowsTheOneBefore`: welcome → publisher status → overseer → done.
  - `onlyTheSetupPagesAreNumbered`: `setupNumber` is `nil, 1, 2` and `setupCount` is 2, so the counter reads "Step 1 of 2" and "Step 2 of 2".
  - `aFilledInSettingTheUserHasNotChangedShowsTheCloudNote`: a filled-in setting shows the note, also when another step was changed.
  - `anEmptyOrChangedSettingShowsNoCloudNote`: no note for an empty setting, and none after the user changed it.
- The pages are views. The owner checks them on a device (below).
- Verification: `Scripts/verify.sh` exits 0, and its log shows `OnboardingStepTests` passing.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with all four `OnboardingStepTests` passing.
- [ ] `git show --stat --format= HEAD` lists exactly the 12 in-scope files.
- [ ] `git diff --stat f1797ca..HEAD -- Hugo/App Hugo/Features/PublisherStatus Hugo/Features/Reports Hugo/Domain Hugo/DesignSystem/Motion` → no output.
- [ ] `grep -rn "Onboarding" Hugo/Features/Settings Hugo/Features/Reports --include='*.swift'` → only the two existing `isOnboarding` lines in `DebugSettingsView.swift` (lines 7 and 14). No Settings or Reports file uses an Onboarding type.
- [ ] `grep -rn "splash.description\|splash.section" Hugo` → no output, in the code and in the catalog.
- [ ] `plans/README.md` status row updated (unless the reviewer maintains it).

## STOP conditions

Stop and report, without improvising, if:

- The drift check shows changes beyond other plans' own catalog keys.
- `git status --short` shows a modified file other than the owner's `Debug.xcscheme` before you start.
- The catalog script prints a line starting with `STOP:`.
- The compile fails on anything other than a typo against this plan. In particular, don't swap `safeAreaBar` back to `safeAreaInset`, don't replace `.glassProminent` or `.glass` with another style, and don't change the `OnboardingPageLayout` initializer to make an error go away. Report the error text.
- A step's lint fails twice after you fixed what it reported.
- `Scripts/verify.sh` fails twice. Report the failing test names from `/tmp/verify123.log`.
- The work seems to need a change in an out-of-scope file, such as `AppRootView.swift`, `PublisherStatusOptionsView.swift` or `OverseerPicker.swift`.

## Owner checks

Do these on devices with the Debug build. Settings → Debugging → reset onboarding shows it again.

1. **New user.** Use a simulator with no Apple Account signed in, or a fresh install with no iCloud settings. The welcome page shows the title, the subtitle `The app that "Helps U Go Out"`, four rows and the privacy line. The rows fade in one after another. Continue leads to "STEP 1 OF 2". Continue stays off until a status is picked, and no iCloud line shows. Then "STEP 2 OF 2": the card says "No group overseer selected". "Choose Group Overseer" opens Contacts. After you pick someone, the card shows their name and phone number, and the button reads "Choose Someone Else". Skip for Now shows only while no one is chosen. "Let's Get Started" closes onboarding. Back works on every page.
2. **Danish.** Repeat item 1 in Danish and read the new texts: "Registrer din tid", "Tilføj din tid i tjenesten med få tryk, sammen med dine bibelstudier.", "Planlæg din måned", "Vælg de dage, hvor du vil i tjenesten, og se, hvordan måneden går.", "Send din rapport", "Når måneden er slut, skriver Hugo din rapport, og du sender den til din gruppetjener.", "Følg dit mål", "Se, hvor tæt du er på dit mål, både for måneden og for hele året.", "Hugo indsamler ikke noget om dig. Det, du skriver, bliver på dine enheder og i din egen iCloud.", "Din forkynderstatus", "Din status bestemmer dit timemål, hvis du har et. Vælg din status for at fortsætte. Du kan ændre den senere i Indstillinger.", "Din gruppetjener", "Vælg en anden" and "Udfyldt fra dine andre enheder via iCloud." The counter reads "TRIN 1 AF 2".
3. **Second device.** With your status and overseer set on the iPhone, delete Hugo (Debug) from the iPad and install it again. On both setup pages, the value is filled in and the line "Filled in from your other devices through iCloud." shows. It may appear a few seconds after the page opens, when iCloud delivers the settings. Continue works straight away, and Skip for Now doesn't show. Pick another status: the line goes away. Go back and forward again: it stays away.
4. **Largest text size** (Settings → Accessibility → Display & Text Size → Larger Text, largest size). Every page scrolls. The welcome rows and the overseer card put the symbol above the text. The buttons stay at the bottom over the scrolling page, and no text is cut off.
5. **VoiceOver.** On each setup page you hear the step, the title (as a heading), the explanation, the iCloud line when it shows, the choices, then Continue and Skip for Now. Each welcome row reads as one item. Status cards read as selected when picked.
6. **Reduce Motion** (Settings → Accessibility → Motion). The welcome rows fade in together without sliding. The change of page is the system's. With Prefer Cross-Fade Transitions also on, check whether pages fade instead of sliding. Either result is the system's behavior, and Hugo adds no page animation of its own.
7. **Settings.** Settings → Report → Group Overseer looks exactly as before, with no introduction text.
8. **iPad.** The onboarding sheet looks right in portrait and in landscape.

The iCloud line also shows after the debug menu's "reset onboarding", because the settings are still on the device. That is expected, and only builds with the debug menu can do it.

## Maintenance notes

- **The overseer is saved in two places.** `OverseerSettingsView` and `OnboardingOverseerPage` both write the four overseer keys from `OverseerContactPicker`. If the stored overseer fields change, change both.
- **The publisher status timeline (SLN-227)** will move the status into SwiftData. The onboarding status page then has to write the first timeline row instead of the `publisherStatus` key, and `OnboardingView` has to read the status from there for Continue and the iCloud line. The iCloud line's rule (`OnboardingStep.showsCloudNote`) stays the same.
- **To add a step**, add a case to `OnboardingStep` in its place, write its page in `Screens` on top of `OnboardingPageLayout`, add it to `OnboardingView.page(for:)`, and update `onlyTheSetupPagesAreNumbered`. If the new page is optional, pass `onSkip` like the overseer page.
- **The welcome rows describe features.** If a feature is renamed or removed (for example the Planner), update its row and its strings.
- **An early pick can be replaced by iCloud.** If the user picks a status before the device's first iCloud download arrives, `SettingsSyncService` then writes the iCloud value over it (plan 118: iCloud wins at launch). This plan doesn't change that. The page shows the new value, without the iCloud line, because the user changed that step.
- **Button contrast, app-wide.** White text on the mint `.glassProminent` button has low contrast in light mode. It is the same button the rest of the app uses, so this plan keeps it. Consider a separate issue if the owner wants to change the accent button for older users.
- **What a reviewer should check:** every hunk matches a step; `AppRootView.swift` is untouched; the catalog diff adds the 14 keys, removes the 4 `splash.*` keys and changes only `onboarding.step.%lld.%lld`'s comment and the English `splash.subtitle`.

## Revision 1 (2026-11-15, after the owner's device check)

> **Execute only this revision.** Steps 0-8 are done (commit `8c4e95f`). Drift check for this revision:
> `git diff --stat 8c4e95f..HEAD -- Hugo/Features/Onboarding HugoTests/Features/Onboarding`
> Expected: no output. Otherwise STOP.

### What the owner saw

The four rows on the welcome page didn't animate in. They were already there when the sheet arrived.

### Why (advisor, confirmed with a simulator recording)

`.onAppear` runs when the sheet starts sliding up, not when it stops. The rows waited 0, 0.06, 0.12, 0.18 and 0.24 seconds, then faded in over 0.3 seconds, all while the sheet was still moving up the screen. Frame by frame (one frame every 0.05 s), every row was fully visible by the time the sheet stopped, so the sheet's own movement hid the animation. The code did what the plan said. The plan didn't allow for the sheet.

### Decision (advisor default, checked in a second recording; the owner can tune the numbers)

- The first row waits 0.45 s after the page appears, which is after the sheet has stopped. The rows then start 0.08 s apart (was 0.06 s).
- Each row rises 20 pt (`HugoLayout.Spacing.roomy`, was 12 pt, `HugoLayout.Spacing.regular`) while it fades in, so the movement is visible.
- Reduce Motion behaves as before. The `.motion` modifier swaps in its own short fade without the delay, so the rows appear together with the page and don't move.
- In the recording of this version, the sheet slides up with only the title and the subtitle, stops, and about 0.2 s later the rows fade in and rise one after another. The cascade ends about 0.6 s after the sheet stops.

### Scope of this revision

- `Hugo/Features/Onboarding/Screens/OnboardingWelcomePage.swift` (the only file)

Commit message:

```
fix: start the onboarding welcome rows' animation after the sheet has slid up

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Step R1: Replace the welcome page

Replace the whole of `Hugo/Features/Onboarding/Screens/OnboardingWelcomePage.swift` with exactly this content. Read the file first, because the Write tool refuses to overwrite a file you haven't read.

```swift
import SwiftUI

/// The first onboarding page: what Hugo does, in four rows, and that Hugo
/// collects nothing. Once the sheet has slid up, the rows fade in and rise one
/// after another. With Reduce Motion on, they fade in together as the page
/// opens, without moving.
struct OnboardingWelcomePage: View {
    /// How long the rows wait after the page appears. The sheet slides up
    /// during that time, and its movement would hide the rows' animation.
    private static let firstRowDelay: Double = 0.45
    /// The time between one row starting and the next.
    private static let rowStagger: Double = 0.08

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingRows = false

    var body: some View {
        OnboardingPageLayout(step: .welcome, title: "splash.title", explanation: "splash.subtitle") {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.roomy) {
                appearing(0) {
                    OnboardingFeatureRow(
                        symbol: "clock",
                        title: "onboarding.welcome.log.title",
                        detail: "onboarding.welcome.log.detail"
                    )
                }
                appearing(1) {
                    OnboardingFeatureRow(
                        symbol: "calendar",
                        title: "onboarding.welcome.plan.title",
                        detail: "onboarding.welcome.plan.detail"
                    )
                }
                appearing(2) {
                    OnboardingFeatureRow(
                        symbol: "arrow.up.message",
                        title: "onboarding.welcome.report.title",
                        detail: "onboarding.welcome.report.detail"
                    )
                }
                appearing(3) {
                    OnboardingFeatureRow(
                        symbol: "target",
                        title: "onboarding.welcome.goal.title",
                        detail: "onboarding.welcome.goal.detail"
                    )
                }
                appearing(4) {
                    Label("onboarding.welcome.privacy", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // The setup pages start below their back button. This page has none,
        // so it gets the same space above its title.
        .contentMargins(.top, HugoLayout.Spacing.section, for: .scrollContent)
        .onAppear { isShowingRows = true }
    }

    /// Fades a row in after the rows above it, and slides it up a little
    /// unless Reduce Motion is on.
    private func appearing<Row: View>(_ index: Int, @ViewBuilder row: () -> Row) -> some View {
        row()
            .opacity(isShowingRows ? 1 : 0)
            .offset(y: isShowingRows || reduceMotion ? 0 : HugoLayout.Spacing.roomy)
            .motion(
                Motion.presence.delay(Self.firstRowDelay + Double(index) * Self.rowStagger),
                value: isShowingRows
            )
    }
}

#Preview {
    NavigationStack {
        OnboardingWelcomePage()
    }
}
```

Compared with the version from Step 5, three things change: the type's doc comment, the two new constants `firstRowDelay` and `rowStagger`, and the `offset` and `motion` lines in `appearing`.

**Verify**:

- `git diff --shortstat Hugo/Features/Onboarding/Screens/OnboardingWelcomePage.swift` → `1 file changed, 14 insertions(+), 4 deletions(-)`.
- `xcrun swift-format lint --strict Hugo/Features/Onboarding/Screens/OnboardingWelcomePage.swift` → exit 0.

### Step R2: Run the gate and commit

**Verify**: `Scripts/verify.sh > /tmp/verify123r1.log 2>&1; echo "exit $?"` → `exit 0` (about 5 minutes; use a 600000 ms timeout). `grep -E "Test run with" /tmp/verify123r1.log` → the test run passed.

Commit only that file, by path:

```sh
git add Hugo/Features/Onboarding/Screens/OnboardingWelcomePage.swift
git commit -m "fix: start the onboarding welcome rows' animation after the sheet has slid up" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

**Verify**: `git show --stat --format= HEAD` lists only `Hugo/Features/Onboarding/Screens/OnboardingWelcomePage.swift`. `git status --short` shows nothing, or only the owner's `Debug.xcscheme`.

### STOP conditions for this revision

- The drift check prints anything.
- `git status --short` shows a modified file other than the owner's `Debug.xcscheme` before you start.
- Lint fails twice, the compile inside `verify.sh` fails, or `verify.sh` fails twice. Report the error text or the failing test names.

### Owner check for this revision

On the iPhone, reset onboarding from the debug menu. The sheet slides up showing only "Welcome to Hugo" and the subtitle. Just after it stops, the four rows and the privacy line fade in and rise one after another. Go to step 1 and back: the rows stay where they are, because they animate only once. With Reduce Motion on, the rows appear with the page and don't move.

### Maintenance note for this revision

`firstRowDelay` (0.45 s) assumes the welcome page arrives in a sliding sheet. If onboarding is ever shown without one, shorten it, or the page sits half empty for a moment.
