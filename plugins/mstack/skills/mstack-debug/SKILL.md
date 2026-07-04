---
name: mstack-debug
description: |
  Reactive debugging: reproduce a reported bug, find the root cause, write a
  failing test that proves the hypothesis, and produce a fix proposal that
  /mstack-code can consume. Never edits source code. Reads from a /mstack-qa
  report when `--from-qa <run>` is passed.
  Use when the user says "debug this", "X is broken", "users report Y", "500
  on Z", "investigate this bug", or invokes /mstack-debug. For broad scenario
  testing → /mstack-qa instead.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Bash
  - AskUserQuestion
  - WebSearch
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# mstack-debug

Reactive RCA for a specific reported bug. Five phases: reproduce → investigate
→ verify hypothesis → propose fix → approval gate. **No source code edits.**
Output goes to `.mstack/debug/<YYYY-MM-DD-HHMM-slug>/` and is consumed by
`/mstack-code`.

## Iron Law

**No fix proposal without a verified root cause.** The artifact that proves
understanding is a failing test that pinpoints the *cause*, not the symptom.
If you cannot write that test, you have not understood — keep investigating
or pause and ask the user.

## Phase 1 — Reproduce

1. **Source the bug report.** Three paths:
   - `--from-qa <run>` arg → read the issue list from
     `.mstack/qa/<run>/report.md` and ask the user which issue to debug.
   - Plain `/mstack-debug` with a description → ask the user (AskUserQuestion)
     for: symptom, repro steps, expected vs actual, env (localhost / staging),
     any console error or stack trace.
   - User pastes a stack trace → extract file:line, ask for repro context if
     unclear.

2. **Initialise the debug directory.**
   `.mstack/debug/<YYYY-MM-DD-HHMM-<slug>>/` with:
   - `report.md` (scaffold below)
   - `assets/` (screenshots, console logs)
   - `specs/` (failing repro test will land here in Phase 3)

3. **Verify dev env.** If repro needs the local server: run
   `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh`, then
   `curl -sf <devUrl> >/dev/null` — start the resolved `commands.dev` only
   with user confirmation.

4. **Reproduce the bug.** Use the simplest tool that does it:
   - HTTP-only bug → `curl` is enough
   - UI/JS bug → write a one-off Playwright spec under `specs/repro.spec.ts`
     and run via `npx playwright test specs/repro.spec.ts --reporter=list`
   - Capture: screenshot to `assets/`, console errors, network failures, stack
     trace. **If you cannot reproduce, stop and ask the user** — do not guess.

5. Mark TaskCreate `reproduced` with the captured artifact paths.

## Phase 2 — Investigate

**Iron Law applies.** Form one hypothesis at a time and disprove it before
moving to the next.

1. Read the code involved — start from the symptom location (stack trace, the
   component the user named), follow imports/calls outward. Use Grep for
   shared utilities, types, env reads.
2. Trace the data flow end-to-end (input → action → DB → response → render).
3. Note suspicious code paths but **don't propose fixes yet** — log
   observations as bullet points in `report.md` under `## Investigation`.
4. If the bug touches an unfamiliar lib, use WebSearch — but every external
   fact carries a URL + date checked in the report.
5. Pause and ask the user if:
   - The bug spans more than ~5 files and no single hypothesis fits
   - You'd need to make a destructive read (e.g. inspect prod DB rows)
   - The repro depends on data the user has but you don't

## Phase 3 — Verify hypothesis

**This is the artifact that proves understanding.**

1. Write a *minimal* failing test under `.mstack/debug/<slug>/specs/` that
   exercises the hypothesised cause directly — not the symptom.
   - Unit-level cause → a small `.test.ts` calling the function with the
     failure-triggering input.
   - Integration cause → Playwright spec exercising the specific code path.
   - The test must fail *for the hypothesised reason* (assertion that names
     the cause), not just "page didn't load".
2. Run it. Confirm it fails with the predicted error.
3. **If the test does not fail as predicted**, the hypothesis is wrong. Loop
   back to Phase 2. Do not paper over by editing the assertion.
4. Once the cause is locked, mark TaskCreate `hypothesis-verified`.

