#!/usr/bin/env bash
# check-implement-done.sh <artifacts-dir>
# until_bash for the `implement` loop. Exit 0 = done.
# Done = every task checkbox in plan.md is ticked AND the repo validation passes.
# Validation only runs once all boxes are ticked, so the full suite is not
# re-run on every loop iteration.
set -euo pipefail

ARTIFACTS_DIR="${1:?usage: check-implement-done.sh <artifacts-dir>}"
PLAN="$ARTIFACTS_DIR/plan.md"

[ -f "$PLAN" ] || { echo "plan.md not found — not done"; exit 1; }

if grep -qE '^\s*-\s*\[ \]' "$PLAN"; then
  remaining=$(grep -cE '^\s*-\s*\[ \]' "$PLAN" || true)
  echo "implement: $remaining task(s) still unchecked in plan.md"
  exit 1
fi

echo "implement: all tasks checked — running repo validation"
exec "$(dirname "$0")/zdx-validate.sh"
