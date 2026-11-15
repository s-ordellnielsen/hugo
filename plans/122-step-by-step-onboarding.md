# Plan 122: Replace the onboarding sheet with a step-by-step setup that also sets up the group overseer and greeting

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat d2d87d5..HEAD -- Hugo/Features/Onboarding Hugo/Features/Settings/Screens/OverseerSettingsView.swift Hugo/Features/Settings/Screens/GreetingTemplateView.swift Hugo/Features/PublisherStatus Hugo/Resources/Localizable.xcstrings`
> Expected: only plans 120 and 121's additions to `Localizable.xcstrings`
> (`settings.appStore.*` and `settings.sync.*` keys). Anything else is a
> mismatch: compare with the excerpts below and STOP if they differ.

## Status

- **Priority**: P2
- **Effort**: M + owner (walk through it on a device, in both languages and at a large text size)
- **Risk**: MED. Every new user sees this first. It reuses existing Settings screens and keeps `OnboardingView(onComplete:)` as the entry point, so `AppRootView` doesn't change.
- **Depends on**: 120, 121 (all three edit the string catalog; run them in order)
- **Category**: direction
- **Planned at**: commit `d2d87d5`, 2026-11-14
- **Issue**: [SLN-220](https://linear.app/sebastianln/issue/SLN-220)

## Why this matters

Today's onboarding is one sheet: a welcome text and the publisher status. A new user leaves it with no group overseer and the default greeting. Their first report then has no recipient until they find Settings → Report on their own. Many users are older and won't go looking. After this plan, onboarding is four short pages, one task each, with a step counter:

1. **Welcome**: what Hugo does.
2. **Publisher status**: required, as today.
3. **Group overseer**: choose them from Contacts, or skip.
4. **Greeting**: keep the suggestion or write your own, with a live preview that uses the overseer's name.

Owner decisions (2026-11-14):
- One step per page, each one skippable except the publisher status (the goals depend on it).
- **Reuse the Settings screens** for the overseer and the greeting, so each setting has one screen and one source of truth.
- **Skip steps iCloud already filled in.** Since plan 118, the overseer and greeting sync between devices. On a new device that already has them, those pages are skipped.
- The rounding-rule and goal steps from the old issue text are dropped. Rounding is chosen per line when the report is submitted, and the goal follows from the publisher status.
- No iOS 27 onboarding requirement exists. (Checked 2026-11-14: the only new iOS 27 rule is the launch screen key, which Hugo already has.)

## Current state

`Hugo/Features/Onboarding/Screens/OnboardingView.swift` (whole file, 66 lines):

```swift
import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UserDefaultsKeys.publisherStatus) var currentStatus: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.spacious) {
                    Text("splash.subtitle")
                        .padding(.horizontal, HugoLayout.Spacing.tight)
                    Text("splash.description.1")
                        .padding(.horizontal, HugoLayout.Spacing.tight)
                    Text("splash.description.2")
                        .padding(.horizontal, HugoLayout.Spacing.tight)

                    VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                        Text("splash.section.publisherStatus.title")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal, HugoLayout.Spacing.tight)
                        Text("splash.section.publisherStatus.description")
                            .font(.caption)
                            .padding(.horizontal, HugoLayout.Spacing.tight)

                        VStack(spacing: HugoLayout.Spacing.compact) {
                            PublisherStatusOptionsView(selection: $currentStatus, rowStyle: .card)
                        }
                        .padding(.top, HugoLayout.Spacing.spacious)
                    }
                    .padding(.top, HugoLayout.Spacing.section)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("splash.title")
            .safeAreaInset(edge: .bottom) {
                Button {
                    onComplete()
                } label: {
                    Label(
                        "splash.action.complete",
                        systemImage: "arrow.right"
                    )
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.hugoAccent)
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.compactCard))
                }
                .disabled(currentStatus == "")
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled(true)
    }

}

