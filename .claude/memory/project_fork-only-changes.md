---
name: Fork-only changes on zdx/customizations
description: Tracks fork-only modifications in cognoco/zdx-archon that should not be upstreamed to coleam00/Archon
type: project
---

## OTEL span tagging for Codex provider (2026-05-08)

Three commits on `zdx/customizations` branch:

1. `fix(provider/codex): tag spans with archon deployment_environment` — adds `buildArchonCodexConfig()` (defense-in-depth config path) and singleton bypass
2. `fix(dag-executor): inject ARCHON_DEPLOYMENT_ENVIRONMENT per-workflow` — injects `ARCHON_DEPLOYMENT_ENVIRONMENT=archon-<workflow-name>` into `config.envVars` at top of `executeDagWorkflow`
3. `fix(provider/codex): use OTEL_RESOURCE_ATTRIBUTES for span tagging` — the actual fix: sets `OTEL_RESOURCE_ATTRIBUTES=deployment.environment=<value>` in `CodexOptions.env`

All marked with `// FORK-ONLY:` comments referencing `.archon/_temp/f-lf2-codex-otel-tagging.md` in `cognoco/eduagent-build`.

**Why:** Per-workflow cost/timing attribution in Logfire requires tagged spans. Claude spans are tagged via `init-tracing.sh` → `.claude/settings.json`. Codex spans needed a different mechanism because the Codex CLI doesn't read `.claude/settings.json`.

**How to apply:** When merging upstream changes from `coleam00/Archon`, watch for conflicts in `packages/providers/src/codex/provider.ts` and `packages/workflows/src/dag-executor.ts`. The fork-only comments mark the exact locations.
