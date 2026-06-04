---
description: File new ZDX work items for incidental issues discovered during execution.
argument-hint: (none — reads $ARTIFACTS_DIR/incidental-findings.md)
---

# zdx-incidental-workitems

During execution, issues unrelated to the work item were noticed and recorded.
File the genuine ones by invoking the **`/zdx:capture`** capability — this node does
not create Cosmo rows itself (ZDX-ADR-0003 reuse contract: capture owns intake, incl.
dedup + soft-DoR; this node only decides _which_ findings are worth filing).

## Inputs

- `$ARTIFACTS_DIR/incidental-findings.md` — recorded incidental issues.
- `$ARTIFACTS_DIR/workitem.json` — the originating work item (`id`, `pageId`).

## Do

1. Read `incidental-findings.md`. For each entry, judge: is this a _real, worth
   tracking_ issue? Discard noise, duplicates, and anything already covered. (Capture
   runs its own dedup downstream, but don't file obvious non-issues.)
2. Compose the kept set as a **capture input array** and write it to
   `$ARTIFACTS_DIR/capture-input.json` — one object per item, linking each back to the
   originating work item via `related_items`:
   ```json
   [
     {
       "name": "<imperative title>",
       "type": "Bug|Incident|Feature|Enhancement|Task|Spike|Design|Hygiene|Documentation",
       "priority": "P0|P1|P2|P3",
       "description": "<one-liner: what + why>",
       "acceptanceCriteria": "<what done looks like, if known>",
       "related_items": ["<origin WI-NN from workitem.json .id>"]
     }
   ]
   ```
3. Invoke capture headlessly (it creates each item at the Captured stage, runs dedup,
   links the origin, and posts soft-DoR diagnostics):
   ```bash
   bun ~/.archon/scripts/zdx-capture.js \
     --in-file  "$ARTIFACTS_DIR/capture-input.json" \
     --out-file "$ARTIFACTS_DIR/capture-results.json" \
     --origin-wi "<origin WI-NN from workitem.json .id>"
   ```
   Run from the target repo root (capture reads its `zdx-config.yaml` + token from cwd).
4. Read `$ARTIFACTS_DIR/capture-results.json` and report each created item: its `WI-NN`
   (`wi_id`) + name, whether it was `auto_linked` to an existing item (`dedup.action`),
   and any `dor_diagnostics`. A non-zero exit means at least one row `failed` — surface
   the `error` for those.

## Rules

- Only file real, trackable work. When in doubt, leave it out — `Captured` items are
  cheap to add but noise pollutes triage.
- These are _incidental_ finds from execution. PR-review leftovers are handled
  separately by `zdx-ci-review`; do not duplicate them here.
- Do not write to Cosmo directly from this node. Capture is the single intake path; if
  it lacks something you need, that's a change request against `/zdx:capture`
  (ZDX-ADR-0003 grey-zone ladder), not a local reimplementation here.
