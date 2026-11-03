# Agent Instructions: Hugo – Helping You Go Out

This file contains strict context, architectural constraints, and modern coding standards for AI agents working in this repository.

## 1. System Target & Tech Stack
- **Platform Target:** iOS 26+ / iPadOS 26+ (No legacy fallbacks allowed).
- **Language:** Swift 6+ with strict concurrency checked.
- **UI Framework:** SwiftUI exclusively (No UIKit wrapper components unless absolutely unavoidable).
- **Database & Sync:** SwiftData with CloudKit container integration (requires automatic syncing constraints).
- **Concurrency:** Modern structured concurrency (`Task`, `actor`, `async/await`, `@MainActor`).

---

## 2. Architecture & Design Patterns

### View & Model Separation
- Keep Views purely visual. Do not perform complex data mapping, computation, or database queries inside the View body.
- Isolate state and business logic into `@MainActor` classes decorated with the `@Observable` macro.
- Use **SwiftData Model Context** dynamically injected via the environment rather than singleton databases.

### Concurrency Rules (Swift 6 Strict Mode)
- Never use legacy threading structures like `DispatchQueue.main.async` or `NSThread`. Use `MainActor.run` or mark classes/methods with `@MainActor`.
- Avoid unstructured `Task { ... }` where structural `async let` or `taskGroup` can be used.
- Ensure all models passing between threads conform to `Sendable` or are constrained to the `@MainActor`.

---

## 3. SwiftUI & State Guidelines

### State Management
- Use the modern `@Observable` macro for ViewModels and State Containers.
- Use `@State` inside views to hold locally instantiated `@Observable` objects or primitive local state.
- Use `@Bindable` when you need to create bindings (`$`) to properties of an `@Observable` model object.
- Never use legacy property wrappers: `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject`.

```swift
/// PREFERRED PATTERN
import SwiftUI

@Observable
@MainActor
class FeatureViewModel {
    var searchQueries: String = ""
    var isProcessing = false
    
    func performSearch() async {
        isProcessing = true
        defer { isProcessing = false }
        // Fetch logic...
    }
}

struct FeatureView: View {
    @State private var viewModel = FeatureViewModel()
    
    var body: some View {
        VStack {
            TextField("Search...", text: $viewModel.searchQueries)
            
            if viewModel.isProcessing {
                ProgressView()
            } else {
                Button("Search") {
                    Task { await viewModel.performSearch() }
                }
            }
        }
    }
}
```

## 4. Previews

```swift
/// PREFERRED PATTERN FOR PREVIEWS
#Preview {
    OverviewView()
        .modelContainer(.preview)
}
```

## 5. Domain Vocabulary & Business Logic

Domain terms are defined in `CONTEXT.md` at the repo root. Use those words in type names, comments and plans, and add a term there in the same change when you introduce a new domain concept.

### Theocratic Year Definition
In this application, we use a custom calendar system called the **Theocratic Year**. You must respect this definition across all date calculations, database schemas, and UI layouts.

- **Definition:** A theocratic year runs from **September 1st** of one year to **August 31st** of the following year.
- **Naming Convention:** It must always be formatted and referred to as `YYYY/YYYY` (e.g., September 1, 2026, to August 31, 2027, is designated as `2026/2027`).
- **Calculations:** 
  - When calculating statistical totals, charts, or filtering database records for a "theocratic year", always bound your start date to September 1st and end date to August 31st.

#### Use the existing helpers

Use `TheocraticYear` (`Hugo/Features/ServiceYear/Domain/TheocraticYear.swift`) instead of writing new date logic: `TheocraticYear.containing(_:calendar:)` or `date.theocraticYear(using:)` to find a date's year, `displayName` for the `YYYY/YYYY` label, `months` for its twelve `YearMonth`s, and `dateRange(calendar:)` for query bounds. Months are `YearMonth` values (`Hugo/Domain/YearMonth.swift`). Always pass the `Calendar` in so tests can fix it.

## 6. Principles

- **Simplicity.** Always keep the app as simple as possible, do not add unnecessary features. No fluff that is unrelated should be added.
- **Ease of use.** The app should be accessible to all, the user base ranges from around 13 to 70 years. As there will be a lot of older users, the app should always explain itself and make good use of accessibility features. Meanwhile the app should also cater to the younger audience.
- **Modularity.** The app will be used by non-tech users and power users. So the app should be modular and be able to adapt to the users needs. But this should under no circumstance be at the expense of the **Simplicity** and **Ease of use** principles.

