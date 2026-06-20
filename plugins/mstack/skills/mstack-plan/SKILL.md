---
name: mstack-plan
description: |
  Interactive consultation skill for planning a feature in your app project.
  Reads existing codebase context, asks about persona/wedge/scope, proposes
  approaches with tradeoffs, and writes a structured plan doc to .mstack/plans/
  that /mstack-review can consume next. No code edits.
  Use when the user says "plan a feature", "let's design X", "I want to add Y",
  or invokes /mstack-plan.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Bash
  - AskUserQuestion
---

# mstack-plan

Consult the user on a new feature, then write a structured plan doc to
`.mstack/plans/YYYY-MM-DD-<slug>.md`. No code edits.

## Resolve project layout

Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh`. It prints the
project's resolved `paths`, `commands`, and a `_resolved` block
(`.mstack/config.json` overrides → auto-detected defaults). The keys this
skill uses:

- `paths.webApp` [monorepo default `apps/web`; flat `.`] — source dirs like
  `src/features/`, `src/lib/`, `src/config/` are under this
- `conventions.serviceLayer`, `conventions.apiPrefix`,
  `conventions.brandStringLiteralRule`
- `_resolved.{packageManager,layout,hasMobile}`

**Throughout this skill, treat every `apps/web/...`, `packages/...`, or
`src/...` path literal — and every `pnpm <script>` command literal — as the
monorepo default. Substitute the resolved `paths.*` / `commands.*` value for
the actual project.** State the detected `layout` to the user; let it shape
where you propose new code lives.

## Steps

1. **Read context** (in parallel):
   - `CLAUDE.md`, `AGENTS.md`, `README.md` if they exist
   - `src/` top-level layout via Glob
   - Any existing plan docs in `.mstack/plans/` (so we don't duplicate)
   - `.mstack/design-system/DESIGN.md` if present (so the plan respects
     locked design decisions). If the feature is UI-heavy and no
     `DESIGN.md` exists, suggest `/mstack-design-system` first.

2. **Ask the user** (one batch via AskUserQuestion):
   - **Persona** — who is this for?
   - **Wedge** — what's the specific user pain this solves?
   - **Out of scope** — what are we explicitly NOT doing?
   - **Constraints** — deadline, must-not-break, deps to avoid?

3. **Propose 2–3 approaches** with tradeoffs. Reference existing patterns from
   `src/features/`, `src/lib/`, `src/config/`. Lock one with the user.

4. **Write the plan doc** using the template at
   `${CLAUDE_PLUGIN_ROOT}/shared/templates/plan.md`. Slug format:
   `YYYY-MM-DD-<lowercase-hyphen-slug>.md` (e.g. `2026-05-12-billing-portal.md`).

5. **Append a learning** if something non-obvious came up (a constraint
   discovered, a rejected approach worth remembering, a deviation from project
   defaults). Use `${CLAUDE_PLUGIN_ROOT}/shared/bin/append-learning.sh`.

6. **Hand off**: tell the user "Plan written to <path>. Run /mstack-review next."

## Plan doc shape

The template includes these sections — keep all of them, even if a section is
"none":

- **Problem** — user pain, who benefits
- **Scope (in / out)** — explicit lists
- **Approach** — chosen path + tradeoffs vs alternatives
- **Data model changes** — tables, columns, migrations
- **Files to touch** — new vs edit
- **Edge cases** — what could go wrong
- **Acceptance criteria** — checkable boxes
- **Open questions** — for the reviewer

## Anti-patterns

- **Don't write code.** This skill is consultation only. If the user pushes,
  remind them: "/mstack-code does the implementation after /mstack-review."
- **Don't skip context-reading.** Plans for your app must respect
  `src/config/` (rebrand layer), `src/features/` (removable modules), and the
  hard rules in `AGENTS.md` (no raw `process.env`, `import "server-only"`, etc.).
- **Don't ship vague acceptance criteria.** If you can't write checkable boxes,
  ask more questions.
- **Don't propose new top-level deps without flagging it.** this project prefers boring
  deps; new ones need explicit user buy-in.
- **Don't propose a session-level advisory lock through a pooler.**
  `pg_try_advisory_lock` + PgBouncer (Neon, Supabase poolers, etc.) is a
  documented anti-pattern: if the lock-holding process dies before its
  `finally`-unlock runs, the pooler keeps the backend session alive and the
  lock is held indefinitely, bricking subsequent deploys. Use
  `pg_advisory_xact_lock` (transaction-scoped, auto-released by COMMIT /
  ROLLBACK) or trust deploy serialization (Replit Reserved VM serializes
  per app). See [ADR 0008](../../../docs/decisions/0008-codebase-conventions.md)
  + [TEMPLATE.md #19](../../../docs/template/TEMPLATE.md).
