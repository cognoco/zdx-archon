# Plan — Persist learnings from WI-89 / first end-to-end `execute-workitem` run

## Context

This session got the Archon `execute-workitem` DAG workflow running end-to-end for the first time, shipping two PRs against `eduagent-build` for WI-89:

- **#373** (Codex variant, `execute-workitem-codex`)
- **#374** (Qwen variant, `execute-workitem`)

Both green-CI, both via the full lifecycle (validate → adversarial-review → address-findings → re-validate → push → create-pr → ci-review → finalize). Getting there required three Archon fork patches, a doppler-wrap pattern for secrets-bearing bash nodes, a workflow-YAML fix for OpenAI structured output, and a hand-applied TS fix in the worktree. Several learnings emerged that should live somewhere durable, plus four follow-up work items.

User approved the 10-item checklist. This plan sequences execution and pins file paths. Claim-guard semantics resolved as **Model A close** — single-value `Claimed By`, dispatcher overwrites by default, Notion property-versioning gives traceability — collapses to one WI covering both Archon-side relaxation and dispatcher-side skill update.

## Repos touched

| Repo                                               | Role                    | Items                       |
| -------------------------------------------------- | ----------------------- | --------------------------- |
| `nexus` (this)                                     | Source-of-truth for ZDX | #1 mirrors, #5, #10, plan   |
| `_tools/archon` (fork branch `zdx/customizations`) | Patched Archon binary   | #2                          |
| `_tools/ZDX-marketplace`                           | Claude Code plugins     | #3, #8 dispatcher half      |
| `_dev/eduagent-build`                              | Target repo             | #1 zdx-config + #4 memories |
| Notion (ZDX Work Items DB)                         | WI registry             | #6, #7, #8, #9              |

## Sequencing — five waves

### Wave 1 — Verification (blocking, ~5 min)

