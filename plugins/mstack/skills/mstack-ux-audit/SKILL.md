---
name: mstack-ux-audit
description: |
  Audit a live UI screen (or set of screens) against the project's design tokens,
  hierarchy, spacing, typography, accessibility, copy clarity, flow friction,
  and AI-slop patterns. Drives Playwright to capture screenshots at desktop
  and mobile, writes a structured report to .mstack/ux-audits/, then after
  user approval applies fixes and re-verifies. May edit code, but only after
  an explicit approval gate.
  Use when the user says "ux audit the X page", "audit the experience",
  "polish the UI", "review how this looks/reads", or invokes /mstack-ux-audit.
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

# mstack-ux-audit

User-centric UX audit (visual + copy + flow + accessibility): capture →
review → report → approve → fix → re-verify.

## Resolve project layout

Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh`. It prints the
project's resolved `paths`, `commands`, and a `_resolved` block
(`.mstack/config.json` overrides → auto-detected defaults). The keys this
skill uses:

- `paths.designTokens` [monorepo default `packages/config/src/design.ts`]
- `paths.brandSource` [default `packages/config/src/brand.ts`]
- `conventions.brandStringLiteralRule` — whether to enforce brand strings only in the brand source

**Throughout this skill, treat every `src/config/...`, `packages/config/...`,
or `apps/web/...` path literal — and every `pnpm <script>` command literal —
as the default. Substitute the resolved `paths.*` / `commands.*` value for the
actual project.** State the detected `layout` to the user.

## Phase 1 — Scope

Use AskUserQuestion:

- **Screens** — list of routes/URLs to review (e.g. `/dashboard`, `/messages`)
  or "all main screens" (auto-discovers via `src/app/(app)/**/page.tsx`)
- **Env** — localhost or deployed URL
- **Auth state** — anonymous, logged-in (Playwright will need a fixture or
  manual session — ask which)
- **Focus** — full audit, or a specific dimension (spacing only, hierarchy
  only, accessibility only)

If localhost, verify the dev server is up; offer to start it.

## Phase 2 — Capture

Initialise `.mstack/ux-audits/<YYYY-MM-DD-HHMM>/` with `report.md` and
`assets/`.

For each screen:

- Screenshot at desktop (1440×900) → `assets/<screen>-desktop.png`
- Screenshot at mobile (390×844) → `assets/<screen>-mobile.png`
- Pull the rendered DOM and computed styles for the main content region
  (Playwright's `page.evaluate`) — needed for spacing/hierarchy analysis
  without re-reading source

## Phase 3 — Review

Read once, in parallel:

- `src/config/design.ts` — the source-of-truth tokens
- `src/app/globals.css` — CSS variables
- `src/lib/ui/` — base primitives (EmptyState, LoadingState, ErrorState,
  DataList)
- The screen's source (`src/app/.../page.tsx`, plus referenced components)

Critique each screen against:

| Dimension | What to check |
|---|---|
| **Tokens** | Hardcoded hex/px? Should be tokens. |
| **Spacing** | Inconsistent gaps? Mismatch with token scale? |
| **Hierarchy** | Heading levels logical? Visual weight matches importance? |
| **Typography** | Font sizes/weights from the scale? Line-length readable? |
| **Color contrast** | WCAG AA min on text? Token combinations meet it? |
| **States** | Loading/empty/error states present? Use the lib/ui primitives? |
| **Responsive** | Mobile screenshot survives? Tap targets ≥44px? |
| **Slop patterns** | Generic "modern dashboard" tropes? Trust-fall gradients? Stock illustrations? Random emoji? |
| **Brand fidelity** | Brand name + tagline used per `src/config/brand.ts`? |
| **Copy clarity** | CTAs verb-led ("Start free trial", not "Click here")? Jargon minimised? Error messages tell the user what to do next? |
| **Flow friction** | Dead-ends visible from this screen (no obvious next action)? Primary path requires more clicks/decisions than necessary? |

For each issue, capture: screen, dimension, severity (critical/high/medium/low),
suspected file:line, and a concrete fix.

## Phase 4 — Report + approval gate

Write `report.md` (scaffold below). Then ask via AskUserQuestion:
"Found N issues (X critical, Y high, …). Approve the fix plan?" Options:
**Approve all · Approve subset · Decline (report-only)**.

## Phase 5 — Fix + re-verify (only if approved)

Per issue:

1. TaskUpdate `in_progress`.
2. Apply the fix. Honour the project's hard rules. Prefer touching component code over
   page code; prefer adding a token over hardcoding.
3. Re-screenshot the affected screen at desktop + mobile, save to
   `assets/<screen>-desktop-after.png` etc.
4. Eyeball-compare before/after; if the fix didn't land visually, **pause**
   (one retry max).
5. Commit:
   ```
   style(design): <issue title>

   Addresses issue N from .mstack/ux-audits/<run>/report.md

   Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
   ```
   Never bypass hooks. Never amend.
6. Update `report.md` with status (✓ fixed · ⏸ paused · ⊘ deferred) and the
   after-screenshot path.

## Pause-if triggers (always pause)

- Edits to `src/config/brand.ts` or `src/config/design.ts` (rebrand layer —
  flag as a token change, ask the user)
- New top-level deps (icon libs, animation libs)
- Restructuring a route or layout (that's `/mstack-plan` territory, not a
  design fix)
- Accessibility fix that requires a behavioural change beyond markup/styles
  (route to `/mstack-plan`)

## Final summary

```
UX audit complete: <path-to-report.md>
Fixed: N · Paused: N · Deferred: N · Report-only: N
```

Append a learning for any pattern observation (e.g. "lib/ui DataList missing
empty-state slot — recurring need").

## report.md scaffold

```markdown
# UX audit — <YYYY-MM-DD HH:MM>

**Scope:** <screens reviewed>
**Env:** <localhost:3000 | URL>
**Status:** in_progress | issues_found | clean | report-only
**Reviewer:** /mstack-ux-audit

## Screens
| Screen | Desktop | Mobile |
|---|---|---|
| /dashboard | assets/dashboard-desktop.png | assets/dashboard-mobile.png |

## Issues

### Issue 1: <title>
- **Screen:** /dashboard
- **Dimension:** spacing | hierarchy | tokens | typography | contrast | states | responsive | slop | brand | copy | flow
- **Severity:** critical | high | medium | low
- **Where:** src/features/foo/Bar.tsx:42 (suspected)
- **Observation:** what's wrong (with screenshot ref if helpful)
- **Fix:** concrete change
- **Status:** open | ✓ fixed (commit <sha>, after: assets/dashboard-desktop-after.png) | ⏸ paused | ⊘ deferred

### Issue 2: …

## Summary
N total · X critical · Y high · Z medium · W low
```

## Anti-patterns

- **Don't fix without approval.** Report lands first, gate is non-negotiable.
- **Don't add new design tokens silently.** Token additions go through
  `/mstack-plan` (they affect every fork via the rebrand layer).
- **Don't restructure layout** in this skill. That's a feature change, not a
  visual fix.
- **Don't use stock decoration** (emoji, generic illustrations) when fixing.
  If a screen needs imagery, flag it for `/mstack-mockup`.
- **Don't bypass hooks.** Same rules as `/mstack-code`.
