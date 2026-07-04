---
name: mstack-ship
description: |
  Close out an implemented feature: run the final build/typecheck/lint gate,
  push the branch, and open a PR whose body is generated from the review doc
  and the code run's task ledger (one commit per task makes the narrative
  for free). Then flip the plan status to shipped, move the roadmap item to
  Shipped, and capture follow-ups into the todo backlog. Asks before
  anything leaves the machine. Never merges.
  Use when the user says "ship it", "open the PR", "push this",
  "create the PR", or invokes /mstack-ship.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Bash
  - AskUserQuestion
---

# mstack-ship

Ship the current feature branch: verify → confirm → push → PR → close the
loop.

## Resolve project layout

Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh`. Keys this skill
uses: `commands.{typecheck,lint,build}` — run THESE, not hardcoded `pnpm`
variants — plus `paths.roadmap`, `paths.todos`,
`_resolved.{packageManager,layout}`.

## Pre-flight

1. **Git state.** Current branch is not `main`/`master`; working tree is
   clean. Abort with a clear message otherwise.
2. **Locate the feature.** `--slug <slug>` arg wins; otherwise take the
   newest `.mstack/code/*/report.md`. Read the report, its task ledger
   (`tasks.md`), the matching review (`.mstack/reviews/<slug>.md`) and plan
   (`.mstack/plans/<slug>.md`).
   - No code report at all → this branch didn't go through the pipeline.
     Ask: "Ship anyway with a hand-written PR body?" — proceed only on yes,
     and write the body from `git log` + diff stats instead of the ledger.
3. **Tooling.** If `gh` is missing or there's no GitHub remote, degrade
   gracefully: still run the gate and push, then print the PR body for
   manual use.

## Gate — verify (never ship on red)

Run in order: `commands.typecheck`, `commands.lint`, `commands.build`.

- A failure stops the run — report the output and exit. No overrides, no
  "ship anyway".
- A script that doesn't exist in this project (command not found / missing
  script) is skipped — say so explicitly in the summary.

## Confirm, then push

Show the user: branch name, commit count (`git log main..HEAD --oneline | wc -l`
— substitute the actual default branch), PR title, and the full drafted body
(below). Then AskUserQuestion:

- **Push and open PR** — the normal path
- **Push only** — no PR; print the body for later
- **Abort** — nothing leaves the machine

Pushing publishes; never push before this gate. Then:
`git push -u origin <branch>`. If a PR already exists for this branch
(`gh pr view --json url` succeeds), update it (`gh pr edit --body …`)
instead of creating a duplicate.

## PR body (generated)

```markdown
## <feature title from the plan>

<the plan's Problem section, first paragraph>

### Changes

<one line per ledger task: `- <task name> (<short SHA>)`>

### Review

Approved review: `.mstack/reviews/<slug>.md` — <N> tasks,
<M> deferred concern(s).

### QA

<latest QA run for this branch: status + report path — or exactly:
"Not QA'd — run /mstack-qa before merging.">

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Close the loop (after push/PR)

1. **Plan doc:** Status `implemented` → `shipped` (Edit).
2. **Roadmap** (only if the file at `paths.roadmap` exists): move or add the
   feature's line under `## Shipped` with today's date and the plan link.
3. **Follow-ups:** every Follow-ups item from the code report and every
   unfixed QA issue for this branch →
   `${CLAUDE_PLUGIN_ROOT}/shared/bin/append-todo.sh "ship <slug>" "<item>"`.
4. **Summary:** PR URL (or "printed body"), which gates ran/were skipped,
   roadmap + todos updates made.

## Anti-patterns

- **Don't merge the PR.** Opening it is the job; merging is the user's call.
- **Don't force-push or rewrite history.** The per-task commits are the PR's
  review surface.
- **Don't ship on red.** A failing gate ends the run.
- **Don't push without the explicit confirm** — even when invoked at the end
  of another flow that already asked once.
- **Don't fabricate the QA line.** No QA run for this branch → say so in the
  PR body verbatim.
- **Don't bypass hooks** (`--no-verify`) — same rule as `/mstack-code`.
