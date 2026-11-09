# Plan 098: Let users pick a preset color for each category (schema V13)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in "STOP conditions" happens, stop and report. Do not
> improvise. When done, update this plan's row in `plans/README.md`, unless a
> reviewer dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat af030fb..HEAD -- Hugo/Persistence Hugo/Domain Hugo/DesignSystem/Theme Hugo/App/AppBootstrapper.swift Hugo/Features/Categories Hugo/Features/Planner HugoTests/Persistence HugoTests/Domain HugoTests/App Hugo/Resources/Localizable.xcstrings CONTEXT.md`
> Expected: no output. If any file changed, compare the "Current state"
> excerpts below with the live code. A mismatch is a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M + owner (device check and CloudKit schema deploy)
- **Risk**: MED. It adds a SwiftData schema version and new CloudKit fields. The UI part is low risk.
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `af030fb`, 2026-11-09
- **Issue**: [SLN-287](https://linear.app/sebastianln/issue/SLN-287)

## Why this matters

The Planner draws each category's plans as bars in the category's color. No screen can set a color, so every bar falls back to the accent color, and Field Service, LDC and other categories all look the same. This plan lets the user pick one of six preset colors or "Automatic" (the accent color) when creating or editing a category. New categories start with the first preset no other category uses.

A color is stored as a **hue** and a **tone**. The tone gives a lighter color in dark mode and a deeper one in light mode, so the same choice stays visible on both backgrounds. Plan 099 (SLN-308) adds two sliders for custom colors on top of this model. This plan must leave room for that but must not build it.

The old `hue`, `sat` and `bri` fields on `Tracker` were added years ago for a color feature that never shipped. No screen ever wrote them, and every row reads as "no color" today. The owner decided (2026-11-09) to replace them with two new optional fields in a new schema version instead of reusing them.

## Current state

### Persistence

- `Hugo/Persistence/AppSchema.swift:117-137`: the current schema is V12. It reuses the V11 `Entry`, `Tracker` and `SubmittedReport` classes and adds `Plan`:

```swift
enum SchemaV12: VersionedSchema {
    static let versionIdentifier = Schema.Version(9, 0, 0)

    typealias Entry = SchemaV11.Entry
    typealias Tracker = SchemaV11.Tracker
    typealias Report = SchemaV11.Report
    typealias SubmittedReport = SchemaV11.SubmittedReport

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self, SubmittedReport.self, Plan.self]
    }
}

typealias CurrentSchema = SchemaV12

