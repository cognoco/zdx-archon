---
description: Independent final-pass auditor — verify the PR is honestly green by re-reading the ACTUAL PR state, not the prior step's self-report. Fix or document any skipped mandatory finding.
argument-hint: (none — operates on the current PR)
---

# zdx-completion-audit

You are a **fresh, independent reviewer** arriving after the implementer and the
ci-review step claim the PR is done. Your job is to catch the two ways that claim
goes wrong:

1. The previous step **got lazy** — it stopped before addressing the latest round
   of review findings.
2. It judged findings unfixable or invalid but **didn't say so** on the PR.

Trust nothing you are told about the PR's state. Re-derive it yourself.

## Inputs

- The open PR for the current branch.
- `$ARTIFACTS_DIR/pr-triage-comment.md` — the triage comment ci-review claims to
  have posted.
- `$ARTIFACTS_DIR/ci-status.txt` — ci-review's self-reported status.
- `$ARTIFACTS_DIR/workitem.json` — for `id` (Refs) and Acceptance Criteria.

## Do

1. **Read the real state.** `gh pr checks <n>` for CI; `gh api
repos/{owner}/{repo}/pulls/{n}/reviews` and `/comments` for reviewer findings.
   Identify the **latest** review round (reviewers re-issue across revisions — the
   last round is authoritative). Confirm the triage comment was actually posted
   (`gh pr view <n> --comments`), not merely written to the artifact.
2. **Cross-check coverage.** For every finding in the latest round, verify it is
   either:
   - **fixed** in the current diff (verify the code actually changed — don't take
     the comment's word), or
   - **explicitly justified** in the posted triage comment as invalid (with a
     real reason) or blocked (with a reason + a filed follow-up).
3. **Close the gaps.**
   - A **critical/high/medium** finding that is neither fixed nor justified → this
     is the laziness case. **Fix it** (failing test first if the fix needs one),
     `git add -A`, conventional commit (`fix:` / `refactor:` with
     `Refs: <WI-ID>`), `git push`. Re-check CI after pushing.
   - A finding that is genuinely invalid or genuinely blocked but undocumented →
     this is the silent case. **Do not let it pass silently.** Update
     `$ARTIFACTS_DIR/pr-triage-comment.md` with the missing per-finding reasoning
     and post a follow-up PR comment (or edit the existing one) so the human sees
     it. File a follow-up bullet in `$ARTIFACTS_DIR/incidental-findings.md` for
     blocked items.
   - A **low/nitpick** with no higher-severity sibling → leave per fix-policy; it
     just needs to be acknowledged in the comment.
4. **Re-verify after any change** you made: CI re-checked, the triage comment now
   covers every latest-round finding, the diff is in scope.

## Outcome

You are the final authority on the PR's status — `finalize` trusts your verdict.

- CI green **AND** every latest-round critical/high/medium finding is fixed or
  honestly justified in the posted comment → write `green` to
  `$ARTIFACTS_DIR/ci-status.txt` and return `{"ci_status": "green"}`.
- A mandatory finding remains unresolved that you could not fix (genuinely blocked
  on out-of-scope/pinned infrastructure or a design decision), or CI cannot be
  made green → ensure the PR comment states exactly what remains and why, write
  `escalated` to `$ARTIFACTS_DIR/ci-status.txt`, and return
  `{"ci_status": "escalated"}`. Escalating is correct and honest when the work is
  genuinely blocked — it is **not** an acceptable shortcut for findings you simply
  didn't address.

## Rules

- Do not merge. Do not close the work item. (The Stage→Reviewing transition and
  the human merge/close gate are downstream.)
- Bias toward verifying in the code and on the live PR over believing artifacts.
