# `zdx/` — the `execute-workitem` Archon workflow (zdx-archon fork)

Source-of-truth for the ZDX `execute-workitem` workflow: it takes one ZDX work
item from **Cosmo** (the estate's Notion-resident work-item system), drives it to
a green PR, and keeps the item's lifecycle correct (claim → Executing → Reviewing
+ completion summary). This is *deploy source* — `deploy.sh` installs it into
**global** `~/.archon/` (execute-workitem runs against arbitrary target repos),
not the fork's repo-local `.archon/`.

## Layout

```
workflows/execute-workitem.yaml   The 18-node DAG.
commands/zdx-*.md                 The AI node instructions (plan, implement,
                                  adversarial-review, …).
scripts/zdx-*.{ts,sh}             Deterministic steps — scope guard, validation,
                                  push, summary, setup, tracing.
deploy.sh                         Copies the above into ~/.archon/, and bundles
                                  the two lib-dependent scripts (zdx-cosmo = Notion
                                  I/O, zdx-capture) from the cosmo marketplace
                                  plugin (see below).
```

The Notion I/O (`zdx-cosmo`) and capture scripts are **not** stored here — their
canonical homes are the `cosmo` marketplace plugin (`skills/execute/execute.ts`,
`skills/capture/capture.ts`), each beside the shared `lib/` it imports. `deploy.sh`
`bun build`s them straight from `$ZDX_MARKETPLACE_HOME` (default:
`~/.claude/plugins/marketplaces/zdx-marketplace`), keeping one canonical lib.

## Deploy

```bash
./deploy.sh
archon validate workflows execute-workitem
```

## Run

```bash
# from inside the target repo:
archon workflow run execute-workitem --branch wi/<WI-NN> "<WI-NN | Notion URL>"
```

## Requirements on the target repo

- A `zdx-config.yaml` with `work-items.database_id` / `data_source_id` and a
  `zdx.validate.command` key (the repo's test/lint/typecheck command).
- `NOTION_TOKEN` available in the environment (or a project `.env`).
- `gh` authenticated for the repo.

## Status

v1 draft — design + requirements live in the **nexus** repo under
`_WIP/zdx-productionization/` (`execute-workitem-design.md`,
`execute-workitem-requirements.md`). Not yet validated or run end-to-end.
