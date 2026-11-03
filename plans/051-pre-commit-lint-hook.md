# Plan 051: Block commits that fail `swift-format` lint with a tracked pre-commit hook

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
- **Depends on**: 037 (the repo must lint clean first, otherwise the hook blocks every commit)
- **Category**: dx
- **Planned at**: commit `3f8d48b`, 2026-11-03

## Why this matters

`Scripts/verify.sh` is the gate every plan uses, and its first step is `swift-format lint --strict`. Nothing runs it automatically. Plan 031 made the gate green and it was red again two days later, because the last commit added tab indentation (plan 037 had to fix 9 diagnostics). This keeps happening because the check only runs when someone remembers to run the whole gate, which takes minutes. Linting takes about a second, so it can run on every commit. A pre-commit hook that lints the Swift files in the commit turns this class of failure from "found later by the next plan" into "rejected at the moment it is made", whether the commit comes from Xcode, a terminal, or an agent.

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
- `.swift-format` (repo root) sets 4-space indentation and a 120-character line length. `swift-format` finds it by searching upward from each linted file, so linting individual files uses the same configuration as linting the directories.
- `README.md:25-28` documents the gate:

  ```markdown
  Scripts/verify.sh

  It runs strict Swift-format lint, Debug tests, and static analysis. `DESTINATION` and `DERIVED_DATA` can be overridden.
  ```

