# Plan 019: Turn the symbol catalog into a static, pre-indexed data set

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for plan 019
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat d65afec..HEAD -- Hugo/Features/SymbolPicker HugoTests/Features/SymbolDefinitionTests.swift`
> If any in-scope file changed, compare the "Current state" excerpts against
> the live code; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/016-green-verification-gate.md
- **Category**: perf
- **Planned at**: commit `d65afec`, 2026-08-06

## Why this matters

Typing one character into the symbol picker's search field currently costs: 52
`SymbolDefinition` allocations (the catalog is a *computed* property), plus up
to 104 `String(localized:)` bundle lookups, plus 52 `split`/`trim`/`lowercased`
passes. That happens on every body evaluation, not just every keystroke. The
picker is the slowest-feeling screen in the app and the fix is entirely
mechanical.

## Current state

`Hugo/Features/SymbolPicker/Enums/SymbolSet.swift:11-14` — the catalog is
rebuilt on every access:

```swift
enum SymbolSet: String, CaseIterable {
    case tracker

    var symbols: [SymbolDefinition] {
        switch self {
        case .tracker:
            [
                SymbolDefinition(
                    icon: "figure.walk",
                    name: "symbol.walk",
                    keywordsKey: "symbol.walk.keywords",
                    attributes: []
                ),
                … 51 more …
            ]
        }
    }
}
```

`Hugo/Features/SymbolPicker/SymbolPicker.swift:20-25` reads it every body pass:

```swift
var filteredSymbols: [SymbolDefinition] {
    if searchText.isEmpty && attributes == nil {
        return set.symbols
    }
    return set.symbols.filter { $0.matches(searchText, attributes) }
}
```

`Hugo/Features/SymbolPicker/Structs/SymbolDefinition.swift:10-47` resolves
localized strings inside the filter, and force-unwraps:

```swift
nonisolated func matches(_ searchText: String, _ attr: SymbolAttribute?) -> Bool {
    var satisfiesAttributes: Bool = true

    if attr != nil && !attributes.contains(attr!) {
        satisfiesAttributes = false
    }
    …
    let query = searchText.lowercased()

    if localizedName.lowercased().contains(query) {
        return true
    }

    return keywords.contains { $0.lowercased().contains(query) }
}
```

where `localizedName` and `keywords` each call `String(localized:)` per access.

`plans/README.md` previously **rejected** splitting this file merely because it
is 275 lines. That rejection stands — this plan changes the *access pattern*,
not the file layout. The catalog stays one coherent list in one file.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0 |
| Tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hugo.xcodeproj -scheme Hugo -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/HugoPlan019 CODE_SIGNING_ALLOWED=NO` | `TEST SUCCEEDED` |
| Full gate | `Scripts/verify.sh` | exit 0 |
| Catalog size | `grep -c "SymbolDefinition(" Hugo/Features/SymbolPicker/Enums/SymbolSet.swift` | `52` (unchanged) |

## Scope

**In scope**:
- `Hugo/Features/SymbolPicker/Enums/SymbolSet.swift`
- `Hugo/Features/SymbolPicker/Structs/SymbolDefinition.swift`
- `Hugo/Features/SymbolPicker/SymbolPicker.swift`
- `HugoTests/Features/SymbolDefinitionTests.swift`

**Out of scope** (do NOT touch):
- The contents of the catalog — do not add, remove, or reorder symbols. This
  plan must be provably behavior-preserving.
- Accessibility labels on the grid buttons — plan 020 owns those, and touching
  the same lines here will conflict.
- `Hugo/Resources/Localizable.xcstrings` — every `symbol.*` key stays as is.
- Splitting `SymbolSet.swift` into multiple files.

## Git workflow

- Branch: `advisor/019-symbol-catalog-performance`
- One commit per step, message style: `` `019` Step N — <summary> ``
- Do NOT push or open a PR.

## Steps

### Step 1: Give `SymbolDefinition` a precomputed search index

Add a lazily-built, cached lowercase index so localization is resolved once per
symbol per process, not once per keystroke:

```swift
nonisolated struct SymbolDefinition: Identifiable, Sendable {
    let icon: String
    let name: LocalizedStringResource
    let keywordsKey: LocalizedStringResource
    let attributes: [SymbolAttribute]

    var id: String { icon }

    /// Lowercased name + keywords, resolved once at catalog construction.
    /// Search compares against this instead of hitting the string catalog
    /// on every keystroke.
    let searchIndex: [String]

    init(
        icon: String,
        name: LocalizedStringResource,
        keywordsKey: LocalizedStringResource,
        attributes: [SymbolAttribute]
    ) {
        self.icon = icon
        self.name = name
        self.keywordsKey = keywordsKey
        self.attributes = attributes

        let localizedName = String(localized: name).lowercased()
        let keywords = String(localized: keywordsKey)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        self.searchIndex = [localizedName] + keywords
    }

    func matches(_ searchText: String, _ attribute: SymbolAttribute?) -> Bool {
        if let attribute, !attributes.contains(attribute) { return false }
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        return searchIndex.contains { $0.contains(query) }
    }
}
```

