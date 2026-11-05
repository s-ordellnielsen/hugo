# Plan 038: Stop the month detail sheet from crashing when its month becomes empty

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/Features/Reports/MonthlyReportDetailView.swift Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift Hugo/Features/ServiceYear/TheocraticYearReport.swift`
> If any of these files changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/037-green-gate-and-serial-tests.md (green gate)
- **Category**: bug
- **Planned at**: commit `3f8d48b`, 2026-10-12
- **Issue**: [SLN-247](https://linear.app/sebastianln/issue/SLN-247)

## Why this matters

On the Year tab, each month row has a "Details" menu item that opens `MonthlyReportDetailView` in a sheet. The view force-unwraps `month.summary!`. A summary exists only while the month has at least one entry. Inside the sheet the user can open an entry and delete it, or change its date to another month. When that was the month's last entry, SwiftData updates the Year tab's `@Query`, the row is rebuilt with `summary == nil`, SwiftUI re-renders the still-open sheet, and the app crashes. Deleting a mistaken entry is a normal task, so the crash is easy to hit. After this plan the sheet shows an empty state instead.

## Current state

- `Hugo/Features/ServiceYear/TheocraticYearReport.swift:3-10`: the value the sheet receives. `summary` is nil when the month has no entries.

  ```swift
  nonisolated struct TheocraticYearMonth: Identifiable {
      let id: YearMonth
      let displayName: String
      let summary: MonthlyReportSummary?
      let isFuture: Bool
      let submittedReport: SubmittedReport?
      let hasUnreportedEntries: Bool
  ```

  `displayName` is always set. `TheocraticYearReportBuilder.swift:22` fills it from the summary or from `month.monthYearString(...)`.

- `Hugo/Features/ServiceYear/Views/ServiceYearMonthRow.swift:42-46`: the sheet is built from the row's live `month` value, so it re-renders when the data changes.

  ```swift
  .sheet(isPresented: $isPresentingDetails) {
      NavigationStack {
          MonthlyReportDetailView(month: month)
      }
  }
  ```

- `Hugo/Features/Reports/MonthlyReportDetailView.swift` (whole file, 48 lines):

  ```swift
  import SwiftUI

  struct MonthlyReportDetailView: View {
      @Environment(\.dismiss) private var dismiss

      let month: TheocraticYearMonth

      @State private var showingAddEntry = false

      private var summary: MonthlyReportSummary {
          // Presented only from months that have a summary.
          month.summary!
      }

      var body: some View {
          List {
              if month.isSubmitted && month.hasUnreportedEntries {
                  Section {
                      Label("report.detail.unreported.banner", systemImage: "exclamationmark.triangle.fill")

                          .font(.subheadline)
                  }
              }

              MonthlyReportTotalsView(summary: summary)
              MonthlyReportEntryListView(summary: summary, report: month.submittedReport)
          }
          .navigationTitle(summary.displayName)
          .navigationSubtitle("report.title")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
              ToolbarItem(placement: .principal) {
                  EditorialNavigationTitle(title: summary.displayName)
              }
              ToolbarItem(placement: .topBarLeading) {
                  Button("navigation.dismiss", systemImage: "xmark", role: .cancel) { dismiss() }
              }
              ToolbarItem {
                  Button("common.add", systemImage: "plus") {
                      showingAddEntry.toggle()
                  }
              }
          }
          .sheet(isPresented: $showingAddEntry) {
              AddEntryView(seededDate: summary.id.date())
          }
      }
  }
  ```

- `Hugo/Features/Reports/MonthlyReportEntryListView.swift:17` pushes `EntryDetailView(entry:)`, where the user can delete the entry or edit its date.
- Empty-state convention: `Hugo/Features/Overview/Views/OverviewListView.swift:24-37` uses `ContentUnavailableView` with the catalog key `overview.entries.empty` ("No Entries" / "Ingen timer" in Danish) and the symbol `text.page.badge.magnifyingglass`. Reuse that key and symbol. Do not add new catalog keys.
- `Hugo/PreviewSupport/ReportPreviewFixtures.swift` already has `ReportPreviewFixtures.emptyMonth` (a `TheocraticYearMonth` whose summary is nil) and `ReportPreviewFixtures.monthWithActivity`.
- Previews follow AGENTS.md: `.modelContainer(.preview)` (defined in `Hugo/PreviewSupport/PreviewModelContainer.swift`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/Reports/MonthlyReportDetailView.swift`
- `plans/README.md` (status row)

