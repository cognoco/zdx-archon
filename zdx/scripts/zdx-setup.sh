#!/usr/bin/env bash
# zdx-setup.sh
# Provisions the worktree before plan/implement — dependency install and any
# repo-local env generation. The command is declared in the repo's
# zdx-config.yaml under `zdx.setup.command`. Run from the repo root.
#
# Optional: a repo that needs no provisioning simply omits the key, and this
# script exits 0 (skip). Contrast zdx-validate.sh, where a missing command is
# a hard error — every repo must be validatable, not every repo needs setup.
set -euo pipefail

CONFIG="zdx-config.yaml"
[ -f "$CONFIG" ] || { echo "zdx-setup: no zdx-config.yaml in $(pwd)"; exit 1; }

if command -v yq >/dev/null 2>&1; then
  CMD="$(yq -r '.zdx.setup.command // ""' "$CONFIG")"
else
  # Minimal fallback parser: `    command: <...>` under a setup: block.
  CMD="$(grep -A3 -E '^\s*setup:' "$CONFIG" | grep -E '^\s*command:' | head -1 | sed -E 's/^\s*command:\s*//; s/^["'\'']//; s/["'\'']\s*$//')"
fi

if [ -z "$CMD" ]; then
  echo "zdx-setup: no zdx.setup.command — nothing to provision, skipping"
  exit 0
fi

echo "zdx-setup: $CMD"
exec bash -c "$CMD"
