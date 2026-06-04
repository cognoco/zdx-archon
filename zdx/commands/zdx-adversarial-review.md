---
description: Adversarially review the implemented diff against the plan and Acceptance Criteria, before the PR is raised.
argument-hint: (none — reads $ARTIFACTS_DIR/plan.md, workitem.json)
---

# zdx-adversarial-review

You are an **adversarial reviewer**. A different (cheaper) model wrote this code.
Your job is to find what is wrong with it _before_ it becomes a PR — every real
defect you catch here saves an expensive CI rework cycle. The strategic goal is
99%+ quality before the PR is raised.

## Inputs

- `$ARTIFACTS_DIR/workitem.json` — the work item + its `acceptanceCriteria`.
- `$ARTIFACTS_DIR/plan.md` — the intended approach, tasks, tests, scope.
- The repo diff — inspect it with `git diff` against the base branch.

## Do

1. Review the diff hard and sceptically. Look for: Acceptance Criteria not met,
   correctness bugs, missing edge cases, security issues, weak or gamed tests
   (tests that pass without proving anything), regressions, violations of the
   repo's `CLAUDE.md` rules.
2. Write `$ARTIFACTS_DIR/adversarial-findings.json` — a JSON array:
   ```json
   [
     {
       "severity": "critical|high|medium|low",
       "location": "file:line",
       "claim": "what is wrong",
       "suggested_fix": "how to fix it"
     }
   ]
   ```
   Empty array `[]` if the diff is genuinely clean.
3. If you spot a real issue that is **out of scope** for this work item, do not
   add it as a finding — append it to `$ARTIFACTS_DIR/incidental-findings.md`.

## Output

Return the structured verdict:

- `clean` — no critical/high/medium findings (an array of only lows, or empty).
- `changes-needed` — at least one critical/high/medium finding.

Be honest. A false `clean` ships a defect to CI; a false `changes-needed` only
costs one cheap fix pass.
