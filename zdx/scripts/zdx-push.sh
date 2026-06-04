#!/usr/bin/env bash
# zdx-push.sh <artifacts-dir>
# Commits the worktree changes with a uniform conventional-commit message
# (type derived from the work item Type) referencing the WI, and pushes the
# branch. Run-artifacts live outside the worktree, so `git add -A` is safe.
set -euo pipefail

ARTIFACTS_DIR="${1:?usage: zdx-push.sh <artifacts-dir>}"
WI="$ARTIFACTS_DIR/workitem.json"
[ -f "$WI" ] || { echo "zdx-push: workitem.json not found"; exit 1; }

WI_ID="$(jq -r '.id // "WI-?"' "$WI")"
WI_NAME="$(jq -r '.name // "work item"' "$WI")"
WI_TYPE="$(jq -r '.type // ""' "$WI")"

case "$WI_TYPE" in
  Bug|Incident)        CONV=fix ;;
  Feature|Enhancement) CONV=feat ;;
  Documentation|Design) CONV=docs ;;
  Hygiene)             CONV=refactor ;;
  *)                   CONV=chore ;;
esac

if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  echo "zdx-push: no changes to commit"
else
  # Stage only paths within the plan's declared scope (plan.md ## Scope → In
  # scope globs), not `git add -A`. scope-guard already proved nothing
  # out-of-scope *changed*, but files can appear between scope-guard and here
  # (e.g. a snapshot written by the validate step, editor cruft). Staging by
  # scope keeps the commit tight regardless. Each glob is reduced to its stable
  # prefix (everything before the first `*`) so a directory glob stages the
  # whole in-scope subtree and an exact path stages just that file.
  PLAN="$ARTIFACTS_DIR/plan.md"
  SCOPE_PATHS=()
  if [ -f "$PLAN" ]; then
    while IFS= read -r g; do
      p="${g%%\**}"
      [ -n "$p" ] && SCOPE_PATHS+=("$p")
    done < <(awk '
      /^## Scope/        {s=1; next}
      s && /^## /        {exit}
      s && /[Ii]n scope:/ {inscope=1; next}
      s && /[Oo]ut of scope:/ {inscope=0}
      inscope && /^[[:space:]]*[-*]/ {
        sub(/^[[:space:]]*[-*][[:space:]]*/, ""); gsub(/`/, ""); print
      }' "$PLAN")
  fi
  if [ "${#SCOPE_PATHS[@]}" -gt 0 ]; then
    echo "zdx-push: staging in-scope paths: ${SCOPE_PATHS[*]}"
    git add -- "${SCOPE_PATHS[@]}"
  else
    echo "zdx-push: no plan scope globs found — falling back to git add -A" >&2
    git add -A
  fi
  git commit -m "$(printf '%s: %s\n\nRefs: %s' "$CONV" "$WI_NAME" "$WI_ID")"
fi

# Wrap with doppler when configured so the husky pre-push hook (which runs
# jest --findRelatedTests on the push delta) gets DATABASE_URL etc. Without
# this, repo-side hooks that legitimately need a real DB fail under Archon
# even though validate already passed via the same mechanism.
# Selector lives in the repo's zdx-config.yaml under zdx.validate.doppler
# (one block applies to both validate and push so secrets stay aligned).
DOPPLER_PROJECT=""
DOPPLER_CFG=""
if [ -f "zdx-config.yaml" ] && command -v yq >/dev/null 2>&1; then
  DOPPLER_PROJECT="$(yq -r '.zdx.validate.doppler.project // ""' zdx-config.yaml)"
  DOPPLER_CFG="$(yq -r '.zdx.validate.doppler.config // ""' zdx-config.yaml)"
fi

if [ -n "$DOPPLER_PROJECT" ] && [ -n "$DOPPLER_CFG" ] \
    && [ -n "${DOPPLER_TOKEN:-}" ] && command -v doppler >/dev/null 2>&1; then
  echo "zdx-push: wrapping git push with doppler run --project=$DOPPLER_PROJECT --config=$DOPPLER_CFG"
  doppler run --project "$DOPPLER_PROJECT" --config "$DOPPLER_CFG" -- git push -u origin HEAD
else
  git push -u origin HEAD
fi
echo "zdx-push: pushed $(git rev-parse --abbrev-ref HEAD)"
