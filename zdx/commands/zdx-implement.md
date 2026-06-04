---
description: Implement one task from plan.md using TDD red-green. Runs in a fresh-context loop until all tasks are done.
argument-hint: (none — reads $ARTIFACTS_DIR/plan.md and progress.md)
---

# zdx-implement

**FRESH session — you have no memory of previous iterations.** All state is on
disk. This prompt runs in a loop; each call you complete exactly one task.

## Inputs

- `$ARTIFACTS_DIR/plan.md` — `## Tasks` (checkboxes), `## Tests`, `## Scope`.
- `$ARTIFACTS_DIR/progress.md` — what previous iterations did (may not exist yet).

## Working directory — read this first

Your **current working directory is the repo worktree** for this run — the
checkout you must edit. Confirm with `pwd`. All code edits, test runs, and
`git` commands happen here, relative to your cwd.

- `$ARTIFACTS_DIR` is a **separate** location holding only `plan.md`,
  `progress.md`, and `incidental-findings.md`. Read and write those files
  there, but **never `cd` into `$ARTIFACTS_DIR` to edit or run code**, and never
  treat it as the repo root.
- Edit only files **under your cwd**. Do **not** reach the repo through any
  other path — no `~/.archon/workspaces/.../source` symlink, no sibling
  worktree, no absolute path outside your cwd. If a file you expect is not under
  your cwd, **stop** and note it in `progress.md` instead of hunting for it
  elsewhere (editing the wrong checkout silently loses the work — the worktree
  this run pushes from is your cwd).

## Do

1. Read `plan.md` and `progress.md`. Pick the **first unchecked** task (`- [ ]`).
2. Implement it with **TDD red-green**:
   - Ensure the task's test from `plan.md` `## Tests` exists in the repo and is
     currently **failing** (red). If the test is not yet written to a file,
     write it exactly as specified — do not weaken it.
   - Write the minimum code to make that test **pass** (green). Run it.
   - For a non-TDD-able task, satisfy the explicit completion check instead.
3. Stay strictly inside `plan.md` `## Scope`. Do not touch anything else. If the
   task seems to need an out-of-scope change, do NOT make it — append a note to
   `$ARTIFACTS_DIR/incidental-findings.md` and stop.
4. Tick the task's box in `plan.md` (`- [ ]` → `- [x]`).
5. **Update `$ARTIFACTS_DIR/progress.md` as you go, not at the end.** Append a
   one-line breadcrumb each time you finish a meaningful step (test written,
   code change applied, test now green, etc.). This way, if the iteration is
   interrupted mid-task by a stream timeout or crash, the next iteration can
   reconstruct in-flight state from progress.md instead of guessing from
   `git diff`. When the task is complete, write a final summary line for it.
6. If — and only if — **every** task box in `plan.md` is now checked, end your
   output with the literal line `<promise>ALL_TASKS_COMPLETE</promise>`.

## Rules

- One task per iteration. Do not run ahead.
- Never weaken, skip, or delete a test to make it pass. The test is the spec.
- Never edit files outside `## Scope`.
- Do not commit or push — later workflow steps handle that.
- On resume after a crash: read `progress.md` carefully. A task may be partially
  done — verify with `git status` / `git diff` before redoing work. Trust
  breadcrumbs in progress.md; do not blindly restart a task that already shows
  test-passing entries.
