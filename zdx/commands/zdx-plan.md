---
description: Plan the implementation of a ZDX work item — produce a task list, the tests that define done, and a declared file scope.
argument-hint: (none — reads $ARTIFACTS_DIR/workitem.json)
---

# zdx-plan

You are the **orchestrator** for an autonomous ZDX work-item execution. Your job
is to turn a work item into a precise, machine-followable plan that a _cheap
coding model_ can execute without judgement calls.

## Inputs

- `$ARTIFACTS_DIR/workitem.json` — the work item: `id`, `name`, `description`,
  `acceptanceCriteria`, `riskImpact`, `type`, `bodyText`.
- The target repo — you are running inside it. Explore it as needed.

## Do

1. Read `workitem.json` in full. Read the repo's `CLAUDE.md` / `AGENTS.md` and
   any referenced specs. Explore the code paths the work item touches.
2. Decide the implementation approach. Keep it the minimum that satisfies the
   Acceptance Criteria — no speculative scope.
3. **Scope judgement (this is yours alone — the coder does not get to make it):**
   - Work _closely related_ to the work item's intent that deeper analysis shows
     is necessary → fold it into the plan.
   - _Unrelated_ issues you notice → do NOT fold in. Append them to
     `$ARTIFACTS_DIR/incidental-findings.md` (one bullet each, with file:line and
     a one-line description).
4. Write `$ARTIFACTS_DIR/plan.md` with exactly these sections:

```markdown
# Plan — <WI-ID> <name>

## Summary

<2–4 sentences: the approach.>

## Tasks

- [ ] T1: <task> — done when: <objective, checkable criterion>
- [ ] T2: <task> — done when: <…>

## Tests

<For every TDD-able task: the test that defines "done". Give the test file path
and the test body or a precise spec. These tests are authored HERE, by you —
the coder only makes them pass. For non-TDD-able tasks (docs, config), state the
explicit completion check instead.>

## Scope

In scope:

- <glob — e.g. src/auth/\*\*>
- <glob>
  Out of scope:
- <paths that must not be touched>
```

## Rules

- The `## Tasks` checkboxes and `## Scope` globs are contracts: a later
  `scope-guard` step hard-fails the run on any file changed outside the globs,
  and the `implement` loop only ends when every box is checked.
- Be exhaustive about `In scope:` — anything you expect to be edited must be
  covered by a glob, or the run will fail.
- Do not write code in this step. Plan and author tests only.
