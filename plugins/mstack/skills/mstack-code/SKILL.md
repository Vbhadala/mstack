---
name: mstack-code
description: |
  The only mstack skill that edits code. Consumes an approved review from
  /mstack-review and executes the implementation plan autonomously, one atomic
  commit per task. Pauses on ambiguity (destructive migrations, brand/design
  layer changes, new deps, failing acceptance criteria). Writes a task ledger
  and run log to .mstack/code/<slug>/ so a partial run can be
  resumed by re-invoking on the same review.
  Use when the user says "implement the plan", "run the implementation",
  "code it", or invokes /mstack-code. Errors clearly if no approved review
  exists.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Bash
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# mstack-code

Execute an approved implementation plan from `/mstack-review`. Autonomous by
default; pauses only when a task hits a real ambiguity. One atomic commit
per task.

## Pre-flight (must pass before any code edits)

1. **Find the review.** Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/find-latest-review.sh`
   (errors if `.mstack/reviews/` is empty). Show path + first few lines and
   confirm: "Implement this review?" If user passes a path arg, use it instead.

2. **Check review status.** Open the review and verify the frontmatter `Status`
   is `approved`. If not, abort with a message asking the user to finish
   `/mstack-review` first.

3. **Check git state.**
   - Current branch must NOT be `main` or `master`. Abort if it is — ask the
     user to create a feature branch.
   - Working tree must be clean. Abort if dirty — ask the user to commit or
     stash.

4. **Initialise the implementation directory.** Create
   `.mstack/code/<review-slug>/` with:
   - `tasks.md` — task ledger (template below)
   - `log.md` — empty, appended to as the run progresses
   - If the directory already exists with an in-progress `tasks.md`, treat this
     as a **resume**: confirm with the user before continuing.

5. **Register tasks** with TaskCreate — one task per implementation-plan entry
   from the review. This gives the user live progress visibility.

## Per-task loop

For each task in order:

1. Mark TaskUpdate `in_progress`. Update `tasks.md` to `[~]` for this task.

2. **Read the files involved** before editing — the review's "Files" list is a
   hint, not a complete read. Sibling files often matter too.

3. **Check the Pause if trigger.** If the task lists a `Pause if` condition
   and the situation matches, **pause now** (jump to "Pause handling" below)
   before making edits.

4. **Make the edits.** Follow the task's `What`. Honor the project's hard rules from
   `AGENTS.md`:
   - No raw `process.env` outside `src/config/env.ts`
   - No hardcoded brand strings outside `src/config/`
   - `import "server-only"` in `lib/db`, `lib/email`, `features/*/server/`
   - Zod at all boundaries (Server Actions, route handlers)
   - Drizzle: schema change → `db:generate` migration; never `db:push`

5. **Verify acceptance.** Run the relevant checks:
   - If task touched `.ts`/`.tsx` → `npm run typecheck`
   - If task added a Drizzle schema change → `npm run db:generate` and confirm
     a migration was produced
   - If the task's `Acceptance` field references a specific test → run it
   - Do NOT run e2e/Playwright (that's `/mstack-qa`'s job)

6. **If verification fails**, treat it as ambiguity → pause (see below).
   Don't loop indefinitely on the same fix.

7. **Commit.** One commit per task. Message format:

   ```
   <type>(<scope>): <task name>

   Implements task N/M from .mstack/reviews/<slug>.md

   Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
   ```

   Type and scope follow the existing repo convention (look at `git log`).
   **Never bypass hooks** (`--no-verify`). If a hook fails, that's a signal —
   pause and ask the user.

8. Mark TaskUpdate `completed`. Update `tasks.md` to `[x]` with the commit SHA.
   Append a one-line entry to `log.md`.

## Pause handling

When a task pauses:

1. Append a detailed entry to `log.md` (what was attempted, what blocked).
2. Update `tasks.md` to `[!]` for this task.
3. Use AskUserQuestion to surface the situation with three options:
   - **Continue with guidance** — user provides a hint, you retry the task
   - **Skip this task** — mark `[-]`, continue to next task
   - **Abort the run** — write the report and stop
4. Record the user's decision in `log.md`.

## Pause-if triggers (defaults — the review can list more)

These always cause a pause, regardless of what the review says:

- Destructive migrations (drop column with data, drop table, type narrowing)
- Edits to `src/config/brand.ts` or `src/config/design.ts` (rebrand layer)
- New top-level deps not pre-approved in the plan or review
- Changes to CI config (`.github/`, `lefthook.yml`)
- Changes to env vars (adding required ones to `.env.example` is fine; renaming
  or removing is a pause)
- Acceptance criterion that turns out unverifiable when you try to write the check

## Final report

When the loop ends (complete, aborted, or all-paused-then-stopped), write
`.mstack/code/<slug>/report.md` with:

- **Status** — complete | partial | aborted
- **Tasks** — table: `✓ done` / `⏸ paused` / `⊘ skipped`, each with commit SHA
  if any
- **Commits** — list with SHAs and one-line messages
- **Follow-ups** — what didn't get done, what needs human attention
- **Recommended next step** — usually `/mstack-qa` with focus area

Then:

- Update the plan's status from `reviewed` → `implemented` (Edit the plan doc).
- Append learnings (`${CLAUDE_PLUGIN_ROOT}/shared/bin/append-learning.sh`) for
  anything non-obvious surfaced during the run.
- Tell the user: "Implementation report at <path>. N commits. Run /mstack-qa
  next."

## tasks.md template (write this in step 4 of pre-flight)

```markdown
# Implementation: <feature>

**Started:** YYYY-MM-DD HH:MM
**Review:** [<slug>](../../reviews/<slug>.md)
**Branch:** <branch>
**Status:** in_progress

---

## Legend
- `[ ]` pending  ·  `[~]` in_progress  ·  `[x]` done
- `[!]` paused (awaiting decision)  ·  `[-]` skipped

## Tasks

- [ ] **Task 1:** <name>
  - Files: <from review>
  - Commit: —
  - Notes: —

- [ ] **Task 2:** …
```

## Gotchas to watch for

- **After deleting an app-router `page.tsx`,** run `rm -rf apps/web/.next`
  before `pnpm typecheck`. Stale `.next/types/validator.ts` files import the
  now-missing `page.js` and `tsc` fails until `.next` is cleared. (Surfaced
  on BetFrnd 2026-05-13; see [ADR 0008](../../../docs/decisions/0008-codebase-conventions.md).)

## Anti-patterns

- **Don't run e2e/Playwright tests.** That's `/mstack-qa`'s job.
- **Don't bypass hooks.** `--no-verify` is forbidden. Hook failures are
  signals — pause.
- **Don't amend commits across tasks.** Each task = one new commit. Pre-commit
  hook failure → fix and create a NEW commit, not `--amend` (the previous
  task's commit must stay intact).
- **Don't batch tasks into one commit** to "save time." Atomic commits are the
  whole point — they're how the review surface stays useful.
- **Don't push.** This skill creates commits locally only. Pushing is the
  user's call (or a future `/mstack-ship`).
- **Don't loop on a failing verification.** One retry max, then pause.
- **Don't skip the resume check.** If `.mstack/code/<slug>/` exists
  with in-progress tasks, ask before clobbering or resuming.
