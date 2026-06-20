---
name: mstack-auto
description: |
  Chains /mstack-plan → /mstack-review → /mstack-code into one pipeline. Pauses
  at two gates (after plan, after review) for the user to confirm — fast path
  is "looks good, continue?" → "yes". Each underlying skill writes its normal
  artifacts to .mstack/, so a /mstack-auto run is identical in output to running
  the three skills manually. Use when you want one-command flow from idea to
  shipped code.
  Use when the user says "auto", "plan and ship X", "do the whole flow",
  "/mstack-auto", or describes a feature and wants to skip the manual handoffs.
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

# mstack-auto

Chain: `/mstack-plan` → gate A → `/mstack-review` → gate B → *(optional gate C
when UI-significant)* `/mstack-mockup` → `/mstack-code`.

This skill orchestrates — it does not duplicate logic. Each underlying skill
runs as if invoked directly, with its full behaviour and artifact output.

**Not included by design:** `/mstack-research` and `/mstack-debug` are user-
triggered, never chained from `/mstack-auto`. Research is an optional upstream
step (run before `/mstack-auto` if the feature needs a tech-choice decision);
debug is a separate reactive flow that feeds `/mstack-code` directly.
`/mstack-ux-audit` is a post-ship polish step, never auto-chained.

## Pre-flight

1. Verify git state up front (same checks as `/mstack-code`):
   - Branch is not `main`/`master`
   - Working tree is clean
   Abort early if either fails — better than discovering it after a plan is
   written.

2. Use AskUserQuestion to collect the feature brief in one shot:
   - **Feature** — what is being built?
   - **Persona** — who is it for?
   - **Wedge** — what user pain does it solve?
   - **Out of scope** — explicit non-goals?
   - **Constraints** — deadline, must-not-break?

   This pre-loads everything `/mstack-plan` would otherwise ask for, so the
   first phase runs without further interruption.

## Step 1 — Plan

Invoke the `/mstack-plan` flow with the pre-collected brief. The plan doc
lands in `.mstack/plans/<slug>.md`.

**Gate A** — show the user the plan path and a one-paragraph summary. Ask:

- **Continue** — proceed to review
- **Edit and continue** — open the plan, ask what to change, edit, then proceed
- **Stop** — exit cleanly; the plan stays for manual `/mstack-review` later

## Step 2 — Review

Invoke the `/mstack-review` flow on the plan from Step 1 (skip the
"find latest plan" step — pass the path directly). Reviews are inherently
interactive (blockers/concerns/decisions surface mid-flow); let those run as
normal — don't try to suppress them.

**Gate B** — show the user the review path and a summary (N tasks, any
deferred concerns). Ask:

- **Continue** — proceed to Gate C (if UI-significant) or Step 3
- **Stop** — exit cleanly; the review stays for manual `/mstack-code` later

## Step 2b — Optional mockup gate (UI-significant only)

Read the `UI-Significant` field from the review doc's frontmatter.

- If `UI-Significant: no` → skip silently, proceed to Step 3.
- If `UI-Significant: yes` → fire **Gate C**:

**Gate C** — show the user the count of UI files touched and which routes are
affected. Ask:

- **Mockup first** — invoke `/mstack-mockup --from-review <slug>`; when mockup
  finishes (winner selected, `FEEDBACK.md` written), resume to Step 3.
- **Skip mockup, go to Code** — proceed to Step 3 directly.
- **Stop** — exit cleanly; both review and (if produced) mockup stay for
  manual continuation.

## Step 3 — Code

Invoke the `/mstack-code` flow on the review from Step 2 (pass the path
directly). Pauses inside `/mstack-code` (acceptance failures, "Pause if"
triggers) surface to the user as normal.

## Final summary

When `/mstack-code` completes, summarise the whole run:

```
mstack-auto complete
  Plan:    .mstack/plans/<slug>.md
  Review:  .mstack/reviews/<slug>.md
  Code:    .mstack/code/<slug>/report.md
  Commits: N · Tasks done: N/M · Paused: N · Skipped: N
  Recommended next step: /mstack-qa with focus on <area>
```

## Anti-patterns

- **Don't reimplement the underlying skills.** `/mstack-auto` only adds the
  brief-collection up front and the two gates. All actual work goes through
  `/mstack-plan`, `/mstack-review`, `/mstack-code` so improvements there flow
  here automatically.
- **Don't skip the gates** even when the user says "just go". The plan and
  review are cheap to glance at, and gate A in particular catches
  misunderstandings before any code is touched. If the user wants fully
  unattended, that's a future `/mstack-yolo` — not this skill.
- **Don't include `/mstack-qa` in the chain.** QA is scenario-driven; it needs
  user input on focus and is best run as a deliberate next step.
- **Don't run if the working tree is dirty** or the branch is `main`/`master`.
  Fail fast in pre-flight, not three skills deep.
