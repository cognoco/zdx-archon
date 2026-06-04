---
description: Write the work item's completion summary, ready to be posted to Notion.
argument-hint: (none — reads $ARTIFACTS_DIR artifacts)
---

# zdx-compose-summary

Write the completion summary for the work item. A later deterministic step
posts it into Notion and transitions the item to `Stage=Reviewing`.

## Inputs

All of `$ARTIFACTS_DIR/`: `workitem.json`, `plan.md`, `progress.md`,
`adversarial-findings.json`, `pr-url.txt`, `ci-status.txt`,
`incidental-findings.md`, `incidental-items.json` (some may be absent).

## Do

Write `$ARTIFACTS_DIR/completion-summary.md` in exactly this shape (the
`work-lifecycle` template):

```markdown
**What was done:**
<Concise description of the work performed, tied to the Acceptance Criteria.>

**What changed:**
<Files, configs, services affected.>

**Verification:**
<Concrete evidence — tests run and their result, the adversarial-review
outcome, the PR URL, and the final CI status. "Tests pass" is not evidence;
"<repo validate command> green; PR <url>; CI green" is.>

**Caveats / Follow-ups:**
<Known limitations. If CI was escalated (ci-status.txt = escalated), say so
explicitly and state what a human needs to look at. List any new work items
filed for incidental findings, by WI-NN + name.>
```

## Rules

- Be specific and honest. This summary is what the human reviewer reads at the
  review gate.
- If `ci-status.txt` is `escalated`, the Caveats section must lead with that.
- Do not transition the work item or write to Notion — that is the next step.
