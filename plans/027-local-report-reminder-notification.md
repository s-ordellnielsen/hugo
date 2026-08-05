# Plan 027: Local report-reminder notification (design + spike)

> **Executor instructions**: This is a **direction/spike** plan, not a
> straight-to-implementation plan. Steps 1–2 are read-only investigation that
> produce a decision record. Only Step 3 writes code, and only a minimal
> proof-of-concept behind a flag. Run every verification command. If anything
> in "STOP conditions" occurs, stop and report — do not improvise. When done,
> update the status row for plan 027 in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Features/Reports/Domain/ReportReminderSchedule.swift Hugo/Features/Overview/OverviewView.swift Configuration/Hugo.entitlements Hugo/Info.plist`
> If any of these changed, re-derive "Current state" from live code and treat a
> mismatch as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: M (spike + decision) → L (full feature, deferred)
- **Risk**: MED (permission UX + scheduling correctness)
- **Depends on**: none blocking; sequencing after plans/017 (error plumbing) and 024 (localization) is recommended so the notification strings and any new alerts reuse those patterns
- **Category**: direction / new-feature spike
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

The app already *knows* when a report is due: `ReportReminderSchedule.dueMonth`
returns the month to prompt for, and `OverviewView.reminderMonth` already
combines "due" with "no real submission" to decide whether to show the
`ReportReminderCard`. But that card only exists **while the app is open**. A
publisher who doesn't open Hugo near month-end never sees it. A local
notification closes that gap without any server.

The operator explicitly approved this direction and deferred the App
Intent/widget alternative — this plan covers **only the local-notification
route**, not a widget.

## Hard constraints established by research (do NOT re-derive)

These are confirmed against the repo and Apple's frameworks; treat as fixed:

1. **Local notifications require no background mode and no entitlement.** The
   existing `UIBackgroundModes = remote-notification` and `aps-environment` in
   `Configuration/Hugo.entitlements` are for *remote push*, which this plan
   does **not** use. Do not add to or rely on them. Do not remove them either
   (out of scope, operator-sensitive).
2. **No notification code exists today** — `grep` for `UserNotifications`,
   `UNUserNotificationCenter`, `requestAuthorization` returns nothing. This is
   a green-field addition.
3. **Permission is opt-in and one-shot.** `UNUserNotificationCenter
   .requestAuthorization(options:)` shows the system prompt once; after denial
   the user must go to Settings. The feature must degrade gracefully to the
   existing in-app card when permission is denied or undetermined.
4. **Local notifications fire whether or not the app is running**, as long as
   the device isn't off. They are the correct tool here (vs. BGTask, which is
   for background *processing*, not user-facing alerts).
5. **Time-zone and theocratic-calendar sensitivity.** The due date is the last
   day of the month (`ReportReminderSchedule`). A naive trigger at midnight
   UTC will fire at the wrong local time for a user in `Europe/Copenhagen`.
   The trigger must use a `Calendar`/`DateComponents` in the user's calendar.

## Current state

- `Hugo/Features/Reports/Domain/ReportReminderSchedule.swift` — `dueMonth(now:calendar:)` and `hasUnreportedEntries(...)`. Pure, `nonisolated`, testable. **This is the scheduling brain; reuse it, don't duplicate it.**
- `Hugo/Features/Overview/OverviewView.swift:28-35` — `reminderMonth` computed property: `dueMonth` ∧ no real submission (sentinel `submittedAt == .distantPast` counts as unsubmitted).
- `Hugo/Features/Overview/ReportReminderCard.swift` — the in-app UI this notification complements.
- No `UserNotifications` import anywhere. No `UNUserNotificationCenterDelegate`. No permission prompt.
- `Configuration/Hugo.entitlements` has `aps-environment`; `Hugo/Info.plist` has `UIBackgroundModes=[remote-notification]`. Both are push-related and **irrelevant** to local notifications — leave untouched.

## Decision this plan must produce (Step 2 output)

The spike must answer, with evidence, before any full implementation:

| Question | Why it's a real fork |
|---|---|
| **Q1: Static vs. refreshed schedule?** | Option A: schedule the next N monthly reminders up-front (e.g. 3), cancel/reschedule on app open. Option B: schedule one, reschedule each time the app opens. A is more robust if the app is rarely opened; B stays accurate to submission state. Recommend **A with re-sync on foreground** — but confirm iOS allows enough pending requests (64/request limit is not a concern; the concern is *stale* notifications for a month that got submitted). |
| **Q2: When in the due window to fire?** | `dueMonth` spans last-day-of-month through a 7-day grace. Firing once on the last day may be too early; firing daily is nagging. Recommend: one notification on the last day of month M, one follow-up on day 3 of M+1 if still unsubmitted. Confirm against `hasUnreportedEntries`. |
| **Q3: How to suppress after submission?** | A scheduled notification can't see SwiftData. It must be *cancelled* when the report is submitted. Identify the exact submission-write call site (plan 017's `persistSubmission`) as the cancellation trigger. If cancellation can't be made reliable, the notification will nag about a submitted month — unacceptable. |
| **Q4: Time of day + calendar?** | Hard-code a sensible hour (e.g. 18:00 local) or make it a setting? Recommend: fixed 18:00 local via `DateComponents(hour: 18)`, calendar `.current`, no setting in v1. |

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Confirm no UN code | `grep -rn "UserNotifications\|UNUserNotificationCenter" Hugo HugoTests` | no matches (pre-spike) |
| Build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan027 CODE_SIGNING_ALLOWED=NO` | `BUILD SUCCEEDED` |
| Full gate | `Scripts/verify.sh` | exit 0 |
| Manual (device) | Schedule a reminder 1 minute out, background the app, wait | banner fires; tapping opens app |

