# Plan 115: Remove the last dead code from SLN-201

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" happens, stop and report. Do not improvise.
> When done, update this plan's row in `plans/README.md`, unless a reviewer
> dispatched you and said they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 7e3c4e9..HEAD -- Hugo/App/AppRootView.swift Hugo/Persistence/SchemaVersions/V8/ReportV8.swift`
> Expected: no output. Otherwise compare the excerpts below with the live
> files. A mismatch is a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW. One unused enum case and one comment. No behavior change, no schema change.
- **Depends on**: 114 (the gate)
- **Category**: tech-debt
- **Planned at**: commit `7e3c4e9`, 2026-11-14
- **Issue**: [SLN-201](https://linear.app/sebastianln/issue/SLN-201)

## Why this matters

SLN-201 listed three bits of dead code from an October audit. Two of them are in use now: `showingHelp` in `ReportSettingsView` opens the Rounding help sheet, and `TabPlacement.sidebarOnly` hides the Settings tab on iPhone. What is left:

1. `TabPlacement.compactOnly` is never produced. Nothing returns it, so the case and its `switch` branch only make the code look as if some tab is iPhone-only.
2. `SchemaV8.Report` is an empty `@Model` class whose file header says `ReportV1.swift`. The class **must stay**. It is listed in the `models` of every schema from V1 to V13, including the current one, and removing it would change the stored schema and need a new schema version and a CloudKit change. `Hugo/Persistence/AppSchema.swift:146-147` records that decision. Only the misleading header and a missing explanation get fixed.

## Current state

`Hugo/App/AppRootView.swift:146-168`:

```swift
    var placement: TabPlacement {
        switch self {
        case .overview: .all
        case .year: .all
        case .planner: .all
        case .settings: .sidebarOnly
        }
    }
}

enum TabPlacement {
    case compactOnly
    case sidebarOnly
    case all

    func isVisible(compact: Bool) -> Bool {
        switch self {
        case .compactOnly: compact
        case .sidebarOnly: !compact
        case .all: true
        }
    }
}
```

`grep -rn "compactOnly" Hugo HugoTests` finds only lines 157 and 163 above.

`Hugo/Persistence/SchemaVersions/V8/ReportV8.swift` (whole file):

```swift
//
//  ReportV1.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

extension SchemaV8 {
    @Model
    final class Report {
        init() {}
    }
}
```

`Hugo/Persistence/AppSchema.swift:146-147`:

```swift
// SchemaV8/V9.Report remains as migration compatibility ballast until a tested
// future schema version can remove it safely.
```

`AGENTS.md` says: "Never edit a shipped schema version." A comment-only change in `ReportV8.swift` doesn't change the model, but nothing between `extension SchemaV8 {` and the closing braces may change.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `xcrun swift-format lint --strict Hugo/App/AppRootView.swift Hugo/Persistence/SchemaVersions/V8/ReportV8.swift` | exit 0, no output |
| Full gate | `Scripts/verify.sh` | exit 0 (several minutes; run with a 600000 ms timeout or in the background) |

## Scope

**In scope**:
- `Hugo/App/AppRootView.swift` (only the `TabPlacement` enum)
- `Hugo/Persistence/SchemaVersions/V8/ReportV8.swift` (only the comment lines above `import Foundation`)

**Out of scope**:
- `Hugo/Persistence/AppSchema.swift` and every other schema file. Do not remove `Report` from any `models` list.
- `ReportSettingsView.showingHelp` and `TabPlacement.sidebarOnly`. Both are in use.
- `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme` has an uncommitted change by the owner. Never stage, commit, revert or stash it.

## Git workflow

- Work on `main` directly. Do NOT create a branch or a worktree. Do NOT push.
- Never stage `plans/`, `.claude/` or `Hugo.xcodeproj/xcshareddata/xcschemes/Debug.xcscheme`. Never run `git add -A`, `git add .`, `git stash`, `git checkout -- .`, `git reset --hard` or `git clean`. Stage files by explicit path.
- One commit: `refactor: remove the unused compactOnly tab placement`

## Steps

### Step 1: Remove `TabPlacement.compactOnly`

In `Hugo/App/AppRootView.swift`, the enum becomes:

```swift
enum TabPlacement {
    case sidebarOnly
    case all

    func isVisible(compact: Bool) -> Bool {
        switch self {
        case .sidebarOnly: !compact
        case .all: true
        }
    }
}
```

**Verify**: `grep -rn "compactOnly" Hugo HugoTests` → no output.

### Step 2: Fix the `ReportV8.swift` header

Replace the comment block above `import Foundation` with:

```swift
//
//  ReportV8.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//
//  An empty model with no attributes. It is in the `models` of every schema
//  version up to the current one, so removing it changes the stored schema.
//  It stays until a new, tested schema version drops it (see the note in
//  `AppSchema.swift`).
//
```

Leave the rest of the file byte for byte as it is.

**Verify**: `git diff Hugo/Persistence/SchemaVersions/V8/ReportV8.swift | grep -E '^[-+]' | grep -v -E '^(\+\+\+|---)' | grep -v -E '^[-+]//'` → no output (only comment lines changed).

### Step 3: Run the gate and commit

**Verify**: `xcrun swift-format lint --strict Hugo/App/AppRootView.swift Hugo/Persistence/SchemaVersions/V8/ReportV8.swift` → exit 0. `Scripts/verify.sh` → exit 0.

Commit both files by path.

## Test plan

No new tests: nothing behaves differently. The existing tests and the analyzer in `Scripts/verify.sh` cover that it still builds.

## Done criteria

- [ ] `grep -rn "compactOnly" Hugo HugoTests` prints nothing
- [ ] `head -2 Hugo/Persistence/SchemaVersions/V8/ReportV8.swift | tail -1` prints `//  ReportV8.swift`
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git show --stat HEAD` lists exactly the two in-scope files

## STOP conditions

- The drift check shows changes and the excerpts don't match.
- `compactOnly` is used anywhere other than the two lines shown.
- `Scripts/verify.sh` fails twice. Report the failing test names.

## Maintenance notes

- If an iPhone-only tab is ever needed, add the case back then.
- Removing `SchemaV8.Report` for real needs a new `VersionedSchema` without it, a migration stage, a `SchemaMigrationTests` case, and a check that CloudKit Production tolerates the unused `CD_Report` record type. That is out of scope for SLN-201.
