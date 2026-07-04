# Changelog

All notable changes to the `mstack` plugin. Format: [Keep a Changelog](https://keepachangelog.com/).
This plugin follows SemVer; the **Contract** sub-section flags changes to the
[skill ↔ project contract](./CONTRACT.md).

## [0.3.0] — Init, contract hardening, pipeline close-out

### Added
- `/mstack-init` — repo onboarding: detection → confirmation → minimal
  `.mstack/config.json` (overrides only) → product docs (PRD / ROADMAP /
  TODOS), adopting existing files in place via `paths.*`.
- `/mstack-status` — regenerates a generated-only `.mstack/STATUS.md`
  (per-feature pipeline table + next command) via
  `shared/bin/pipeline-status.sh`.
- `/mstack-ship` — final build/typecheck/lint gate, push, PR generated from
  the review doc + task ledger, plan status → `shipped`, roadmap item →
  Shipped, follow-ups → TODOS.
- `shared/bin/append-todo.sh` — dedup'd capture into the todo backlog;
  wired into plan (deferred scope), review (deferred concerns), qa
  (deferred issues), debug (out-of-scope bugs), code (paused/skipped tasks,
  follow-ups), ship (post-ship follow-ups).
- `shared/templates/prd.md` + `shared/templates/roadmap.md`.
- `scripts/test.sh` (fixture-based script tests), `scripts/release.sh`
  (synced version bump), GitHub Actions `validate` workflow.

### Changed
- Skills stopped assuming Drizzle/Next.js: hard rules now resolve from
  `conventions.hardRules` + ORM discipline from `conventions.orm`; dev-server
  checks use the resolved `devUrl`; commit trailers no longer pin a model
  name; plugin-escaping relative doc links removed.
- `/mstack-plan` reads TODOS / PRD / ROADMAP / recent learnings before
  consulting; `/mstack-review`'s UI-Significant heuristic now counts Expo /
  mobile screens.
- `find-latest-plan.sh` / `find-latest-review.sh` pick the newest file by
  filename date prefix (clone-safe) instead of mtime.
- `validate.sh`: resolver smoke test actually runs in an empty temp dir;
  new checks for plugin-escaping links and pinned model trailers.

### Contract
- **New resolver keys** (all auto-detected, all overridable):
  `devUrl` (expo → `http://localhost:8081`, else `:3000`),
  `paths.{prd,roadmap,todos}` (defaults `.mstack/product/PRD.md`,
  `.mstack/product/ROADMAP.md`, `.mstack/TODOS.md`),
  `conventions.orm` (`drizzle|prisma|none`, from deps),
  `conventions.hardRules` (string array, default `[]`),
  `_resolved.hasExpo`.
- **New layout value `expo`** for standalone Expo apps (expo dep +
  `app.json`/`app.config.*`): `mobileApp: "."`, dev command uses the `start`
  script.
- **Default layout for undetectable repos changed `monorepo` → `flat`.**
  Repos relying on the old fallback should add `.mstack/config.json`.
- **New repo-owned artifacts:** `.mstack/TODOS.md` (append-todo.sh),
  `.mstack/STATUS.md` (generated, never hand-edited),
  `.mstack/product/{PRD,ROADMAP}.md` (optional, created/adopted by
  `/mstack-init`).
- **Plan status flow extended:** `draft → reviewed → implemented → shipped`
  (`/mstack-ship` sets `shipped`).

## [0.2.0] — Layer 2: config-driven portability

### Added
- `shared/bin/resolve-config.sh` — single resolver that auto-detects package
  manager (lockfile), layout (monorepo vs flat), and mobile presence, then
  deep-merges `<repo>/.mstack/config.json` on top. Skills run it to get real
  `paths`/`commands`/`conventions` instead of assuming a fixed stack.
- `mstack.schema.json` — JSON Schema for `.mstack/config.json` (the example
  already referenced it).

### Changed
- The 7 stack-coupled skills (`mstack-design-system`, `mstack-mockup`,
  `mstack-ux-audit`, `mstack-code`, `mstack-review`, `mstack-plan`, `mstack-qa`)
  now resolve project layout via `resolve-config.sh` and substitute resolved
  values for the monorepo defaults; mobile-only steps gate on `hasMobile`.
  `mstack-debug` got a one-line env-path generalization.
- `validate.sh` now syntax-checks shared scripts, validates the schema, and
  smoke-tests the resolver output.

### Contract
- **Skills now resolve the project by running
  `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh`** (auto-detect →
  `.mstack/config.json` override). Consuming repos may add a `.mstack/config.json`
  to override any auto-detected path/command; most apps need none. See
  [`CONTRACT.md`](./CONTRACT.md).

## [0.1.0]

### Added
- Initial extraction of the mstack workflow from the source template
  `.claude/skills/` into a distributable Claude Code plugin.
- 10 skills: `mstack-plan`, `mstack-review`, `mstack-code`, `mstack-auto`,
  `mstack-qa`, `mstack-debug`, `mstack-mockup`, `mstack-design-system`,
  `mstack-ux-audit`, `mstack-research`.
- Shared helpers (`shared/bin/*.sh`) and templates (`shared/templates/*.md`),
  referenced via `${CLAUDE_PLUGIN_ROOT}`.

### Changed
- Shared assets moved from `mstack-shared/` to plugin-root `shared/`; skill
  references rewired from `.claude/skills/mstack-shared/...` to
  `${CLAUDE_PLUGIN_ROOT}/shared/...`.
- Rebranded to neutral `mstack` naming (Layer 1): skills `mlabs-*` → `mstack-*`,
  marketplace `millionlabs` → `mstack` (install string `mstack@mstack`), author/
  homepage neutralized, and all "MLabs"/"Million Labs" prose genericized. Stack/
  path coupling (`packages/config`, `pnpm`, etc.) is untouched — that's Layer 2.

### Contract
- Skills now resolve project paths via `.mstack/config.json` →
  `CLAUDE.md`/`AGENTS.md` → template defaults. See
  [`mstack.config.example.json`](./mstack.config.example.json). _Prose
  decoupling of remaining hardcoded paths is tracked as follow-up._