Note three deliberate changes: the force-unwrap `attr!` becomes `if let`, the
`Codable` conformance is dropped (nothing decodes this type — verify with
`grep -rn "SymbolDefinition" Hugo HugoTests` before removing; if anything does,
keep it and write the initializer accordingly), and `Sendable` is added since
the type is now stored in a `static let`.

**Verify**: `grep -n "attr!" Hugo/Features/SymbolPicker` → no matches.
The 5 existing tests in `HugoTests/Features/SymbolDefinitionTests.swift` pass.

### Step 2: Make the catalog a `static let`

Change `SymbolSet.symbols` from a computed property to a stored static lookup:

```swift
enum SymbolSet: String, CaseIterable, Sendable {
    case tracker

    var symbols: [SymbolDefinition] {
        switch self {
        case .tracker: Self.trackerSymbols
        }
    }

    private static let trackerSymbols: [SymbolDefinition] = [
        … the existing 52 entries, moved verbatim …
    ]
}
```

Move the array **verbatim**. Do not reformat entries, do not reorder, do not
"tidy" the mixed one-line/multi-line style — plan 016 already normalized it and
a reorder would silently change the grid.

**Verify**: `grep -c "SymbolDefinition(" Hugo/Features/SymbolPicker/Enums/SymbolSet.swift`
→ `52`. `git diff --word-diff` on that file shows only the wrapper change.

### Step 3: Cache the filtered result in the view

`SymbolPicker.filteredSymbols` still recomputes per body pass. Hold the result
in state and refresh it only when an input changes:

```swift
@State private var filteredSymbols: [SymbolDefinition] = []

private func refreshFilter() {
    if searchText.isEmpty && attributes == nil {
        filteredSymbols = set.symbols
    } else {
        filteredSymbols = set.symbols.filter { $0.matches(searchText, attributes) }
    }
}
```

driven by `.onAppear { refreshFilter() }`, `.onChange(of: searchText) { refreshFilter() }`,
`.onChange(of: attributes) { refreshFilter() }`.

Do **not** add a debounce. With the index in place the filter is a handful of
substring checks over 52 short strings; a debounce would add perceived latency
for no benefit.

**Verify**: `Scripts/verify.sh` → exit 0. Manual: open Add Category → tap the
icon → type "hus"/"house" — results filter without stutter; clearing the field
restores all 52; the attribute filter menu still narrows correctly and the
badge still appears.

## Test plan

Extend `HugoTests/Features/SymbolDefinitionTests.swift` (5 existing tests;
model after them):

- `searchIndexContainsLowercasedName` — a definition's `searchIndex` first
  element equals its localized name lowercased.
- `matchesIsCaseInsensitive` — `matches("HOUSE", nil)` and `matches("house", nil)`
  agree.
- `matchesWithAttributeFiltersOut` — a symbol without `.fill` returns `false`
  for `matches("", .fill)`.
- `emptyQueryWithNoAttributeMatchesEverything` — `matches("", nil) == true`.
- `catalogIdentityIsStable` — `SymbolSet.tracker.symbols.map(\.id)` equals
  itself across two accesses **and** has 52 unique entries. This is the
  behavior-preservation proof for Step 2.

Verification: test command → `TEST SUCCEEDED`, 5 more tests than before.

## Done criteria

ALL must hold:

- [ ] `grep -n "var symbols: \[SymbolDefinition\] {" Hugo/Features/SymbolPicker/Enums/SymbolSet.swift` → the body is a `switch` returning a static, not an array literal
- [ ] `grep -c "SymbolDefinition(" Hugo/Features/SymbolPicker/Enums/SymbolSet.swift` → `52`
- [ ] `grep -rn "attr!" Hugo` → no matches
- [ ] `grep -n "String(localized:" Hugo/Features/SymbolPicker/Structs/SymbolDefinition.swift` → only inside `init`
- [ ] `Scripts/verify.sh` exits 0
- [ ] Test count increased by 5; all pass
- [ ] `git status` shows no files outside the in-scope list
- [ ] `plans/README.md` row for 019 updated

## STOP conditions

Stop and report if:

- `grep -rn "SymbolDefinition" Hugo HugoTests` shows the type being decoded
  from JSON or a plist anywhere — then `Codable` must stay and the memberwise
  initializer cannot be replaced.
- The 52-symbol count changes at any point.
- `String(localized:)` inside a `static let` initializer resolves before the
  app's locale is available, producing English strings in a Danish build.
  Symptom: search by Danish keyword stops working. If observed, stop — the fix
  is a `lazy` catalog or an explicit locale parameter, and that is a design
  decision.
- Adding `Sendable` to `SymbolDefinition` produces a concurrency error because
  `LocalizedStringResource` is not `Sendable` in this SDK.

## Maintenance notes

- Adding a symbol now means adding one entry to `trackerSymbols` — the index
  builds itself in `init`. Do not construct `SymbolDefinition` with a
  hand-written `searchIndex`.
- The locale-at-init concern in the STOP conditions is the one real risk here.
  If the app ever gains in-app language switching, the static catalog must
  become locale-keyed.
- Deliberately deferred: adding a second `SymbolSet` case. The `switch` is
  ready for it.
- Reviewer should scrutinize: the Step 2 diff, with `--word-diff`, to confirm
  the 52 entries moved byte-for-byte.
