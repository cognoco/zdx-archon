---
description: Fix the findings raised by the adversarial review. Precise, spec-driven — no judgement calls.
argument-hint: (none — reads $ARTIFACTS_DIR/adversarial-findings.json)
---

# zdx-address-findings

The adversarial review found defects. Fix them — exactly, and only them.

## Inputs

- `$ARTIFACTS_DIR/adversarial-findings.json` — the findings array.
- `$ARTIFACTS_DIR/plan.md` — the `## Scope` you must stay within.

## Do

1. Read `adversarial-findings.json`.
2. Fix **every critical, high, and medium** finding. Apply each `suggested_fix`
   at its `location`; if the suggested fix is wrong, fix the underlying `claim`
   correctly.
3. Fix `low` findings too while you are here — they are cheap now.
4. When a fix needs a test, follow TDD: failing test first, then the fix.
5. Stay strictly inside `plan.md` `## Scope`. If a finding genuinely cannot be
   fixed within scope, append it to `$ARTIFACTS_DIR/incidental-findings.md` and
   leave it.

## Rules

- This is a precise spec, not an open task — implement the findings, nothing more.
- Never weaken a test to make it pass.
- Do not commit or push — later workflow steps handle that.
