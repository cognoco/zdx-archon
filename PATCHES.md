# zdx/customizations — patches against upstream Archon

This branch carries the minimal ZDX-specific patches against upstream Archon
(`coleam00/archon`). Each entry documents the _why_, the _files touched_, and
how to reproduce against a clean upstream checkout. All patches are candidates
for upstreaming; track that work in the Archon project (Notion) WI for fork
upstreaming.

## Maintenance

- **Source-of-truth for runtime config** that depends on these patches lives
  in `nexus/zdx/archon/` (workflows, scripts, commands) and is deployed to
  `~/.archon/` via `nexus/zdx/archon/deploy.sh`.
- **Rebuild the binary** after touching any source file:
  - `bun --filter @archon/workflows type-check`
  - `TARGET=bun-darwin-arm64 OUTFILE=dist/binaries/archon-darwin-arm64 bash scripts/build-binaries.sh`
  - `kill <archon-serve-pid>` (launchd KeepAlive respawns from the new binary)
- **Verify a patch landed in the compiled binary**: each numeric constant or
  unique error string in the patch should appear in `strings dist/binaries/archon-darwin-arm64 | grep <distinctive-token>`. See per-patch verify lines below.

## Patch index

| #   | Commit     | File(s)                                       | Summary                                                                                                              | Upstream PR       |
| --- | ---------- | --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ----------------- |
| 1   | `19931557` | `packages/workflows/src/dag-executor.ts`      | maxBuffer 1 MB → 100 MB on bash / script / loop-until_bash subprocess execs                                          | not yet           |
| 2   | `19931557` | `packages/workflows/src/dag-executor.ts`      | SUBPROCESS_DEFAULT_TIMEOUT 2 min → 30 min; honor `node.idle_timeout` as fallback                                     | not yet           |
| 3   | `2c98ae1b` | `packages/workflows/src/dag-executor.ts`      | bash / script error classifier: drop substring `'timed out'` match; require SIGTERM+killed and distinguish maxBuffer | not yet           |
| 4   | `d9b64e05` | `packages/providers/package.json`, `bun.lock` | `@openai/codex-sdk` 0.125 → 0.132 to match installed codex CLI                                                       | n/a (vendor bump) |

Upstream base when this file was first written: `aa71520a fix(providers): expand ${VAR_NAME} brace syntax in MCP config env vars (#1728)` — last commit reachable from `upstream/dev` at merge time.

---

## Patch 1 — maxBuffer 1 MB → 100 MB

**Why.** Node's `child_process.execFile` defaults to a 1 MB stdout/stderr buffer. Any non-trivial test/lint run (jest verbose, full-repo lint) easily exceeds that. When the buffer fills, execFile kills the child with `ERR_CHILD_PROCESS_STDIO_MAXBUFFER`, hiding the real test outcome. 100 MB caps real-world output while keeping daemon memory bounded against pathological commands.

**Files.** `packages/workflows/src/dag-executor.ts` — three call sites:

- `executeBashNode` (`execFileAsync('bash', ...)`)
- `executeScriptNode` (`execFileAsync(<runtime>, ...)`)
- Loop node `until_bash` clause (`execFileAsync('bash', ...)`)

**Shape.**

```ts
const SUBPROCESS_MAX_BUFFER = 100 * 1024 * 1024;
// at each call site:
await execFileAsync(cmd, args, { cwd, timeout, env, maxBuffer: SUBPROCESS_MAX_BUFFER });
```

