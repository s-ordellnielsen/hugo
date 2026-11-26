#!/bin/sh
# Runs only the named test suites while you work. Not the commit gate: run
# Scripts/verify.sh before committing. Example:
#   Scripts/test-quick.sh HugoTests/YearMonthTests HugoTests/TheocraticYearTests
# Shares the simulator and the run lock with verify.sh.
set -eu
if [ $# -eq 0 ]; then
    echo "usage: Scripts/test-quick.sh <HugoTests/SuiteName>..." >&2
    exit 2
fi
cd "$(dirname "$0")/.."
args=""
for suite in "$@"; do
    args="$args --only $suite"
done
# shellcheck disable=SC2086
exec Scripts/verify.sh $args
