# Plan 028: Export / backup (design + spike)

> **Executor instructions**: This is a **direction/spike** plan. Steps 1–2 are
> read-only and produce a decision record (`plans/028-decision-record.md`).
> Only Step 3 writes code — a minimal, feature-flagged export proof-of-concept.
> Run every verification command. If anything in "STOP conditions" occurs, stop
> and report — do not improvise. When done, update the status row for plan 028
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Persistence/AppSchema.swift Hugo/Persistence/ModelContainerFactory.swift Hugo/Persistence/SchemaVersions/V10 Hugo/Persistence/SchemaVersions/V8`
> If any changed, re-derive "Current state" from live code; a schema change is a
> STOP condition (the export format depends on it).

## Status

- **Priority**: P3
- **Effort**: M (spike + decision) → L (full feature, deferred)
- **Risk**: MED (data fidelity + privacy)
- **Depends on**: none blocking; recommended after plans/023 (API hygiene) and 024 (localization) so exported strings/keys follow settled patterns
- **Category**: direction / new-feature spike
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

The app's entire value is the user's reporting history. That history lives in a
SwiftData store backed by **CloudKit** (`ModelContainerFactory.swift:11` uses a
default — i.e. CloudKit-synced — configuration). CloudKit sync is *not* a
backup: it propagates deletions, it is opaque to the user, and this repository
has already survived a 10-version migration chain with at least one abandoned
migration (plan 014) and a schema kept purely as "compatibility ballast"
(`AppSchema.swift:108-109`). A user-owned, portable export is the safety net
that sync cannot be. The operator explicitly approved this direction.

## Hard constraints established by research (do NOT re-derive)

1. **No export/backup/share code exists.** `grep` for `ShareLink`,
   `fileExporter`, `JSONEncoder` (outside one rounding-rule test), `CSV`,
   `UTType` finds nothing in app code. Green-field.
2. **The live user-facing data is three models** (current = `SchemaV10`,
   `AppSchema.swift:111-113`):
   - `Entry` — `date`, `duration`, `bibleStudies`, `createdAt`, `tracker` (rel)
   - `Tracker` — the persistence name for what the UI calls a *Category*
     (AGENTS.md: keep the name `Tracker` in persistence)
   - `SubmittedReport` — the monthly submission record (V10)
   - **`Report` (V8) is legacy migration ballast**, explicitly "kept until a
     tested future schema can remove it safely." It is **not** part of the
     export's user-facing payload — decide in Step 2 whether to include it for
     fidelity or exclude it as dead weight; recommend **exclude**.
3. **No secrets are stored**, but an export is still personal data (service
   activity). Treat the file as private: local share only, no analytics, no
   third-party upload.
4. **Calendar/timezone fidelity is load-bearing.** `Entry.date`, `createdAt`,
   and the theocratic-year/month logic (`YearMonth`, `TheocraticYear`) all run
   through `Calendar.current`. An export that serializes dates as naive
   timestamps loses the user's wall-clock intent. Dates must round-trip with
   explicit, unambiguous representation (ISO-8601 with offset), and the export
   must record the producing calendar/timezone.
5. **Format must be versioned independently of the SwiftData schema.** The
   schema has already churned 10 versions; the export format must survive
   future schema changes. A top-level `formatVersion` is mandatory.

## Current state

- `Hugo/Persistence/AppSchema.swift` — `CurrentSchema = SchemaV10`; public
  typealiases `Entry`, `Tracker`, `SubmittedReport`. `SchemaV8/V9.Report` is
  documented ballast.
- `Hugo/Persistence/ModelContainerFactory.swift` — CloudKit-backed default
  config (line 11) and an in-memory/no-cloud config (line 17) used by tests.
- No existing serialization of `Entry`/`Tracker`/`SubmittedReport` to any
  portable format. The models are `@Model` classes (reference types, SwiftData
  relationships), **not** `Codable` — export needs dedicated DTOs, not
  `JSONEncoder` on the models directly.

## Decision this plan must produce (Step 2 output)

The spike must answer, with evidence, before full implementation:

| Question | Why it's a real fork |
|---|---|
| **Q1: Format — JSON, CSV, or both?** | JSON preserves structure/relationships and is restorable; CSV is human-openable in Numbers/Excel but flattens relationships (an Entry's category by id vs. name). Recommend **JSON as the canonical, restorable format; CSV as an optional human-readable companion**. Confirm whether the operator wants restore capability at all — that decides whether JSON is required. |
| **Q2: Restore now or export-only?** | Export-only is far simpler (no merge/conflict semantics). Restore implies identity resolution (duplicate categories? re-imported entries?) and CloudKit re-sync behavior. Recommend **export-only in v1; design the format so restore can be added without breaking it**. |
| **Q3: How are categories/entries linked in the export?** | By stable name, or by a generated stable id? `Tracker` has no user-facing UUID guarantee stated here — Step 1 must check whether `Tracker` has a stable identity suitable for export, or whether the export should key entries to category *name* (risky if renamed) vs. a synthesized UUID (needs to be persisted to be stable across exports). |
| **Q4: What is the restore/fidelity boundary for `Report` ballast and internal fields?** | Exclude `Report` (recommend). Include `createdAt`? `entriesClosedAt`/sentinel semantics on `SubmittedReport`? Record exactly which fields are in/out and why. |
| **Q5: Delivery mechanism?** | `ShareLink`/`fileExporter` to Files/AirDrop (recommended — user controls destination, no server), vs. email. Confirm no entitlement is needed (none is, for local share). |

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Confirm no export code | `grep -rn "ShareLink\|fileExporter\|JSONEncoder" Hugo` | no app-code matches (pre-spike) |
| Inspect Tracker identity | `sed -n '1,40p' Hugo/Persistence/SchemaVersions/V8/TrackerV8.swift` | see whether a stable id/name exists |
| Build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan028 CODE_SIGNING_ALLOWED=NO` | `BUILD SUCCEEDED` |
| Full gate | `Scripts/verify.sh` | exit 0 |
| Manual | Export → open file in Files / a text editor | valid JSON; dates ISO-8601 with offset |