**Reproduce on clean upstream.** `git show 19931557 -- packages/workflows/src/dag-executor.ts | git apply -`
(Or cherry-pick `19931557` if the patches haven't drifted.)

**Test.** Run any bash node that produces > 1 MB of output (e.g. `pnpm test` at repo scale with verbose mode). On unpatched upstream: fails with `ERR_CHILD_PROCESS_STDIO_MAXBUFFER`. On patched: completes.

**Verify in binary.** `strings dist/binaries/archon-darwin-arm64 | grep '104857600'` → should match.

---

## Patch 2 — SUBPROCESS_DEFAULT_TIMEOUT 2 min → 30 min, honor `idle_timeout`

**Why.** Upstream `SUBPROCESS_DEFAULT_TIMEOUT = 120_000` is sized for small bash glue (`init-tracing.sh`, JSON fetches). A real repo validation node needs 5+ minutes. The workflow YAML's `idle_timeout` field was only consulted in loop-node code paths, not in bash/script-node executors. Authors who set `idle_timeout: 300000` on a bash node believed (reasonably) that it governed the subprocess; it didn't.

**Files.** `packages/workflows/src/dag-executor.ts` — same three call sites as Patch 1.

**Shape.**

```ts
const SUBPROCESS_DEFAULT_TIMEOUT = 30 * 60_000;
// at each call site:
const timeout = node.timeout ?? node.idle_timeout ?? SUBPROCESS_DEFAULT_TIMEOUT;
```

**Reproduce on clean upstream.** Same patch commit `19931557`.

**Test.** Add a bash node with `idle_timeout: 600000` that runs `sleep 200; echo done`. On unpatched: fails at 2 min. On patched: completes.

**Verify in binary.** `strings dist/binaries/archon-darwin-arm64 | grep '1800000'` → multiple matches expected; the constant appears as `it0=1800000` (or similar minified name) in the bash-node executor section.

---

## Patch 3 — bash/script error classifier: SIGTERM + killed (not substring)

**Why.** Upstream classifier:

```ts
const isTimeout = err.killed === true || (err.message ?? '').includes('timed out');
```

Node's `execFile` packs the child's stderr into `err.message`. Application test output frequently contains the substring `"timed out"` in legitimate log messages (e.g. `"filing waitForEvent timed out — proceeding with stale topic placement"`). When tests fail for non-timeout reasons, the substring match misclassifies the failure as a node timeout, hiding the actual cause and reporting a misleading `timed out after Nms` to the user.

**Fix.**

```ts
const isMaxBuffer = err.code === 'ERR_CHILD_PROCESS_STDIO_MAXBUFFER';
const isTimeout = !isMaxBuffer && err.killed === true && err.signal === 'SIGTERM';
```

Both `timeout` and `maxBuffer` overruns kill with SIGTERM via execFile's `killSignal`, but maxBuffer sets `err.code = 'ERR_CHILD_PROCESS_STDIO_MAXBUFFER'`, so we can distinguish. A genuine application exit (e.g. failing test → bash exit-1) has `err.killed === false` and falls through to the normal error formatter.

**Files.** `packages/workflows/src/dag-executor.ts` — two call sites (bash node, script node). The loop-`until_bash` site has its own simpler handler that doesn't need this change.

**Reproduce on clean upstream.** Cherry-pick `2c98ae1b` (or `git show 2c98ae1b -- packages/workflows/src/dag-executor.ts | git apply -`).

**Test.** Create a bash node whose command is `echo "request timed out"; exit 1`. On unpatched: reported as `timed out after Nms` (wrong). On patched: reported as `failed [exit 1]: request timed out` with the real exit code surfaced.

**Verify in binary.** `strings dist/binaries/archon-darwin-arm64 | grep 'ERR_CHILD_PROCESS_STDIO_MAXBUFFER'` → should appear inside the bash-node executor section.

---

## Patch 4 — `@openai/codex-sdk` 0.125 → 0.132

**Why.** Codex CLI installed via Homebrew advanced ahead of the SDK pinned by upstream Archon. While the JWT crash that triggered investigation was ultimately env-pollution from `~/.archon/.env` (not an SDK/CLI mismatch), the bump is kept because it pairs Archon's TypeScript types with the actual CLI version present on the host.

**Files.** `packages/providers/package.json`, `bun.lock`.

**Reproduce on clean upstream.** Cherry-pick `d9b64e05`, then `bun install --frozen-lockfile=false` to refresh the lock.

**Test.** Run any Codex node (e.g. `execute-workitem-codex`'s `plan`); should complete without "agent identity JWT payload is not valid JSON" (assuming `CODEX_*` env tokens are not also leaking from `~/.archon/.env` — see `nexus/docs/learnings/tooling/codex-external-auth-env-jwt-crash-2026-05-22.md`).