#Preview {
    OnboardingView(onComplete: {})
}
```

It is presented from `Hugo/App/AppRootView.swift`: `.sheet(isPresented: $needsOnboarding) { OnboardingView { needsOnboarding = false } }`, where `needsOnboarding` is `@AppStorage(UserDefaultsKeys.isOnboarding)` with default `true`. The debug menu (`DebugSettingsView`) can set it back to `true` to show onboarding again. **Keep the `OnboardingView(onComplete:)` initializer exactly as it is**, so `AppRootView` doesn't change.

Existing strings (English | Danish) that stay in use:
- `splash.title`: Welcome to Hugo | Velkommen til Hugo
- `splash.subtitle`: The app that *"Helps U Go Out"* | Din nye forkyndermakker
- `splash.description.1`: Hugo helps you keep track of your report so you can focus on your field service. | Hugo hjælper dig med at holde styr på din rapport, så du kan fokusere på din tjeneste
- `splash.description.2`: But before we begin, we need to know a bit about you | Men før vi begynder, har vi brug for lidt informationer om dig
- `splash.section.publisherStatus.title`: Publisher Status | Forkynderstatus
- `splash.section.publisherStatus.description`: Please select your current publisher status below | Vælg venligst din nuværende forkynderstatus herunder
- `splash.action.complete`: Let's Get Started | Lad os komme i gang!

`Hugo/Features/PublisherStatus/Screens/PublisherStatusOptionsView.swift` takes `@Binding var selection: String` and `let rowStyle: PublisherStatusOptionRow.Style` and lists every status. Don't change it.

`Hugo/Features/Settings/Screens/OverseerSettingsView.swift` (54 lines) is a `List` that shows the chosen overseer, a "Choose Group Overseer" button that opens `OverseerContactPicker` in a sheet, and a remove button. It reads `@AppStorage(UserDefaultsKeys.overseerFullName) private var fullName = ""` and three more overseer keys. Its body starts:

```swift
struct OverseerSettingsView: View {
    @AppStorage(UserDefaultsKeys.overseerFullName) private var fullName = ""
    @AppStorage(UserDefaultsKeys.overseerPhoneNumber) private var phoneNumber = ""
    @AppStorage(UserDefaultsKeys.overseerFirstName) private var firstName = ""
    @AppStorage(UserDefaultsKeys.overseerLastName) private var lastName = ""

    @State private var isPickingContact = false

