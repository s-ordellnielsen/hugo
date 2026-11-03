# Plan 051: Fix `swift-format` problems automatically in a tracked pre-commit hook

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3f8d48b..HEAD -- Scripts README.md .swift-format`
> Plan 037 is expected to have changed nothing in these paths. If `Scripts/`
> already contains anything besides `verify.sh`, or `git config --get core.hooksPath`
> prints a value, compare against the "Current state" excerpts before
> proceeding. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: 037 (the repo must lint clean first, otherwise the hook rewrites unrelated files)
- **Category**: dx
- **Planned at**: commit `3f8d48b`, 2026-11-03; revised 2026-11-03 at `455a3e4` after the first execution attempt found two defects (see Step 1 and Step 3)

## Why this matters

`Scripts/verify.sh` is the gate every plan uses, and its first step is `swift-format lint --strict`. Nothing runs it automatically. Plan 031 made the gate green and it was red again two days later, because the last commit added tab indentation (plan 037 had to fix 9 diagnostics). Almost every such diagnostic is a formatting problem that `swift-format format` can fix by itself, so there is no reason to make a person or an agent fix them by hand. A pre-commit hook that formats the Swift files in the commit, adds the result to the commit, and then lints as a final check means formatting problems never reach history, whether the commit comes from Xcode, a terminal, or an agent. Anything the formatter cannot fix, such as a file that does not parse, still blocks the commit with the diagnostics.

The hook lives in a tracked directory and is activated with `git config core.hooksPath`, because anything inside `.git/hooks` is not versioned and would be lost on a fresh clone.

## Current state

- `Scripts/` contains only `verify.sh`:

  ```sh
  #!/bin/sh
  set -eu

  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
  export DEVELOPER_DIR
  ...
  xcrun swift-format lint --strict --recursive Hugo HugoTests
  ```

- `.git/hooks/` contains only the `*.sample` files, and `git config --get core.hooksPath` prints nothing, so no hook is active.
- `.swift-format` (repo root) sets 4-space indentation and a 120-character line length. `swift-format` finds it by searching upward from each file, so formatting individual files uses the same configuration as the directory-level lint.
- `README.md:25-28` documents the gate:

  ```markdown
  Scripts/verify.sh

  It runs strict Swift-format lint, Debug tests, and static analysis. `DESTINATION` and `DERIVED_DATA` can be overridden.
  ```

- Commit messages use semantic prefixes such as `fix:`, `feat:`, `refactor:`, `docs:`, `chore:` (the owner asked for this on 2026-11-03).

## Design decisions

- **Format only what the commit contains.** The hook formats staged Swift files, never the whole tree, so a commit cannot pick up unrelated reformatting (plan 037 forbids that for the same reason: blame noise).
- **Never sweep in unstaged work.** Re-staging a file with `git add` also stages any unstaged hunks in it. So a file that has unstaged changes (a `git add -p` commit) is **not** auto-formatted; it only goes through the final lint. The hook must not change what the author chose to commit beyond formatting.
- **Lint checks what will be committed.** After formatting, `swift-format lint --strict` runs on the *staged* content of each file (exported with `git checkout-index`), not on the working-tree file. For a fully staged file the two are identical. For a partly staged file the unstaged hunks are not part of the commit, so a problem in them must not block it. A formatter failure (for example a file that does not parse) never aborts the hook early; the lint step reports it and blocks with a clear message.
- **Lint rules and format rules are the same configuration**, so a file the formatter has just rewritten passes the lint. If it does not, that is a real problem and the commit is blocked.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint everything | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Install the hook | `Scripts/install-hooks.sh` | prints `Git hooks installed (core.hooksPath=Scripts/hooks).` |
| Check install | `git config --get core.hooksPath` | `Scripts/hooks` |
| Run the hook by hand | `Scripts/hooks/pre-commit` | exit 0 when staged Swift files are clean or fixable |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope** (the only files you should modify or create):

- `Scripts/hooks/pre-commit` (new, executable)
- `Scripts/install-hooks.sh` (new, executable)
- `README.md` (document the hook, one short section)
- `plans/README.md` (status row)

**Out of scope**:

- `Scripts/verify.sh`. It stays the full gate and is not changed.
- Running tests or analysis in the hook. Those take minutes and would make every commit painful.
- Formatting files that are not part of the commit.
- `AGENTS.md`. Plan 050 rewrites it and should mention the hook there. Do not edit it here, to avoid a conflict.
- Xcode Cloud `ci_scripts`. Server-side enforcement is a separate decision.
- Any Swift source file.

## Git workflow

- Branch: only if the operator tells you to. In this repo the operator has been working directly on `main`.
- Commit message: `chore: add pre-commit hook that formats staged Swift files`. Do not commit unless told to.
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Write the hook

Create `Scripts/hooks/pre-commit`:

```sh
#!/bin/sh
# Formats the staged Swift files under Hugo/ and HugoTests/ with swift-format,
# adds the result to the commit, then lints exactly what is staged. Formatting
# and linting only: tests and analysis stay in Scripts/verify.sh. Bypass in an
# emergency with `git commit --no-verify`.
set -eu

