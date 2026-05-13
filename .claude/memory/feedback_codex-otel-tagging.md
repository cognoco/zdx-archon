---
name: Codex OTEL tagging learnings
description: Hard-won lessons from 3 rounds of fixing Codex span tagging in Logfire — covers env var plumbing, Codex SDK behavior, and verification discipline
type: feedback
---

## Codex CLI does NOT honor [otel].environment for OTel resource attributes

The `CodexOptions.config = { otel: { environment } }` path (which maps to `--config otel.environment=...` on the CLI) does NOT set `deployment.environment` on OTel spans. Even the global `~/.codex/config.toml`'s `[otel].environment = "native"` produces `null` spans in Logfire. The field may be used internally by codex but it is not propagated to the OTel resource.

**How to apply:** When tagging Codex OTel spans, use `OTEL_RESOURCE_ATTRIBUTES=deployment.environment=<value>` in `CodexOptions.env` instead of `CodexOptions.config`. This is the standard OTel SDK mechanism and is honored by codex's Rust instrumentation.

## Verify assumptions about SDK behavior BEFORE coding

The plan's §B5 required manual verification before implementation. Rounds 1 and 2 were wasted because the foundational assumption (that `[otel].environment` maps to `deployment.environment`) was never empirically tested.

**Why:** A 60-second `codex exec` probe with env vars would have caught this on round 1.
**How to apply:** When a plan says "verify before coding" or flags an open question, do the verification step first and report findings. Don't skip it because the spec seems plausible.

## process.env is daemon-wide — not per-workflow

The Archon daemon (`archon serve`) runs as a long-lived launchd service. Its `process.env` is shared across all concurrent workflow runs. `.claude/settings.json` env vars are only read by Claude Code subprocesses, not by the daemon process itself.

**Why:** Round 1 assumed `process.env` would have per-workflow values from `init-tracing.sh`. It doesn't.
**How to apply:** Per-workflow data must flow through `requestEnv` (via `SendQueryOptions.env`, populated from `config.envVars` in the dag-executor). Never rely on `process.env` for per-run values in the daemon.

## CodexOptions.env replaces process.env entirely

Per the SDK doc-comment: "When provided, the SDK will not inherit variables from `process.env`." The existing `buildCodexEnv()` helper handles this by merging `process.env` with `requestEnv` before passing to the SDK.

**How to apply:** When adding env vars to `CodexOptions.env`, always go through `buildCodexEnv()` (or merge with its output) — don't just set a single var or the codex subprocess loses PATH, HOME, etc.