    var body: some View {
        List {
            if !fullName.isEmpty {
```

`Hugo/Features/Settings/Screens/GreetingTemplateView.swift` (66 lines) is a `List` with a `TextField` bound to `@AppStorage(UserDefaultsKeys.overseerGreetingTemplate) private var template = ""` and a live preview that uses the overseer's first name. Its body starts:

```swift
    var body: some View {
        List {
            Section {
                TextField("report.greeting.default", text: $template, axis: .vertical)
```

Both screens set their own `.navigationTitle` and are pushed inside a `NavigationStack` from Settings. Both use synthesized initializers today (`OverseerSettingsView()`, `GreetingTemplateView()`).

Rules that apply (`AGENTS.md` sections 6 and 7):
- "The app should always explain itself" (users from about 13 to 70).
- Feature role folders: `Screens` (destinations), `Views` (embedded components), `Domain` (value types and logic, `nonisolated` where possible). Create a role folder when its first file arrives. A feature may use another feature's views (Onboarding may use Settings screens). No circular dependencies: Settings must not use Onboarding.
- Tests mirror the source folders and use Swift Testing (`import Testing`, `@Test`, `#expect`).
- Layout tokens exist as `HugoLayout.Spacing.tight`, `.compact`, `.spacious`, `.section` and `HugoLayout.CornerRadius.compactCard` (all used in the file above). The accent color is `.hugoAccent`.

Strings go in `Hugo/Resources/Localizable.xcstrings`: JSON, two-space indentation, keys in sorted position, `en` and `da` both `"state" : "translated"`, with a `comment`. Copy the shape of an existing key such as `settings.account.shareTestFlight`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `xcrun swift-format lint --strict <changed Swift files>` | exit 0, no output |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |
| Layout | `Scripts/check-layout.sh` | exit 0, no output |
| Full gate | `Scripts/verify.sh > /tmp/verify122.log 2>&1; echo "exit $?"` | `exit 0` (about 5 minutes; 600000 ms timeout) |

## Scope

**In scope**:
- `Hugo/Features/Onboarding/Domain/OnboardingStep.swift` (create)
- `Hugo/Features/Onboarding/Views/OnboardingStepBar.swift` (create)
- `Hugo/Features/Onboarding/Screens/OnboardingView.swift` (rewrite)
- `HugoTests/Features/Onboarding/Domain/OnboardingStepTests.swift` (create)
- `Hugo/Features/Settings/Screens/OverseerSettingsView.swift` (an optional introduction)
- `Hugo/Features/Settings/Screens/GreetingTemplateView.swift` (an optional introduction)
- `Hugo/Resources/Localizable.xcstrings` (five new keys)

**Out of scope**:
- `Hugo/App/AppRootView.swift`, `DebugSettingsView.swift` and `UserDefaultsKeys.swift`.
- `PublisherStatusOptionsView` and `PublisherStatusOptionRow`.
- Removing or rewording the existing `splash.*` strings.
- Notifications, rounding or goal steps.
- `Hugo.xcodeproj` and `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` (uncommitted change by the owner; never stage, commit, revert or stash it).

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage `plans/`, `.claude/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage files by explicit path.
- One commit: `feat: set up the group overseer and greeting in a step-by-step onboarding`

## Steps

### Step 1: The steps and the skipping rule (Domain)

Create `Hugo/Features/Onboarding/Domain/OnboardingStep.swift`:

```swift
/// One page of the first-run setup, in order.
nonisolated enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case publisherStatus
    case overseer
    case greeting

    /// The step's position for "Step 2 of 4", starting at 1.
    var number: Int { rawValue + 1 }

    static var count: Int { allCases.count }

    /// The page after this one. Pages for settings that already exist, for
    /// example synced from the user's other devices, are skipped. Nil means
    /// the setup is finished.
    func next(hasOverseer: Bool, hasGreeting: Bool) -> OnboardingStep? {
        var candidate = OnboardingStep(rawValue: rawValue + 1)
        while let step = candidate {
            switch step {
            case .overseer where hasOverseer, .greeting where hasGreeting:
                candidate = OnboardingStep(rawValue: step.rawValue + 1)
            default:
                return step
            }
        }
        return nil
    }
}
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Onboarding/Domain/OnboardingStep.swift` → exit 0.

### Step 2: Test the rule

Create `HugoTests/Features/Onboarding/Domain/OnboardingStepTests.swift`:

```swift
import Testing

@testable import Hugo

struct OnboardingStepTests {
    @Test
    func aNewUserSeesEveryStepInOrder() {
        #expect(OnboardingStep.welcome.next(hasOverseer: false, hasGreeting: false) == .publisherStatus)
        #expect(OnboardingStep.publisherStatus.next(hasOverseer: false, hasGreeting: false) == .overseer)
        #expect(OnboardingStep.overseer.next(hasOverseer: false, hasGreeting: false) == .greeting)
        #expect(OnboardingStep.greeting.next(hasOverseer: false, hasGreeting: false) == nil)
    }

    @Test
    func stepsThatAreAlreadySetUpAreSkipped() {
        #expect(OnboardingStep.publisherStatus.next(hasOverseer: true, hasGreeting: false) == .greeting)
        #expect(OnboardingStep.publisherStatus.next(hasOverseer: false, hasGreeting: true) == .overseer)
        #expect(OnboardingStep.publisherStatus.next(hasOverseer: true, hasGreeting: true) == nil)
        #expect(OnboardingStep.overseer.next(hasOverseer: true, hasGreeting: true) == nil)
    }

    @Test
    func theWelcomeAndPublisherStatusAreNeverSkipped() {
        #expect(OnboardingStep.welcome.next(hasOverseer: true, hasGreeting: true) == .publisherStatus)
    }

    @Test
    func numbersCountFromOne() {
        #expect(OnboardingStep.allCases.map(\.number) == [1, 2, 3, 4])
        #expect(OnboardingStep.count == 4)
    }
}
```

**Verify**: `xcrun swift-format lint --strict HugoTests/Features/Onboarding/Domain/OnboardingStepTests.swift` → exit 0.

### Step 3: The strings

Add five keys to `Hugo/Resources/Localizable.xcstrings`, each in its sorted position:

| Key | English | Danish | Comment |
|---|---|---|---|
| `onboarding.action.continue` | Continue | Fortsæt | Button that moves to the next onboarding page. |
| `onboarding.action.skip` | Skip for Now | Spring over | Button that leaves an onboarding step for later. |
| `onboarding.greeting.introduction` | Every report you send starts with this greeting. Keep the suggestion or write your own. You can change it later in Settings. | Hver rapport, du sender, starter med denne hilsen. Behold forslaget, eller skriv din egen. Du kan ændre den senere under Indstillinger. | Explanation at the top of the greeting page in onboarding. |
| `onboarding.overseer.introduction` | Hugo sends your monthly report to your group overseer. Choose them from your contacts, or skip this and do it later in Settings. | Hugo sender din månedsrapport til din gruppetjener. Vælg vedkommende blandt dine kontakter, eller spring over og gør det senere under Indstillinger. | Explanation at the top of the group overseer page in onboarding. |
| `onboarding.step.%lld.%lld` | Step %1$lld of %2$lld | Trin %1$lld af %2$lld | Step counter at the bottom of each onboarding page, for example "Step 2 of 4". |

**Verify**: `python3 -I -c "import json;d=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print(sorted(k for k in d if k.startswith('onboarding.')))"` → `['onboarding.action.continue', 'onboarding.action.skip', 'onboarding.greeting.introduction', 'onboarding.overseer.introduction', 'onboarding.step.%lld.%lld']`.

### Step 4: Let the two Settings screens show an introduction

1. In `OverseerSettingsView.swift`, after `@State private var isPickingContact = false`, add:

```swift

    /// Text shown above the screen's content, used when onboarding embeds it.
    var introduction: LocalizedStringKey? = nil
```

   and make the first thing inside `List {` (before `if !fullName.isEmpty {`):

```swift
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

2. In `GreetingTemplateView.swift`, add the same `introduction` property after the four `@AppStorage` lines, and the same `if let introduction { … }` block as the first thing inside `List {`.

Settings keeps calling `OverseerSettingsView()` and `GreetingTemplateView()` with no introduction, so the Settings screens look exactly as before.

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Settings/Screens/OverseerSettingsView.swift Hugo/Features/Settings/Screens/GreetingTemplateView.swift` → exit 0. `grep -rn "OverseerSettingsView()\|GreetingTemplateView()" Hugo --include='*.swift'` still lists the Settings call sites and the previews, unchanged.

### Step 5: The bottom bar

Create `Hugo/Features/Onboarding/Views/OnboardingStepBar.swift`:

```swift
import SwiftUI

/// The bottom of every onboarding page: the step counter, the main button
/// and, on optional steps, a skip button.
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

            if let onSkip {
                Button("onboarding.action.skip", action: onSkip)
                    .padding(.vertical, HugoLayout.Spacing.tight)
            }
        }
        .padding()
        .background(.bar)
    }
}

#Preview {
    VStack {
        Spacer()
        OnboardingStepBar(step: .overseer, isLast: false, canContinue: false, onSkip: {}, onContinue: {})
    }
}
```

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Onboarding/Views/OnboardingStepBar.swift` → exit 0.

### Step 6: Rewrite `OnboardingView`

Replace the whole of `Hugo/Features/Onboarding/Screens/OnboardingView.swift` with:

```swift
import SwiftUI

/// The first-run setup: one page per step, pushed in a navigation stack so
/// the user can go back. Steps whose setting already exists are skipped
/// (see `OnboardingStep.next`).
struct OnboardingView: View {
    let onComplete: () -> Void

    @AppStorage(UserDefaultsKeys.publisherStatus) private var currentStatus = ""
    @AppStorage(UserDefaultsKeys.overseerFullName) private var overseerFullName = ""
    @AppStorage(UserDefaultsKeys.overseerGreetingTemplate) private var greetingTemplate = ""

    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            page(for: .welcome)
                .navigationDestination(for: OnboardingStep.self) { step in
                    page(for: step)
                }
        }
        .interactiveDismissDisabled(true)
    }

    private func nextStep(after step: OnboardingStep) -> OnboardingStep? {
        step.next(hasOverseer: !overseerFullName.isEmpty, hasGreeting: !greetingTemplate.isEmpty)
    }

    private func advance(from step: OnboardingStep) {
        if let next = nextStep(after: step) {
            path.append(next)
        } else {
            onComplete()
        }
    }

    @ViewBuilder
    private func page(for step: OnboardingStep) -> some View {
        let isLast = nextStep(after: step) == nil
        switch step {
        case .welcome:
            welcomePage
                .safeAreaInset(edge: .bottom) {
                    OnboardingStepBar(step: step, isLast: isLast) { advance(from: step) }
                }
        case .publisherStatus:
            publisherStatusPage
                .safeAreaInset(edge: .bottom) {
                    OnboardingStepBar(step: step, isLast: isLast, canContinue: !currentStatus.isEmpty) {
                        advance(from: step)
                    }
                }
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
        case .greeting:
            GreetingTemplateView(introduction: "onboarding.greeting.introduction")
                .safeAreaInset(edge: .bottom) {
                    OnboardingStepBar(step: step, isLast: isLast) { advance(from: step) }
                }
        }
    }

    private var welcomePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.spacious) {
                Text("splash.subtitle")
                    .font(.title3)
                Text("splash.description.1")
                Text("splash.description.2")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("splash.title")
    }

    private var publisherStatusPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                Text("splash.section.publisherStatus.description")
                    .padding(.horizontal, HugoLayout.Spacing.tight)

                VStack(spacing: HugoLayout.Spacing.compact) {
                    PublisherStatusOptionsView(selection: $currentStatus, rowStyle: .card)
                }
                .padding(.top, HugoLayout.Spacing.spacious)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("splash.section.publisherStatus.title")
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
```

Notes for the executor:
- `isLast` is worked out when the page is built. On the overseer page it changes once the user picks someone (the greeting page may then still follow), so the button text follows `overseerFullName`. That is intended.
- The old file declared `@Environment(\.dismiss) private var dismiss` without using it. It's gone on purpose.

**Verify**: `xcrun swift-format lint --strict Hugo/Features/Onboarding/Screens/OnboardingView.swift` → exit 0. `Scripts/check-layout.sh` → exit 0. `grep -c "OnboardingView {" Hugo/App/AppRootView.swift` → `1` (unchanged call site).

### Step 7: Run the gate and commit

**Verify**: `Scripts/verify.sh > /tmp/verify122.log 2>&1; echo "exit $?"` → `exit 0`. `grep "OnboardingStepTests" /tmp/verify122.log | grep -c passed` → at least `1`, and no test fails.

Commit the seven in-scope files by path.

## Test plan

- New: `OnboardingStepTests`: the full order for a new user, skipping steps that are already set up, never skipping the welcome or the publisher status, and the step numbers.
- The pages are views. The owner walks through them on a device (below).

## Done criteria

- [ ] `Scripts/verify.sh` exits 0, with `OnboardingStepTests` passing
- [ ] `git diff --stat d2d87d5..HEAD -- Hugo/App/AppRootView.swift` shows only plan 121's changes (this plan doesn't touch it)
- [ ] `grep -rn "Onboarding" Hugo/Features/Settings --include='*.swift'` finds nothing except `DebugSettingsView`'s existing reset (no new Settings → Onboarding dependency)
- [ ] `git show --stat HEAD` lists exactly the seven in-scope files

## STOP conditions

- The drift check shows changes other than plans 120 and 121's catalog keys, and the excerpts don't match.
- `git status --short` shows `Hugo/Resources/Localizable.xcstrings` modified before you start.
- The `switch` pattern `case .overseer where hasOverseer, .greeting where hasGreeting:` doesn't compile. Report the error. Don't restructure the rule on your own.
- Embedding `OverseerSettingsView` or `GreetingTemplateView` needs changes beyond the optional `introduction` property.
- `Scripts/verify.sh` fails twice. Report the failing test names.

## Owner checks

Use Settings → Debugging → reset onboarding on a device with the Debug build:
1. Walk through all four pages in English and in Danish. The counter reads "Step 1 of 4" … "Step 4 of 4" ("Trin … af 4"). Back works on every page. The publisher status page won't continue without a choice.
2. On the overseer page, choose a contact. The name appears and Continue turns on. Skip for Now is only shown while no one is chosen.
3. On the greeting page, the preview uses the overseer's first name. The last button reads "Let's Get Started" and closes onboarding.
4. With an overseer and a greeting already set (from iCloud or from step 2 last time), reset onboarding again: after the publisher status, onboarding finishes without showing those pages.
5. At the largest accessibility text size, every page scrolls, and the bottom bar stays readable.
6. Settings → Report → Group Overseer and Greeting look exactly as before (no introduction text).

## Maintenance notes

- To add a step, add a case to `OnboardingStep` in its place, give it a skip condition in `next` if it can already be set up, and add its page to `OnboardingView.page(for:)`. Update `numbersCountFromOne`.
- The overseer and greeting pages are the Settings screens. A change to those screens changes onboarding too, which is the point.
- If the report reminder (SLN-218) lands, its permission prompt doesn't belong in onboarding. The issue says to ask after the first submitted report.

## Revision 1 (2026-11-15, after the owner's device check)

> **Execute only this revision.** Steps 1-7 are done (commit `5a87ac7`). Drift check for this revision:
> `git diff --stat c076cf9..HEAD -- Hugo/Features/Onboarding HugoTests/Features/Onboarding`
> Expected: no output. Otherwise STOP.

### What the owner saw

The counter said there were 4 steps, but after the publisher status page the sheet closed. The owner never saw the overseer and greeting pages. Their phone already had both set, so `OnboardingStep.next` skipped both pages and finished, while the counter kept counting all four.

### Decision (owner, 2026-11-15)

**Always show all four pages. Never skip.** If the overseer or greeting already exists (for example from iCloud), its page shows it filled in, and Continue works straight away. That's simpler, and the counter is always right. This replaces the earlier "skip steps iCloud already filled in" decision.

### Scope of this revision

- `Hugo/Features/Onboarding/Domain/OnboardingStep.swift`
- `Hugo/Features/Onboarding/Screens/OnboardingView.swift`
- `HugoTests/Features/Onboarding/Domain/OnboardingStepTests.swift`

Commit: `fix: always show all four onboarding steps`

### Step R1: Drop the skipping rule

In `OnboardingStep.swift`, replace the whole `next(hasOverseer:hasGreeting:)` function and its doc comment with:

```swift
    /// The page after this one, or nil after the last page.
    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
```

### Step R2: Use it in `OnboardingView`

In `OnboardingView.swift`:

1. Delete the line `@AppStorage(UserDefaultsKeys.overseerGreetingTemplate) private var greetingTemplate = ""`. Keep `overseerFullName`: the overseer page still uses it to turn Continue on and to show Skip for Now.
2. Replace `nextStep(after:)` with:

```swift
    private func nextStep(after step: OnboardingStep) -> OnboardingStep? {
        step.next
    }
```

3. In the type's doc comment, delete the sentence `Steps whose setting already exists are skipped (see \`OnboardingStep.next\`).` and the line break it leaves. The comment then reads `/// The first-run setup: one page per step, pushed in a navigation stack so` / `/// the user can go back.`

Nothing else in the view changes. The overseer page already enables Continue when an overseer exists, and shows Skip for Now only when none is set. The greeting page shows the stored greeting in its text field.

### Step R3: Replace the tests

Replace the body of `OnboardingStepTests` with:

```swift
    @Test
    func everyStepFollowsTheOneBefore() {
        #expect(OnboardingStep.welcome.next == .publisherStatus)
        #expect(OnboardingStep.publisherStatus.next == .overseer)
        #expect(OnboardingStep.overseer.next == .greeting)
        #expect(OnboardingStep.greeting.next == nil)
    }

    @Test
    func numbersCountFromOne() {
        #expect(OnboardingStep.allCases.map(\.number) == [1, 2, 3, 4])
        #expect(OnboardingStep.count == 4)
    }
```

### Step R4: Run the gate and commit

**Verify**:
- `grep -rn "hasOverseer\|hasGreeting\|greetingTemplate" Hugo/Features/Onboarding HugoTests/Features/Onboarding` → no output.
- `xcrun swift-format lint --strict` on the three files → exit 0.
- `Scripts/verify.sh > /tmp/verify122r1.log 2>&1; echo "exit $?"` → `exit 0`, with both `OnboardingStepTests` tests passing.

Commit the three files by path.

### Owner check for this revision

On your phone, which has an overseer and a greeting, reset onboarding. All four pages appear with "Step 1 of 4" … "Step 4 of 4". The overseer page shows your overseer with Continue on and no Skip for Now. The greeting page shows your greeting. The last button reads "Let's Get Started".
