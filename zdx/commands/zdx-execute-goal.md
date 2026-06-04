---
description: Execute a small, refined work item end-to-end (plan → TDD implement → one self-review round) in a single frontier pass. No commit/push/PR.
argument-hint: (none — reads $ARTIFACTS_DIR/workitem.json)
---

# zdx-execute-goal

You are a frontier engineer executing **one small, already-refined work item**
end to end, in a single pass. The item is intentionally small (typically a
single root cause, ~1–3 files). Work to your strengths — you own the plan, the
tests, and the implementation. Be surgical: every changed line must trace to the
work item's Acceptance Criteria.

This is the collapse of plan + implement + a light review into one node. You do
**three phases** internally; do not stop between them.

## Inputs

- `$ARTIFACTS_DIR/workitem.json` — `id`, `name`, `description`,
  `acceptanceCriteria`, `riskImpact`, `type`, `bodyText`. For scanner-sourced
  bugs the `bodyText` usually contains a **Recommended remediation** and the
  exact file/lines — treat it as a strong hint, not gospel; verify against the
  code.
- The target repo — you are running inside its worktree. Explore as needed.

## Phase 1 — Plan (tests-first)

1. Read `workitem.json` in full. Read the repo's `CLAUDE.md` / `AGENTS.md` and
   explore the code paths the item touches. Confirm the real root cause — do not
   trust the finding's line numbers blindly.
2. Decide the **minimum** change that satisfies the Acceptance Criteria. No
   speculative scope, no adjacent cleanup, no refactor that isn't required.
3. Write `$ARTIFACTS_DIR/plan.md` with **exactly** these sections (the `## Scope`
   `In scope:` globs are a hard contract — a later `scope-guard` step fails the
   run on any file changed outside them, so be exhaustive but tight):

```markdown
# Plan — <WI-ID> <name>

## Summary

<2–4 sentences: the root cause and the fix approach.>

## Tasks

- [ ] T1: <task> — done when: <objective, checkable criterion>
- [ ] T2: <task> — done when: <…>

## Tests

<For each TDD-able task: the failing test that defines "done" — file path + the
test body or a precise spec. For Bug/Incident items the AC requires a regression
test; author it here. For non-TDD-able tasks (config/docs), state the explicit
completion check instead.>

## Scope

In scope:

- <glob — e.g. apps/api/src/services/dictation/\*\*>
- <glob>
  Out of scope:
- <paths that must not be touched>
```

**Test placement — make the defining test runnable by fast validation.** The
regression test that defines "done" should execute during the workflow's
`validate` step, not only later in CI. Most repos split tests into a _fast_ tier
(unit) and a _slow_ tier (integration), and `validate` runs only the fast tier.
Prefer a **unit-level** test (e.g. `*.test.ts`) over an integration test
(e.g. `*.integration.test.ts`) unless the behavior genuinely requires integration
setup (real DB, network). For a small logic fix, a unit test that mocks the
boundary (repo / helper / client) and asserts the corrected behavior is both
faster and is the one `validate` will actually run. Check the repo's existing
test files to see which tier a given path uses before choosing.

## Phase 2 — Implement (red → green → refactor)

4. For each task: write the **failing test first**, watch it fail for the right
   reason, then make it pass with the minimal change. Refactor only if it keeps
   tests green and stays in scope. Tick the `- [ ]` box in `plan.md` as each task
   completes. Keep brief breadcrumbs in `$ARTIFACTS_DIR/progress.md`.
5. Run the repo's test/validate command yourself as you go — leave the tree in a
   green state. (A separate `validate` node will re-run the full suite.)

## Phase 3 — One self-review round (light)

6. Re-read your own `git diff` against the **Acceptance Criteria** and `plan.md`.
   This is a single, focused pass — not a deep adversarial cycle (the real PR
   reviewers do that downstream). Check for: AC fully met, no missed behavioral
   variant the AC enumerates, no obvious regression, no debug residue, no
   out-of-scope edits. Fix what you find. Do not invent new scope.

## Out-of-scope discoveries

Anything you notice that is _unrelated_ to this item — do **not** fold it in.
Append one bullet per issue to `$ARTIFACTS_DIR/incidental-findings.md` with
`file:line` and a one-line description. A later node files these as new work
items.

## Rules

- **Do not commit, push, or open a PR.** Leave the working tree changed; the
  push node owns the conventional commit.
- Stay inside the `## Scope` globs. If the real fix genuinely needs a path you
  didn't anticipate, update `plan.md`'s `In scope:` to cover it (with a one-line
  note in the Summary) rather than silently drifting.
- Minimum solution that satisfies the AC. If you wrote a lot, ask whether a
  senior engineer would call it overcomplicated — if so, cut it.
