# mstack

The mstack agent workflow as a Claude Code plugin: an opinionated
**init → plan → review → code → qa → ship** pipeline plus a quick-fix lane,
deep debugging, mockups, design-system, UX audit, research, status, and an
Expo release runway — installable into any repo and versioned independently
of the app it runs in.

**How the pieces connect:** features flow `plan → review → (mockup) → code →
qa → ship` (or `/mstack-auto` for the chained version, `/mstack-expo` for the
mobile release). Bugs enter through `/mstack-fix`, which escalates to
`/mstack-debug` when the cause isn't evident and to `/mstack-plan` when the
fix outgrows a quick lane. `/mstack-init` onboards a repo once;
`/mstack-status` tells you where everything is.

## Skills

| Skill | Edits code? | Purpose |
|---|---|---|
| `/mstack-plan` | no | Interactive feature consultation → `.mstack/plans/<slug>.md` |
| `/mstack-review` | no | Critique a plan, lock decisions → approved review doc |
| `/mstack-code` | **yes** | Execute an approved review, atomic commit per task |
| `/mstack-fix` | **yes** | Quick-fix lane: bounded look → fix → verify → one commit; escalates to /mstack-debug or /mstack-plan on size/ambiguity |
| `/mstack-auto` | **yes** | plan → review → code in one flow, with approval gates |
| `/mstack-qa` | gated | Scenario-driven Playwright QA + structured bug report |
| `/mstack-debug` | no | Deep RCA with a failing test that proves the cause → hands to /mstack-fix or /mstack-plan |
| `/mstack-mockup` | no | HTML design variants under `.mstack/mockups/` (native device frames on Expo) |
| `/mstack-design-system` | **yes** | Formulate/rebrand/adopt tokens → design source of truth (adopt = extract-only for legacy repos) |
| `/mstack-ux-audit` | gated | UX review against the design system |
| `/mstack-research` | no | Parallel tech-choice research with sources |
| `/mstack-init` | no* | Onboard a repo: detection → minimal config → PRD/ROADMAP/TODOS (*writes only `.mstack/` + optional `AGENTS.md`) |
| `/mstack-status` | no | Regenerate `.mstack/STATUS.md` — pipeline state + next command per feature |
| `/mstack-ship` | gated | Verify gate → push → PR from review + ledger → roadmap/TODOS close-out |
| `/mstack-expo` | gated | Expo release runway: preflight gate → OTA vs store build → EAS build/submit/update → monitoring + rollback |

## Install

```bash
# one-time: register the marketplace
/plugin marketplace add vbhadala/mstack

# install (or update) the plugin in the current repo
/plugin install mstack@mstack
```

Then onboard the repo — `/mstack-init` scans the codebase, confirms the
detection with you, and writes a minimal `.mstack/config.json` containing
only the overrides that differ from auto-detection (plus optional
PRD/ROADMAP/TODOS product docs). Hand-copying
[`mstack.config.example.json`](./mstack.config.example.json) to
`.mstack/config.json` works too, but init writes less and detects more.

## How it adapts per repo

Skills are layout-agnostic by [contract](./CONTRACT.md): each run starts by
executing `shared/bin/resolve-config.sh`, which **auto-detects** the project
(package manager from the lockfile; layout `monorepo | flat | expo` from the
directory structure and deps; ORM, Expo presence, dev URL, token-drift mode)
and then deep-merges `.mstack/config.json` on top — explicit values always
win. Most repos need no config file at all; a legacy app adds one only to
override what detection got wrong.

- Plugin assets (skills, `shared/bin`, `shared/templates`) are read-only and
  resolved via `${CLAUDE_PLUGIN_ROOT}`.
- The repo owns `.mstack/` (config + run artifacts).

See [`CONTRACT.md`](./CONTRACT.md) for the full interface and
[`CHANGELOG.md`](./CHANGELOG.md) for version history.
