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
- **Planned at**: commit `3f8d48b`, 2026-11-03

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

- Commit messages are short imperative sentences without prefixes (from `git log`).

## Design decisions

- **Format only what the commit contains.** The hook formats staged Swift files, never the whole tree, so a commit cannot pick up unrelated reformatting (plan 037 forbids that for the same reason: blame noise).
- **Never sweep in unstaged work.** Re-staging a file with `git add` also stages any unstaged hunks in it. So a file that has unstaged changes (a `git add -p` commit) is **not** auto-formatted; it only goes through the final lint. The hook must not change what the author chose to commit beyond formatting.
- **Lint stays as the final check.** After formatting, `swift-format lint --strict` runs on the same files. This catches what formatting cannot fix, and the partially staged files above.
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

- Branch: `advisor/051-pre-commit-format-hook`
- Commit message: `Add pre-commit hook that formats staged Swift files`
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Write the hook

Create `Scripts/hooks/pre-commit`:

```sh
#!/bin/sh
# Formats the staged Swift files under Hugo/ and HugoTests/ with swift-format,
# adds the result to the commit, then lints as a final check. Formatting and
# linting only: tests and analysis stay in Scripts/verify.sh. Bypass in an
# emergency with `git commit --no-verify`.
set -eu

# Xcode and GUI git clients start hooks with a minimal PATH, so do not rely on it.
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

cd "$(git rev-parse --show-toplevel)"

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
    xcrun swift-format format --in-place "$file"
    if ! git diff --quiet -- "$file"; then
        git add -- "$file"
        echo "swift-format fixed and re-staged: $file" >&2
    fi
done

# Final check on exactly the staged paths. NUL-separated so names with spaces survive.
if ! printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 xcrun swift-format lint --strict; then
    echo >&2
    echo "Commit blocked: swift-format could not fix the problems listed above." >&2
    echo "Fix them by hand, or for a partly staged file run: xcrun swift-format format --in-place <file>" >&2
    exit 1
fi
```

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

Use throwaway files so nothing real is touched. Do this on the plan's branch. The probes are committed temporarily; Step 3.5 removes them from history by resetting.

1. **A fixable problem is fixed and committed.** Stage a file with tab indentation and commit:

   ```sh
   printf 'struct HookProbe {\n\tlet value = 1\n}\n' > Hugo/App/HookProbe.swift
   git add Hugo/App/HookProbe.swift
   git commit -m "Hook probe fixable"
   ```

   **Verify**:
   - The commit succeeds, and the output contains `swift-format fixed and re-staged: Hugo/App/HookProbe.swift`.
   - `git show HEAD:Hugo/App/HookProbe.swift | grep -c "$(printf '\t')"` → `0` (committed content has no tabs).
   - `git status --porcelain -- Hugo/App/HookProbe.swift` prints nothing (working tree matches the commit).

2. **A partly staged file is left alone.** Create the file, commit it, then stage one change while leaving a second change unstaged:

   ```sh
   printf 'struct HookProbe {\n    let value = 1\n}\n' > Hugo/App/HookProbe.swift
   git add Hugo/App/HookProbe.swift && git commit -q -m "Hook probe base"
   printf 'struct HookProbe {\n    let value = 2\n}\n' > Hugo/App/HookProbe.swift
   git add Hugo/App/HookProbe.swift
   printf 'struct HookProbe {\n    let value = 2\n\tlet extra = 3\n}\n' > Hugo/App/HookProbe.swift
   git commit -m "Hook probe partial"
   ```

   **Verify**:
   - The commit succeeds. The output does **not** contain `fixed and re-staged`.
   - `git show HEAD:Hugo/App/HookProbe.swift` contains `value = 2` and does **not** contain `extra`.
   - `git diff -- Hugo/App/HookProbe.swift` still shows the unstaged `extra` line, so the author's unstaged work was not swept in.