**Out of scope**:

- `ServiceYearMonthRow.swift`. Do not change how the sheet is presented. Dismissing the sheet automatically would close it under the user while they work in it.
- `MonthlyReportTotalsView` and `MonthlyReportEntryListView`. They keep taking a non-optional `MonthlyReportSummary`.
- `Localizable.xcstrings`. Reuse existing keys only.

## Git workflow

- Branch: `advisor/038-month-detail-crash`
- Commit message style: short imperative sentence, for example `Show an empty state when a month detail loses its last entry`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Remove the force unwrap and add an empty state

Rewrite the body of `MonthlyReportDetailView` so it branches on `month.summary`:

```swift
var body: some View {
    Group {
        if let summary = month.summary {
            List {
                if month.isSubmitted && month.hasUnreportedEntries {
                    Section {
                        Label("report.detail.unreported.banner", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                    }
                }

                MonthlyReportTotalsView(summary: summary)
                MonthlyReportEntryListView(summary: summary, report: month.submittedReport)
            }
        } else {
            ContentUnavailableView {
                Label("overview.entries.empty", systemImage: "text.page.badge.magnifyingglass")
            } actions: {
                Button("entry.add.label") {
                    showingAddEntry = true
                }
            }
        }
    }
    .navigationTitle(month.displayName)
    // keep .navigationSubtitle, .navigationBarTitleDisplayMode and the toolbar as they are,
    // but replace summary.displayName with month.displayName in EditorialNavigationTitle
    .sheet(isPresented: $showingAddEntry) {
        AddEntryView(seededDate: month.id.date())
    }
}
```

Delete the `private var summary: MonthlyReportSummary` property entirely. Keep the toolbar items (principal title, dismiss button, add button) unchanged apart from the `displayName` source.

**Verify**:

- `grep -n 'summary!' Hugo/Features/Reports/MonthlyReportDetailView.swift` → no matches.
- `grep -rn 'summary!' Hugo` → no matches outside `Hugo/PreviewSupport/`.
- `xcrun swift-format lint --strict --recursive Hugo HugoTests` → exit 0.

### Step 2: Add previews for both states

At the end of the file add:

```swift
#Preview("With entries") {
    NavigationStack {
        MonthlyReportDetailView(month: ReportPreviewFixtures.monthWithActivity)
    }
    .modelContainer(.preview)
}

#Preview("Empty month") {
    NavigationStack {
        MonthlyReportDetailView(month: ReportPreviewFixtures.emptyMonth)
    }
    .modelContainer(.preview)
}
```

**Verify**: `Scripts/verify.sh` → exit 0, 153 tests pass (or the current count if earlier plans added tests).

### Step 3 [owner]: Reproduce on a simulator

1. Run the app, add a single entry to a past month that has no other entries.
2. Year tab → that month's "..." menu → Details → tap the entry → delete it.
3. Expected: the sheet shows "No Entries" with an "Add Entry" button. Before this plan the app crashed here.
4. Repeat, but change the entry's date to another month instead of deleting it. Same expected result.

## Test plan

There are no view tests in this repo, and the crash comes from SwiftUI re-rendering a sheet, so a unit test cannot reproduce it. The guard is the `grep` for `summary!`, the two previews (both must render in Xcode's canvas), and the owner repro in Step 3.

## Done criteria

- [ ] `grep -rn 'summary!' Hugo --include=*.swift | grep -v PreviewSupport` prints nothing
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status --porcelain` lists only `Hugo/Features/Reports/MonthlyReportDetailView.swift` and `plans/README.md`
- [ ] `plans/README.md` row for 038 updated (DONE, or BLOCKED on the owner repro)

## STOP conditions

Stop and report back if:

- `TheocraticYearMonth` no longer has a non-optional `displayName`.
- `MonthlyReportDetailView` is presented from anywhere other than `ServiceYearMonthRow` (`grep -rn 'MonthlyReportDetailView(' Hugo`). Report the new call site before changing behavior.
- The fix seems to need changes to `MonthlyReportTotalsView` or `MonthlyReportEntryListView`.

## Maintenance notes

- Any other view that takes a `TheocraticYearMonth` and assumes `summary != nil` has the same hazard while it stays on screen during edits. Branch on the optional instead of force-unwrapping.
- If the detail view later gains its own `@Query` for the month's entries, the empty branch remains the right behavior.
