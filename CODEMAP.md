# Codemap

Read this file before exploring the repo. It points to the file you are most likely to edit for each area. `AGENTS.md` section 7 defines the folder roles used below: Screens (destinations), Views (embedded components), State (`@Observable` workflow classes), Domain (pure value logic) and Services (anything that touches `ModelContext` or the system). `CONTEXT.md` defines the domain terms. Types are written as `TypeName` (role folder). Paths are relative to the repo root.

## App

`Hugo/App` is composition only. `HugoApp` is the entry point, `AppRootView` holds the tab bar (`AppTab`), `AppBootstrapper` seeds defaults and runs first-launch work, `ModelContainerLoader` builds the container and `StoreLoadFailureView` shows when it cannot. `CloudTrackerLookup` asks CloudKit whether categories already exist before seeding, so a second device does not create duplicates. `HugoCommands` holds the iPad and Mac menu commands.
Tests: `HugoTests/App/`.

## DesignSystem

Generic UI with no feature types. Subfolders: `Components` (`AdaptiveTwoColumnStack`, `GradientSlider`, `MarkedProgressBar`, `SelectableOptionRow`), `Modifiers` (`ReadableContentWidth`, `ErrorAlert`, `ContentHeightSheetDetents`), `Styles` (`CardButtonStyle`, `HugoToggleStyle`), `Motion` (`Motion`) and `Theme` (`HugoLayout` in `Theme.swift`, `CategoryColorStyle`). Geometry helpers sit next to their view as `*Geometry.swift` so tests can reach them.
Tests: `HugoTests/DesignSystem/`.

## Domain

Value types shared by several features: `YearMonth`, `RoundingRule`, `CategoryColor`, `HeadlineDuration`, `ServiceDurationFormatter` and `UserDefaultsKeys`. Every UserDefaults key lives in `UserDefaultsKeys`, with comments saying whether it syncs.
Tests: `HugoTests/Domain/`.

## Persistence

- Current schema: `SchemaV14` in `Hugo/Persistence/AppSchema.swift`. `CurrentSchema` is a typealias, and `Entry`, `Tracker`, `SubmittedReport`, `Plan` and `SchoolCredit` are typealiases to its models.
- Model definitions per version: `Hugo/Persistence/SchemaVersions/V14/` (`EntryV14`, `TrackerV14`, `SubmittedReportV14`, `PlanV14`, `SchoolCreditV14`). Never edit an older version folder.
- Migration plan: `HugoMigrationPlan` in `Hugo/Persistence/HugoMigrationPlan.swift`. Add the new schema to `schemas` and a stage such as `migrateV13toV14`.
- Container creation: `ModelContainerFactory`. Sync repair: `SyncDeduplicator` (merges duplicate categories and monthly reports) run by `SyncDeduplicationScheduler`.
- Other: `SubmittedReportSelection` picks the canonical report, `SubmittedReport+Submission` creates one, `ModelContext+IsolatedChange` holds the isolated-change helper. `Hugo/Persistence/Legacy/` holds `TrackerType` and old model leftovers.
- Tests: `HugoTests/Persistence/`. Schema migrations are tested in `SchemaMigrationTests.swift`, with helpers in `HugoTests/TestSupport/` (`InMemoryModelContainer`, `TemporaryStore`).

## PreviewSupport

`PreviewModelContainer` provides `.modelContainer(.preview)`. `ReportPreviewFixtures` provides sample entries, `summary`, `yearReport` and `ServiceMonth` values.

## Features/Categories

Add, edit, delete and pick categories, plus the Default category. The persisted model is `Tracker`.
- `AddCategoryView`, `CategoryDetailView`, `CategoryListView` (Screens). `CategoryPicker` (Screens) is used by Entries.
- `CategoryDeletionService`, `DefaultCategoryService` (Services). The latter also migrates the old per-category default flag.
- `DefaultCategory`, `CategoryName` (Domain). `DefaultCategoryDefinition` defines the seeded Field Service category.
- `CategoryColorPreset` (Domain) lists Category color choices. `TrackerCategoryColor.swift` extends `Tracker` with `setCategoryColor`.
Terms: Category, Category kind, Field Service category, Credit category, Default category, Category color.
Tests: `HugoTests/Features/Categories/`.