3. **An unfixable problem blocks the commit.** A file that does not parse cannot be formatted:

   ```sh
   git checkout -- Hugo/App/HookProbe.swift
   printf 'struct HookBroken {\n' > Hugo/App/HookBroken.swift
   git add Hugo/App/HookBroken.swift
   git commit -m "Hook probe broken"
   ```

   **Verify**: the commit is rejected, the output contains `Commit blocked`, and `git log -1 --format=%s` is still `Hook probe partial`.

4. **A commit with no Swift files is ignored.** Unstage the broken file (`git rm -f --cached Hugo/App/HookBroken.swift && rm Hugo/App/HookBroken.swift`), stage only `plans/README.md`, and run `Scripts/hooks/pre-commit`.

   **Verify**: exit 0, no output.

5. **Remove every probe.** Reset the three probe commits and delete the file:

   ```sh
   git reset --hard HEAD~3
   rm -f Hugo/App/HookProbe.swift Hugo/App/HookBroken.swift
   ```

   Use `git reset --hard` only here, only to drop the commits made in this step list, and only if `git log --format=%s -3` shows exactly `Hook probe partial`, `Hook probe base`, `Hook probe fixable`. Any other output is a STOP condition.

   **Verify**: `git ls-files Hugo | grep Hook` prints nothing, and `git log -1 --format=%s` is the commit that was `HEAD` before Step 3. Re-create your Step 1, 2 and 4 files first if the reset removed them, or commit them before running Step 3 so the reset cannot touch them.

   Commit the two scripts (Steps 1 and 2) **before** starting Step 3 so the reset cannot remove them. Do so with `git add Scripts && git commit -m "Add pre-commit hook that formats staged Swift files"`.

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

Commit `README.md` with the message `Document the pre-commit format hook`. The hook runs on this commit and must pass silently, since it contains no Swift files.

## Test plan

No XCTest or Swift Testing tests, because the hook is a shell script. Step 3 is the test: one fixable file fixed and committed, one partly staged file left alone, one unparseable file blocked, one non-Swift commit ignored. Re-run Step 3 if the hook is edited later.

## Done criteria

- [ ] `Scripts/hooks/pre-commit` and `Scripts/install-hooks.sh` exist and are executable (`test -x` on both)
- [ ] `git config --get core.hooksPath` prints `Scripts/hooks`
- [ ] Step 3 results all matched (fixed, left alone, blocked, ignored)
- [ ] `git ls-files Hugo | grep Hook` prints nothing
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status --porcelain` lists no files outside the Scope list
- [ ] `plans/README.md` row for 051 says DONE

## STOP conditions

Stop and report back if:

- `xcrun swift-format lint --strict --recursive Hugo HugoTests` does not exit 0 before you start. Plan 037 has not landed or has regressed. Do not install the hook until the repo is clean, or the first commit that touches an old file will also reformat it.
- `git config --get core.hooksPath` already prints a different value, or `.git/hooks` contains a non-sample hook. Someone has their own setup. Report it. Do not overwrite it.
- Step 3.1 is rejected, or the committed file still contains tabs. The hook is not running or the formatter did not apply.
- Step 3.2 stages the unstaged `extra` line. The partial-staging protection is broken and the hook must not be installed as is.
- `git log --format=%s -3` does not show exactly the three probe commits before the reset in Step 3.5.

## Maintenance notes

- Hooks are per clone. A new clone, a new machine, or a fresh checkout in a git worktree needs `Scripts/install-hooks.sh` once. Plan 050 should mention it in `AGENTS.md` so agents run it too.
- The hook rewrites files in the working tree while Xcode may have them open. Xcode reloads files changed on disk, but an unsaved edit in the editor at commit time could be lost or conflict. Save before committing.
- Because the hook re-stages fixed files, `git commit` can produce a commit whose content differs from what `git diff --cached` showed beforehand. The output line `swift-format fixed and re-staged: <file>` is the only signal, by design.
- Xcode's own commit UI runs hooks but shows only a short error on failure. If a commit from Xcode fails with no explanation, run `Scripts/hooks/pre-commit` in a terminal to see the diagnostics.
- A server-side check (Xcode Cloud `ci_post_clone.sh` running the lint step) would catch commits made with `--no-verify` or without the installer. It is not part of this plan.
