---
description: Drive the PR to green — watch CI and external code review, fix findings under the ZDX fix-policy, iterate up to 5 passes.
argument-hint: (none — operates on the current PR)
---

# zdx-ci-review

Drive the open PR to **green**. Iterate **internally up to 5 passes** — do not
exceed five.

## Each pass

1. **Read state:** `gh pr checks` for CI; fetch external code-review findings
   (`gh api repos/{owner}/{repo}/pulls/{n}/reviews` and `/comments`). Review bots
   vary by repo — Claude Code, Codex, Kilo, CodeRabbit.
2. **Assess validity.** Code reviewers are noisy and will surface something new
   on every pass. Do not take findings at face value — for each, decide if the
   claim is _real_. Reject the invalid ones (no fix, no work item).
3. **Apply the fix-policy** to the valid findings:
   - **critical / high / medium → always fix.**
   - **low / nitpick → fix only if a higher-severity fix is already in this
     batch.** A lone low → leave it.
   - Fixing needs a test → TDD: failing test first.
4. **Commit + push** the fixes: `git add -A`, a conventional commit
   (`fix: …` / `refactor: …`) with `Refs: <WI-ID>` from `workitem.json`, then
   `git push`.
5. Re-check on the next pass.

## Green

**Green** = the main CI check passes **AND** the reviewers can only produce lows
or nitpicks (every critical/high/medium has been fixed or validly rejected).
Realistically reviewers never go fully silent — green is "nothing mandatory left."

## Latest-round coverage (do this before you decide the outcome)

You may **not** declare an outcome until you have accounted for every finding in
the **latest** review round. Re-fetch the current state one final time
(`gh pr checks`, `gh api …/reviews`, `…/comments`) — reviewers re-issue findings
across revisions, so the last round is the one that counts. For each finding in
that latest round, it must end in exactly one of three states, with a reason:

- **fixed** — you changed code; name what.
- **invalid** — the claim is not real; say why in one or two sentences.
- **blocked** — real but not fixable inside this work item's scope (e.g. it
  requires a coupled change to pinned infrastructure or a design decision); say
  why, and append a follow-up bullet to `$ARTIFACTS_DIR/incidental-findings.md`.

A finding that is neither fixed nor explicitly justified is **not** accounted
for — keep working. Skipping the last round because you "already fixed enough"
is the failure this step exists to prevent.

## Residual findings

For **valid** findings you did not fix (lows/nitpicks with genuine merit), make
an educated judgement call: append the worthwhile ones to
`$ARTIFACTS_DIR/incidental-findings.md` so they become tracked work items.
**Rejected/invalid findings get nothing** — no fix, no work item.

## Final triage comment (MANDATORY — always post, green or escalated)

Before returning, post **one** comment to the PR
(`gh pr comment <n> --body-file $ARTIFACTS_DIR/pr-triage-comment.md`) that gives a
human reviewer everything they need to finish the review without re-deriving your
reasoning. Write the body to `$ARTIFACTS_DIR/pr-triage-comment.md` first (never
inside the worktree), then post it. Structure:

```markdown
## Final triage of automated review findings

<Reviewers + verdicts (e.g. "claude-review and CodeRabbit: APPROVED_WITH_ISSUES,
0 blocking"). Explicit CI status: which checks pass / skip and why.>

<Numbered, per-finding triage for EVERY finding in the latest round — each marked
**fixed** / **invalid (why)** / **blocked (why + the follow-up WI you filed)**.
Be specific: reference the file, the reviewer, and what you did or why you didn't.>

### Definition of done

Per the PR's DoD — CI green + no valid critical/high/medium findings remaining —
<state explicitly whether it holds, and if escalated, exactly what remains and why.>
```

This comment is the honest handoff. It is **not** a substitute for fixing: a
finding you _could_ fix but merely described here is a failure. The
`completion-audit` step independently re-reads the real PR state and this comment
to verify coverage.

## Outcome

- Green reached (latest round fully accounted for, nothing mandatory left) →
  post the triage comment, write `green` to `$ARTIFACTS_DIR/ci-status.txt`,
  return `{"ci_status": "green"}`.
- Not green after 5 passes → **stop**. Post the triage comment (clearly stating
  what remains and why), write `escalated` to `$ARTIFACTS_DIR/ci-status.txt`,
  leave the PR for a human, return `{"ci_status": "escalated"}`.