# Xcode and GUI git clients start hooks with a minimal PATH, so do not rely on it.
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

root=$(git rev-parse --show-toplevel)
cd "$root"

# Added, copied, modified or renamed files only; deleted files cannot be formatted.
files=$(git diff --cached --name-only --diff-filter=ACMR -- 'Hugo/*.swift' 'HugoTests/*.swift')

if [ -z "$files" ]; then
    exit 0
fi

printf '%s\n' "$files" | while IFS= read -r file; do
    # A file with unstaged changes is skipped: `git add` would stage those changes too.
    if ! git diff --quiet -- "$file"; then
        continue
    fi
    # A file the formatter cannot handle (for example one that does not parse) is
    # left for the lint below, which reports it and blocks the commit.
    xcrun swift-format format --in-place "$file" || continue
    if ! git diff --quiet -- "$file"; then
        git add -- "$file"
        echo "swift-format fixed and re-staged: $file" >&2
    fi
done

# Final check on the staged content, which is what the commit will contain. It can
# differ from the working tree for a partly staged file.
staged=$(mktemp -d)
trap 'rm -rf "$staged"' EXIT
printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 git checkout-index --prefix="$staged/" --

if ! (cd "$staged" && printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 xcrun swift-format lint --strict --configuration "$root/.swift-format"); then
    echo >&2
    echo "Commit blocked: swift-format could not fix the problems listed above." >&2
    echo "Fix them by hand, or for a partly staged file run: xcrun swift-format format --in-place <file>" >&2
    exit 1
fi
```

(The first execution attempt used a simpler version that linted the working-tree file and let a formatter failure abort the hook under `set -e`. That blocked a commit whose staged content was clean, and it skipped the "Commit blocked" message for files that do not parse. The version above fixes both. It was checked against all the probes in Step 3, plus a file name containing a space.)

Then `chmod +x Scripts/hooks/pre-commit`.

**Verify**: `test -x Scripts/hooks/pre-commit && sh -n Scripts/hooks/pre-commit && echo OK` → `OK`.

### Step 2: Write the installer

Create `Scripts/install-hooks.sh`:

```sh
#!/bin/sh
# One-time setup per clone: use the tracked hooks in Scripts/hooks.
set -eu

cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath Scripts/hooks
echo "Git hooks installed (core.hooksPath=Scripts/hooks)."
```

Then `chmod +x Scripts/install-hooks.sh` and run it.

**Verify**:

- `Scripts/install-hooks.sh` prints `Git hooks installed (core.hooksPath=Scripts/hooks).`
- `git config --get core.hooksPath` → `Scripts/hooks`

### Step 3: Prove the hook fixes, protects, and blocks

Run every probe in a throwaway clone, never in the real repository. Probes make commits, and the real branch must stay untouched.

```sh
T=$(mktemp -d)
git clone -q . "$T/probe"
cp Scripts/hooks/pre-commit "$T/probe/Scripts/hooks/pre-commit"   # create the folder first if needed
cd "$T/probe"
git config user.name probe && git config user.email probe@example.com
git config core.hooksPath Scripts/hooks
git add Scripts && git commit -q -m "chore: add hook"
```

(The clone has its own copy of the repo's committed files, so `Scripts/hooks/` may not exist there yet: `mkdir -p Scripts/hooks` before the `cp`.) Then run the probes below from inside `$T/probe`. When finished, `cd` back to the real repository and `rm -rf "$T"`.

1. **A fixable problem is fixed and committed.**

   ```sh
   printf 'struct HookProbe {\n\tlet value = 1\n}\n' > Hugo/App/HookProbe.swift
   git add Hugo/App/HookProbe.swift
   git commit -m "probe fixable"
   ```

   **Verify**:
   - The commit succeeds, and the output contains `swift-format fixed and re-staged: Hugo/App/HookProbe.swift`.
   - `git show HEAD:Hugo/App/HookProbe.swift | grep -c "$(printf '\t')"` → `0`.
   - `git status --porcelain -- Hugo/App/HookProbe.swift` prints nothing.

2. **A partly staged file with a clean staged part commits, and the unstaged part is left alone.** The committed file (value 1, from probe 1) is the base:

   ```sh
   printf 'struct HookProbe {\n    let value = 2\n}\n' > Hugo/App/HookProbe.swift
   git add Hugo/App/HookProbe.swift
   printf 'struct HookProbe {\n    let value = 2\n\tlet extra = 3\n}\n' > Hugo/App/HookProbe.swift
   git commit -m "probe partial"
   ```

   **Verify**:
   - The commit succeeds. The output does **not** contain `fixed and re-staged`.
   - `git show HEAD:Hugo/App/HookProbe.swift` contains `value = 2` and does **not** contain `extra`.
   - `git diff -- Hugo/App/HookProbe.swift` still shows the unstaged `extra` line.

3. **A partly staged file whose staged part has a problem is blocked.**

   ```sh
   git checkout -- Hugo/App/HookProbe.swift
   printf 'struct HookProbe {\n\tlet value = 3\n}\n' > Hugo/App/HookProbe.swift
   git add Hugo/App/HookProbe.swift
   printf 'struct HookProbe {\n\tlet value = 3\n\tlet more = 4\n}\n' > Hugo/App/HookProbe.swift
   git commit -m "probe staged problem"
   ```

   **Verify**: the commit is rejected, the output contains `Indentation` and `Commit blocked`, and `git log -1 --format=%s` is still `probe partial`.

4. **An unparseable file is blocked with the guidance message.**

   ```sh
   git checkout -- Hugo/App/HookProbe.swift && git reset -q --hard HEAD
   printf 'struct HookBroken {\n' > Hugo/App/HookBroken.swift
   git add Hugo/App/HookBroken.swift
   git commit -m "probe broken"
   ```

   **Verify**: the commit is rejected, the output contains `expected '}' to end struct` and `Commit blocked`, and `git log -1 --format=%s` is still `probe partial`. Then `git rm -q -f --cached Hugo/App/HookBroken.swift && rm Hugo/App/HookBroken.swift`.

5. **A commit with no Swift files is ignored.** Stage only `plans/README.md` (append a line first) and run `Scripts/hooks/pre-commit`.

   **Verify**: exit 0, no output.

6. **A file name with a space survives.**

   ```sh
   git reset -q --hard HEAD
   printf 'struct Spaced {\n\tlet v = 1\n}\n' > "Hugo/App/Has Space.swift"
   git add "Hugo/App/Has Space.swift"
   git commit -m "probe space"
   ```

   **Verify**: the commit succeeds and `git show "HEAD:Hugo/App/Has Space.swift" | grep -c "$(printf '\t')"` → `0`.

7. **Clean up.** `cd` back to the real repository and run `rm -rf "$T"`. In the real repository, `git status --porcelain` must show only the new script files and the README edit (no probe files), and `git log -1 --format=%s` must be unchanged.

### Step 4: Document it

In `README.md`, directly after the paragraph that follows `Scripts/verify.sh` (line 28), add:

```markdown
### Pre-commit format hook

