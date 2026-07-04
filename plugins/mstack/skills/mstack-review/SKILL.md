---
name: mstack-review
description: |
  Review a plan doc produced by /mstack-plan and convert it into an approved
  implementation plan that /mstack-code can execute autonomously. Reads the most
  recent plan in .mstack/plans/ (or a user-specified one), critiques it against
  project conventions and the existing codebase, raises blockers/concerns, locks
  decisions with the user, then writes .mstack/reviews/YYYY-MM-DD-<slug>.md
  with an ordered task list. No code edits.
  Use when the user says "review the plan", "review my plan", or invokes
  /mstack-review. Errors clearly if no plan exists.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# mstack-review

Review a `/mstack-plan` output and produce an approved implementation plan in
`.mstack/reviews/YYYY-MM-DD-<slug>.md`. No code edits.

## Resolve project layout

Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh`. It prints the
project's resolved `paths`, `commands`, and a `_resolved` block
(`.mstack/config.json` overrides → auto-detected defaults). The keys this
skill uses:

- `paths.webApp` [monorepo default `apps/web`; flat `.`] — web-app paths and
  route globs are relative to this
- `paths.brandSource` / `paths.designTokens` and
  `conventions.brandStringLiteralRule` — the rebrand layer and its rule
- `conventions.serviceLayer`, `conventions.apiPrefix`
- `commands.*`, `_resolved.{packageManager,layout}`

**Throughout this skill, treat every `apps/web/...`, `packages/...`, or
`src/config/...` path literal — and every `pnpm <script>` command literal —
as the monorepo default. Substitute the resolved `paths.*` / `commands.*`
value for the actual project** (e.g. route globs `apps/web/src/app/**` become
`<paths.webApp>/src/app/**`). State the detected `layout` to the user.

## Steps

1. **Find the plan.** Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/find-latest-plan.sh`
   (errors if `.mstack/plans/` is empty). Show the user the path + first few
   lines and confirm: "Review this plan?" If they say no or pass a path arg,
   use that path instead.

2. **Read the plan + codebase context** in parallel:
   - The plan doc itself
   - `CLAUDE.md`, `AGENTS.md` for hard rules
   - The specific files the plan says it'll touch (existing ones, via Read)
   - Sibling files in `src/features/` if the plan adds a new feature module
   - `src/config/` if the plan touches brand/design/env
   - `paths.prd` if the file exists — check the plan against the PRD's
     non-goals and personas; a plan that contradicts a non-goal is a Blocker
     until the user resolves it (change the plan or update the PRD)

3. **Critique the plan.** Check for:
   - **Scope clarity** — are in/out lists explicit and tight?
   - **project convention fit** — respects `src/config/` (no hardcoded brand strings),
     `src/features/` removability rule, `import "server-only"` for server code,
     Zod at boundaries, Drizzle generate-not-push, etc. (see `AGENTS.md`).
   - **Edge cases** — auth states, empty states, network failures, idempotency
     for emails/webhooks, concurrent edits.
   - **Acceptance criteria** — checkable? specific? testable?
   - **Files to touch** — does the list match what the approach actually requires?
     Anything missing (migrations, env vars, docs)?
   - **New deps** — any? flagged?
   - **Open questions** — resolvable now, or should they block?

4. **Raise blockers and concerns** with the user via AskUserQuestion. Loop until
   no blockers remain. Concerns get a decision recorded; suggestions get taken
   or explicitly deferred.

5. **Generate the implementation plan.** Convert the approved plan into an
   ordered task list. Each task is:
   - Atomic (one commit's worth of change)
   - Has Files / What / Acceptance fields
   - Optionally has a **Pause if** trigger — list specific situations where
     `/mstack-code` must escalate instead of guessing (e.g. "Pause if migration
     would require dropping a column with data")
   - Ordered so each task leaves the codebase in a working state if possible

5b. **Compute the `UI-Significant` flag.** Walk the task list's `Files` fields
    and apply the heuristic:

    The change is **UI-Significant: yes** when the implementation plan touches
    **any** of:

    - `apps/web/src/app/**/page.tsx` (route page added or modified)
    - `apps/web/src/app/**/layout.tsx`
    - `apps/web/src/features/*/components/**/*.tsx`
    - `apps/web/src/components/**/*.tsx` (excluding `marketing/*` — that's
      content, not UI shell)
    - Any **new** route under `apps/web/src/app/`
    - `<paths.mobileApp>/app/**/*.tsx` (Expo Router screen added or modified;
      when the layout is `expo`, the glob is `app/**/*.tsx` at repo root)
    - `<paths.mobileApp>/src/components/**/*.tsx`

    …**AND** either (a) the count of such files is **≥3**, OR (b) any file in
    the set is a **new** `page.tsx` or a **new** Expo Router screen.
    Otherwise **UI-Significant: no**.

    This flag is the single source of truth for the optional `/mstack-mockup`
    gate in the main chain — `/mstack-auto` and the manual chain both read it.

6. **Write the review doc** using the template at
   `${CLAUDE_PLUGIN_ROOT}/shared/templates/review.md`. Filename matches the plan
   slug (e.g. plan `2026-05-12-billing-portal.md` → review
   `2026-05-12-billing-portal.md`). Populate the `UI-Significant` frontmatter
   field with the value from step 5b.

7. **Update the plan's status** from `draft` to `reviewed` via Edit.

8. **Append learnings** if the review surfaced something non-obvious — a
   constraint discovered while reading code, a deviation from project defaults,
   a rejected approach worth remembering. Use
   `${CLAUDE_PLUGIN_ROOT}/shared/bin/append-learning.sh`.

8b. **Capture deferrals.** Every Concern decided as "defer" and every
    Suggestion explicitly deferred goes to the backlog:
    `${CLAUDE_PLUGIN_ROOT}/shared/bin/append-todo.sh "review <slug>" "<item>"`.
    A deferral that lives only inside the review doc is a lost work item.

9. **Hand off** based on `UI-Significant`:
   - If `yes`: tell the user "Review written to <path>. Recommended next:
     `/mstack-mockup --from-review <slug>` to explore designs before code, or
     `/mstack-code` to skip straight to implementation."
   - If `no`: tell the user "Review written to <path>. Run /mstack-code next."

## What "Pause if" should capture

`/mstack-code` runs autonomously. The **Pause if** field is the safety net for
situations where you'd want a human in the loop:

- Destructive migrations (drop column, drop table, type change with data loss)
- Decisions that affect shared infra (CI config, deploy config, env vars in prod)
- Acceptance criteria that turn out ambiguous when you actually try to write
  the test
- New top-level deps not pre-approved in the plan
- Touching `src/config/brand.ts` or `src/config/design.ts` (rebrand layer)

If a task has none of these risks, omit the field — the task runs without
interruption.

## Anti-patterns

- **Don't write code.** Review only. If you'd reach for Edit on a `src/` file,
  stop and put it in the implementation plan instead.
- **Don't approve a plan with vague acceptance criteria.** Push back until each
  criterion is checkable. This is the #1 failure mode of `/mstack-code`.
- **Don't silently rewrite the plan.** Surface every change as a Concern with
  a recorded decision, even if obvious.
- **Don't skip reading the actual codebase.** A plan can claim "edit
  `src/features/foo/bar.ts`" but the file's structure may force a different
  approach. Read first, critique with evidence.
- **Don't accept new deps without flagging.** this project prefers boring deps; new
  ones need a Concern + decision in the review.
