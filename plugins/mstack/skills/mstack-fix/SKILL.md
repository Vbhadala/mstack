---
name: mstack-fix
description: |
  The single front door for bug fixes. Quick lane: bounded root-cause look,
  minimal fix, same-session verification, one commit — with hard escalation
  triggers as the safety mechanism (size budget exceeded, schema/deps/brand
  layer touched, or cause not evident → route to /mstack-debug or
  /mstack-plan instead of pushing through). Consumes verified debug reports
  via --from-debug, using their failing spec as the acceptance criterion.
  Edits code; writes a short fix report to .mstack/fixes/.
  Use when the user says "fix this", "X is broken", "quick fix", "hotfix",
  or invokes /mstack-fix. For feature-scale changes → /mstack-plan; for
  broad testing → /mstack-qa.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Bash
  - AskUserQuestion
---

# mstack-fix

Quick-fix lane: intake → scope gate → bounded look → fix → verify → commit
→ report. **The size budget is the safety mechanism** — this lane is fast
*because* anything that doesn't fit it escalates. Escalating is success,
not failure.

**Narration:** one short line per phase — the fix report carries the record.

## Resolve project layout

Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh`. Keys this skill
uses: `conventions.{hardRules,orm,tokenDrift}`, `commands.{typecheck,test,dev}`,
`devUrl`, `paths.todos`, `_resolved.{layout,packageManager}`.

## Intake

Two paths:

- **Plain description** ("login button broken on Safari") → collect via
  AskUserQuestion only what's missing: symptom, how to reproduce, expected
  vs actual. One batch, skip questions the user already answered.
- **`--from-debug <slug>`** → read `.mstack/debug/<slug>/report.md`
  (must have `Status: ready-for-fix`). The report's **Fix plan** is your
  instruction and its failing spec at `.mstack/debug/<slug>/specs/` is your
  acceptance criterion. Skip the bounded look — the cause is already
  verified.

Initialise `.mstack/fixes/<YYYY-MM-DD-HHMM-slug>.md` (scaffold below).

## Scope gate (before ANY edit)

Check the escalation triggers. ANY match → stop, set the report's Status
to `escalated`, record what you found, and route:

| Trigger | Route |
|---|---|
| Fix needs >3 source files (tests excluded) | `/mstack-plan` — that's a change, not a fix |
| Schema / migration change required | `/mstack-plan` (destructive risk needs review) |
| New dependency required | `/mstack-plan` |
| Brand/design token layer (`paths.brandSource`/`designTokens`/`globalsCss`) | `/mstack-design-system` or `/mstack-plan` |
| CI config, env-var renames, auth/payment/security-critical logic | `/mstack-plan` |
| Root cause not evident after the bounded look (below) | `/mstack-debug` — pass the report path; your findings become its head start |
| Can't reproduce at all | `/mstack-debug` (or stop and ask the user) |

The gate re-applies DURING the fix: if the edit starts sprawling past a
trigger mid-flight, stop and escalate — sunk work is not a reason to
continue.

## Bounded look (skip when `--from-debug`)

Reproduce the bug with the lightest tool that works (`curl` against
`devUrl`, an existing test, a manual check the user confirms). Then a
**bounded** root-cause look: start at the symptom location, follow the
code path, form ONE hypothesis. Budget: roughly one focused pass — if
you're opening file after file or on your second hypothesis, the cause is
"not evident": escalate to `/mstack-debug`. No fix without a reproduced
bug and a named cause.

## Fix

Honor the same authority order as `/mstack-code`: resolved
`conventions.hardRules` verbatim → `AGENTS.md`/`CLAUDE.md` rules → ORM
discipline per `conventions.orm` (a schema change already escalated at the
gate, so this mostly means: don't hand-edit generated files) → template
defaults where the project uses them. Minimal diff: fix the cause, touch
nothing else.

## Verify (same-session evidence, all that apply)

1. Re-run the reproduction → the bug must be gone.
2. `--from-debug` → run the debug run's failing spec → must now pass.
3. `.ts`/`.tsx` touched → resolved `commands.typecheck`.
4. A test covers the touched code → run that test (not the whole suite).
5. Styles/UI touched and `conventions.tokenDrift` != `off` → run
   `${CLAUDE_PLUGIN_ROOT}/shared/bin/check-token-drift.sh <files touched>`;
   `warn` findings go in the report, `block` findings fail verification.

One fix attempt + one retry max. A second verification failure means the
cause wasn't what you thought → escalate to `/mstack-debug`.

**Evidence rule:** every claim in the report cites the command run in THIS
session and its result. An unreproduced bug is an unverifiable fix.

## Commit (one commit)

```
fix(<scope>): <symptom, imperative>

Root cause: <one line>. Fix report: .mstack/fixes/<slug>.md

Co-Authored-By: <model> <noreply@anthropic.com>
```

Replace `<model>` with the model you are currently running as. Never
`--no-verify`; a hook failure is a signal — stop and ask. Never push —
that's the user's call (or `/mstack-ship`).

## Report + close the loop

Fill the scaffold; then append any adjacent-bug or follow-up to the
backlog (`${CLAUDE_PLUGIN_ROOT}/shared/bin/append-todo.sh "fix <slug>"
"<item>"`) and a learning if the cause was a gotcha worth remembering
(`append-learning.sh`). Tell the user: status, commit, evidence, and — if
escalated — the exact next command.

```markdown
# Fix — <symptom one-liner>

**Started:** YYYY-MM-DD HH:MM
**Source:** <user-report | debug/<slug>>
**Status:** fixed | escalated | aborted
**Commit:** <sha or —>

## Symptom / repro
<what + how reproduced>

## Root cause
<one paragraph — or, if escalated: what the bounded look ruled out>

## Fix
<files touched + what changed, in prose>

## Evidence
- repro re-run: <command → result>
- <typecheck/test/spec/drift: command → result>

## Escalation (if Status: escalated)
**Trigger:** <which row of the scope gate>
**Route:** /mstack-debug | /mstack-plan | /mstack-design-system
**Handed over:** <findings the next skill should start from>

## Follow-ups
<appended to TODOS, or "none">
```

## Red flags — you are rationalizing

| Thought | Reality |
|---|---|
| "Just one more file and I'm done" | The budget exists because spirals are invisible from inside. 4th file = escalate. |
| "I almost see the cause — one more grep" | The bounded look expired. /mstack-debug exists precisely for this. |
| "The schema tweak is really part of this fix" | Schema = pipeline. That's the gate, not a judgment call. |
| "The fix is obvious, I'll skip reproducing" | Unreproduced bug = unverifiable fix. Reproduce first, always. |
| "The drift warning is pre-existing noise" | New lines are yours. Fix them or record why not in the report. |
| "While I'm here, this function could be cleaner" | Refactors ride the pipeline. Minimal diff, one cause, one commit. |

## Anti-patterns

- **Don't investigate past the bounded look.** Deep RCA is `/mstack-debug`'s
  job — it has the Iron Law and the failing-test discipline; you don't.
- **Don't batch multiple bugs into one run.** One symptom per fix run; the
  second bug goes to TODOS or its own run.
- **Don't edit tests to make them pass.** If a test disagrees with your
  fix, your cause was wrong — escalate.
- **Don't treat escalation as failure.** A 10-minute escalation with clean
  findings beats a 2-hour wrong fix. The report's `escalated` status is a
  first-class outcome.
- **Don't push, don't merge.** Commit locally only.