> Note: local notifications do NOT reliably fire on the Simulator when the app
> is in the foreground, and permission prompts are per-install. **Step 3's
> acceptance requires a physical device run.**

## Scope

**In scope (this plan)**:
- A decision record (written to `plans/027-decision-record.md`) answering Q1–Q4.
- A minimal, **feature-flagged** proof-of-concept: request permission, schedule
  one reminder for the current due month, cancel it on submission. No settings
  UI, no full monthly series, no custom actions.

**Out of scope (do NOT touch / defer to a follow-up plan)**:
- Any App Intent or Widget work — explicitly deferred by the operator.
- A settings screen for notification time/day. (Record as a follow-up.)
- Remote push. The existing `remote-notification` background mode stays as-is.
- Productionizing the full monthly reschedule series, rich notification actions
  ("Mark submitted" inline), or notification-driven deep links to the report.
- `Hugo/Info.plist` background modes and `Configuration/Hugo.entitlements` —
  **untouched**; local notifications need neither.
- Localization of notification strings beyond adding the keys; Danish lands via
  plan 024's pattern.

## Git workflow

- Branch: `advisor/027-report-reminder-notification`
- One commit per step, message style: `` `027` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 1: Confirm the scheduling brain and the cancellation hook (read-only)

1. Re-read `ReportReminderSchedule.dueMonth` and `hasUnreportedEntries`. Write
   down, in the decision record, the exact dates that constitute "due" for a
   reference month (pick one, e.g. September 2026) in `Europe/Copenhagen`.
2. Find the exact call site where a submission is durably saved — plan 017's
   `persistSubmission` in `SubmitReportFormModel`. This is the **cancellation
   hook**. Confirm a submission write is observable there (it is, post-017,
   because that plan makes it `throws` and explicit). Record the function
   signature.
3. Confirm there is genuinely no existing `UNUserNotificationCenterDelegate`
   or app-level notification setup to integrate with.

**Output**: first section of `plans/027-decision-record.md`.

### Step 2: Answer Q1–Q4 with evidence (read-only)

For each of Q1–Q4, record the chosen answer and the reasoning, grounded in the
code read in Step 1. Specifically verify the **suppression** path (Q3): trace
that cancelling pending requests in the submission-save path actually prevents
the stale-month nag. If you cannot make Q3 reliable, **STOP** — a reminder that
fires for an already-submitted month is a regression, not a feature.

**Output**: completed `plans/027-decision-record.md`. This file is the real
deliverable of the plan; Step 3 is optional pending operator sign-off on it.

### Step 3: Minimal flagged proof-of-concept (only after operator reads Step 2)