## 7. Project structure

### Top level of `Hugo/`

- `App`: app entry point, root view, bootstrap and the CloudKit boundary. Composition only, no reusable UI.
- `DesignSystem`: generic UI that knows nothing about any feature.
- `Domain`: value types shared by several features (`YearMonth`, `RoundingRule`, `UserDefaultsKeys`).
- `Features`: one folder per feature.
- `Persistence`: SwiftData schemas, migrations, the container factory and sync repair.
- `PreviewSupport`: preview containers and fixtures.
- `Resources`: string catalogs, help Markdown and app icons.

Do not add other top-level folders. Do not create catch-all folders such as `Utilities`, `Helpers`, `Managers`, `Common`, `Shared`, `Extensions` or a top-level `Views`. Every folder is named after what it holds or what role its files play.

### `DesignSystem`

This is the place for UI that is generic on purpose. Its subfolders are named by role: `Components` (reusable views), `Styles` (`ButtonStyle` and similar), `Modifiers` (`ViewModifier` and `View` extensions), `Motion` and `Theme` (tokens such as `HugoLayout` and colors). Add a new role folder when a new kind of generic code appears.

A file belongs here only if it names no feature type (no `Entry`, `Tracker`, `SubmittedReport` and so on), imports nothing from a feature, and either two or more features use it or it was written to be used anywhere. A view that shows an entry or a category belongs to its feature, even when it looks reusable. Features may use `DesignSystem` and `Domain`. `DesignSystem` and `Domain` never use a feature.

### Feature folders

Every Swift file in a feature lives in a role folder, even when it is the only file in that role. Create a role folder when its first file arrives, and do not leave empty folders. The roles are:

- `Screens`: destinations. Tab roots, pushed screens and sheets, which normally own a navigation title or toolbar.
- `Views`: components embedded in screens, including UIKit bridges (`UIViewRepresentable`).
- `State`: `@MainActor @Observable` classes that hold a screen's state and workflow.
- `Domain`: value types and logic, `nonisolated` where possible. No views and no `ModelContext`.
- `Services`: types that read or write the SwiftData context or the system, for example `CategoryDeletionService`.

Use no other role folders and do not nest folders inside a role folder. If a role folder grows too large, the feature probably contains two features. A feature may use another feature's types when it has to (for example `Entries` uses `CategoryPicker`), but avoid circular dependencies between features.

Tests mirror the source layout: the test for `Hugo/Features/Reports/Domain/ReportComposer.swift` lives in `HugoTests/Features/Reports/Domain/`. Shared test helpers live in `HugoTests/TestSupport`.

## 8. Verification and testing

- Run `Scripts/verify.sh` before every commit. It runs `swift-format lint --strict`, the tests (serially) and static analysis, and must exit 0. Use 4-space indentation; tabs fail the lint.
- Run `Scripts/install-hooks.sh` once after cloning. The pre-commit hook formats staged Swift files.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`). Persistence tests use `InMemoryModelContainer.make()`.
- Types with time- or locale-dependent logic take `now`, `calendar`, `locale` and `UserDefaults` as initializer parameters with production defaults (see `SubmitReportFormModel`). Tests pass fixed values.
- Schema changes need a new `VersionedSchema`, a stage in `HugoMigrationPlan`, and a test in `SchemaMigrationTests`. Never edit a shipped schema version.
- CloudKit sync can duplicate rows, because it cannot enforce uniqueness. Merges live in `SyncDeduplicator` and must choose the surviving row from synced attributes only.
- Get an entry's category with `entry.resolvedCategory()`, never from `entry.tracker` directly.

## Final repository conventions

* Put new code where section 7 says. Do not add catch-all folders; generic UI goes in `Hugo/DesignSystem` under its admission rule.
* Pure value logic does not need a ViewModel. Simple views may own local state; use `@Observable` for stateful workflows and `@Bindable` for SwiftData models when bindings are required.
* Persistence names remain `Tracker` even where the UI says Category. Historical SwiftData schemas are compatibility definitions.
* Swift 6 complete concurrency checking and MainActor default isolation are intentional project settings.
* All SwiftData models must be compatible with CloudKit. Unless specifically specified as not being synced in the cloud, all models will be synced with CloudKit and thus their models will *have* to be compatible with CloudKit.
