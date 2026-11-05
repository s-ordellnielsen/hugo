# Plan 047: Stop failed saves from discarding other edits, reject empty category names, and persist exactly what was sent

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Hugo/Features/Reports/SubmitReportView.swift Hugo/Features/Reports/SubmitReportFormModel.swift Hugo/Features/Categories/CategoryDetailView.swift Hugo/Features/Entries/EntryDetailView.swift`
> Plans 039, 040, 043 and 045 edit these files. They are expected to have
> landed first. Match the excerpts below by content, not line number, and STOP
> if the code they describe is gone.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/045-flag-changes-after-submission.md (last plan to edit `SubmitReportView.swift` / `SubmitReportFormModel.swift` before this one)
- **Category**: bug
- **Planned at**: commit `3f8d48b`, 2026-10-12
- **Issue**: [SLN-251](https://linear.app/sebastianln/issue/SLN-251)

## Why this matters

Three small gaps can lose or corrupt data:

1. **A failed save throws away unrelated edits.** Entry and category edit screens write straight into the shared main `ModelContext` and rely on SwiftData's autosave. When an explicit save fails, three places call `context.rollback()`, which discards every unsaved change in the app, not just the failed operation.
2. **A category can be renamed to an empty name.** The add-category screen trims and rejects empty names, but the edit screen binds the name field directly. A separate category named `""` gets the same report-line ID as Field Service (`""`), so the two lines share one rounding rule and one carried-in key.
3. **The saved report can differ from the message that was sent.** While the Messages composer is open, any data change (for example an entry arriving through CloudKit) reloads the submit model. The reload clears the prepared message, which can blank the composer, and then the numbers saved after "Send" no longer match the text the overseer received. If the reload leaves a line undecided, `persistSubmission` returns `nil`, nothing is saved, and the sheet still closes as if it had succeeded.

## Current state

### Rollbacks

- `Hugo/Features/Reports/SubmitReportView.swift` (`persist()`):

  ```swift
  private func persist() {
      do {
          try model.persistSubmission(in: context)
          dismiss()
      } catch {
          context.rollback()
          saveErrorMessage = error.localizedDescription
      }
  }
  ```

- `Hugo/Features/Categories/CategoryDetailView.swift` (delete button; after plan 040 it calls `CategoryDeletionService`):

  ```swift
  Button("common.delete", role: .destructive) {
      do {
          try CategoryDeletionService(context: context).delete(tracker)
          dismiss()
      } catch {
          context.rollback()
          errorMessage = error.localizedDescription
      }
  }
  ```

- `Hugo/Features/Entries/EntryDetailView.swift` (delete confirmation):

  ```swift
  do {
      context.delete(entry)
      try context.save()
      dismiss()
  } catch {
      context.rollback()
      deletionError = error.localizedDescription
  }
  ```

### Category name

- `Hugo/Features/Categories/CategoryDetailView.swift`: `@Bindable var tracker = tracker` inside `body`, and `TextField("tracker.settings.name.placeholder", text: $tracker.name)` in `Section("tracker.settings.name.label")`.
- `Hugo/Features/Categories/AddCategoryView.swift:84-86` (the rule to match): `let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !trimmedName.isEmpty else { return }`.
- `Hugo/Features/Reports/Domain/ReportingLine.swift:3`: "the aggregate Field Service line (`id == ""`) or one separate category (`id == category name`)".

### Submit model

`Hugo/Features/Reports/SubmitReportFormModel.swift`:

```swift
/// The composed message ready to hand to Messages (or the pasteboard).
/// Set by `prepareSubmission()`; cleared when the rule changes.
private(set) var preparedContent: ReportMessageContent?

func load(entries: [Entry], submissions: [SubmittedReport]) {
    self.entries = entries
    ... recompute()
}

private func recompute() {
    preparedContent = nil
    results = ReportingLineCalculator.compute(lines, rules: rules)
}