Behind a `UserDefaultsKeys`-gated debug flag (follow the `UserDefaultsKeys`
constant pattern; do not hardcode the key string):

1. Add `import UserNotifications` in a new
   `Hugo/Features/Reports/ReportReminderScheduler.swift`.
2. A single `nonisolated enum ReportReminderScheduler` with:
   - `requestAuthorizationIfNeeded() async -> Bool`
   - `scheduleReminder(for month: YearMonth, calendar: Calendar) async` — builds
     `UNMutableNotificationContent` (title/body via localized keys), a
     `UNCalendarNotificationTrigger` from `DateComponents` at 18:00 local on
     the chosen fire date, `repeats: false`.
   - `cancelReminder(for month: YearMonth)` — removes the pending request by a
     stable identifier derived from the month.
3. Wire `requestAuthorizationIfNeeded` into app startup (guarded by the flag),
   and `cancelReminder` into the submission-save path found in Step 1.
4. All strings through `String(localized:)` / catalog keys (`notification.report-reminder.*`), English only; Danish via plan 024.

**Do not** schedule a multi-month series in this step. One due-month reminder
is enough to prove the mechanics on device.

**Verify on a physical device**: set the fire date ~1 minute out, background
the app, confirm the banner fires and tapping opens the app. Then submit the
report and confirm the pending request is cancelled (re-check via
`UNUserNotificationCenter.current().getPendingNotificationRequests` in a debug
dump, or by observing no fire).

## Test plan

- `HugoTests/Features/Reports/ReportReminderSchedulerTests.swift`:
  - The **fire-date computation** (the pure part) is unit-testable: given a
    month and calendar, assert the `DateComponents` (day = last day / grace
    day, hour = 18). Extract this into a pure function so it does not need a
    notification center.
  - Mirror the style of `ReportRoundingCalculatorTests` / the existing
    `ReportReminderSchedule` usage. `UNUserNotificationCenter` itself is **not**
    unit-tested — it needs a device; keep it behind a protocol seam if you want
    to assert `add`/`remove` calls with a mock.
- Do **not** attempt to unit-test actual banner delivery — that is the manual
  device check.

## Done criteria

For the **spike** (this plan) to be DONE:

- [ ] `plans/027-decision-record.md` exists and answers Q1–Q4 with evidence
- [ ] Q3 (suppress-after-submit) is proven reliable, or the plan is marked BLOCKED
- [ ] No `UIBackgroundModes`/entitlement changes in `git diff`
- [ ] POC behind a flag; flag off → zero behavioral change
- [ ] POC code compiles; `Scripts/verify.sh` exits 0
- [ ] Device check: banner fires; cancellation works
- [ ] `plans/README.md` row for 027 updated

Full production feature (multi-month series, settings, actions, deep link) is
explicitly a **follow-up plan** informed by the decision record.

## STOP conditions

Stop and report if:

- Suppression after submission cannot be made reliable (Q3). Do not ship a nag.
- Any change to `Info.plist` background modes or entitlements seems necessary —
  it is not, for local notifications; a belief that it is means a
  misunderstanding to resolve first.
- The `remote-notification` background mode appears to be load-bearing for this
  — it is not; do not touch it, and report if something seems to require it.
- Scheduling correctness depends on a calendar/timezone assumption that
  `ReportReminderSchedule` does not already encode.
- The POC would require more than the flagged minimal wiring — that is scope
  creep into the follow-up feature.

## Maintenance notes

- The deliverable is the **decision record**, not the POC. Future-you should be
  able to implement the full feature from `027-decision-record.md` without
  re-doing this research.
- Keep `ReportReminderSchedule` as the single source of "when is a month due" —
  the scheduler must call it, never reimplement the window math.
- The existing `remote-notification` background mode + `aps-environment` are
  for a future push feature and are intentionally left alone. Do not "clean
  them up" here; the operator has flagged build/config as sensitive.
- Notification copy should match the in-app `ReportReminderCard` tone. Reuse
  its wording concepts; keep strings keyed so plan 024 translates them.
- A follow-up full-feature plan should consider: multi-month reschedule,
  user-configurable time of day, an inline "Mark submitted" action, and a deep
  link that opens the report form directly.
- Reviewer should scrutinize: the Q3 suppression trace and that no config files
  were touched.