## Scope

**In scope (this plan)**:
- A decision record (`plans/028-decision-record.md`) answering Q1–Q5.
- A minimal, **feature-flagged** export POC: serialize current `Entry` +
  `Tracker` + `SubmittedReport` to versioned JSON via dedicated `Codable` DTOs,
  and surface it through `ShareLink`/`fileExporter`. No CSV, no restore.

**Out of scope (do NOT touch / defer to a follow-up plan)**:
- **Restore/import** entirely (Q2 — export-only v1).
- CSV export (Q1 companion) — only if the operator asks after the decision.
- Any change to the SwiftData models, schema, or migration chain. Export reads
  models; it must not alter them. Adding a persisted stable-id to `Tracker`
  would be a **schema change** — if Q3 concludes one is needed, that is a
  STOP, not a step.
- CloudKit configuration, entitlements, `Info.plist` — untouched.
- Encryption/password-protection of the export (record as follow-up).
- Localization of any export UI beyond keyed strings; Danish via plan 024.

## Git workflow

- Branch: `advisor/028-export-backup`
- One commit per step, message style: `` `028` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 1: Map the exportable domain (read-only)

1. Read `EntryV8` (the current `Entry` via typealias), `TrackerV8`, and
   `SubmittedReportV10`. List every stored property and relationship.
2. Answer **Q3 concretely**: does `Tracker` have a stable, export-safe identity
   (a persisted UUID or unique name)? Record the finding. If identity is only
   the SwiftData object id (not stable across stores), note that entries cannot
   be linked to categories by id in the export and decide the name-vs-
   synthesized-uuid tradeoff.
3. Record the exact date/calendar fields and how `YearMonth`/`TheocraticYear`
   derive from them, so the export's date representation preserves intent.
4. Confirm `Report` is unused by current UI (per `AppSchema.swift:108`) and
   record the decision to exclude it (Q4).

**Output**: first section of `plans/028-decision-record.md`, including a
field-by-field in/out table for the three models.

### Step 2: Answer Q1–Q5 with evidence (read-only)

For each question record the chosen answer and reasoning, grounded in Step 1.
Pay special attention to **Q3** (identity) and **Q4** (field boundary) — these
define the format's stability. If Q3 concludes a persisted stable id is
required on `Tracker`, **STOP** (that is a schema change this plan forbids) and
report the tradeoff to the operator instead of proceeding.

**Output**: completed `plans/028-decision-record.md` — the real deliverable.