## Features/Entries

Add, view and edit Entries. Read an entry's category through `entry.resolvedCategory()` in `EntryCategory.swift`, never `entry.tracker`.
- `AddEntryFormModel` (State) holds the add and edit form workflow.
- `AddEntryView`, `EntryDetailView`, `EntryTimePickerView` (Screens).
- `EntryRow`, `DurationWheelPicker`, `EntryContextMenu` (Views).
- `EntryCategory` (Domain) resolves the Category snapshot. `BibleStudiesRule`, `CategoryTotals` (Domain).
Terms: Entry, Category snapshot, Untracked entry, Logged time.
Tests: `HugoTests/Features/Entries/`.

## Features/Help

In-app help articles. Article text is Markdown in `Hugo/Resources/Markdown/Help/` (`Base.lproj`, `da.lproj`). `HelpArticle` (Domain), `HelpView` (Screens), `HelpMenu` (Views).
Tests: `HugoTests/Features/Help/`.

## Features/Onboarding

First-launch flow. `OnboardingView` (Screens) runs the pages in `OnboardingStep` order (Domain): welcome, overseer, publisher status. `OnboardingPageLayout`, `OnboardingStepBar` (Views).
Terms: Overseer, Publisher status.
Tests: `HugoTests/Features/Onboarding/`.

## Features/Overview

The first tab: month progress and the entry list.
- `OverviewView` (Screens) is the tab root. `PlanPaceSheet`, `CarriedInBreakdownSheet` (Screens).
- `OverviewMetrics` (Domain) computes the numbers the screen shows. `PlanPaceSentence.swift` (an extension of `PlanPace`), `MonthlyProgressStatus`, `MonthlyCircleFill` (Domain).
- `MonthlyProgressCard`, `OverviewListView`, `ReportReminderCard` (Views).
Terms: Monthly goal, Counted time, Plan pace, Carried-in entry.
Tests: `HugoTests/Features/Overview/`.

## Features/Planner

Plans per day and the monthly target. `PlannerView` (Screens) is the tab root.
- `PlanService` (Services) writes Plans. `PlanFormModel` (State) drives `PlanFormView` (Screens).
- `PlannerTarget`, `PlanPace`, `PlanMatcher`, `PlannedItem`, `PlannerMonth` (Domain). `PlanMatcher` decides which Entries cover which Plans.
- `PlannerCalendarGrid`, `PlannerDayCell`, `PlannerMonthPage` (Views).
- `PlannerDaySheet`, `PlannerTargetSettingsView`, `BufferScopeSettingsView` (Screens).
Terms: Planner, Plan, Still planned, Projected time, Monthly target, Adjusted target, Buffer, Plan pace, Covered time, Unplanned time, Logging a plan.
Tests: `HugoTests/Features/Planner/`.

## Features/PublisherStatus

The publisher status choice and its goal rules. `PublisherStatus` (Domain) holds the status values and their monthly and yearly goals. `PublisherStatusOptionsView` (Screens), `PublisherStatusOptionRow` (Views).
Terms: Publisher status, Monthly goal, Yearly goal.
Tests: `HugoTests/Features/PublisherStatus/`.

## Features/Reports

Building and sending the monthly report.
- `ReportingLineCalculator`, `MonthlyReportBuilder`, `MonthlyReportSummary`, `ReportingLine` (Domain) turn Entries into reporting lines and rounding.
- `ServiceMonth` (Domain) combines a month, its entries and its canonical report. It also reports unreported changes.
- `ReportComposer` (Domain) renders the greeting template and message.
- `SubmitReportFormModel` (State) drives `SubmitReportView` (Screens). It takes `now`, `calendar`, `locale` and `UserDefaults`.
- `ReportSubmissionService` (Services) saves the `SubmittedReport`.
- `CarriedInTime`, `ReportAdjustments`, `ReportReminderSchedule` (Domain).
Terms: Report, Submitted report, Service month, Reporting line, Remainder, Rounding rule, Transfer, Reported hours, Unreported change, Due month, Greeting template, Canonical report, Placeholder report.
Tests: `HugoTests/Features/Reports/`.

