#!/usr/bin/env bash
# zdx-summary.sh <artifacts-dir>
# Final run summary to stdout. Read-only; no side effects.
set -euo pipefail

ARTIFACTS_DIR="${1:?usage: zdx-summary.sh <artifacts-dir>}"
WI="$ARTIFACTS_DIR/workitem.json"

echo "──────────────────────────────────────────────"
echo " execute-workitem — run summary"
echo "──────────────────────────────────────────────"
if [ -f "$WI" ]; then
  echo " Work item : $(jq -r '.id // "?"' "$WI") — $(jq -r '.name // "?"' "$WI")"
fi
[ -f "$ARTIFACTS_DIR/pr-url.txt" ]   && echo " PR        : $(cat "$ARTIFACTS_DIR/pr-url.txt")"
[ -f "$ARTIFACTS_DIR/ci-status.txt" ] && echo " CI        : $(cat "$ARTIFACTS_DIR/ci-status.txt")"
echo " Outcome   : work item left at Stage=Reviewing (closure is a human gate)"
if [ -s "$ARTIFACTS_DIR/incidental-findings.md" ]; then
  echo " Incidental: see incidental-findings.md — new work items may have been filed"
fi
echo "──────────────────────────────────────────────"
