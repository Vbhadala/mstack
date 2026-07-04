---
name: mstack-init
description: |
  Onboard a repo onto mstack. Scans the codebase (layout, package manager,
  ORM, dev URL, Expo presence), confirms or corrects the detection with the
  user, and writes a minimal .mstack/config.json containing only the
  overrides that differ from auto-detection. Then detects or constructs the
  product docs — PRD, ROADMAP, TODOS — adopting existing files in place via
  config paths rather than moving them. Safe to re-run: diffs and confirms
  before changing anything. Never edits source code.
  Use when the user says "set up mstack", "onboard this repo", "init
  mstack", "adopt mstack here", or invokes /mstack-init.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# mstack-init

Onboard the current repo: detect → confirm → minimal config → product docs.
Writes only under `.mstack/` (plus an optional `AGENTS.md` stub). Never
edits source code.

## Phase 0 — Mode

- No `.mstack/config.json` → **fresh init**.
- `.mstack/config.json` exists → **refresh**: re-run detection, diff against
  the existing config, propose only the changes. Never silently overwrite.

## Phase 1 — Scan (no questions yet)

1. Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh` and keep the
   full JSON — this is the auto-detected baseline every later diff is
   computed against.
2. Read in parallel: root `package.json` (plus workspace `package.json`s if
   monorepo), `CLAUDE.md`, `AGENTS.md`, `README.md`.
3. Detect existing product docs — check these locations in order, first hit
   wins:
   - **PRD:** `.mstack/product/PRD.md`, `PRD.md`, `docs/PRD.md`, `docs/prd.md`
   - **Roadmap:** `.mstack/product/ROADMAP.md`, `ROADMAP.md`, `docs/ROADMAP.md`,
     `roadmap.md`
   - **Todos:** `.mstack/TODOS.md`, `TODOS.md`, `TODO.md`, `BACKLOG.md`
4. Gather hard-rule candidates: imperative lines from `AGENTS.md`/`CLAUDE.md`
   ("never …", "always …", "must …"), plus rules implied by the stack (ORM
   migration discipline is already covered by `conventions.orm` — don't
   duplicate it as a hardRule).

## Phase 2 — Confirm detection (one AskUserQuestion batch)

First show a detection summary table in plain text: layout, packageManager,
ORM, devUrl, hasMobile/hasExpo, and the key paths — each marked ✓ (confident)
or ? (guessed). Then ask only what is uncertain or consequential:

- **Detection correct?** — "all correct" / "fix some fields" (collect
  corrections as free text)
- **Dev URL** — confirm the default or provide the real one
- **Hard rules** — multi-select from the Phase 1 candidates + free text for
  extras. Selected entries become `conventions.hardRules`.

## Phase 3 — Product docs

For each of PRD / Roadmap / Todos, resolve one of three outcomes:

- **Existing file found** → adopt it in place: record its path in
  `paths.{prd,roadmap,todos}`. Never move or rewrite the user's file.
- **Missing → construct** (user opted in).
- **Missing → skip** — a first-class answer; leave the default path, move on.
  A one-off bugfix engagement doesn't need a PRD.

Ask once (single AskUserQuestion batch, one question per missing doc):
"No PRD/roadmap/todos found — construct it, or skip?"

Constructing:

- **PRD** — draft from the codebase BEFORE asking: routes/screens → feature
  list, DB schema → domain model, README → positioning. Then one question
  batch: audience/personas, top 1–3 problems solved, explicit non-goals.
  Write `.mstack/product/PRD.md` from
  `${CLAUDE_PLUGIN_ROOT}/shared/templates/prd.md` with every placeholder
  filled; unknowns become explicit `TBD` lines, never invented facts.
- **Roadmap** — one question: "What's Now / Next / Later? (rough list is
  fine)". Seed `## Shipped` with the major features already visible in the
  codebase. Write `.mstack/product/ROADMAP.md` from
  `${CLAUDE_PLUGIN_ROOT}/shared/templates/roadmap.md`.
- **Todos** — no interview. Create `.mstack/TODOS.md` containing only the
  standard header (the same one `append-todo.sh` writes):

  ```markdown
  # TODOS

  Captured work items — deferred review concerns, out-of-scope bugs, skipped
  tasks, ideas. One line each. Prune freely. `/mstack-plan` reads this before
  planning; check items off with a pointer to the plan that absorbed them.
  ```

## Phase 4 — Write the config

Compute the **minimal override set**: diff the user-confirmed values against
the Phase 1 auto-detected baseline and keep ONLY keys that differ, plus
adopted product-doc paths and any `hardRules`. Prepend
`"$schema": "<${CLAUDE_PLUGIN_ROOT}/mstack.schema.json resolved to a
relative or absolute path>"` only if the user wants editor validation —
otherwise omit it.

- Everything matched detection and no hard rules were added → say "detection
  is fully correct — no config file needed" and write nothing.
- Fresh init → Write `.mstack/config.json`.
- Refresh → show the JSON diff, confirm via AskUserQuestion, then Edit.

Then re-run `resolve-config.sh` and echo the resolved summary — proof the
config round-trips (and catches any `unknown config key` warning
immediately).

## Phase 5 — AGENTS.md stub (optional)

If neither `AGENTS.md` nor `CLAUDE.md` exists, offer to write a ~20-line
`AGENTS.md`: project one-liner, resolved layout/commands, the confirmed hard
rules. Decline is fine — this is the only write outside `.mstack/`.

## Phase 6 — Hand off

Summarise: detection results, config path (or "no config needed"), product
docs adopted / created / skipped, hard-rule count. Recommended next step:

- Repo has no `.mstack/plans/` yet → "Run `/mstack-plan` for your first
  feature."
- Otherwise → "Run `/mstack-status` any time to see pipeline state."

## Anti-patterns

- **Don't write a config that mirrors auto-detection.** Only overrides. A
  fat config freezes future detection improvements out of the repo.
- **Don't move or rewrite existing PRD/roadmap/todo files.** Adopt them
  where they live via `paths.*`.
- **Don't interrogate.** Three question batches maximum (detection, product
  docs, PRD interview). Every question must change what gets written.
- **Don't edit source code.** `.mstack/` plus the optional `AGENTS.md` stub
  is the entire write surface.
- **Don't fabricate PRD content.** Draft from the codebase, confirm with the
  user; unknowns stay as explicit `TBD` lines.
- **Don't duplicate the ORM rule into hardRules.** `conventions.orm` already
  carries it; hardRules is for rules detection can't infer.
