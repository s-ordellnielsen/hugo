# Plan 046: Refresh the Overview when the day or month changes while the app is open

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/Features/Overview/OverviewView.swift Hugo/App/AppRootView.swift`
> Plan 044 changes `reminderMonth` in `OverviewView.swift`, and plan 041 adds
> `scenePhase` handling to `AppRootView.swift`. Those are expected. STOP on any
> other mismatch with the excerpts below.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/044-merge-duplicate-reports-and-carry-entries.md (edits `OverviewView.reminderMonth`; run it first)
- **Category**: bug
- **Planned at**: commit `3f8d48b`, 2026-10-12

## Why this matters

`OverviewView` builds its entries query for the current month once, in `init`. iOS keeps a suspended app in memory for days, and nothing re-creates the view when the date changes. A user who opens Hugo on October 1 after last using it on September 30 sees "October" in the progress card's header (it reads `Date.now` on each render) but September's hours, and a new October entry does not appear in the list or move the ring. The report reminder, which depends on the day of the month, can also show or hide a day late. After this plan the Overview is rebuilt whenever the calendar day changes: on returning to the foreground, and on the system's "significant time change" notification (midnight, time-zone change, manual clock change).

## Current state

- `Hugo/Features/Overview/OverviewView.swift:4-24`:

  ```swift
  struct OverviewView: View {
      @Query private var entries: [Entry]
      @Query private var submissions: [SubmittedReport]

      @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

      @State private var showingAddEntry = false
      @State private var showingDetails = false

      init() {
          let interval = CurrentMonthInterval.current(now: .now, calendar: .current)
          let start = interval.start
          let end = interval.end
          _entries = Query(
              filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
      }

      private var metrics: OverviewMetrics {
          OverviewMetrics.make(
              entries: entries, status: PublisherStatus.status(for: statusID), now: .now, calendar: .current)
      }
  ```

  The rest of the file (`reminderMonth`, `body`, a `#Preview { OverviewView() }`) reads `.now` directly.
- `Hugo/App/AppRootView.swift:86-92` creates it with `case .overview: OverviewView()`. `Hugo/Features/Overview/Views/OverviewListView.swift` has a `#Preview { OverviewView().modelContainer(.preview) }`.
- `CurrentMonthInterval.current(now:calendar:)` is in `Hugo/Features/Overview/OverviewMetrics.swift:3-12` and is unit-tested.
- The target enables `MemberImportVisibility`, so using `NotificationCenter.publisher` needs `import Combine`, and `UIApplication` needs `import UIKit`. AGENTS.md forbids `DispatchQueue`; use `RunLoop.main` when a scheduler is needed.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/Features/Overview/OverviewView.swift`
- `plans/README.md` (status row)

**Out of scope**:

- `AppRootView.swift`. `OverviewView()` keeps its zero-argument initializer, so call sites and previews stay unchanged.
- Other tabs. The Year tab computes "now" on each render from an unbounded query (performance is plan 048).
- `MonthlyProgressCard`, `OverviewMetrics`, `ReportReminderSchedule`.

## Git workflow

- Branch: `advisor/046-overview-day-change`
- Commit message style: short imperative sentence, for example `Rebuild the Overview when the day changes`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Split the view into a day-aware wrapper and the existing content

1. Rename the existing `struct OverviewView` to `private struct OverviewDayView` and give it a `today: Date` parameter:

   ```swift
   private struct OverviewDayView: View {
       let today: Date
       // existing @Query, @AppStorage, @State properties unchanged

       init(today: Date) {
           self.today = today
           let interval = CurrentMonthInterval.current(now: today, calendar: .current)
           let start = interval.start
           let end = interval.end
           _entries = Query(
               filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
       }
       // metrics, reminderMonth and body unchanged
   }
   ```

   Leave `metrics`, `reminderMonth` and `body` reading `.now` as they do today. The wrapper re-creates this view whenever the day changes, so `.now` is fresh.
2. Add a new `struct OverviewView` above it:

   ```swift
   struct OverviewView: View {
       @Environment(\.scenePhase) private var scenePhase
       @State private var today = Calendar.current.startOfDay(for: .now)

       var body: some View {
           OverviewDayView(today: today)
               .id(today)
               .onChange(of: scenePhase) { _, phase in
                   if phase == .active { refreshToday() }
               }
               .onReceive(
                   NotificationCenter.default
                       .publisher(for: UIApplication.significantTimeChangeNotification)
                       .receive(on: RunLoop.main)
               ) { _ in
                   refreshToday()
               }
       }

       private func refreshToday() {
           let start = Calendar.current.startOfDay(for: .now)
           if start != today { today = start }
       }
   }
   ```

   `.id(today)` gives the content a new identity on a new day, so `init` runs again and the query moves to the new month. Sheets open at midnight are dismissed by this; that is acceptable.
3. Add `import Combine` and `import UIKit` at the top of the file.

**Verify**:

- `grep -n 'struct OverviewView\|struct OverviewDayView' Hugo/Features/Overview/OverviewView.swift` → both present.
- `grep -rn 'OverviewView()' Hugo` → the same three call sites as before (`AppRootView.swift`, two previews).
- `grep -n 'DispatchQueue' Hugo/Features/Overview/OverviewView.swift` → no matches.
- `Scripts/verify.sh` → exit 0.

Commit: `Rebuild the Overview when the day changes`.

### Step 2 [owner]: Check on a device

1. Open Hugo on the Overview, then go to Settings → General → Date & Time, turn off "Set Automatically" and move the date to the 1st of next month. Return to Hugo. The progress card shows the new month with 0 hours, and the entries list is empty.
2. Add an entry: it appears in the list and the ring.
3. Restore automatic date and time.

## Test plan

No new unit tests: the month interval logic is already covered by `OverviewMetricsTests.currentMonthUsesHalfOpenIntervalAcrossDecember`, and the change is view wiring. The owner check in Step 2 covers the behavior.

## Done criteria

- [ ] `grep -c 'Calendar.current.startOfDay' Hugo/Features/Overview/OverviewView.swift` prints at least 2
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 046 updated

## STOP conditions

Stop and report back if:

- `OverviewView` takes parameters at any call site (`grep -rn 'OverviewView(' Hugo`).
- The `onReceive` closure produces Swift 6 concurrency errors you cannot fix in two attempts. Then keep only the `scenePhase` trigger and report.
- The previews fail to compile because `OverviewDayView` is `private`. Make it `fileprivate` instead and continue.

## Maintenance notes

- Any view that bakes "now" into a `@Query` in `init` has this problem. Pass the day in from a wrapper like this one and key the view with `.id`.
- If the Overview later keeps editing state that must survive midnight (a long form), move that state above the `.id` boundary.