@discardableResult
func persistSubmission(in context: ModelContext) throws -> SubmittedReport? {
    guard canSend else { return nil }
    ...
}
```

`SubmitReportView` calls `model.load` from `.onAppear` and from `.onChange` of `entries`, `submissions`, `overseerFullName` and `overseerPhoneNumber` (`syncModel()`). The composer sheet:

```swift
.sheet(isPresented: $isComposingMessage) {
    if let content = model.preparedContent {
        MessageComposeView(
            recipients: model.overseerPhoneNumber.isEmpty ? [] : [model.overseerPhoneNumber],
            body: content.body
        ) { sent in
            isComposingMessage = false
            if sent {
                persist()
            }
        }
    }
}
.alert("report.submit.copied", isPresented: $showingCopiedNotice) {
    Button("common.ok") {
        persist()
    }
}
```

### Conventions

- Persistence helpers live in `Hugo/Persistence`. Tests: Swift Testing with `InMemoryModelContainer.make()`.
- `SubmitReportFormModelTests.swift` helpers: `makeModel(now:userDefaults:)`, `entry(_:_:_:seconds:createdAt:tracker:source:)`, `mainLineID(in:)`.
- String catalog edits go through the helper script below, which keeps Xcode's exact JSON format (2-space indent, `" : "`, unescaped non-ASCII, empty objects as `{` + blank line + `}`, no trailing newline, number-aware key order).

```python
# /tmp/xcstrings_edit.py  (do not commit)
import json
import re

PATH = "Hugo/Resources/Localizable.xcstrings"


def load():
    with open(PATH, encoding="utf-8") as f:
        return json.loads(f.read())


def save(data):
    out = json.dumps(data, indent=2, separators=(",", " : "), ensure_ascii=False)
    out = re.sub(r"^( *)(.*)\{\}", lambda m: f"{m.group(1)}{m.group(2)}{{\n\n{m.group(1)}}}", out, flags=re.M)
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(out)


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def entry(comment, en, da):
    return {"comment": comment, "localizations": {"da": unit(da), "en": unit(en)}}


def natural(key):
    return [(0, int(t)) if t.isdigit() else (1, t.lower()) for t in re.split(r"(\d+)", key) if t != ""]


def insert_sorted(strings, key, value):
    items = list(strings.items())
    index = next((i for i, (k, _) in enumerate(items) if natural(k) > natural(key)), len(items))
    items.insert(index, (key, value))
    return dict(items)
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Focused tests | `xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoVerifyDerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:HugoTests/IsolatedChangeTests -only-testing:HugoTests/CategoryNameTests -only-testing:HugoTests/SubmitReportFormModelTests` | `** TEST SUCCEEDED **` |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope**:

- `Hugo/Persistence/ModelContext+IsolatedChange.swift` (create)
- `Hugo/Features/Categories/CategoryName.swift` (create)
- `Hugo/Features/Reports/SubmitReportView.swift`
- `Hugo/Features/Reports/SubmitReportFormModel.swift`
- `Hugo/Features/Categories/CategoryDetailView.swift`
- `Hugo/Features/Entries/EntryDetailView.swift`
- `Hugo/Resources/Localizable.xcstrings` (one key)
- `HugoTests/Persistence/IsolatedChangeTests.swift` (create)
- `HugoTests/Features/Categories/CategoryNameTests.swift` (create)
- `HugoTests/Features/Reports/SubmitReportFormModelTests.swift`
- `plans/README.md` (status row)

**Out of scope**:

- `AddEntryView` and `AddCategoryView`. On failure they delete only the object they inserted, which is already correct.
- Changing report-line IDs (for example prefixing separate IDs). Preventing empty names is enough and keeps stored data unchanged.
- Explicit saves for live edits on the edit screens. They keep relying on autosave.

## Git workflow

- Branch: `advisor/047-safe-saves`
- Commit message style: short imperative sentence, for example `Keep unrelated edits when a save fails`.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add an isolated-change helper and use it at the three rollback sites

