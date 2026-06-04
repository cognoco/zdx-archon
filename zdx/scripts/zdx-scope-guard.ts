#!/usr/bin/env bun
/**
 * zdx-scope-guard.ts <artifacts-dir> [base-branch]
 *
 * Hard stop on file drift: every file changed in this worktree must match a
 * glob in plan.md's `## Scope` → `In scope:` list. Out-of-scope changes mean
 * the implementation strayed beyond the plan — fail the run.
 *
 * Exit 0 = all changes in scope. Exit 1 = drift (lists the offending files).
 */
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { execSync } from 'node:child_process';

const artifactsDir = process.argv[2];
const base = process.argv[3] || 'main';
if (!artifactsDir) {
  console.error('usage: zdx-scope-guard.ts <artifacts-dir> [base-branch]');
  process.exit(1);
}

const planPath = join(artifactsDir, 'plan.md');
if (!existsSync(planPath)) {
  console.error('zdx-scope-guard: plan.md not found');
  process.exit(1);
}

// Extract glob lines under "## Scope" → "In scope:".
const plan = readFileSync(planPath, 'utf8');
const scopeSection = plan.split(/^##\s+/m).find(s => /^scope/i.test(s)) ?? '';
const inScope = scopeSection.split(/in scope:/i)[1]?.split(/out of scope:/i)[0] ?? '';
// Strip the list bullet, then any surrounding markdown inline-code backticks.
// LLM-generated plans idiomatically format paths as `path/to/file`; without
// this, the backticks become part of the glob and never match the real path
// (every changed file would falsely report as out-of-scope drift).
const globs = inScope
  .split('\n')
  .map(l =>
    l
      .replace(/^\s*[-*]\s*/, '')
      .trim()
      .replace(/^`+|`+$/g, '')
      .trim()
  )
  .filter(l => l && !l.startsWith('#'));

if (!globs.length) {
  console.error('zdx-scope-guard: plan.md declares no `In scope:` globs — cannot enforce scope');
  process.exit(1);
}

const sh = (c: string) => {
  try {
    return execSync(c, { encoding: 'utf8' });
  } catch {
    return '';
  }
};

// Resolve the diff base. Prefer `git merge-base HEAD origin/<base>` over the
// raw `<base>` ref — the local `<base>` branch can drift behind origin while a
// workflow is running (the team merges upstream PRs), which would otherwise
// make `git diff <base>...HEAD` include commits that landed on origin AFTER
// this worktree branched, producing false "out-of-scope" reports.
//
// merge-base is also stable under upstream fast-forwards: as origin/<base>
// advances, the merge-base stays at the commit this worktree branched from,
// so this is correct even if upstream moves DURING the run.
//
// Best-effort: silent fetch first so origin/<base> is fresh; fall back to the
// raw <base> ref if no origin remote / no origin/<base> / fetch unavailable.
sh('git fetch origin --quiet');
const mergeBase = sh(`git merge-base HEAD origin/${base}`).trim();
const diffBase = mergeBase || base;
if (mergeBase) {
  console.log(
    `zdx-scope-guard: diffing HEAD against merge-base ${mergeBase.slice(0, 7)} (vs origin/${base})`
  );
} else {
  console.log(
    `zdx-scope-guard: no origin/${base} merge-base resolvable; falling back to local ref '${base}'`
  );
}

// Collect every changed/untracked file in the worktree.
const changed = new Set<string>();
for (const c of [
  `git diff --name-only ${diffBase}...HEAD`,
  'git diff --name-only',
  'git diff --name-only --cached',
  'git ls-files --others --exclude-standard',
])
  sh(c)
    .split('\n')
    .map(f => f.trim())
    .filter(Boolean)
    .forEach(f => changed.add(f));

// Literal-first short-circuit: Bun.Glob treats `[...]` as a character class,
// so a literal scope entry like `apps/.../quiz/[roundId].tsx` (Expo Router
// dynamic-route convention) would NEVER match the file of that exact name.
// Check literal equality first; fall back to glob matching for true patterns.
const literalScope = new Set(globs);
const matchers = globs.map(g => new Bun.Glob(g));
const drift = [...changed].filter(f => !literalScope.has(f) && !matchers.some(m => m.match(f)));

if (drift.length) {
  console.error(`zdx-scope-guard: ${drift.length} file(s) changed outside plan.md scope:`);
  drift.forEach(f => console.error(`  - ${f}`));
  console.error(`declared scope:\n${globs.map(g => `  - ${g}`).join('\n')}`);
  process.exit(1);
}
console.log(`zdx-scope-guard: OK — ${changed.size} changed file(s), all in scope`);
