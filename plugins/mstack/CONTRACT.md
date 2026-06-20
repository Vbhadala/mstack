# mstack ↔ project contract

The mstack skills are distributed as a versioned plugin and installed into many
repos — fresh template forks **and** pre-existing apps with different
layouts. That means a repo can run a *newer* skill against *older* project
conventions. Treat this file as the interface between the two.

## How skills discover the project

Stack-coupled skills resolve project paths/commands by running **one shared
script** at the start of a run:

```sh
${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh
```

It prints a single JSON object and applies this precedence (lowest → highest):

1. **Auto-detected defaults** — package manager from the lockfile
   (`pnpm-lock.yaml`/`yarn.lock`/`package-lock.json`/`bun.lockb`), layout from
   the directory structure (`apps/web` or `pnpm-workspace.yaml` → `monorepo`;
   else `src/` → `flat`), and mobile presence (`apps/mobile`). Most apps need
   no config.
2. **`<repo-root>/.mstack/config.json`** — deep-merged on top; explicit values
   always win. Copy [`mstack.config.example.json`](./mstack.config.example.json)
   there and edit. Validated by [`mstack.schema.json`](./mstack.schema.json).

Output keys skills consume:

| Key | Meaning |
|---|---|
| `paths.{designTokens,globalsCss,brandSource,webApp,mobileApp}` | source-of-truth file/dir locations (`mobileApp` is `null` when there's no mobile target) |
| `commands.{dev,build,lint,typecheck,test,genMobileTw}` | package scripts, prefixed for the detected package manager |
| `conventions.{brandStringLiteralRule,serviceLayer,apiPrefix}` | project rules |
| `_resolved.{packageManager,layout,hasMobile,source}` | informational; skills announce these and gate mobile-only steps on `hasMobile` |

A skill must **never hardcode** `packages/config/...`, `@your-scope`, or a
`pnpm` script as the only option. Resolve it, fall back to the bracketed
default, and tell the user the detected `layout`/`packageManager`.

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
