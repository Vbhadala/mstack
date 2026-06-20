# mstack ↔ project contract

The mstack skills are distributed as a versioned plugin and installed into many
repos — fresh template forks **and** pre-existing apps with different
layouts. That means a repo can run a *newer* skill against *older* project
conventions. Treat this file as the interface between the two.

## How skills discover the project

Skills resolve project-specific paths and commands in this order:

1. **`<repo-root>/.mstack/config.json`** — if present, it wins. Copy
   [`mstack.config.example.json`](./mstack.config.example.json) there and edit.
2. **`CLAUDE.md` / `AGENTS.md`** — skills read these for conventions and the
   workspace layout.
3. **Built-in defaults** — a default template layout (`packages/config`,
   `apps/web`, `pnpm` scripts). Correct for template forks; may be wrong for a
   legacy app, which is exactly why `.mstack/config.json` exists.

A skill must **never hardcode** `packages/config/...`, `@your-scope`, or a `pnpm`
script as the only option. Read it from config, fall back to the default, and
say which one you used.

## Runtime layout in the consuming repo

The plugin ships read-only assets. The repo owns its working dir:

| Path | Owner | Purpose |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/*` | plugin | skill instructions (read-only) |
| `${CLAUDE_PLUGIN_ROOT}/shared/bin/*` | plugin | helper scripts |
| `${CLAUDE_PLUGIN_ROOT}/shared/templates/*` | plugin | plan/review/design templates |
| `<repo>/.mstack/config.json` | repo | per-repo overrides (this contract) |
| `<repo>/.mstack/plans|reviews|qa|code/*` | repo | durable run artifacts |
| `<repo>/.mstack/learnings.jsonl` | repo | appended learnings |

`${CLAUDE_PLUGIN_ROOT}` is set by Claude Code to the plugin's install dir when a
skill from this plugin runs — shell commands inside SKILL.md can use it directly.

## Versioning rule

When a skill changes what it expects from the project (a new config key, a new
required script, a moved artifact path), it is a **breaking change to this
contract**. Bump the plugin minor/major and record it in
[`CHANGELOG.md`](./CHANGELOG.md) under a `### Contract` heading so repos pinned
to an older convention know what to update.
