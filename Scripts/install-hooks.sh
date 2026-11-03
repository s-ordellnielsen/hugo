#!/bin/sh
# One-time setup per clone: use the tracked hooks in Scripts/hooks.
set -eu

cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath Scripts/hooks
echo "Git hooks installed (core.hooksPath=Scripts/hooks)."