### Step 3: Minimal flagged export POC (only after operator reads Step 2)

Behind a `UserDefaultsKeys`-gated debug flag:

1. New file `Hugo/Features/Settings/Export/` (or the feature folder the
   operator prefers) with `Codable` DTOs:
   - `ExportDocument: Codable` — `formatVersion: Int`, `generatedAt: Date`,
     `calendarIdentifier: String`, `timeZoneIdentifier: String`, plus
     `trackers: [TrackerDTO]`, `entries: [EntryDTO]`, `submittedReports: [SubmittedReportDTO]`.
   - DTOs carry only the fields marked "in" in Step 1's table. Dates encoded
     ISO-8601 with offset (`JSONEncoder.DateEncodingStrategy.iso8601` at
     minimum; consider fractional seconds off for readability).
2. A pure, testable mapping layer: `Entry -> EntryDTO`, etc., taking an
   explicit `Calendar`/`TimeZone` so tests are deterministic.
3. A `ShareLink(item:)` or `.fileExporter` presenting the generated `Data` as a
   `.json` file (define a `UTType`-conforming file representation, or use
   `.json`). No restore path.

**Do not** add CSV, restore, or a settings screen in this step.

**Verify**: export on device/simulator → open the file → valid JSON, correct
`formatVersion`, ISO-8601 dates with offset, entries linked to categories per
the Q3 decision, `Report` ballast absent.

## Test plan

- `HugoTests/Features/Settings/Export/ExportMappingTests.swift` (or matching
  folder), mirroring the existing `import Testing` / `@Test` / `#expect` style:
  - `entryMapsToDTOWithAllExportedFields`
  - `datesRoundTripThroughISO8601` — encode then decode, assert equality of the
    instant and that the producing calendar/timezone identifiers are recorded.
  - `exportDocumentCarriesFormatVersion`
  - `entriesLinkToCategoriesPerDecision` — assert the Q3 linkage (name or id).
  - `legacyReportBallastIsExcluded` — assert no `Report` payload is produced.
- All mapping is pure and injects `Calendar`/`TimeZone` → no device needed.
  File *delivery* (`ShareLink`) is the manual check, not unit-tested.

## Done criteria

For the **spike** (this plan) to be DONE:

- [ ] `plans/028-decision-record.md` exists, answers Q1–Q5, includes the field in/out table
- [ ] Q3 identity decision recorded; if it needs a schema change, plan is BLOCKED and reported
- [ ] No model/schema/migration/config diffs in `git diff`
- [ ] POC behind a flag; flag off → zero behavioral change
- [ ] Exported file is valid versioned JSON with ISO-8601 dates + recorded calendar/timezone
- [ ] `Report` ballast excluded; only `Entry`/`Tracker`/`SubmittedReport` exported
- [ ] `Scripts/verify.sh` exits 0
- [ ] `plans/README.md` row for 028 updated

Full feature (restore, CSV, scheduling, encryption) is explicitly a
**follow-up plan** informed by the decision record.

## STOP conditions

Stop and report if:

- Q3 concludes `Tracker` needs a persisted stable id → that is a schema change;
  report the tradeoff, do not implement it here.
- Any change to a model, schema file, migration, entitlements, or `Info.plist`
  seems necessary → out of scope; report.
- Restore/merge semantics creep into scope → that is the follow-up feature.
- Date serialization would lose wall-clock intent (naive timestamps) → fix the
  encoding; do not ship lossy dates.
- The export would include `Report` ballast or any field not in the agreed
  in/out table.

## Maintenance notes

- The deliverable is the **decision record**, not the POC. Future-you should
  implement restore/CSV from `028-decision-record.md` without re-doing research.
- Keep the export format's `formatVersion` independent of the SwiftData schema
  version. Bump `formatVersion` only on a breaking format change; never couple
  it to `Schema.Version`.
- Restore, when built, must reconcile against CloudKit re-sync — record that as
  the hardest known unknown for the follow-up plan.
- The export is personal data: keep it local, user-shared, and out of any
  analytics. Do not add telemetry to the export path.
- `Tracker` = UI "Category" naming must be preserved in the export's field
  naming decision (use the persistence name internally, present "category" only
  if the format is user-facing).
- Reviewer should scrutinize: the Q3 identity decision and the date-encoding
  fidelity — those two determine whether the export is actually restorable
  later.