1. Create `Hugo/Persistence/ModelContext+IsolatedChange.swift`:

   ```swift
   import SwiftData

   extension ModelContext {
       /// Saves any pending edits first, then applies `changes` and saves again.
       /// If applying or saving `changes` fails, only `changes` are rolled back,
       /// because everything else was already saved.
       func performIsolatedChange(_ changes: () throws -> Void) throws {
           if hasChanges { try save() }
           do {
               try changes()
               if hasChanges { try save() }
           } catch {
               rollback()
               throw error
           }
       }
   }
   ```

2. `SubmitReportView.persist()`: replace the body with the version in Step 4 (it also handles `nil`).
3. `CategoryDetailView` delete button: `try context.performIsolatedChange { try CategoryDeletionService(context: context).delete(tracker) }`, then `dismiss()`. Remove `context.rollback()` from the `catch`; keep setting `errorMessage`.
4. `EntryDetailView` delete: `try context.performIsolatedChange { context.delete(entry) }`, then `dismiss()`. Remove `context.rollback()` and the separate `try context.save()`.
5. Create `HugoTests/Persistence/IsolatedChangeTests.swift`:
   - `failedChangeKeepsEarlierPendingEdits`: insert and save `Tracker(name: "A")`; set `tracker.name = "B"` without saving; call `performIsolatedChange { context.insert(Tracker(name: "C")); throw TestError() }` and expect it to throw. Afterwards `tracker.name == "B"`, `context.hasChanges == false`, and fetching trackers returns only "B".
   - `successfulChangeIsSaved`: `performIsolatedChange { context.insert(Tracker(name: "C")) }`; afterwards `context.hasChanges == false` and the fetch contains "C".

**Verify**: `grep -rn 'context.rollback()' Hugo` → matches only inside `ModelContext+IsolatedChange.swift` (the helper calls `rollback()` on itself, so expect zero `context.rollback()` matches). Focused tests pass.

Commit: `Keep unrelated edits when a save fails`.

### Step 2: Never commit an empty category name

1. Create `Hugo/Features/Categories/CategoryName.swift`:

   ```swift
   import Foundation

   nonisolated enum CategoryName {
       /// The name to keep after editing: the trimmed edit, or the original
       /// name when the edit is empty.
       static func committed(edited: String, original: String) -> String {
           let trimmed = edited.trimmingCharacters(in: .whitespacesAndNewlines)
           return trimmed.isEmpty ? original : trimmed
       }
   }
   ```

2. In `CategoryDetailView`, add `@State private var originalName: String?`. On the `Form` add:

   ```swift
   .onAppear {
       if originalName == nil { originalName = tracker.name }
   }
   .onDisappear {
       tracker.name = CategoryName.committed(edited: tracker.name, original: originalName ?? tracker.name)
   }
   ```

   Also add `.onSubmit { tracker.name = CategoryName.committed(edited: tracker.name, original: originalName ?? tracker.name) }` to the `TextField`.
3. Create `HugoTests/Features/Categories/CategoryNameTests.swift` with: empty edit returns original; whitespace-only edit returns original; `"  Bethel "` returns `"Bethel"`; a normal edit returns the edit.

**Verify**: focused tests pass.

Commit: `Keep a category's name when the edit is empty`.

### Step 3: Freeze the submit model while a message is prepared

In `SubmitReportFormModel`:

1. Add `private var pendingLoad: (entries: [Entry], submissions: [SubmittedReport])?`.
2. At the top of `load(entries:submissions:)`:

   ```swift
   // A prepared message is what the user is about to send. Keep the numbers
   // it was built from until the user sends or cancels it.
   guard preparedContent == nil else {
       pendingLoad = (entries, submissions)
       return
   }
   ```

