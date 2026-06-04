#!/usr/bin/env bash
# zdx-validate.sh
# Runs the target repo's validation command (tests + lint + typecheck).
# The command is declared in the repo's zdx-config.yaml under
# `zdx.validate.command`. Run from the repo root.
set -euo pipefail

CONFIG="zdx-config.yaml"
[ -f "$CONFIG" ] || { echo "zdx-validate: no zdx-config.yaml in $(pwd)"; exit 1; }

if command -v yq >/dev/null 2>&1; then
  CMD="$(yq -r '.zdx.validate.command // ""' "$CONFIG")"
else
  # Minimal fallback parser: `    command: <...>` under a validate: block.
  CMD="$(grep -A3 -E '^\s*validate:' "$CONFIG" | grep -E '^\s*command:' | head -1 | sed -E 's/^\s*command:\s*//; s/^["'\'']//; s/["'\'']\s*$//')"
fi

if [ -z "$CMD" ]; then
  echo "zdx-validate: zdx-config.yaml has no zdx.validate.command — cannot validate this repo"
  exit 1
fi

echo "zdx-validate: $CMD"

# Optional secret injection: when zdx-config.yaml declares zdx.validate.doppler
# and DOPPLER_TOKEN is available in the daemon's env, wrap CMD with `doppler
# run` so secrets like DATABASE_URL reach the test process. This lets repos
# whose test suites legitimately need a real database run validation under
# Archon without committing secrets or globally configuring the daemon for
# one project's secret store.
DOPPLER_PROJECT=""
DOPPLER_CFG=""
if command -v yq >/dev/null 2>&1; then
  DOPPLER_PROJECT="$(yq -r '.zdx.validate.doppler.project // ""' "$CONFIG")"
  DOPPLER_CFG="$(yq -r '.zdx.validate.doppler.config // ""' "$CONFIG")"
fi

if [ -n "$DOPPLER_PROJECT" ] && [ -n "$DOPPLER_CFG" ] \
    && [ -n "${DOPPLER_TOKEN:-}" ] && command -v doppler >/dev/null 2>&1; then
  echo "zdx-validate: wrapping with doppler run --project=$DOPPLER_PROJECT --config=$DOPPLER_CFG"
  exec doppler run --project "$DOPPLER_PROJECT" --config "$DOPPLER_CFG" -- bash -c "$CMD"
fi

exec bash -c "$CMD"
