#!/usr/bin/env bash
# deploy.sh — install the execute-workitem workflow into ~/.archon/.
#
# Source-of-truth is this directory (zdx-archon fork, zdx/). Archon discovers
# *global* workflows/commands/scripts from ~/.archon/, so deployment is a copy —
# execute-workitem runs against arbitrary target repos, hence global, not the
# fork's repo-local .archon/. Re-run after any edit here. Idempotent.
#
# The two lib-dependent scripts (zdx-cosmo, zdx-capture) are NOT sourced from
# here — their canonical homes are the cosmo marketplace plugin, where each lives
# beside the shared lib it imports (skills/execute/execute.ts and
# skills/capture/capture.ts → ../../lib/). `bun build` inlines those imports into
# self-contained artifacts straight from the marketplace checkout, so there is one
# canonical lib (the cosmo plugin), never a fork copy.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${ARCHON_HOME:-$HOME/.archon}"
ZDX_MARKETPLACE_HOME="${ZDX_MARKETPLACE_HOME:-$HOME/.claude/plugins/marketplaces/zdx-marketplace}"

COSMO="$ZDX_MARKETPLACE_HOME/plugins/cosmo"
if [[ ! -d "$COSMO/lib" ]]; then
  echo "error: cosmo plugin lib not found at $COSMO/lib" >&2
  echo "       set ZDX_MARKETPLACE_HOME to a checkout of the zdx-marketplace repo" >&2
  exit 1
fi

for d in workflows commands scripts; do
  mkdir -p "$DEST/$d"
  # Copy files only — a stray subdirectory must not abort the deploy.
  find "$SRC/$d" -maxdepth 1 -type f -exec cp -v {} "$DEST/$d/" \;
done

# Bundled scripts. These import the shared ZDX lib, so they cannot be flat-copied —
# their imports would not resolve in the flat ~/.archon/scripts/ layout. `bun build`
# inlines the imports into a self-contained artifact, sourced from the cosmo plugin
# (canonical home of both the scripts and the lib).
echo "bundling lib-dependent scripts from $COSMO …"
bun build "$COSMO/skills/execute/execute.ts" --target=bun --outfile "$DEST/scripts/zdx-cosmo.ts"
bun build "$COSMO/skills/capture/capture.ts" --target=bun --outfile "$DEST/scripts/zdx-capture.js"

chmod +x "$DEST"/scripts/*.sh 2>/dev/null || true

# Machine-local config templates. Seed only when absent — re-running deploy.sh
# after workflow edits must never overwrite a tuned ~/.pi/agent/*.json or a
# populated ~/.archon/.env. (Existence-guarded rather than `cp -n`, which exits
# non-zero on skip under BSD/macOS and would trip `set -e` on re-deploy.) To pick
# up template changes on an existing machine, diff manually against
# zdx/templates/ and merge what you want.
PI_DEST="${PI_HOME:-$HOME/.pi/agent}"
mkdir -p "$PI_DEST"
[[ -f "$PI_DEST/settings.json" ]] || cp -v "$SRC/templates/pi-settings.json" "$PI_DEST/settings.json"
[[ -f "$PI_DEST/models.json"   ]] || cp -v "$SRC/templates/pi-models.json"   "$PI_DEST/models.json"

if [[ ! -f "$DEST/.env" ]]; then
  cp -v "$SRC/templates/.env.example" "$DEST/.env"
  echo "→ seeded $DEST/.env from template — fill in real secrets before running workflows"
fi

echo
echo "deployed execute-workitem → $DEST"
echo "next: archon validate workflows execute-workitem"