- Commit messages are short imperative sentences without prefixes (from `git log`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lint everything | `xcrun swift-format lint --strict --recursive Hugo HugoTests` | exit 0, no output |
| Install the hook | `Scripts/install-hooks.sh` | prints `Git hooks installed (core.hooksPath=Scripts/hooks).` |
| Check install | `git config --get core.hooksPath` | `Scripts/hooks` |
| Run the hook by hand | `Scripts/hooks/pre-commit` | exit 0 when staged Swift files are clean |
| Full gate | `Scripts/verify.sh` | exit 0 |

## Scope

**In scope** (the only files you should modify or create):

- `Scripts/hooks/pre-commit` (new, executable)
- `Scripts/install-hooks.sh` (new, executable)
- `README.md` (document the hook, one short section)
- `plans/README.md` (status row)

**Out of scope**:

- `Scripts/verify.sh`. It stays the full gate and is not changed.
- Running tests or analysis in the hook. Those take minutes and would make every commit painful. The hook is lint only.
- Auto-formatting in the hook (`swift-format format --in-place`). A hook that rewrites files makes the commit differ from what the author staged. The hook reports and the author fixes.
- `AGENTS.md`. Plan 050 rewrites it and should mention the hook there. Do not edit it here, to avoid a conflict.
- Xcode Cloud `ci_scripts`. Server-side enforcement is a separate decision.
- Any Swift source file.

## Git workflow

- Branch: `advisor/051-pre-commit-lint-hook`
- Commit message: `Add pre-commit hook that lints staged Swift files`
- Do not push or open a PR unless the operator instructed it.

## Steps

### Step 1: Write the hook

Create `Scripts/hooks/pre-commit`:

```sh
#!/bin/sh
# Rejects a commit when a staged Swift file under Hugo/ or HugoTests/ fails
# `swift-format lint --strict`. Lint only: tests and analysis stay in
# Scripts/verify.sh. Bypass in an emergency with `git commit --no-verify`.
set -eu

# Xcode and GUI git clients start hooks with a minimal PATH, so do not rely on it.
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

cd "$(git rev-parse --show-toplevel)"

# Added, copied, modified or renamed files only; deleted files cannot be linted.
files=$(git diff --cached --name-only --diff-filter=ACMR -- 'Hugo/*.swift' 'HugoTests/*.swift')

if [ -z "$files" ]; then
    exit 0
fi

# Lint exactly the staged paths. `printf` + `xargs` keeps names with spaces intact.
if ! printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 xcrun swift-format lint --strict; then
    echo >&2
    echo "Commit blocked: the Swift files above fail swift-format lint." >&2
    echo "Fix them with: xcrun swift-format format --in-place <file>" >&2
    echo "(only on files you changed; do not reformat unrelated files)" >&2
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

### Step 3: Prove the hook blocks a bad commit and allows a good one

Use a throwaway file so nothing real is touched. Do this on the plan's branch.

1. Stage a file with tab indentation:

   ```sh
   printf 'struct HookProbe {\n\tlet value = 1\n}\n' > Hugo/App/HookProbe.swift
   git add Hugo/App/HookProbe.swift
   git commit -m "Hook probe"
   ```

   **Verify**: the commit is rejected. Output contains `[Indentation]` for `Hugo/App/HookProbe.swift` and `Commit blocked`. `git log -1 --format=%s` is still the previous commit's subject.

2. Replace the tabs with spaces and retry:

   ```sh
   printf 'struct HookProbe {\n    let value = 1\n}\n' > Hugo/App/HookProbe.swift
   git add Hugo/App/HookProbe.swift
   Scripts/hooks/pre-commit
   ```

   **Verify**: the hook exits 0 with no output.

3. Remove the probe. It must not be committed:

   ```sh
   git rm -f --cached Hugo/App/HookProbe.swift
   rm Hugo/App/HookProbe.swift
   ```

   **Verify**: `git status --porcelain | grep HookProbe` prints nothing.

4. Confirm the hook ignores commits with no Swift files: stage only `plans/README.md` and run `Scripts/hooks/pre-commit` → exit 0, no output.

### Step 4: Document it

In `README.md`, directly after the paragraph that follows `Scripts/verify.sh` (line 28), add:

```markdown
### Pre-commit lint hook

Run once per clone:

    Scripts/install-hooks.sh

After that, every commit lints the staged Swift files with `swift-format` and is rejected if they fail. It checks formatting only; run `Scripts/verify.sh` for tests and static analysis. Skip it in an emergency with `git commit --no-verify`.
```

**Verify**: `grep -n 'install-hooks' README.md` → one match.

### Step 5: Run the full gate and commit

**Verify**: `Scripts/verify.sh` → exit 0 (the gate is unaffected because no Swift file changed).

Commit with the message from the Git workflow section. The hook runs on this commit and must pass, since it contains no Swift files.

## Test plan

No XCTest or Swift Testing tests, because the hook is a shell script. Step 3 is the test: one commit rejected for a lint violation, one clean file accepted, one non-Swift commit ignored. Re-run Step 3 if the hook is edited later.

## Done criteria

- [ ] `Scripts/hooks/pre-commit` and `Scripts/install-hooks.sh` exist and are executable (`test -x` on both)
- [ ] `git config --get core.hooksPath` prints `Scripts/hooks`
- [ ] Step 3 results all matched (bad file blocked, clean file allowed, probe removed)
- [ ] `git ls-files Hugo | grep HookProbe` prints nothing
- [ ] `Scripts/verify.sh` exits 0
- [ ] `git status --porcelain` lists no files outside the Scope list
- [ ] `plans/README.md` row for 051 says DONE

## STOP conditions

Stop and report back if:

- `xcrun swift-format lint --strict --recursive Hugo HugoTests` does not exit 0 before you start. Plan 037 has not landed or has regressed. Do not install the hook until the repo is clean, or it blocks every commit.
- `git config --get core.hooksPath` already prints a different value, or `.git/hooks` contains a non-sample hook. Someone has their own setup. Report it. Do not overwrite it.
- Step 3.1 commits successfully. The hook is not running, and the likely cause is a missing executable bit or `core.hooksPath` not being set.
- The hook rejects a clean file, for example because `swift-format` cannot find `.swift-format` when invoked on individual files.

## Maintenance notes

- Hooks are per clone. A new clone, a new machine, or a fresh checkout in a git worktree needs `Scripts/install-hooks.sh` once. Plan 050 should mention it in `AGENTS.md` so agents run it too.
- The hook lints the working-tree copy of each staged file, not the staged blob. If a file is partly staged (`git add -p`), the hook can pass or fail based on unstaged lines. That is accepted for simplicity.
- Xcode's own commit UI runs hooks, but only shows a short error. If a commit from Xcode fails with no explanation, run `Scripts/hooks/pre-commit` in a terminal to see the diagnostics.
- If linting ever becomes slow enough to notice, the fix is still per-file linting. Do not move tests into the hook.
- A server-side check (Xcode Cloud `ci_post_clone.sh` running the lint step) would catch commits made with `--no-verify`. It is not part of this plan.
