---
name: mstack-design-system
description: |
  Formulate (or rebrand) the design system for an app project. Accepts
  references — screenshots, Figma URLs, competitor sites, or a freeform
  brief — and proposes a complete system (color, typography, radius,
  motion, brand voice). Writes tokens directly to the project's
  source-of-truth files (resolved per project — design tokens, globals
  CSS, brand source) and, when the project has a mobile target,
  regenerates its mobile Tailwind config so web + mobile + email stay in
  sync. Produces .mstack/design-system/DESIGN.md plus light/dark preview
  pages. Upstream of /mstack-mockup.
  Use when the user says "design system", "brand", "rebrand the app",
  "tokens from this screenshot", or invokes /mstack-design-system.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash
  - AskUserQuestion
  - WebFetch
---

# mstack-design-system

Build or rebuild the design system. The source of truth is three project
files — design tokens, globals CSS, and brand source — resolved per project
in Phase 0. When the project has a mobile target, its Tailwind config is
**generated** from the tokens — never edit it directly.

This skill is upstream of `/mstack-mockup`. Mockups consume tokens; this
skill defines them.

## Phase 0 — Resolve project layout

Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh`. It prints the
project's resolved `paths`, `commands`, and a `_resolved` block
(`.mstack/config.json` overrides → auto-detected defaults). The keys this
skill uses:

- `paths.designTokens` [monorepo default `packages/config/src/design.ts`]
- `paths.globalsCss` [default `apps/web/src/app/globals.css`]
- `paths.brandSource` [default `packages/config/src/brand.ts`]
- `commands.genMobileTw` — the mobile-token regen script
- `_resolved.hasMobile` / `_resolved.layout` / `_resolved.packageManager`

**Throughout this skill, treat every `packages/config/...`, `apps/web/...`,
or `apps/mobile/...` path literal — and every `pnpm <script>` command
literal — as the monorepo default. Substitute the resolved `paths.*` /
`commands.*` value for the actual project.** Tell the user the detected
`layout` and `packageManager`. **If `_resolved.hasMobile` is false**, this
project has no mobile target: skip every `gen:mobile-tw`, mobile-font, and
"both surfaces" step, and treat web as the only surface.

## Phase 1 — Detect mode

Read the current state in parallel:

- `packages/config/src/design.ts`
- `packages/config/src/brand.ts`
- `apps/web/src/app/globals.css`
- `.mstack/design-system/DESIGN.md` if it exists

Classify:

- **from-scratch** — brand.name is still the unchanged starter default AND no
  `DESIGN.md` exists. Treat as a fresh project.
- **rebrand** — brand.name has been customised, tokens are mostly the
  shadcn / project defaults, no `DESIGN.md`. The user has named their
  product but not yet locked the look.
- **evolve** — `DESIGN.md` exists. Refining or extending what's there.

Tell the user which mode you're in and let them override.

## Phase 2 — Intake references

One batch via `AskUserQuestion`:

- **References** — what should the system be inspired by? Multi-select +
  free text:
  - Paste image paths (screenshots, moodboards) — the Read tool can
    inspect them.
  - Paste website URLs (competitors, products you admire) — use
    `WebFetch` to extract palette + type hints.
  - Paste a Figma file URL — if the `pencil` MCP is available (`.pen`
    files) use it; otherwise treat as a brief and ask the user to
    describe the salient parts.
  - "Describe in words" — freeform aesthetic brief.
  - "Pure preferences" — no external refs, drive from the next two
    questions.
- **Aesthetic** — `minimal` | `editorial` | `dense-utility` | `playful`
  | `brutalist` | `luxe` | `your-call`.
- **Surfaces** — `web only` | `mobile only` | `both` (default `both`
  since this is the monorepo).
- **Rebrand depth** (only in `rebrand` / `evolve` mode) — `palette only`
  | `palette + type` | `everything including motion + radius`.

Then collect brand identity, **only if missing or default**:

- `brand.name`, `brand.tagline`, `brand.taglineHighlight`,
  `brand.supportEmail`, `brand.socialHandle`, `brand.legalEntity`,
  `brand.url`.

## Phase 3 — Research references

For each reference the user gave:

- **Images** — Read the image; extract the dominant 4–6 colors (estimate
  OKLCH), note type weight + density, motion vibe is unknowable from a
  still — leave for Phase 4.
- **URLs** — `WebFetch` the page. Ask the embedded model to report
  back: primary brand color (hex), secondary, neutral spine,
  body/heading font families, radius character (sharp / soft / pill),
  density (airy / tight). Don't trust scraped CSS blindly; treat it as
  signal.
- **Figma / `.pen` files** — use the `pencil` MCP tools (`open_document`,
  `get_variables`, `get_screenshot`) if the file is a `.pen`. For real
  Figma URLs without API access, ask the user to export key frames as
  images and re-run.

Synthesise into a one-screen "what the references say" summary before
proposing anything.

## Phase 4 — Propose the system

Present the proposed system to the user in a single message. Show:

- **Palette** — light + dark, each token as OKLCH **and** hex side by
  side. Cover every shadcn token (background, foreground, card, popover,
  primary, secondary, muted, accent, destructive, border, input, ring,
  chart-1..5, sidebar-*) plus the project additions (`success`,
  `warning`). Flag any AA failures and ask whether they're deliberate
  brand exemptions (like the existing white-on-orange CTA).
- **Typography** — sans / display / mono choices. Prefer Google Fonts +
  Expo Font compatible families. State exactly how to load each on web
  (`next/font`) and mobile (Expo Font). Type scale: keep the 8-step
  ramp; only adjust if the aesthetic demands it (e.g. editorial wants
  bigger hero sizes).
- **Radius** — pick a `--radius` base; the rest derives via `calc()`.
- **Motion** — durations + easings. Default to the existing values
  unless the aesthetic clearly disagrees (brutalist → faster, slower
  easings; luxe → slower, gentler easings).
- **Voice notes** — 2–3 bullets on copy tone (terse vs warm, technical
  vs plain, humour vs straight).

Then `AskUserQuestion`:

- **Lock it in?** — `yes, write the tokens` | `iterate — adjust X` |
  `start over with different refs`.

Loop until the user locks.

## Phase 5 — Write tokens

Only after explicit lock-in. Edit in this exact order:

1. **`packages/config/src/design.ts`** — OKLCH values for `colors.light`
   + `colors.dark`, type scale, fonts (the CSS var references), radius,
   motion. Keep the inline comments that explain AA exemptions; update
   their hex equivalents if the brand color changed.
2. **`apps/web/src/app/globals.css`** — mirror every value from
   `design.ts`. The file uses CSS variables, not OKLCH triplets — match
   the existing format exactly (`oklch(L C H)` or `oklch(L C H / alpha)`).
   Cover `:root` (light) and `.dark` (dark) blocks, plus chart and
   sidebar tokens.
3. **`packages/config/src/brand.ts`** — `brand.name`, `tagline`,
   `taglineHighlight`, `supportEmail`, `socialHandle`, `legalEntity`,
   `url`, and the `emailColors` hex fallbacks (Gmail / Outlook do not
   support `oklch()` inline, so these must be hand-tuned sRGB hex
   equivalents of `design.colors.light`).
4. **Mobile sync — only if `_resolved.hasMobile`.** Run
   `commands.genMobileTw` from repo root to regenerate the mobile Tailwind
   config (default `apps/mobile/tailwind.config.js`). **Never hand-edit that
   file** — it has a `DO NOT EDIT — GENERATED FILE` header for a reason. If
   the project has no mobile target, skip this step.
5. **If the project provides a contrast check** (e.g. a `check-contrast`
   script), run it. If it fails:
   - If the failure is a documented brand exemption, ensure the check's
     allowlist still covers it.
   - If it's a new failure, fix the offending pair or get explicit
     user approval to add it to the allowlist.
6. If `_resolved.hasMobile` and a `gen:mobile-tw:check` script exists, run it
   to confirm mobile is in sync.

If `brand.name` changed, warn the user that the ESLint
`no-brand-string-literal` rule reads `brand.name` from this file — they
may need to rename their CI lock or check
`tooling/eslint-config/src/rules/no-brand-string-literal.mjs`.

## Phase 6 — DESIGN.md + previews

Create `.mstack/design-system/`:

```
design-system/
├── DESIGN.md          # filled-in template, the doc-of-record
├── preview-light.html # palette swatches + type ramp + button/input/card samples
└── preview-dark.html  # same in dark mode
```

`DESIGN.md` uses the template at
`${CLAUDE_PLUGIN_ROOT}/shared/templates/design.md`. Fill every placeholder
with real values — no `{{TOKEN}}` left over.

`preview-*.html` are standalone files (Tailwind CDN + inlined CSS
variables matching the new tokens). Show:

- Every palette token as a swatch with name + OKLCH + hex.
- The full type ramp using the chosen sans / display / mono families.
- Sample components: button (primary / secondary / destructive), input
  (idle + focus), card with body text, alert (success / warning / error).
- The radius scale rendered as boxes.

Print the absolute paths to all three files at the end. Don't shell out
to a browser.

## Phase 7 — Hand off

Tell the user:

> Design system locked in. Tokens written to
> `packages/config/src/design.ts`, `apps/web/src/app/globals.css`, and
> `packages/config/src/brand.ts`. Mobile Tailwind regenerated.
> `DESIGN.md` + previews at `.mstack/design-system/`.
>
> Next: `/mstack-mockup` will now use these tokens.

Append a learning via
`${CLAUDE_PLUGIN_ROOT}/shared/bin/append-learning.sh mstack-design-system <kind> "<text>"`
if something non-obvious came up — e.g. a font fallback chosen because
the primary won't load on Android, a deliberate AA exemption, a
reference that was rejected because its palette wouldn't dark-mode
cleanly.

## Anti-patterns

- **Don't write tokens before Phase 5.** Phases 2–4 are consultation
  only. The user must explicitly lock in before any file under
  `packages/` or `apps/` is touched.
- **Don't edit `apps/mobile/tailwind.config.js` by hand.** It is
  generated from `packages/config/src/design.ts`. Always regenerate via
  `pnpm gen:mobile-tw`.
- **Don't skip the email hex fallbacks.** Gmail / Outlook strip
  `oklch()`. If `brand.emailColors` drifts from `design.colors.light`,
  every transactional email looks broken.
- **Don't invent fonts that aren't installable.** Either pick from
  Google Fonts (works for both `next/font` and Expo Font) or instruct
  the user to add the font files to `apps/mobile/assets/fonts/` and
  the web app's font loader. State the exact import line.
- **Don't propose new AA-failing pairs without flagging them.** The
  repo has one deliberate exemption (white-on-orange CTA); document any
  new one in `DESIGN.md` and `scripts/check-contrast.ts`'s allowlist.
- **Don't overwrite an existing `DESIGN.md` silently.** In `evolve`
  mode, diff what's changing and confirm with the user before writing.
- **Don't run this skill as a colour-swap shortcut.** If the user just
  wants to tweak one token, do an `Edit` to `design.ts` + `globals.css`
  + `pnpm gen:mobile-tw` directly; don't drag them through 7 phases.