3. Add:

   ```swift
   /// Discards the prepared message and applies data that arrived meanwhile.
   func cancelPreparedSubmission() {
       preparedContent = nil
       if let pending = pendingLoad {
           pendingLoad = nil
           load(entries: pending.entries, submissions: pending.submissions)
       }
   }
   ```

4. At the end of a successful `persistSubmission` (after `try context.save()`), set `preparedContent = nil` and `pendingLoad = nil`.
5. Tests in `SubmitReportFormModelTests.swift`:
   - `loadWhilePreparedKeepsTheSentNumbers`: load one 5 400 s June entry, set `.transfer` on the main line, call `prepareSubmission()`. Load again with an extra 1 800 s June entry. Expect `preparedContent != nil` and the main result's `line.actualSeconds == 5_400`. Persist into an in-memory context: the stored main line's `durationInSeconds == 5_400`.
   - `cancelAppliesDataThatArrivedMeanwhile`: same setup, then `cancelPreparedSubmission()`. Expect `preparedContent == nil` and the main line's `actualSeconds == 7_200`.

**Verify**: focused tests pass.

### Step 4: Treat a missing save as an error, and cancel properly

1. Add the error string with the helper:

   ```python
   import sys
   sys.path.insert(0, "/tmp")
   import xcstrings_edit as x

   data = x.load()
   data["strings"] = x.insert_sorted(data["strings"], "report.submit.not-saved", x.entry(
       "Error shown when a submitted report could not be stored.",
       "The report could not be saved. Check each line and try again.",
       "Rapporten kunne ikke gemmes. Tjek hver linje, og prøv igen.",
   ))
   x.save(data)
   ```

2. Replace `SubmitReportView.persist()`:

   ```swift
   private func persist() {
       do {
           var stored: SubmittedReport?
           try context.performIsolatedChange {
               stored = try model.persistSubmission(in: context)
           }
           guard stored != nil else {
               saveErrorMessage = String(localized: "report.submit.not-saved")
               return
           }
           dismiss()
       } catch {
           saveErrorMessage = error.localizedDescription
       }
   }
   ```

3. In the composer callback, cancel when the message was not sent:

   ```swift
   ) { sent in
       isComposingMessage = false
       if sent {
           persist()
       } else {
           model.cancelPreparedSubmission()
       }
   }
   ```

**Verify**: `Scripts/verify.sh` → exit 0.

Commit steps 3-4: `Save exactly the report that was sent`.

### Step 5 [owner]: Spot checks

1. Rename a category to spaces only and go back: the old name is kept.
2. Open the submit sheet, tap Send, cancel the composer: the screen still works and reflects any entry added meanwhile on another device.

## Test plan

- `IsolatedChangeTests`: 2 tests (Step 1).
- `CategoryNameTests`: 4 tests (Step 2).
- `SubmitReportFormModelTests`: 2 new tests (Step 3).

## Done criteria

- [ ] `grep -rn 'context.rollback()' Hugo` prints nothing
- [ ] `grep -n 'cancelPreparedSubmission' Hugo/Features/Reports/SubmitReportView.swift` shows one call
- [ ] `Scripts/verify.sh` exits 0, with 8 more tests than before this plan
- [ ] `git status --porcelain` lists only files from the Scope list
- [ ] `plans/README.md` row for 047 updated

## STOP conditions

Stop and report back if:

- `CategoryDeletionService` does not exist (plan 040 has not landed).
- `performIsolatedChange`'s first `save()` fails in tests because the in-memory store rejects pending changes. Report the error.
- There are other `rollback()` calls in `Hugo/` besides the three listed.
- Freezing `load` makes an existing `SubmitReportFormModelTests` test fail. Report which one.

## Maintenance notes

- New delete or multi-object save paths should use `performIsolatedChange` instead of saving and rolling back the shared context directly.
- `CategoryName.committed` is the single rule for category names. `AddCategoryView` keeps its own equivalent trim; unify the two if either changes.
- If the submit screen gains more inputs, make sure they also cannot change while `preparedContent` is set.
