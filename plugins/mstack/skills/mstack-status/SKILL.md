---
name: mstack-status
description: |
  Show where every feature is in the mstack pipeline. Runs a deterministic
  scan of .mstack/ artifacts (plans, reviews, code ledgers, QA runs, TODOS)
  via pipeline-status.sh and regenerates .mstack/STATUS.md — a generated,
  never-hand-edited status page — then summarises the state and the
  recommended next command per feature. Read-only apart from STATUS.md.
  Use when the user says "status", "where are we", "what's next", "pipeline
  state", "what was I doing", or invokes /mstack-status.
allowed-tools:
  - Read
  - Bash
  - Write
---

# mstack-status

One job: regenerate `.mstack/STATUS.md` and tell the user where things
stand.

## Steps

1. Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/pipeline-status.sh` from the repo
   root. It prints the complete STATUS.md content (generated header,
   per-feature table with plan/review/code state and next command, open-todo
   count, latest QA run).
2. Write the output verbatim to `.mstack/STATUS.md`.
3. Read the todos file and the newest QA report (if any) so the summary has
   specifics, not just counts.
4. Reply with: the table, the single most useful next command overall, and
   any red flags — a paused code run (`[!]` entries in a ledger), a QA run
   with open critical issues, an unusually long open-todo list.

## Anti-patterns

- **Don't hand-edit STATUS.md** and don't preserve stale content — always
  regenerate from the script output.
- **Don't invent state.** If an artifact is missing its `**Status:**` line,
  show `?` and name the file that needs fixing.
- **Don't turn this into a planning session.** Point at the next command and
  stop — `/mstack-plan` and friends do the actual work.
