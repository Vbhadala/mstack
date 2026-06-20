# Changelog

All notable changes to the `mstack` plugin. Format: [Keep a Changelog](https://keepachangelog.com/).
This plugin follows SemVer; the **Contract** sub-section flags changes to the
[skill ↔ project contract](./CONTRACT.md).

## [Unreleased]

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