## Features/SchoolCredits

School credit hours, stored as `SchoolCredit`. `SchoolCreditService` (Services), `School`, `SchoolCreditLine` (Domain). The entry form is `SchoolCreditFormView` in ServiceYear.
Terms: School, School credit, Credit.
Tests: `HugoTests/Features/SchoolCredits/`.

## Features/ServiceYear

The Service Year tab and the theocratic year logic.
- `TheocraticYear` (Domain) is the only place for theocratic year date logic.
- `TheocraticYearReportBuilder`, `TheocraticYearReport` (Domain) aggregate months for a year.
- `YearlyGoalRule`, `YearlyGoalProgress` (Domain) apply the Credit allowance to the Yearly goal.
- `ServiceYearView`, `ServiceYearDetailView`, `MonthDetailView` (Screens).
- `ServiceYearMonthRow`, `TheocraticYearPicker` (Views).
Terms: Theocratic year, Year total, Counted time, Credit allowance, Yearly goal, Expected time.
Tests: `HugoTests/Features/ServiceYear/`.

## Features/Settings

Settings screens and sync status.
- `SettingsView`, `GeneralSettingsView`, `ReportSettingsView`, `OverseerSettingsView`, `DebugSettingsView` (Screens).
- `SyncedSettings` (Domain) lists which UserDefaults keys sync. `SettingsSyncService` (Services) mirrors them to iCloud.
- `CloudSyncMonitor` (State), `CloudAccountStatusReader` (Services), `CloudSyncStatus` (Domain).
- `DiagnosticsCollector` (Services), `DiagnosticsReport` (Domain).
Terms: Synced setting, Greeting template, Overseer, Publisher status.
Tests: `HugoTests/Features/Settings/`.

## Features/SymbolPicker

Icon picker for categories. `SymbolPicker` (Screens), `SymbolSet`, `SymbolDefinition`, `SymbolAttribute` (Domain).
Tests: `HugoTests/Features/SymbolPicker/`.

## Where to look for

| Task | Start here |
| --- | --- |
| Add a category field | New `VersionedSchema` in `Hugo/Persistence/SchemaVersions/`, `Hugo/Persistence/AppSchema.swift`, `Hugo/Persistence/HugoMigrationPlan.swift`, test in `HugoTests/Persistence/SchemaMigrationTests.swift`, then `Hugo/Features/Categories/Screens/AddCategoryView.swift`. Deploy the CloudKit schema first. |
| Change theocratic year logic | `Hugo/Features/ServiceYear/Domain/TheocraticYear.swift` |
| Change report composition or rounding | `Hugo/Features/Reports/Domain/ReportComposer.swift`, `ReportingLineCalculator.swift`, `Hugo/Domain/RoundingRule.swift` |
| Change the yearly goal or credit allowance | `Hugo/Features/ServiceYear/Domain/YearlyGoalRule.swift` |
| Add a setting | Key in `Hugo/Domain/UserDefaultsKeys.swift`, UI in `Hugo/Features/Settings/Screens/`, and `Hugo/Features/Settings/Domain/SyncedSettings.swift` if it syncs |
| Change what duplicates sync merges | `Hugo/Persistence/SyncDeduplicator.swift` |
| Add a reusable component | A role folder in `Hugo/DesignSystem/`, if it passes the admission rule in `AGENTS.md` |
| Change layout tokens | `Hugo/DesignSystem/Theme/Theme.swift` (`HugoLayout`) |
| Add a preview fixture | `Hugo/PreviewSupport/ReportPreviewFixtures.swift`, or `PreviewModelContainer.swift` for stored data |
| Add a test container or store | `HugoTests/TestSupport/InMemoryModelContainer.swift` |
| Add a help article | Markdown in `Hugo/Resources/Markdown/Help/Base.lproj/`, then `Hugo/Features/Help/Domain/HelpArticle.swift` |
| Change user-facing strings | `Hugo/Resources/Localizable.xcstrings` |
| Add a build flag | `Configuration/*.xcconfig` and the table in `README.md` |