## Phase 4 — Propose fix

Write `.mstack/debug/<slug>/report.md` (scaffold below). The fix plan must
include:

- **What to change** — file paths + the change in prose (not a diff).
- **Why it fixes the cause** — one line linking the change to the failing
  assertion.
- **Project hard-rule reminders** for `/mstack-code` if relevant: quote the
  resolved `conventions.hardRules` entries that apply, plus the ORM
  discipline for `conventions.orm` (drizzle: generated migrations, never
  `db:push`; prisma: `prisma migrate dev`, never `db push`), plus any
  template defaults the project actually uses (`server-only` imports, Zod at
  boundaries, brand-string rule).
- **Acceptance criteria** — exactly two:
  1. Run the failing spec at `.mstack/debug/<slug>/specs/repro.spec.ts` → must
     pass.
  2. Re-run the original repro (manual or Playwright) → must not reproduce
     the symptom.
- **Out-of-scope** — note any adjacent bugs you spotted but are NOT proposing
  to fix (avoid scope creep into `/mstack-code`).

## Phase 5 — Approval gate

AskUserQuestion with three options:

- **Run /mstack-code on this debug doc** — exits the skill; user invokes
  `/mstack-code .mstack/debug/<slug>/report.md` next.
- **Hand to me for manual fix** — exits; user takes it from here.
- **Investigate further** — loop back to Phase 2 with user-provided hint.

**Never edit source code.** That is `/mstack-code`'s sole job. This skill ends
with the report written and `report.md` `Status:` set to one of
`ready-for-code | manual | reopened`.

Append a learning via `${CLAUDE_PLUGIN_ROOT}/shared/bin/append-learning.sh` if
the RCA surfaced something non-obvious (a hidden coupling, a stale cache, a
framework gotcha).

## report.md scaffold

```markdown
# Debug — <symptom one-liner>

**Started:** YYYY-MM-DD HH:MM
**Source:** <user-report | qa/<run>#issue-N>
**Env:** <localhost | staging>
**Status:** investigating | hypothesis-verified | ready-for-code | manual | reopened
**Investigator:** /mstack-debug

## Symptom

<what the user sees / what's broken>

## Repro

1. …
2. …

**Expected:** …
**Actual:** …
**Artifact:** assets/repro.png, assets/console.log

## Investigation

- Observation 1 (file:line)
- Observation 2
- …

## Root cause

<one paragraph naming the cause — not the symptom>

**Failing test:** specs/repro.spec.ts — asserts <X> which fails because <Y>.

## Fix plan (for /mstack-code)

**Files to change:**
- `path/to/file.ts` — <what change, in prose>

**Why it fixes the cause:** <one line>

**Hard-rule reminders:** <only the relevant ones>

**Acceptance:**
1. `npx playwright test .mstack/debug/<slug>/specs/repro.spec.ts` passes
2. Original repro no longer reproduces the symptom

**Out of scope:** <adjacent bugs spotted but not in this fix>

## External references (if any)

- <url> — checked YYYY-MM-DD — <one-line summary>
```

## Anti-patterns

- **Don't propose a fix without the failing test.** No test = no understanding.
- **Don't edit source code.** Even "tiny" edits. Hand off to `/mstack-code`.
- **Don't run the project's permanent e2e suite** for repro. Write a focused
  spec under `specs/` and run only that.
- **Don't expand scope.** If you find a second bug, note it in the report's
  out-of-scope section, capture it via
  `${CLAUDE_PLUGIN_ROOT}/shared/bin/append-todo.sh "debug <slug>" "<bug>"`,
  and ask the user — don't chase it.
- **Don't fix in `e2e/`.** The repro spec belongs under `.mstack/debug/<slug>/specs/`,
  not in the project's permanent suite.
- **Don't loop in Phase 2** for more than ~5 dead-end hypotheses. Pause and
  ask the user.
- **Don't trust LLM-cached knowledge** for library behaviour. Every external
  fact in the report carries a URL + date.
- **Don't bypass hooks.** Same rules as `/mstack-code` — except this skill never
  commits anything, so the rule is moot here.
