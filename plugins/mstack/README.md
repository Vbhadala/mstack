# mstack

The mstack agent workflow as a Claude Code plugin: an opinionated
**plan → review → code** pipeline plus QA, debugging, mockups, design-system,
UX audit, and research — installable into any repo and versioned independently
of the app it runs in.

## Skills

| Skill | Edits code? | Purpose |
|---|---|---|
| `/mstack-plan` | no | Interactive feature consultation → `.mstack/plans/<slug>.md` |
| `/mstack-review` | no | Critique a plan, lock decisions → approved review doc |
| `/mstack-code` | **yes** | Execute an approved review, atomic commit per task |
| `/mstack-auto` | **yes** | plan → review → code in one flow, with approval gates |
| `/mstack-qa` | gated | Scenario-driven Playwright QA + structured bug report |
| `/mstack-debug` | no | Root-cause a specific failure, propose a fix |
| `/mstack-mockup` | no | Static HTML design variants under `.mstack/mockups/` |
| `/mstack-design-system` | **yes** | Formulate/rebrand tokens → design source of truth |
| `/mstack-ux-audit` | gated | UX review against the design system |
| `/mstack-research` | no | Parallel tech-choice research with sources |

## Install

```bash
# one-time: register the marketplace
/plugin marketplace add vbhadala/mstack

# install (or update) the plugin in the current repo
/plugin install mstack@mstack
```

Then, in the repo, copy and edit the project config (optional but recommended
for non-template apps):

```bash
mkdir -p .mstack && cp "$CLAUDE_PLUGIN_ROOT/mstack.config.example.json" .mstack/config.json
```

## How it adapts per repo

Skills are layout-agnostic by [contract](./CONTRACT.md): they read
`.mstack/config.json`, then `CLAUDE.md`/`AGENTS.md`, then fall back to the
template defaults. Drop a `.mstack/config.json` into a legacy app to point the
skills at its actual paths and scripts.

- Plugin assets (skills, `shared/bin`, `shared/templates`) are read-only and
  resolved via `${CLAUDE_PLUGIN_ROOT}`.
- The repo owns `.mstack/` (config + run artifacts).

See [`CONTRACT.md`](./CONTRACT.md) for the full interface and
[`CHANGELOG.md`](./CHANGELOG.md) for version history.
