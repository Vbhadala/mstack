---
name: mstack-qa
description: |
  Scenario-driven QA testing. Asks the user what to focus on (a feature, a
  user journey, a suspected bug, or "everything"), drives Playwright through
  the relevant flows, captures screenshots and console errors, and writes a
  structured bug report to .mstack/qa/YYYY-MM-DD/. After user approval of the
  fix plan, applies fixes and re-verifies. May edit code, but only after an
  explicit approval gate.
  Use when the user says "qa this", "test the X flow", "find bugs in Y",
  "qa the app", or invokes /mstack-qa.
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

# mstack-qa

Scenario-driven QA: ask focus → test → report → approve → fix → re-verify.

## Resolve project layout

Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh`. It prints the
project's resolved `paths`, `commands`, and a `_resolved` block
(`.mstack/config.json` overrides → auto-detected defaults). The keys this
skill uses:

- `commands.dev` / `commands.build` / `commands.test` — run THESE, not a
  hardcoded `pnpm ...` (e.g. an npm project resolves to `npm run dev`)
- `paths.brandSource` and `conventions.brandStringLiteralRule` — the brand /
  config source and whether to enforce no hardcoded brand strings outside it
- `paths.webApp`, `_resolved.{packageManager,layout}`

**Throughout this skill, treat every `apps/web/...`, `packages/...`,
`src/config/...` path literal — and every `pnpm <script>` command literal —
as the monorepo default. Substitute the resolved `paths.*` / `commands.*`
value for the actual project.** State the detected `layout`/`packageManager`.

## Phase 1 — Ask focus

Use AskUserQuestion to determine scope. Offer common scenarios:

- A specific feature (e.g. "auth", "messages", "admin")
- A specific user journey (e.g. "signup → email verify → first login")
- A suspected bug (e.g. "unread badge stays after opening message")
- The whole app smoke pass

Also ask: which env (the resolved `devUrl` — default `http://localhost:3000`,
Expo `http://localhost:8081` — or a staging URL)? If local, verify the dev
server is up via `curl -sf <devUrl> >/dev/null` — start it with the resolved
`commands.dev` (default `pnpm dev`) only if the user confirms.

## Phase 2 — Test

1. **Initialise the QA directory:** `.mstack/qa/<YYYY-MM-DD-HHMM>/` with
   `report.md` (scaffold below) and `assets/`.

2. **Drive Playwright** using the repo's existing config (`playwright.config.ts`,
   `e2e/`). Prefer writing temporary spec files in `.mstack/qa/<run>/specs/`
   rather than polluting `e2e/`. Run via `npx playwright test --reporter=list`
   pointed at the temporary spec dir.

3. **For each scenario step**, capture:
   - Screenshot to `assets/<step-N>.png`
   - Console errors and network failures (Playwright collects these)
   - Any visual regression (compare to last QA run if assets exist)

4. **Track tasks live** with TaskCreate per scenario step so the user sees
   progress.

5. **Categorise findings** by severity:
   - **critical** — auth broken, data loss, blank screens, crashes
   - **high** — flow can't complete, key feature broken
   - **medium** — UX friction, edge case mishandled, console errors
   - **low** — cosmetic, copy, minor polish

## Phase 3 — Report + approval gate

Write `report.md` with the scaffold below. Then use AskUserQuestion to ask:
"Found N issues (X critical, Y high, …). Approve the fix plan?" Options:

- **Approve all** — fix everything in the report
- **Approve subset** — user picks which severities or specific issues
- **Decline** — stop, leave the report for human follow-up

If declined, exit cleanly with status `report-only`.

## Phase 4 — Fix + re-verify (only if approved)

For each approved issue:

1. TaskUpdate `in_progress`.
2. Make the fix. Honour the project's hard rules from `AGENTS.md` (no raw
   `process.env` or hardcoded brand strings outside the brand/config source —
   `paths.brandSource` and its directory; only enforce the brand-string rule
   when `conventions.brandStringLiteralRule` is set — plus `import
   "server-only"`, Zod boundaries, Drizzle generate-not-push where they apply).
3. Run the resolved `commands.typecheck` (default `pnpm typecheck`) if
   `.ts`/`.tsx` was touched.
4. Re-run the failing scenario via Playwright. If it now passes, mark fixed.
   If not, **pause** (one retry max) and ask the user.
5. Commit per fix using:
   ```
   fix(qa): <issue title>

   Fixes issue N from .mstack/qa/<run>/report.md

   Co-Authored-By: <model> <noreply@anthropic.com>
   ```

   Replace `<model>` with the name of the model you are currently running as
   (e.g. "Claude Fable 5") — never a hardcoded model from this doc.
   Never `--no-verify`. Never amend.
6. Update `report.md` with the fix status (✓ fixed · ⏸ paused · ⊘ deferred).

## Final summary

After fixes (or after a report-only exit), tell the user:

```
QA run complete: <path-to-report.md>
Fixed: N · Paused: N · Deferred: N · Report-only: N
Recommended next step: <if anything paused/deferred> | <if all clean: "ship">
```

**Escalation hook — un-RCA'd issues → /mstack-debug.** If any issue ended
`⏸ paused` or `⊘ deferred` *because root cause wasn't obvious* (not because
the user chose to defer), the "Recommended next step" line MUST suggest:

```
/mstack-debug --from-qa <YYYY-MM-DD-HHMM>
```

This is a *suggestion*, not an auto-spawn — the user invokes it. `/mstack-debug`
will read the issue from this run's `report.md` and do a focused RCA.

Append a learning if anything non-obvious surfaced (e.g. a flaky selector,
a hidden auth requirement). Use `append-learning.sh`.

## report.md scaffold

```markdown
# QA report — <YYYY-MM-DD HH:MM>

**Focus:** <user-provided>
**Env:** <localhost:3000 | staging URL>
**Status:** in_progress | issues_found | clean | partial | report-only
**Tester:** /mstack-qa

## Scenarios run
1. <scenario> — <pass/fail>
2. …

## Issues

### Issue 1: <title>
- **Severity:** critical | high | medium | low
- **Repro:**
  1. …
  2. …
- **Expected:** …
- **Actual:** …
- **Screenshot:** assets/issue-1.png
- **Console errors:** … (or "none")
- **Suspected cause:** … (file:line if known)
- **Fix plan:** …
- **Status:** open | ✓ fixed (commit <sha>) | ⏸ paused | ⊘ deferred

### Issue 2: …

## Summary
N total · X critical · Y high · Z medium · W low
```

## Anti-patterns

- **Don't fix without approval.** The gate is non-negotiable. The report has
  to land first.
- **Don't write specs into `e2e/`.** Use the temporary spec dir under the QA
  run; `e2e/` is for the project's permanent suite.
- **Don't loop on flaky tests.** If a scenario fails inconsistently, mark it
  flaky in the report and ask the user — don't keep retrying.
- **Don't fix beyond the approved scope.** If you spot a bug while fixing
  another, add it to the report and ask, don't sneak it in.
- **Don't bypass hooks.** Same rules as `/mstack-code`.
