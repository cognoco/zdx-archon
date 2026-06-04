---
description: Open a ready (non-draft) pull request for the implemented work item, using the repo's PR template.
argument-hint: (none — reads $ARTIFACTS_DIR artifacts)
---

# zdx-create-pr

The branch is committed and pushed. Open the PR.

## Inputs

- `$ARTIFACTS_DIR/workitem.json` — `id`, `name`, `description`, `acceptanceCriteria`.
- `$ARTIFACTS_DIR/plan.md`, `progress.md`, `adversarial-findings.json` — context.
- `$BASE_BRANCH` — the PR base branch.

## Do

1. Confirm a PR does not already exist for this branch
   (`gh pr list --head "$(git branch --show-current)"`). If it does, capture it
   and skip creation.
2. Find the repo's PR template (`.github/pull_request_template.md`,
   `.github/PULL_REQUEST_TEMPLATE.md`, or `docs/PULL_REQUEST_TEMPLATE.md`). If
   one exists, fill in **every section** from the artifacts — no placeholders.
3. Create a **ready (non-draft)** PR with `gh pr create --base "$BASE_BRANCH"` so
   review bots fire immediately:
   - Title: imperative, under 70 chars.
   - Body: filled template, or — if no template — summary / changes / validation
     evidence. Reference the work item: include `Refs: <WI-ID>` (the work item is
     closed by a human review gate, so do **not** use `Closes`).
   - Write the PR body to a file under `$ARTIFACTS_DIR/` (never inside the
     worktree) if you use `--body-file`.
4. Record the PR URL: `gh pr view --json url -q .url > "$ARTIFACTS_DIR/pr-url.txt"`.

## Rules

- Ready PR, not draft.
- Do not merge. Do not close the work item.
