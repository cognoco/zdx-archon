#!/usr/bin/env bash
set -euo pipefail

# Usage: init-tracing.sh [--workflow <name>] [<pr-identifier>]
#
# Workflow name resolution (highest priority first):
#   1. --workflow <name> flag (preferred: set explicitly in workflow YAML
#      bash: line, e.g. `bash: ./.archon/scripts/init-tracing.sh --workflow
#      execute-cleanup-pr-claude "$ARGUMENTS"`)
#   2. ARCHON_WORKFLOW env var
#   3. Legacy task-<workflow>-<timestamp> directory naming regex
#   4. "unknown-workflow" fallback
#
# Archon's worktree dirs are `archon/thread-<uuid>` so the regex never matches
# in modern runs — pass --workflow explicitly.

workflow_flag=""
pr_arg=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --workflow)
            workflow_flag="${2:-}"
            shift 2
            ;;
        --workflow=*)
            workflow_flag="${1#--workflow=}"
            shift
            ;;
        *)
            # First non-flag positional is the PR identifier.
            if [[ -z "$pr_arg" ]]; then
                pr_arg="$1"
            fi
            shift
            ;;
    esac
done

run_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"

cwd="$(pwd)"

archon_repo="$(basename "$(dirname "$(dirname "$(dirname "$cwd")")")")"

if [[ -n "$workflow_flag" ]]; then
    archon_workflow="$workflow_flag"
elif [[ -n "${ARCHON_WORKFLOW:-}" ]]; then
    archon_workflow="$ARCHON_WORKFLOW"
else
    task_dir="$(basename "$cwd")"
    if [[ "$task_dir" =~ ^task-(.+)-[0-9]{10,}$ ]]; then
        archon_workflow="${BASH_REMATCH[1]}"
    else
        archon_workflow="unknown-workflow"
    fi
fi

env_label="archon-${archon_workflow}"

# Merge into existing .claude/settings.json (preserves project settings).
#
# Both env vars carry the same value (`archon-<workflow>`):
#   - LOGFIRE_ENVIRONMENT: read by claude-code-plugin to tag claude spans.
#   - ARCHON_DEPLOYMENT_ENVIRONMENT: read by Archon's codex provider in our
#     fork (cognoco/zdx-archon) to set CodexOptions.config.otel.environment
#     so codex_sdk_ts spans land tagged. The Logfire-specific name is kept
#     in parallel for backward compatibility with anything else reading it.
#     See cognoco/eduagent-build:.archon/_temp/f-lf2-codex-otel-tagging.md
#     for the design context.
mkdir -p .claude
if [[ -f .claude/settings.json ]]; then
    jq --arg env "$env_label" '. + {"env": ((.env // {}) + {"LOGFIRE_ENVIRONMENT": $env, "ARCHON_DEPLOYMENT_ENVIRONMENT": $env})}' \
        .claude/settings.json > .claude/settings.json.tmp && mv .claude/settings.json.tmp .claude/settings.json
else
    jq -n --arg env "$env_label" '{"env":{"LOGFIRE_ENVIRONMENT":$env,"ARCHON_DEPLOYMENT_ENVIRONMENT":$env}}' > .claude/settings.json
fi

# The settings.json mutation above is run-local tracing config — it must never
# be flagged by scope-guard or committed by push. If the file is tracked, tell
# git to ignore local working-tree changes to it for the life of this worktree
# (per-worktree index, so it does not affect the canonical checkout). Untracked
# (newly created) settings.json is handled by repo .gitignore conventions.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
   && git ls-files --error-unmatch .claude/settings.json >/dev/null 2>&1; then
    git update-index --skip-worktree .claude/settings.json || true
fi

if [[ -n "$pr_arg" ]]; then
    jq -n \
        --arg rid "$run_id" \
        --arg wf "$archon_workflow" \
        --arg repo "$archon_repo" \
        --arg pr "$pr_arg" \
        '{"archon.run_id":$rid,"archon.workflow":$wf,"archon.repo":$repo,"archon.pr":$pr}' \
        > .claude/logfire-resource-attributes.json
else
    jq -n \
        --arg rid "$run_id" \
        --arg wf "$archon_workflow" \
        --arg repo "$archon_repo" \
        '{"archon.run_id":$rid,"archon.workflow":$wf,"archon.repo":$repo}' \
        > .claude/logfire-resource-attributes.json
fi

mkdir -p .codex
printf '[otel]\nenvironment = "%s"\n' "$env_label" > .codex/config.toml

echo "archon.run_id=${run_id}"
echo "archon.workflow=${archon_workflow}"
echo "environment=${env_label}"
echo "wrote: ${cwd}/.claude/settings.json"
echo "wrote: ${cwd}/.claude/logfire-resource-attributes.json"
echo "wrote: ${cwd}/.codex/config.toml"
