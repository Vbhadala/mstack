# Review: {{FEATURE_NAME}}

**Date:** {{DATE}}
**Slug:** {{SLUG}}
**Plan reviewed:** [{{PLAN_FILENAME}}](../plans/{{PLAN_FILENAME}})
**Status:** approved
**UI-Significant:** {{UI_SIGNIFICANT}}
**Reviewer:** {{AUTHOR}}

---

## Summary

One paragraph: is the plan ready to implement, and what changed during review?

## Findings

What the review surfaced. Group by severity. Drop sections that are empty.

### Blockers (must fix before /mstack-code)
-

### Concerns (raised, decided, recorded)
- **Concern:** …
  **Decision:** …

### Suggestions (taken or deferred)
-

## Decisions locked

Net new decisions made during review (beyond what was in the plan):

-

## Implementation plan

Ordered tasks for `/mstack-code` to execute top-to-bottom. Each task is atomic
(reviewable as a single commit). `/mstack-code` runs autonomously but pauses if
a task lists a **Pause if** trigger that matches the situation.

### Task 1: {{TASK_NAME}}

- **Files:** `path/to/file.ts` (new) · `path/to/other.ts` (edit)
- **What:** what changes, in 1–3 sentences
- **Acceptance:** how to know it's done (specific, checkable)
- **Pause if:** (optional) ambiguity trigger — leave out if none

### Task 2: …

## Open questions

Anything still unresolved that `/mstack-code` should escalate, not guess.

-