Run once per clone:

    Scripts/install-hooks.sh

After that, every commit formats the staged Swift files with `swift-format`, adds the fixes to the commit, and rejects the commit only if something cannot be fixed automatically. Files with unstaged changes are not reformatted, only checked. It covers formatting only; run `Scripts/verify.sh` for tests and static analysis. Skip it in an emergency with `git commit --no-verify`.
```

**Verify**: `grep -n 'install-hooks' README.md` → one match.

### Step 5: Run the full gate and commit the docs

**Verify**: `Scripts/verify.sh` → exit 0 (no Swift file changed).

If the operator asked you to commit, commit `README.md` with `docs: document the pre-commit format hook`. The hook runs on this commit and must pass silently, since it contains no Swift files. Otherwise leave it uncommitted.

## Test plan

No XCTest or Swift Testing tests, because the hook is a shell script. Step 3 is the test: one fixable file fixed and committed, one partly staged file left alone, one unparseable file blocked, one non-Swift commit ignored. Re-run Step 3 if the hook is edited later.

## Done criteria

- [ ] `Scripts/hooks/pre-commit` and `Scripts/install-hooks.sh` exist and are executable (`test -x` on both)
- [ ] `git config --get core.hooksPath` prints `Scripts/hooks`
- [ ] Step 3 results all matched (fixed, left alone, staged problem blocked, unparseable file blocked with guidance, non-Swift ignored, space in name fine)
- [ ] `git ls-files Hugo | grep Hook` prints nothing, and the real repository's `git log -1` is unchanged by Step 3
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status --porcelain` lists no files outside the Scope list
- [ ] `plans/README.md` row for 051 says DONE

## STOP conditions

Stop and report back if:

- `xcrun swift-format lint --strict --recursive Hugo HugoTests` does not exit 0 before you start. Plan 037 has not landed or has regressed. Do not install the hook until the repo is clean, or the first commit that touches an old file will also reformat it.
- `git config --get core.hooksPath` already prints a different value, or `.git/hooks` contains a non-sample hook. Someone has their own setup. Report it. Do not overwrite it.
- Probe 1 is rejected, or the committed file still contains tabs. The hook is not running or the formatter did not apply.
- Probe 2 stages the unstaged `extra` line, or is rejected. The partial-staging protection is broken and the hook must not be installed as is.
- Probe 3 or 4 is accepted. The hook is not linting the staged content.
- Any probe commit appears in the real repository's history. Probes belong in the throwaway clone only.

## Maintenance notes

- The final lint checks the staged blob of every staged Swift file, exported to a temporary directory, so a problem in unstaged work never blocks a commit. Diagnostics show repository-relative paths.
- Hooks are per clone. A new clone, a new machine, or a fresh checkout in a git worktree needs `Scripts/install-hooks.sh` once. Plan 050 should mention it in `AGENTS.md` so agents run it too.
- The hook rewrites files in the working tree while Xcode may have them open. Xcode reloads files changed on disk, but an unsaved edit in the editor at commit time could be lost or conflict. Save before committing.
- Because the hook re-stages fixed files, `git commit` can produce a commit whose content differs from what `git diff --cached` showed beforehand. The output line `swift-format fixed and re-staged: <file>` is the only signal, by design.
- Xcode's own commit UI runs hooks but shows only a short error on failure. If a commit from Xcode fails with no explanation, run `Scripts/hooks/pre-commit` in a terminal to see the diagnostics.
- A server-side check (Xcode Cloud `ci_post_clone.sh` running the lint step) would catch commits made with `--no-verify` or without the installer. It is not part of this plan.