// SchemaV8/V9.Report remains as migration compatibility ballast until a tested
// future schema version can remove it safely.
typealias Entry = CurrentSchema.Entry
typealias Tracker = CurrentSchema.Tracker
typealias SubmittedReport = CurrentSchema.SubmittedReport
typealias Plan = CurrentSchema.Plan
```

- `Hugo/Persistence/SchemaVersions/V11/TrackerV11.swift:23-25,32-49`: the old color channels and the initializer:

```swift
        var iconName: String = "tag.fill"
        var hue: Double = 0.0
        var sat: Double = 1.0
        var bri: Double = 0.0

        var createdAt: Date = Date()

        @Relationship(deleteRule: .nullify, inverse: \Entry.tracker)
        var entries: [Entry]? = []

        init(
            id: UUID = UUID(), name: String? = nil, type: TrackerType? = nil, allowBibleStudies: Bool? = nil,
            isDefault: Bool? = nil, iconName: String? = nil, hue: Double? = nil, sat: Double? = nil, bri: Double? = nil
        ) {
```

- **Why V13 needs four new model files, not one.** `EntryV11.swift:20` declares `@Relationship var tracker: Tracker?`, which inside `extension SchemaV11` means `SchemaV11.Tracker`. `SubmittedReportV11.swift:52` declares `@Relationship(deleteRule: .nullify, inverse: \Entry.sourceSubmission) var generatedEntries: [Entry]? = []`. A new `Tracker` class therefore needs a new `Entry` class, which in turn needs a new `SubmittedReport` class. `Plan` has no relationships, but `PlanV12.swift:32` (`init(date:duration:startMinute:tracker: Tracker?)`) and `:44` (`func setCategory(_ tracker: Tracker?)`) take a `SchemaV12.Tracker`, which is the V11 class. The callers pass the current `Tracker`: `PlanService.swift:27,39`, `CategoryDeletionService.swift:20`, `PreviewModelContainer.swift:17,20`, `PlanFormModelTests.swift:30`, `CategoryDeletionServiceTests.swift:37` and `SchemaMigrationTests.swift:298`. So `Plan` needs a V13 copy as well. Only the legacy `Report` (no relationships, no `Tracker` parameters) stays a typealias.
- `Hugo/Persistence/HugoMigrationPlan.swift:15-29` lists the schemas and stages. `migrateV11toV12` at lines 372-376 is the exemplar for a lightweight stage:

```swift
    /// Adds the `Plan` model. No existing data changes.
    static let migrateV11toV12: MigrationStage = .lightweight(
        fromVersion: SchemaV11.self,
        toVersion: SchemaV12.self
    )
```

- `Hugo/Persistence/SyncDeduplicator.swift:241-250`: the tie-break when merging duplicate categories reads the old channels:

```swift
    /// Earliest `createdAt` wins; ties fall back to the remaining synced fields.
    private static func survivorPrecedes(_ a: Tracker, _ b: Tracker) -> Bool {
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        if a.name != b.name { return a.name < b.name }
        if a.iconName != b.iconName { return a.iconName < b.iconName }
        if a.type.rawValue != b.type.rawValue { return a.type.rawValue < b.type.rawValue }
        if a.hue != b.hue { return a.hue < b.hue }
        if a.sat != b.sat { return a.sat < b.sat }
        return a.bri < b.bri
    }
```

- `Hugo/App/AppBootstrapper.swift:59-73` seeds Field Service with `hue: definition.hue, sat: definition.saturation, bri: definition.brightness`. `Hugo/Features/Categories/Domain/DefaultCategoryDefinition.swift` holds `hue: 0.5, saturation: 1, brightness: 0` for that row. Brightness 0 means "no color".
- `HugoTests/Persistence/SchemaMigrationTests.swift` opens migrated stores with `makeCurrentStore(at:)` (lines 1190-1202, `Schema(versionedSchema: CurrentSchema.self)` plus `MigrationPlan.self`). Several tests fetch **V11 types from the current store**, which only works while the current schema reuses the V11 classes:
  - lines 570, 640, 699, 754, 838: `try context.fetch(FetchDescriptor<SchemaV11.Entry>())`
  - line 375: `func fields(_ c: SchemaV11.SubmittedReport.SubmittedCategory) -> ...` is applied to a report fetched from the current store.
  - line 41: `FetchDescriptor<SchemaV11.Report>()`. This stays valid because `Report` remains the same class in V13.
  - `makeV11Store(at:trackers:entries:)` at lines 1158-1170 is the helper pattern for a versioned store, and `migratingV11StoreKeepsEntriesAndStartsWithoutPlans` at lines 1010-1027 is the pattern for a migration test.

### The color type and where it is drawn

- `Hugo/Domain/CategoryProgressColor.swift` is the read-only color type (whole file):

```swift
/// A category's stored color, or nil when the stored channels are unset or out
/// of range. Views fall back to `.hugoAccent` for nil.
nonisolated struct CategoryProgressColor: Equatable, Sendable {
    let hue: Double
    let saturation: Double
    let brightness: Double

    init?(hue: Double, saturation: Double, brightness: Double) {
        guard (0...1).contains(hue), (0...1).contains(saturation), (0...1).contains(brightness),
            brightness > 0
        else { return nil }
        ...
```

  It is tested by `HugoTests/Domain/CategoryProgressColorTests.swift` (3 tests).
- It is used in exactly these places:
  - `Hugo/Features/Planner/Domain/PlanMatcher.swift:11` (`LoggedCategoryTime.color`) and `:28` (`PlannerBar.color`), both typed `CategoryProgressColor?`.
  - `Hugo/Features/Planner/Domain/PlannedItem.swift:19` (`let color: CategoryProgressColor?`) and `:43`, `color: live.flatMap { CategoryProgressColor(hue: $0.hue, saturation: $0.sat, brightness: $0.bri) })`.
  - `Hugo/Features/Planner/Domain/PlannerMonth.swift:62-64`, `color: tracker.flatMap { CategoryProgressColor(hue: $0.hue, saturation: $0.sat, brightness: $0.bri) },`.
- Views that draw it:
  - `Hugo/Features/Planner/Views/PlannerBarView.swift`. `PlannerBarShape` takes `let color: Color` and uses `color.opacity(0.15)`, `.fill(color)` and `.strokeBorder(color, lineWidth: 1)`. `PlannerBarView` converts the optional color at lines 32-35:

```swift
    private var color: Color {
        guard let color = bar.color else { return .hugoAccent }
        return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }
```

  - `Hugo/Features/Planner/Views/PlannedCategoryCard.swift:15-18` has the same `color` property, used once at line 52 (`.fill(color)`).
  - `PlannerLegend.swift:17` and `PlannerStatusHeader.swift:101` call `PlannerBarShape(fraction: fraction, color: .hugoAccent)`. They must keep compiling unchanged.
- `Hugo/DesignSystem/Theme/Theme.swift:56-66`:

```swift
extension Color {
    /// Hugo's signature opt-in accent color (currently System Teal).
    /// Enables: `.tint(.hugoAccent)`, `Color.hugoAccent`.
    static var hugoAccent: Color { .mint }
}

extension ShapeStyle where Self == Color {
    /// Hugo's signature opt-in accent color (currently System Teal).
    /// Enables: `.foregroundStyle(.hugoAccent)`, `.background(.hugoAccent)`.
    static var hugoAccent: Color { Color.hugoAccent }
}
```

  The project uses **MainActor default isolation**, so these statics are MainActor-isolated. A `ShapeStyle.resolve(in:)` implementation is nonisolated, so it cannot call them unless they are marked `nonisolated` (Step 4).

### Category screens

- `Hugo/Features/Categories/Screens/AddCategoryView.swift` keeps form state in `@State` (`name`, `type`, `allowBibleStudies`, `isDefault`, `iconName`) and has `@Query private var trackers: [Tracker]`. It builds the tracker in `submit()` (lines 84-108) with `Tracker(name:type:allowBibleStudies:isDefault:iconName:)`. Its icon tile (lines 26-40) draws `Image(systemName: iconName)` with `.foregroundStyle(.primary)`. The sections, in order, are: icon tile, name `TextField`, type picker, then options (`tracker.options.label`).
- `Hugo/Features/Categories/Screens/CategoryDetailView.swift` binds directly to the model (`@Bindable var tracker = tracker`, `TextField(..., text: $tracker.name)`). Its icon tile (lines 22-41) uses `.foregroundStyle(.primary)`. The sections, in order, are: icon tile, name (`tracker.settings.name.label`), type picker, then the advanced-options link.
- `Hugo/Features/Categories/Screens/CategoryListView.swift:20-33` and `CategoryPicker.swift:30-35` draw each row as `Label { Text(tracker.name) } icon: { Image(systemName: tracker.iconName) }` inside a row styled `.foregroundStyle(.primary)`.
- **Model extension pattern to copy**: `Hugo/Features/Entries/Domain/EntryCategory.swift:21-22` declares `extension Entry { nonisolated func resolvedCategory(...) }`. Model properties are readable from nonisolated code, and the Planner's nonisolated `PlannedItem.init` and `PlannerMonth.make` read tracker fields directly.
- **Accessibility pattern to copy**: `Hugo/Features/Categories/Screens/CategoryPicker.swift:43-44` uses `.accessibilityAddTraits(selection?.id == tracker.id ? [.isButton, .isSelected] : .isButton)`.
- **Motion**: `Hugo/DesignSystem/Motion/Motion.swift` has `.motion(Motion.feedback, value:)`, which respects Reduce Motion. Use it for the selection ring.

### Vocabulary and design rules (from `CONTEXT.md`, `AGENTS.md`, `plans/README.md`)

- A "Category" is what the UI calls it. Persistence names stay `Tracker` (`AGENTS.md`: "Persistence names remain `Tracker` even where the UI says Category").
- `plans/README.md`, "Design decisions carried into every plan": "`.hugoAccent` is ... strictly opt-in: progress gauges, primary CTAs, active status/completion markers, and fallback category colors only." and "Category-specific colors are content data, not chrome." This plan updates the second line (Step 10 is the advisor's job; do not edit the README design section yourself).
- A red/green "short of plan" coloring was rejected on 2026-11-04 because it could discourage users who are behind. For that reason the presets contain **no red and no yellow**: a red bar reads as "behind", and yellow is too faint as a thin bar in light mode.
- Colors are a visual aid only. Bars and rows must stay distinguishable by name and order.

## The color model (load-bearing; implement exactly)

A `CategoryColor` is `hue` and `tone`, each in `0...1`. It turns into HSB components differently per appearance, and then a contrast floor nudges the result if it would be too faint:

| Appearance | Saturation | Brightness | If contrast < 2.0 against any reference background |
|---|---|---|---|
| Light | `0.70 + 0.15 * tone` | `0.92 - 0.42 * tone` | lower brightness by 0.02 while brightness > 0.2 |
| Dark | `0.12 + 0.68 * tone` | `1.00 - 0.10 * tone` | raise brightness by 0.02 up to 1.0, then lower saturation by 0.02 down to 0 |

The reference backgrounds, as sRGB bytes, are:

- Light: `#FFFFFF` (systemBackground) and `#F2F2F7` (systemGroupedBackground).
- Dark: `#000000`, `#1C1C1E` (secondarySystemGroupedBackground) and `#2C2C2E` (tertiarySystemGroupedBackground).

Contrast is the WCAG ratio `(L1 + 0.05) / (L2 + 0.05)`, where L is relative luminance. Each sRGB channel `c` is linearized as `c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)`, and `L = 0.2126 R + 0.7152 G + 0.0722 B`.

The advisor checked these formulas with a script over 48 hues × 11 tones. 86 of 528 light-mode combinations get darkened (yellows and greens), and 3 dark-mode combinations get lightened. Presets checked against the backgrounds (minimum contrast):

| Preset | id | hue | tone | Light result | Dark result |
|---|---|---|---|---|---|
| Blue | `blue` | 0.60 | 0.55 | `#265DB0`, 5.7:1 | `#7AAAF1`, 5.9:1 |
| Indigo | `indigo` | 0.68 | 0.50 | `#3429B5`, 8.9:1 | `#8C83F2`, 4.4:1 |
| Purple | `purple` | 0.78 | 0.50 | `#8829B5`, 6.2:1 | `#CF83F2`, 5.4:1 |
| Pink | `pink` | 0.90 | 0.45 | `#BA2B81`, 5.0:1 | `#F48CCA`, 6.3:1 |
| Orange | `orange` | 0.07 | 0.45 | `#BA672B`, 3.7:1 | `#F4B78C`, 8.0:1 |
| Green | `green` | 0.37 | 0.55 | `#26B044`, 2.6:1 | `#7AF194`, 9.8:1 |

The owner may tune hue and tone values in `CategoryColorPreset.all` after the device check. That is the only place to tune them.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Layout rules | `Scripts/check-layout.sh` | exit 0, no output |
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/SchemaMigrationTests -only-testing:HugoTests/SyncDeduplicatorTests -only-testing:HugoTests/AppBootstrapperTests -only-testing:HugoTests/CategoryColorTests -only-testing:HugoTests/CategoryColorPresetTests` | `** TEST SUCCEEDED **` |
| Catalog JSON | `python3 -I -c "import json;json.load(open('Hugo/Resources/Localizable.xcstrings'))"` | exit 0 |
| Full gate (before every commit) | `Scripts/verify.sh` | exit 0 |
| Whitespace | `git diff --check` | exit 0 |

The Xcode project uses synchronized folders (`PBXFileSystemSynchronizedRootGroup`), so new `.swift` files under `Hugo/` and `HugoTests/` are picked up without editing `project.pbxproj`.

## Suggested executor toolkit

- Use the `write-swift` skill if available, for Swift 6 isolation questions in Steps 3-4.

## Scope

**In scope** (the only files you may modify or create):

- `Hugo/Persistence/AppSchema.swift`
- `Hugo/Persistence/HugoMigrationPlan.swift`
- `Hugo/Persistence/SchemaVersions/V13/TrackerV13.swift` (create)
- `Hugo/Persistence/SchemaVersions/V13/EntryV13.swift` (create)
- `Hugo/Persistence/SchemaVersions/V13/SubmittedReportV13.swift` (create)
- `Hugo/Persistence/SchemaVersions/V13/PlanV13.swift` (create)
- `Hugo/Persistence/SyncDeduplicator.swift` (the `survivorPrecedes` function only)
- `Hugo/App/AppBootstrapper.swift` (`seedDefaults` only)
- `Hugo/Features/Categories/Domain/DefaultCategoryDefinition.swift`
- `Hugo/Domain/CategoryProgressColor.swift` (delete)
- `Hugo/Domain/CategoryColor.swift` (create)
- `Hugo/DesignSystem/Theme/Theme.swift` (`nonisolated` on the two `hugoAccent` statics, plus one new size token)
- `Hugo/DesignSystem/Theme/CategoryColorStyle.swift` (create)
- `Hugo/Features/Categories/Domain/CategoryColorPreset.swift` (create)
- `Hugo/Features/Categories/Domain/TrackerCategoryColor.swift` (create)
- `Hugo/Features/Categories/Views/CategoryColorPicker.swift` (create)
- `Hugo/Features/Categories/Screens/AddCategoryView.swift`
- `Hugo/Features/Categories/Screens/CategoryDetailView.swift`
- `Hugo/Features/Categories/Screens/CategoryListView.swift` (row icon only)
- `Hugo/Features/Categories/Screens/CategoryPicker.swift` (row icon only)
- `Hugo/Features/Planner/Domain/PlanMatcher.swift`, `PlannedItem.swift`, `PlannerMonth.swift` (type rename and reading the new property only)
- `Hugo/Features/Planner/Views/PlannerBarView.swift`, `PlannedCategoryCard.swift` (color plumbing only)
- `Hugo/Resources/Localizable.xcstrings` (the new `tracker.color.*` keys only)
- `CONTEXT.md` (one new term)
- `HugoTests/Persistence/SchemaMigrationTests.swift`
- `HugoTests/Persistence/SyncDeduplicatorTests.swift`
- `HugoTests/Domain/CategoryProgressColorTests.swift` (delete)
- `HugoTests/Domain/CategoryColorTests.swift` (create)
- `HugoTests/Features/Categories/Domain/CategoryColorPresetTests.swift` (create)

**Out of scope** (do NOT touch):

- Every file under `Hugo/Persistence/SchemaVersions/V1` … `V12`. Shipped schema versions are never edited (`AGENTS.md` section 8).
- `HugoMigrationPlan` stages before `migrateV11toV12`, including the `SchemaV11` references at lines 251-389. They describe history.
- `Hugo.xcodeproj/project.pbxproj`. It has unrelated, uncommitted owner changes. Never stage it.
- Custom color sliders, a color wheel button and hue names. Those belong to plan 099 (SLN-308).
- Coloring entry rows, the Overview, Reports, the Year tab or the Planner legend and status header. The owner wants color used sparingly: Planner bars and cards, category icons in lists and pickers, and the editor's icon tile only.
- `TrackerSummary` (legacy V7 report snapshot) and its `hue`/`sat`/`bri` fields. Legacy data, untouched.
- `Plan` snapshots: do not add a color snapshot to `Plan`. Plans read the live category's color.

## Git workflow

- Work on `main` directly. No branch, no worktree, no push.
- Stage explicit paths only. Never stage `.claude/`, `plans/` (the reviewer commits those) or `Hugo.xcodeproj/project.pbxproj`.
- Two commits, each after `Scripts/verify.sh` exits 0. Use Conventional Commits, as in `git log` (for example `feat: add the Plan model in schema V12`):
  1. `feat: replace the unused category color channels with hue and tone in schema V13` (Steps 1-4; the app first compiles again after Step 4, because removing `CategoryProgressColor` breaks the two Planner views that Step 4 rewires)
  2. `feat: let users pick a preset color for each category` (Steps 5-9)

## Steps

### Step 1: Add schema V13 with new `Tracker`, `Entry` and `SubmittedReport` classes

1. Create the folder `Hugo/Persistence/SchemaVersions/V13/`.
2. Copy `V11/EntryV11.swift` to `V13/EntryV13.swift`, `V11/SubmittedReportV11.swift` to `V13/SubmittedReportV13.swift` and `V12/PlanV12.swift` to `V13/PlanV13.swift`. In each copy, change only:
   - the header comment's file name (`EntryV13.swift`, `SubmittedReportV13.swift`, `PlanV13.swift`)
   - `extension SchemaV11 {` (or `extension SchemaV12 {` for the plan) to `extension SchemaV13 {`

   Keep everything else byte-identical, including the nested `EntryTracker`, `SubmittedCategory` and `SubmittedReportingLine` types and `Plan`'s doc comments. Unqualified `Tracker`, `Entry` and `SubmittedReport` inside the extension now resolve to the V13 classes, and that is intended.
3. Copy `V11/TrackerV11.swift` to `V13/TrackerV13.swift`, change the header and `extension SchemaV13 {`, then replace the three color lines and the initializer:

```swift
        var iconName: String = "tag.fill"
        /// The category color's hue, 0...1. Nil with `colorTone` means Automatic.
        /// Read and write through `categoryColor` / `setCategoryColor(_:)`.
        var colorHue: Double?
        /// The category color's tone, 0...1. See `CategoryColor`.
        var colorTone: Double?

        var createdAt: Date = Date()

        @Relationship(deleteRule: .nullify, inverse: \Entry.tracker)
        var entries: [Entry]? = []

        init(
            id: UUID = UUID(), name: String? = nil, type: TrackerType? = nil, allowBibleStudies: Bool? = nil,
            isDefault: Bool? = nil, iconName: String? = nil
        ) {
```

   In the initializer body, delete the three `if let hue/sat/bri` lines and keep the rest.
4. In `AppSchema.swift`, add after `SchemaV12`:

```swift
/// Replaces the never-used `hue`, `sat` and `bri` category channels with
/// optional `colorHue` and `colorTone`. `Tracker` changes, so `Entry` and
/// `SubmittedReport`, which relate to it, and `Plan`, whose initializer takes
/// a `Tracker`, get V13 classes too. Their stored attributes are unchanged.
enum SchemaV13: VersionedSchema {
    static let versionIdentifier = Schema.Version(10, 0, 0)

    typealias Report = SchemaV12.Report

    static var models: [any PersistentModel.Type] {
        [Entry.self, Tracker.self, Report.self, SubmittedReport.self, Plan.self]
    }
}
```

   and change `typealias CurrentSchema = SchemaV12` to `typealias CurrentSchema = SchemaV13`.
5. In `HugoMigrationPlan.swift`, append `SchemaV13.self` to `schemas` and `migrateV12toV13` to `stages`, and add after `migrateV11toV12`:

```swift
    /// Drops the never-used `hue`, `sat` and `bri` category channels and adds
    /// optional `colorHue` and `colorTone`. No screen ever wrote a color, so
    /// every category starts as Automatic.
    static let migrateV12toV13: MigrationStage = .lightweight(
        fromVersion: SchemaV12.self,
        toVersion: SchemaV13.self
    )
```

Do not build yet: the old `hue`/`sat`/`bri` readers fail to compile until Step 3.

**Verify**: `ls Hugo/Persistence/SchemaVersions/V13` lists the four files, and `diff <(sed 1,11d Hugo/Persistence/SchemaVersions/V11/EntryV11.swift) <(sed 1,11d Hugo/Persistence/SchemaVersions/V13/EntryV13.swift)` prints nothing (line 11 is the `extension` line). Run the same `diff` for `SubmittedReport` (also line 11), and for `PlanV12.swift` against `PlanV13.swift` with `sed 1,9d` (its `extension` line is line 9). If your copy's `extension` line sits on another line, adjust the `sed` range so both files skip the header and the `extension` line.

### Step 2: Add `CategoryColor` and remove `CategoryProgressColor`

Create `Hugo/Domain/CategoryColor.swift` (Foundation only, no SwiftUI):

```swift
import Foundation

/// A category color as the user chose it: a hue and a tone, both 0...1.
/// The same choice gives a deeper color in light mode and a lighter one in
/// dark mode, and is nudged until it stands out from the background, so it
/// stays visible in both. A category without one is Automatic and uses the
/// accent color. See "Category color" in CONTEXT.md.
nonisolated struct CategoryColor: Hashable, Sendable {
    enum Appearance: Sendable {
        case light
        case dark
    }

    /// The color to draw, as HSB channels from 0 to 1.
    struct Components: Equatable, Sendable {
        let hue: Double
        let saturation: Double
        let brightness: Double
    }

    /// The lowest contrast ratio against any reference background.
    static let minimumContrast = 2.0

    let hue: Double
    let tone: Double

    /// Clamps both values into 0...1. Non-finite values become 0.
    init(hue: Double, tone: Double) {
        self.hue = Self.clamped(hue)
        self.tone = Self.clamped(tone)
    }

    /// Reads the stored fields. Nil (Automatic) unless both are set, finite
    /// and within 0...1.
    init?(storedHue: Double?, storedTone: Double?) {
        guard let storedHue, let storedTone, storedHue.isFinite, storedTone.isFinite,
            (0...1).contains(storedHue), (0...1).contains(storedTone)
        else { return nil }
        self.init(hue: storedHue, tone: storedTone)
    }

    func components(for appearance: Appearance) -> Components { ... }
}
```

Implement `components(for:)` exactly as the table in "The color model" says, with private helpers:

- `static func rgb(_ c: Components) -> (red: Double, green: Double, blue: Double)`: the standard HSB-to-RGB conversion (sector `i = floor(h * 6) mod 6`, `f = h * 6 - floor(h * 6)`, `p = b(1 - s)`, `q = b(1 - fs)`, `t = b(1 - (1 - f)s)`).
- `static func relativeLuminance(red:green:blue:) -> Double` (WCAG, see above).
- `static func contrastRatio(_ a: Double, _ b: Double) -> Double` (luminances in, ratio out; order-independent).
- `static let lightBackgrounds` / `darkBackgrounds`: luminances of the reference colors, computed from their sRGB bytes divided by 255.

Make `relativeLuminance`, `contrastRatio`, `lightBackgrounds`, `darkBackgrounds` and `rgb` `internal` (not `private`) so the tests can use them. The correction loops must always end: light stops at brightness 0.2, and dark stops when brightness is 1 and saturation is 0.

Then:

- Delete `Hugo/Domain/CategoryProgressColor.swift` and `HugoTests/Domain/CategoryProgressColorTests.swift`.
- Create `HugoTests/Domain/CategoryColorTests.swift` (see Test plan).

**Verify**: `grep -rn "CategoryProgressColor" Hugo HugoTests` lists only the Planner files that Step 3 changes (`PlanMatcher.swift`, `PlannedItem.swift`, `PlannerMonth.swift`).

### Step 3: Read and write the color on `Tracker`, and switch every reader

1. Create `Hugo/Features/Categories/Domain/TrackerCategoryColor.swift`:

```swift
import Foundation

extension Tracker {
    /// The category color, or nil for Automatic.
    nonisolated var categoryColor: CategoryColor? {
        CategoryColor(storedHue: colorHue, storedTone: colorTone)
    }

    /// Stores `color`, or clears both fields for Automatic.
    func setCategoryColor(_ color: CategoryColor?) {
        colorHue = color?.hue
        colorTone = color?.tone
    }
}
```

2. Planner domain: replace the type `CategoryProgressColor?` with `CategoryColor?` in `PlanMatcher.swift` (2 places) and `PlannedItem.swift:19`. Change the doc comment at `PlannedItem.swift:18` to `/// The live category's color, or nil for Automatic (views use \`CategoryColorStyle\`).`. Replace the readers:
   - `PlannedItem.swift:43`: `color: live?.categoryColor)`
   - `PlannerMonth.swift:62-64`: `color: tracker?.categoryColor,`
3. `SyncDeduplicator.survivorPrecedes`: replace the last three lines with:

```swift
        if a.colorHue != b.colorHue { return (a.colorHue ?? -1) < (b.colorHue ?? -1) }
        return (a.colorTone ?? -1) < (b.colorTone ?? -1)
```

   This keeps the rule in `AGENTS.md`: the survivor is chosen from synced attributes only, and when every compared field is equal the function returns `false`.
4. `DefaultCategoryDefinition`: remove the `hue`, `saturation` and `brightness` properties and their three arguments. `AppBootstrapper.seedDefaults`: remove the `hue:`, `sat:` and `bri:` arguments. Field Service now seeds as Automatic.
5. `SchemaMigrationTests.swift`: replace `FetchDescriptor<SchemaV11.Entry>()` with `FetchDescriptor<Entry>()` at the five lines listed in Current state, and change the parameter type at line 375 from `SchemaV11.SubmittedReport.SubmittedCategory` to `SubmittedReport.SubmittedCategory`. These tests open the **current** store, which no longer contains V11 classes. Leave line 41 (`SchemaV11.Report`) and every `SchemaV11.` use inside `makeV11Store` and `migratingV11StoreKeepsEntriesAndStartsWithoutPlans` unchanged.
6. Add the migration, round-trip and dedup tests from the Test plan.

**Verify**:

- `grep -rnE "\b(sat|bri)\b|\.hue\b|CategoryProgressColor" Hugo/App Hugo/Features Hugo/Domain Hugo/Persistence/SyncDeduplicator.swift` prints only lines about `CategoryColor`'s own `hue` (in `CategoryColor.swift` and `TrackerCategoryColor.swift`) plus `PlannerBarView.swift:34` and `PlannedCategoryCard.swift:17`, which Step 4 replaces.
- Do not build yet: `PlannerBarView.swift:34` and `PlannedCategoryCard.swift:17` still read `.saturation`/`.brightness` until Step 4. The build, tests and commit 1 happen at the end of Step 4.

### Step 4: Draw a category color with a dynamic `ShapeStyle`

1. In `Theme.swift`, add `nonisolated` to both `static var hugoAccent` declarations (`nonisolated static var hugoAccent: Color { .mint }`, and the same in the `ShapeStyle` extension). Change nothing else about them. Add `static let colorSwatch: CGFloat = 32` to `HugoLayout.Size`, after `calendarBarHeight`.
2. Create `Hugo/DesignSystem/Theme/CategoryColorStyle.swift`:

```swift
import SwiftUI

/// Draws a category color for the current light or dark mode, or the accent
/// color for Automatic (nil). SwiftUI resolves it while drawing, so it follows
/// appearance changes without the view reading the color scheme.
nonisolated struct CategoryColorStyle: ShapeStyle {
    let color: CategoryColor?

    init(_ color: CategoryColor?) {
        self.color = color
    }

    func resolve(in environment: EnvironmentValues) -> Color {
        guard let color else { return .hugoAccent }
        return color.color(for: CategoryColor.Appearance(environment.colorScheme))
    }
}

extension CategoryColor.Appearance {
    nonisolated init(_ colorScheme: ColorScheme) {
        self = colorScheme == .dark ? .dark : .light
    }
}

extension CategoryColor {
    /// The SwiftUI color for one appearance. Gradients use this, because a
    /// gradient stop needs a concrete `Color`.
    nonisolated func color(for appearance: Appearance) -> Color {
        let c = components(for: appearance)
        return Color(hue: c.hue, saturation: c.saturation, brightness: c.brightness)
    }
}
```

   This file is admitted to `DesignSystem` because it names no feature type (`CategoryColor` lives in `Hugo/Domain`) and both Planner and Categories use it.
3. `PlannerBarView.swift`: make `PlannerBarShape` generic so it accepts any style, and keep its body as it is:

```swift
struct PlannerBarShape<Style: ShapeStyle>: View {
    let fraction: Double
    let color: Style
```

   `color.opacity(0.15)` still works, because `ShapeStyle.opacity(_:)` exists. `PlannerLegend` and `PlannerStatusHeader` keep passing `.hugoAccent`. In `PlannerBarView`, replace the `color` property with `private var color: CategoryColorStyle { CategoryColorStyle(bar.color) }`.
4. `PlannedCategoryCard.swift`: replace its `color` property in the same way. Line 52's `.fill(color)` stays.

**Verify**: the focused test command prints `** TEST SUCCEEDED **` (this is the first build since Step 1, and it runs the Step 2-3 tests), and `grep -rn "Color(hue:" Hugo/Features` prints nothing. Then `Scripts/verify.sh` exits 0, and you make commit 1.

### Step 5: Add the presets and the suggestion rule

Create `Hugo/Features/Categories/Domain/CategoryColorPreset.swift`:

```swift
import Foundation

/// A hand-picked category color. The row in Add Category and the category
/// screen offers Automatic first, then these, in this order.
nonisolated struct CategoryColorPreset: Identifiable, Sendable {
    let id: String
    let name: LocalizedStringResource
    let color: CategoryColor

    /// No red (it reads as "behind plan") and no yellow (too faint as a thin
    /// bar in light mode). Teal is Automatic, so no preset looks like it.
    static let all: [CategoryColorPreset] = [
        CategoryColorPreset(id: "blue", name: "tracker.color.preset.blue", color: CategoryColor(hue: 0.60, tone: 0.55)),
        CategoryColorPreset(id: "indigo", name: "tracker.color.preset.indigo", color: CategoryColor(hue: 0.68, tone: 0.50)),
        CategoryColorPreset(id: "purple", name: "tracker.color.preset.purple", color: CategoryColor(hue: 0.78, tone: 0.50)),
        CategoryColorPreset(id: "pink", name: "tracker.color.preset.pink", color: CategoryColor(hue: 0.90, tone: 0.45)),
        CategoryColorPreset(id: "orange", name: "tracker.color.preset.orange", color: CategoryColor(hue: 0.07, tone: 0.45)),
        CategoryColorPreset(id: "green", name: "tracker.color.preset.green", color: CategoryColor(hue: 0.37, tone: 0.55)),
    ]

    /// The preset whose hue and tone are each within 0.001 of `color`.
    static func matching(_ color: CategoryColor?) -> CategoryColorPreset? { ... }

    /// The color a new category starts with: the preset used by the fewest
    /// existing categories, first in `all` on a tie. With any preset unused,
    /// that is the first unused one. Automatic and custom colors count for no
    /// preset.
    static func suggested(forNewCategoryAmong existing: [CategoryColor?]) -> CategoryColor { ... }
}
```

Run `swift-format` over the file if a line exceeds the lint's limit. The lint reports it, so fix the formatting and leave the values alone.

**Verify**: `CategoryColorPresetTests` pass (focused command).

### Step 6: Add the color picker row

Create `Hugo/Features/Categories/Views/CategoryColorPicker.swift`. It's a horizontal row of swatches with Automatic first, then `CategoryColorPreset.all`:

```swift
import SwiftUI

/// A row of color swatches for a category: Automatic, then the presets.
struct CategoryColorPicker: View {
    @Binding var selection: CategoryColor?

    @ScaledMetric(relativeTo: .body) private var swatchSize = HugoLayout.Size.colorSwatch

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: HugoLayout.Spacing.compact) {
                swatch(color: nil, name: "tracker.color.automatic")
                ForEach(CategoryColorPreset.all) { preset in
                    swatch(color: preset.color, name: preset.name)
                }
            }
            .padding(.vertical, HugoLayout.Spacing.tight)
        }
        .scrollIndicators(.hidden)
    }

    private func isSelected(_ color: CategoryColor?) -> Bool {
        guard let color else { return selection == nil }
        return CategoryColorPreset.matching(selection)?.color == color
    }

    private func swatch(color: CategoryColor?, name: LocalizedStringResource) -> some View {
        let selected = isSelected(color)
        return Button {
            selection = color
        } label: {
            Circle()
                .fill(CategoryColorStyle(color))
                .frame(width: swatchSize, height: swatchSize)
                .overlay {
                    if color == nil {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(HugoLayout.Spacing.tight)
                .overlay {
                    Circle().strokeBorder(.primary, lineWidth: 2.5).opacity(selected ? 1 : 0)
                }
                .frame(minWidth: HugoLayout.Size.minimumHitTarget, minHeight: HugoLayout.Size.minimumHitTarget)
                .contentShape(Circle())
                .motion(Motion.feedback, value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
```

Add `#Preview` blocks that show the row with `nil` selected and with Blue selected (`@Previewable @State`), following the `CategoryPicker` preview.

**Verify**: build succeeds (focused command).

### Step 7: Put the row on Add Category and the category screen

1. **`AddCategoryView`**:
   - Add `@State private var color: CategoryColor?` and `@State private var didSuggestColor = false`.
   - Insert this section right after the name `TextField` section:

```swift
                Section {
                    CategoryColorPicker(selection: $color)
                } header: {
                    Text("tracker.color.label")
                } footer: {
                    Text("tracker.color.footer")
                }
```

   - Add `.onAppear { guard !didSuggestColor else { return }; didSuggestColor = true; color = CategoryColorPreset.suggested(forNewCategoryAmong: trackers.map(\.categoryColor)) }` to the `NavigationStack`'s `Form`.
   - In `submit()`, call `tracker.setCategoryColor(color)` right after creating the tracker and before `context.insert(tracker)`.
   - In the icon tile, change `.foregroundStyle(.primary)` to `.foregroundStyle(CategoryColorStyle(color))`.
2. **`CategoryDetailView`**: insert the same section (same header and footer keys) right after the name section, with a binding to the model:

```swift
                CategoryColorPicker(
                    selection: Binding(
                        get: { tracker.categoryColor },
                        set: { tracker.setCategoryColor($0) }))
```

   Change the icon tile's `.foregroundStyle(.primary)` to `.foregroundStyle(CategoryColorStyle(tracker.categoryColor))`. Leave the toolbar's principal icon unchanged.
3. **`CategoryListView`** and **`CategoryPicker`**: on the row's `Image(systemName: tracker.iconName)` only, add `.foregroundStyle(CategoryColorStyle(tracker.categoryColor))`. The row text stays `.primary`.

**Verify**: build succeeds, and `grep -n "CategoryColorPicker" Hugo/Features/Categories/Screens/*.swift` shows exactly two matches (Add and Detail).

### Step 8: Add the strings (English and Danish)

Add these keys to `Hugo/Resources/Localizable.xcstrings`, with the same JSON shape as `tracker.options.label` (an `en` and a `da` `stringUnit` with `"state": "translated"`, plus a `comment`). Keep neighboring keys and file formatting intact.

| Key | English | Danish | Comment |
|---|---|---|---|
| `tracker.color.label` | Color | Farve | Header above the category color row. |
| `tracker.color.footer` | The Planner uses this color for the category, and so does its icon. | Planlæg bruger denne farve til kategorien, og det gør dens ikon også. | Footer under the category color row. |
| `tracker.color.automatic` | Automatic | Automatisk | VoiceOver name of the swatch that uses the app's own color. |
| `tracker.color.preset.blue` | Blue | Blå | Name of a category color preset. |
| `tracker.color.preset.indigo` | Indigo | Indigo | Name of a category color preset. |
| `tracker.color.preset.purple` | Purple | Lilla | Name of a category color preset. |
| `tracker.color.preset.pink` | Pink | Pink | Name of a category color preset. |
| `tracker.color.preset.orange` | Orange | Orange | Name of a category color preset. |
| `tracker.color.preset.green` | Green | Grøn | Name of a category color preset. |

"Planlæg" is the Danish name of the Planner tab (key `tab.planner`).

**Verify**: catalog JSON check exits 0, and `python3 -I -c "import json;s=json.load(open('Hugo/Resources/Localizable.xcstrings'))['strings'];print(sum(k.startswith('tracker.color.') for k in s))"` prints `9`.

### Step 9: Add the domain term

In `CONTEXT.md`, under `## Time`, add this after the **Category snapshot** entry:

```markdown
**Category color**:
The color a category is drawn in: Automatic (the app's accent color) or a hue and a tone the user picked. The tone gives a deeper color in light mode and a lighter one in dark mode, so the same choice stays visible on both. A category color is only a visual aid; names and order always tell categories apart.
_Avoid_: Tint, theme color
```

**Verify**: `grep -c "^\*\*Category color\*\*:" CONTEXT.md` prints `1`. Then run `Scripts/verify.sh` (exit 0), `git diff --check` (exit 0), and make commit 2.

### Step 10 (owner, not the executor): CloudKit schema and device check

Report these to the owner as open items. Do not attempt them.

1. **CloudKit Development**: run a Debug build on a device signed into iCloud, then set a preset color on a category and wait for it to sync. That creates `CD_colorHue` and `CD_colorTone` on `CD_Tracker`, and both fields must exist before deploying. In CloudKit Console, check that both fields exist on `CD_Tracker` in Development.
2. **Deploy to Production** in CloudKit Console **before** any TestFlight build ships V13. Build 120 lost sync on Production because an optional field was missing (`CD_startMinute`, November 2026).
3. **Device check, light and dark mode**:
   - Every preset is easy to see in the Planner's calendar bars, in day-sheet cards, as list icons and on the icon tile.
   - Field Service still shows the accent color after upgrading from build 120 data.
   - A new category preselects the first unused preset.
   - Tapping Automatic clears the color.
   - A device on an older build keeps showing Automatic after another device sets a color.
   - VoiceOver reads each swatch's name and "Selected".

## Test plan

All tests use Swift Testing (`import Testing`, `@Test`, `#expect`) and `@testable import Hugo`.

`HugoTests/Domain/CategoryColorTests.swift` (new):

- `storedNilMeansAutomatic`: `CategoryColor(storedHue: nil, storedTone: 0.5)`, `(0.5, nil)` and `(nil, nil)` are all nil.
- `storedOutOfRangeOrNonFiniteMeansAutomatic`: `(1.5, 0.5)`, `(0.5, -0.1)` and `(.nan, 0.5)` are nil.
- `clampingInitializerClamps`: `CategoryColor(hue: 1.4, tone: -1)` has hue 1 and tone 0, and `CategoryColor(hue: .nan, tone: .infinity)` has hue 0 and tone 0.
- `blueMatchesTheFormulaInBothAppearances`: hue 0.60, tone 0.55. Light gives saturation 0.7825 and brightness 0.689. Dark gives saturation 0.494 and brightness 0.945. Check each within `1e-9` (no correction applies to this color).
- `lightToneDeepensAndDarkToneSaturates`: for hue 0.6, light brightness at tone 0 is greater than at tone 1, and dark saturation at tone 0 is less than at tone 1.
- `faintYellowIsDarkenedInLightMode`: hue 0.15, tone 0, light brightness is less than 0.92.
- `everyColorMeetsTheContrastFloor`: for hues `i / 48.0` (i in 0..<48) and tones `j / 10.0` (j in 0...10), the light components reach at least `CategoryColor.minimumContrast` against every entry of `lightBackgrounds`, and the dark components against every entry of `darkBackgrounds`. Use `rgb`, `relativeLuminance` and `contrastRatio`, and compare with `>= minimumContrast - 1e-9`.

`HugoTests/Features/Categories/Domain/CategoryColorPresetTests.swift` (new):

- `presetsHaveUniqueIDsAndColors`: 6 presets, unique ids, unique colors.
- `matchingFindsPresetWithinTolerance`: `CategoryColor(hue: 0.6004, tone: 0.5496)` matches `blue`, and `CategoryColor(hue: 0.5, tone: 0.5)` and `nil` match nothing.
- `suggestionPicksFirstUnusedPreset`: existing `[nil, blue]` suggests indigo, and `[]` suggests blue.
- `suggestionCyclesWhenAllAreUsed`: existing = all six presets plus another blue suggests indigo (the fewest uses, first in order).
- `suggestionIgnoresCustomColors`: existing `[CategoryColor(hue: 0.5, tone: 0.5)]` suggests blue.

`HugoTests/Persistence/SchemaMigrationTests.swift` (add, modeled on `migratingV11StoreKeepsEntriesAndStartsWithoutPlans` and `makeV11Store`):

- Add `makeV12Store(at:trackers:entries:plans:)`, which is `makeV11Store` with `SchemaV12.self`, `[SchemaV12.Tracker]`, `[SchemaV12.Entry]` and `[SchemaV12.Plan]`.
- `migratingV12StoreStartsEveryCategoryAsAutomatic`: a V12 store with Field Service (`hue: 0.5, sat: 1, bri: 0`), a second tracker with a stray value (`hue: 0.3, sat: 0.8, bri: 0.9`), an entry on Field Service, and a plan for the second tracker (`SchemaV12.Plan(date:duration:tracker:)`). After `makeCurrentStore`:
  - 2 trackers, every one with `colorHue == nil`, `colorTone == nil` and `categoryColor == nil`.
  - The entry's `tracker?.name` is still "Field Service".
  - 1 plan, whose `categoryID` equals the second tracker's id.
- `currentStoreRoundTripsCategoryColor` (in-memory, like `currentStoreRoundTripsPlanWithCategorySnapshot`): `setCategoryColor(CategoryColor(hue: 0.6, tone: 0.55))`, save, fetch, and expect `categoryColor` to equal it. Then `setCategoryColor(nil)` leaves both fields nil.

`HugoTests/Persistence/SyncDeduplicatorTests.swift` (add):

- `colorBreaksATieBetweenOtherwiseEqualCopies`: two trackers with the same id, `createdAt`, name, icon and type. One has no color and one has blue. `mergeDuplicateCategories()` removes 1, and the survivor is the one with no color (nil sorts as -1). This checks the tie-break is deterministic.

`HugoTests/App/AppBootstrapperTests.swift`: no change needed. `seedsDefaultCategoryOnFirstLaunchWithoutCloudData` must still pass.

## Done criteria

- [ ] `Scripts/verify.sh` exits 0
- [ ] The focused test command prints `** TEST SUCCEEDED **`, and the new tests above exist and run
- [ ] `grep -rn "CategoryProgressColor" Hugo HugoTests` prints nothing
- [ ] `grep -n "typealias CurrentSchema = SchemaV13" Hugo/Persistence/AppSchema.swift` prints one line
- [ ] `grep -rnE "\.(sat|bri)\b" Hugo/App Hugo/Features Hugo/Domain Hugo/DesignSystem Hugo/Persistence/SyncDeduplicator.swift` prints nothing
- [ ] `git diff af030fb --stat -- Hugo/Persistence/SchemaVersions/V1 Hugo/Persistence/SchemaVersions/V2 Hugo/Persistence/SchemaVersions/V2_1 Hugo/Persistence/SchemaVersions/V3 Hugo/Persistence/SchemaVersions/V4 Hugo/Persistence/SchemaVersions/V5 Hugo/Persistence/SchemaVersions/V6 Hugo/Persistence/SchemaVersions/V7 Hugo/Persistence/SchemaVersions/V8 Hugo/Persistence/SchemaVersions/V9 Hugo/Persistence/SchemaVersions/V10 Hugo/Persistence/SchemaVersions/V11 Hugo/Persistence/SchemaVersions/V12` prints nothing
- [ ] The catalog has 9 `tracker.color.*` keys, each with English and Danish
- [ ] `git status --short` shows no modified files outside the Scope list (the owner's pre-existing `project.pbxproj` change excepted, unstaged)
- [ ] `plans/README.md` row for 098 updated, and the owner told about Step 10

## STOP conditions

Stop and report, without improvising, if:

- The drift check shows changes and the excerpts above no longer match.
- Opening a V12 store with the V13 schema throws (for example "Cannot use staged migration with an unknown model version", "Duplicate version checksums" or a lightweight-migration mapping error). Do not switch to a custom stage on your own. Report the exact error.
- Any existing `SchemaMigrationTests` test still fails to compile or fails after the six edits in Step 3, item 5.
- The compiler rejects `nonisolated` on `CategoryColorStyle`, on the `hugoAccent` statics or on `Tracker.categoryColor`, and one obvious fix (for example moving the `nonisolated` keyword) does not solve it.
- Something seems to need an edit in `SchemaVersions/V1`-`V12` or in an earlier migration stage.
- A Planner test that passes `color: nil` stops compiling for a reason other than the type rename.

## Maintenance notes

- **Plan 099 (SLN-308)** adds a color wheel button and two sliders to `CategoryColorPicker`, and reuses `CategoryColor`, `CategoryColor.color(for:)` and `CategoryColorPreset.matching`. A color that matches no preset is a custom color. In this plan's row it shows no swatch as selected, and that is expected until 099 lands.
- **Repeating plans** (an idea in `plans/README.md`) were going to take schema V13. They now need V14.
- **Old builds and sync.** Builds up to 120 never read `colorHue`/`colorTone`, so they keep drawing Automatic. CloudKit keeps the old `CD_hue`, `CD_sat` and `CD_bri` fields forever (fields can't be deleted from a deployed CloudKit schema), but nothing reads them any more.
- **Increase Contrast** is not handled specially. If testers ask, raise `minimumContrast` when `environment.colorSchemeContrast == .increased` inside `CategoryColorStyle`, not in the presets.
- Reviewers should check two things: the four V13 model files must be exact copies apart from the header, the extension line and the `Tracker` color fields, and the dedup tie-break must still return `false` for fully equal copies.