1. Query Notion Projects DB. Confirm rows exist for **Archon**, **Pi**, **eduagent-build/MentoMate**. Create missing rows now (items #7, #8, #9 depend on this).
2. `git status` in each of the four repos. Fail fast if anything is mid-edit.
3. `pgrep -fl "archon serve"` — note daemon PID. Plan a clean restart after Wave 4 item #1.

### Wave 2 — Parallel additions (no shared files, no runtime risk)

- **Item #2** — `PATCHES.md` on fork `zdx/customizations` (own branch)
- **Item #4** — eduagent-build memories (own repo)
- **Item #5** — nexus memory (own repo)
- **Item #10** — `zdx-config.yaml` schema page (own file)

### Wave 3 — Marketplace edit (single repo, atomic)

- **Item #3** — archon-ops skill. Per `_tools/ZDX-marketplace/CLAUDE.md`: bump `marketplace.json` metadata.version + plugin's plugins[] entry + `plugins/archon-ops/.claude-plugin/plugin.json` version **FIRST**, then edit reference docs.

### Wave 4 — Doppler de-globalize (touches running infrastructure)

- **Item #1**, in strict order:
  1. Add `zdx.validate.doppler.{project, config}` block to `_dev/eduagent-build/zdx-config.yaml`, commit + push to main (scripts will read this; it must exist first).
  2. Update `nexus/zdx/archon/scripts/zdx-validate.sh` + `zdx-push.sh` to read selectors via `yq` instead of env vars (keep `DOPPLER_TOKEN` env-driven).
  3. Run `nexus/zdx/archon/deploy.sh` to copy scripts to `~/.archon/scripts/`.
  4. Remove `ZDX_DOPPLER_PROJECT` + `ZDX_DOPPLER_CFG` lines from `~/.archon/.env` (keep `DOPPLER_TOKEN`).
  5. Restart daemon (`kill <pid>`, KeepAlive respawns).
  6. Smoke test: run a small Archon workflow that exercises the validate node against eduagent-build, confirm `yq` read in logs.

### Wave 5 — Work items (after Notion projects verified in Wave 1)

Parallel; all use the `zdx-notion create`–compatible JSON / equivalent MCP tool depending on existing conventions:

- **Item #6** — eduagent-build WI
- **Item #7** — Archon WI (upstream fork patches + auto-`additionalProperties: false` for codex)
- **Item #8** — Claim-guard WI (Archon-side + dispatcher skill)
- **Item #9** — Pi fallback WI

Cross-link in descriptions: item #6 references PRs #373/#374; item #10's schema page links from `nexus/zdx/standard/README.md`.

## Per-item detail

### #1 — Doppler de-globalize

**Files**:

- `_dev/eduagent-build/zdx-config.yaml` — add `zdx.validate.doppler: { project: mentomate, config: dev }` under existing `zdx:` root
- `nexus/zdx/archon/scripts/zdx-validate.sh` — replace `[ -n "${ZDX_DOPPLER_PROJECT:-}" ] && [ -n "${ZDX_DOPPLER_CFG:-}" ]` env reads with `yq` reads from `zdx-config.yaml`; fall back to nothing (= skip wrap) if absent
- `nexus/zdx/archon/scripts/zdx-push.sh` — same
- `~/.archon/.env` — remove the two `ZDX_DOPPLER_*` lines
- `~/.archon/scripts/*` — deploy.sh updates

**Pattern** (sketch):

```bash
DOPPLER_PROJECT="$(yq -r '.zdx.validate.doppler.project // ""' zdx-config.yaml)"
DOPPLER_CFG="$(yq -r '.zdx.validate.doppler.config // ""' zdx-config.yaml)"
if [ -n "$DOPPLER_PROJECT" ] && [ -n "$DOPPLER_CFG" ] && [ -n "${DOPPLER_TOKEN:-}" ] && command -v doppler >/dev/null 2>&1; then
  exec doppler run --project "$DOPPLER_PROJECT" --config "$DOPPLER_CFG" -- bash -c "$CMD"
fi
```

**Verify**: `grep ZDX_DOPPLER ~/.archon/.env` returns empty; running validate against eduagent-build still wraps with doppler (visible in script's echo line); validate exits 0.

### #2 — PATCHES.md on fork

**File**: `_tools/archon/PATCHES.md` (committed on `zdx/customizations`)

**Format** (no precedent — design now):

```markdown
# zdx/customizations patches against upstream Archon

Base: <upstream commit + date>
Branch: zdx/customizations

## Patch index

| #   | Commit   | File(s)                                    | Summary                                                                                                                                | Upstream PR            |
| --- | -------- | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| 1   | 19931557 | packages/workflows/src/dag-executor.ts     | maxBuffer 1 MB → 100 MB; subprocess timeout 2 min → 30 min + idle_timeout fallback; classifier signal/killed/code instead of substring | tracked in [Archon WI] |
| 2   | d9b64e05 | packages/providers/package.json + bun.lock | @openai/codex-sdk 0.125 → 0.132                                                                                                        | n/a (vendor bump)      |

## Patch 1: dag-executor bash/script node defaults & classifier

**Why:** Upstream defaults (1 MB stdout buffer, 2 min subprocess timeout) are sized for small bash glue, not full repo test suites. Classifier substring `'timed out'` produced false positives from application log content.
**Files:** packages/workflows/src/dag-executor.ts
**Reproduce on clean upstream:** `git show 19931557 | git apply -`
**Test:** Run any bash node that calls `pnpm test:*` producing >1 MB of output and lasting >2 min; confirm completion + correct error classification on real failures.
```

**Verify**: `cat PATCHES.md`; cross-check each row commit SHA exists; reproduce-apply works on a scratch upstream clone (optional, document only).

### #3 — archon-ops skill update

**Order (mandatory per marketplace CLAUDE.md)**:

1. Edit `_tools/ZDX-marketplace/.claude-plugin/marketplace.json`: bump `metadata.version` + `plugins[archon-ops].version` (`0.1.1` → `0.1.2`).
2. Edit `_tools/ZDX-marketplace/plugins/archon-ops/.claude-plugin/plugin.json`: bump `version` (`0.1.1` → `0.1.2`).
3. **THEN** edit reference docs:
   - `references/troubleshooting.md` — diagnose bash-node "timed out" failures (signals to read; elapsed-vs-configured mismatch); resume semantics
   - `references/observability.md` — three-data-sources pattern already there; add cross-reference to shim diagnostic learning at `nexus/docs/learnings/operations/binary-shim-diagnostic-pattern-2026-05-22.md`
   - `references/good-practices.md` — `additionalProperties: false` requirement for codex `output_format: { type: object }`; doppler-wrap pattern for bash nodes that need secrets (link to `zdx-validate.sh`/`zdx-push.sh` as reference impl)

**Verify**: `cat plugin.json | jq .version` matches `marketplace.json`; new sections render in the cached install after `claude plugins sync` (or whatever the refresh command is).

### #4 — eduagent-build memories

**Files** (use repo's simpler frontmatter `name` / `description` / `type: project`):

- `_dev/eduagent-build/.claude/memory/doppler-secrets.md` — project=`mentomate`, configs=`dev`/`stg`/`prd`; `DATABASE_URL` lives in Doppler; tests in `*.test.ts` that need DB depend on it (e.g., `idempotency-assistant-state.test.ts`); the doppler-wrap in `zdx-validate.sh` is how Archon validate gets it.
- `_dev/eduagent-build/.claude/memory/load-database-env-windows-hardcode.md` — `packages/test-utils/src/lib/load-database-env.ts` hardcodes `C:/Tools/doppler/doppler.exe`; on macOS only the env-var path of the resolver fires. Cross-platform fix tracked in eduagent-build WI (#6).
- Update `_dev/eduagent-build/.claude/memory/MEMORY.md` index.

**Verify**: `ls _dev/eduagent-build/.claude/memory/`; both new files appear in index; frontmatter matches existing files' shape.

### #5 — Nexus memory

**File**: `nexus/.claude/memory/reference-archon-locations.md` — type=`reference`. Map of where Archon things live:

- Runtime: `~/.archon/` (workflows, scripts, commands, .env)
- Source-of-truth mirror: `nexus/zdx/archon/` (deploy via `deploy.sh`)
- Fork: `_tools/archon`, branch `zdx/customizations` (patched binary at `dist/binaries/archon-darwin-arm64`)
- Patches summary: `_tools/archon/PATCHES.md` (after #2)

Use Nexus's full frontmatter schema per `nexus/CLAUDE.md` (name, description, type, created, last_confirmed, status).
Update `nexus/.claude/memory/MEMORY.md` index.

**Verify**: file exists with valid frontmatter; index updated.

### #6 — eduagent-build WI

**Project**: eduagent-build/MentoMate. **Type**: Bug or Task. **Layer**: Item. **Priority**: P2.

**Title**: validate too permissive vs husky pre-commit (tsc gap) + test categorization + loadDatabaseEnv cross-platform

**Acceptance criteria**:

- `validate` (or `check-change-class.sh --run --fast`) runs `tsc --build` (or equivalent strict typecheck) on changed files so type errors are caught before push.
- Tests requiring `DATABASE_URL` either move to `*.integration.test.ts` (excluded from api:unit) or `api:unit` runs with Doppler wrap by default.
- `loadDatabaseEnv` resolver detects Doppler on macOS/Linux paths (`/opt/homebrew/bin/doppler`, `/usr/local/bin/doppler`) — not just the Windows hardcode.

**Context to include**: WI-89 session (this one), PRs #373 + #374, the 4 specific TS errors in `apps/mobile/src/app/(app)/quiz/play.test.tsx` (lines 74/83/84/1123) that validate missed and pre-commit caught, `idempotency-assistant-state.test.ts` as an example of mis-categorization.

### #7 — Archon WI

**Project**: Archon. **Type**: Enhancement. **Layer**: Item or Work Package (likely Work Package — two atomic changes). **Priority**: P2.

**Title**: Upstream `zdx/customizations` patches + auto-inject `additionalProperties: false` for codex structured output

**Acceptance criteria**:

- Three dag-executor patches from `PATCHES.md` upstreamed (PRs filed against upstream Archon repo): maxBuffer default, subprocess timeout + idle_timeout fallback, bash/script error classifier.
- Codex provider auto-injects `additionalProperties: false` at every object level when `output_format.type === 'object'` and provider is `codex`.

**Context to include**: link to fork `PATCHES.md`, this session's debugging trail, learning entries at `nexus/docs/learnings/tooling/archon-bash-node-default-limits-too-tight-2026-05-22.md`.

### #8 — Claim-guard WI

**Project**: Archon. **Type**: Enhancement. **Layer**: Work Package. **Priority**: P2.

**Title**: Move claim-guard from Archon-side refusal to dispatcher-side responsibility

**Acceptance criteria**:

- Archon's `fetch-and-check` / `claim` nodes in `execute-workitem.yaml` no longer refuse on prior claim. Write proceeds (overwrites on re-claim). Workflow surfaces a one-line warning event when overwrite occurs.
- The `work-items` skill (`_tools/ZDX-marketplace/plugins/work-items/skills/work-items/SKILL.md`) gains a "Claim Coordination" section: before any dispatch that invokes `archon workflow run execute-workitem`, the dispatching agent reads `Claimed By`; if non-empty and not the same agent, prompts the human for explicit override.
- Notion property-versioning is the audit trail (no schema change).
- Cross-referenced from `work-lifecycle` skill.

**Home for claim-check**: inline section in `work-items` SKILL.md (per agent recommendation; aligns with schema/lifecycle authority).

**Context to include**: WI-89 session (had to manually reset claim between Codex and Qwen runs), the user's principle: "Archon should just assume it should execute it."

### #9 — Pi fallback WI

**Project**: Pi (verify exists in Wave 1). **Type**: Investigation/Enhancement. **Layer**: Item. **Priority**: P3 (open-ended product question).

**Title**: Investigate Pi-native inter-provider fallback (rate limits + silent stream drops)

**Acceptance criteria** (open-ended; this is a spike):

- Document whether Pi can support automatic failover from primary provider → fallback when primary returns 429/credit-exhaustion / silent stream close.
- If yes, propose config shape (e.g., `models.json` per-provider `fallback: <provider/model>`).
- If no, document operational alternative (workflow-level alternates).

**Context to include**: kimi-k2.6 / Fireworks streaming pattern, OpenRouter 402 credit cap hit during WI-89 run, existing retry config in `~/.pi/agent/settings.json`, learning at `nexus/docs/learnings/tooling/kimi-k2.6-fireworks-streaming-unstable-2026-05-22.md`.

### #10 — zdx-config.yaml schema page

**File**: `nexus/zdx/standard/config.md`

**Frontmatter** (matching standard's existing convention):

```yaml
---
zdx-doc: standard/config
zdx-version: 0.1.0
zdx-status: draft
updated: 2026-05-23
governs:
  - zdx-config.yaml schema
  - per-repo zdx tooling configuration
---
```

**Content**: Document the top-level `zdx:` key and all sub-keys discovered in existing usages:

- `zdx.version`
- `zdx.work-items.{database_id, data_source_id, token: { env_var }, defaults: { type, layer, priority, project_id }}`
- `zdx.setup.command`
- `zdx.validate.command`
- `zdx.validate.doppler.{project, config}` ← NEW (from #1)
- `zdx.conformance.deviations: []`
- `zdx.extensions: { ... }` (note as extension point)

Reference real examples in `nexus/zdx-config.yaml` and `_dev/eduagent-build/zdx-config.yaml`.

Update `nexus/zdx/standard/README.md` file index to link `config.md`.

**Verify**: `zdx/standard/README.md` links `config.md`; frontmatter validates.

## Risk register

| Risk                                                                         | Mitigation                                                                                          |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Notion `Project` rows for Archon/Pi don't exist                              | Verify in Wave 1; create rows before filing WIs                                                     |
| Doppler env-var removal while a workflow is mid-run                          | Check `archon workflow status` empty before #1 step 4                                               |
| Marketplace version bump forgotten                                           | Make it the FIRST edit in Wave 3, not the last                                                      |
| `_tools/archon` fork branch in mid-edit                                      | `git status` in Wave 1                                                                              |
| Doppler binary missing from daemon's PATH (different from interactive shell) | `_env.sh` defensive PATH already covers `/opt/homebrew/bin`; confirm during smoke test              |
| eduagent-build memory frontmatter mismatch                                   | Use existing repo's simpler shape (`name`, `description`, `type: project`), not Nexus's richer one  |
| Scope creep on claim-guard WI                                                | Keep dispatcher-side change to the `work-items` skill only; don't pull in `work-lifecycle` rewrites |

## Verification — end-to-end

After all 10 items:

1. `git status` clean across all four repos (or only intentional uncommitted edits).
2. `archon workflow run execute-workitem WI-NN` against eduagent-build on a fresh test WI (or a no-op dry-run) — doppler-wrap visible in script output, validate green, no `ZDX_DOPPLER_*` env vars consulted.
3. `claude plugins sync` (or the equivalent) refreshes archon-ops + work-items; version diff shows new content.
4. Four new WIs visible in Notion DB with correct projects, types, priorities, acceptance criteria.
5. `nexus/zdx/standard/config.md` linked from README and renders cleanly.
6. `nexus/.claude/memory/MEMORY.md` and `_dev/eduagent-build/.claude/memory/MEMORY.md` both updated.
7. `_tools/archon/PATCHES.md` exists on `zdx/customizations` branch with all three patches documented.

## Open execution-time decisions

These don't block planning but will be decided at execution:

- **Notion WI creation mechanism**: prefer `zdx-notion.ts` CLI if it supports single-WI create from CLI args (not just JSON file); otherwise use MCP `notion-create-pages` directly. Confirm at Wave 5 start.
- **Commit boundaries**: each wave gets at least one commit per repo; user approval before any commit per project-wide rule.
- **Marketplace version bump magnitude**: `0.1.1 → 0.1.2` (patch — additive content only). User can override if they want minor.
