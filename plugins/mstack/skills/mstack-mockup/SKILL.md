---
name: mstack-mockup
description: |
  Generate multiple UI mockup variants for a screen or feature, using the
  project's existing Tailwind config and design tokens / brand source
  (resolved per project) so the brand actually applies. Outputs static HTML
  variants under .mstack/mockups/<feature>/v1..vN/, collects feedback, and
  iterates on the chosen direction. Pure design exploration — never edits
  src/.
  Use when the user says "mockup the X screen", "show me design options for
  Y", "design shotgun", or invokes /mstack-mockup.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Bash
  - AskUserQuestion
---

# mstack-mockup

Generate N design variants for a screen, collect feedback, iterate on the
winner. Output is static HTML; nothing under `src/` is touched.

## Resolve project layout

Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh`. It prints the
project's resolved `paths`, `commands`, and a `_resolved` block
(`.mstack/config.json` overrides → auto-detected defaults). The keys this
skill uses:

- `paths.designTokens` [monorepo default `packages/config/src/design.ts`]
- `paths.globalsCss` [default `apps/web/src/app/globals.css`]
- `paths.brandSource` [default `packages/config/src/brand.ts`]
- `_resolved.hasExpo` — switches native-frame rendering on (Phase 3)

**Throughout this skill, treat every `packages/config/...`, `apps/web/...`,
`apps/mobile/...`, or legacy `src/config/...` path literal — and every
`pnpm <script>` command literal — as the monorepo default. Substitute the
resolved `paths.*` / `commands.*` value for the actual project.** State the
detected `layout` to the user.

## Phase 1 — Brief

Two intake paths:

**A. Standalone (no args)** — ask the user (one batch via AskUserQuestion):

- **Feature/screen** — what is being designed (e.g. "billing portal landing",
  "messages thread view")?
- **Users** — who sees this and what's their primary action?
- **Variant axis** — what should the variants differ on (layout density vs
  visual style vs hierarchy vs all three)?
- **Number of variants** — default 3, max 5.

**B. From a review (`--from-review <slug>`)** — slot in the main chain after
`/mstack-review`. Read `.mstack/reviews/<slug>.md`:

- Derive **Feature/screen** from the review's title + first task's `Files`
  field (the routes/components being touched).
- Derive **Users** from the underlying plan doc (linked in the review
  frontmatter as `Plan reviewed`) — the plan's "Persona" / "User" section.
- **Still ask** for Variant axis + Number of variants (those are taste
  decisions per-mockup, not pre-decided by the review).
- Confirm the derived Feature/Users back to the user before generating, so
  they can correct if the auto-derivation missed something.

## Phase 2 — Read brand context

In parallel:

- `packages/config/src/design.ts` (or legacy `src/config/design.ts`) —
  semantic tokens + scales
- `packages/config/src/brand.ts` (or legacy `src/config/brand.ts`) —
  name, tagline, support email
- `apps/web/src/app/globals.css` (or legacy `src/app/globals.css`) — CSS
  variables (OKLCH, light + dark)
- `apps/mobile/tailwind.config.js` (generated; read for reference only)
- `components.json` (shadcn) and any existing screens that solve a similar
  problem (`apps/web/src/features/*/`, `apps/web/src/app/(app)/*/page.tsx`)
- `.mstack/design-system/DESIGN.md` if present — the locked design system
- `paths.prd` if the file exists — personas and voice constraints that
  should shape copy and layout choices
- `${CLAUDE_PLUGIN_ROOT}/shared/references/frontend-craft.md` — the craft
  rules every variant must satisfy (hierarchy, states, copy, anti-slop)

The mockups must use the actual brand tokens. No fake colours, no fake
typefaces.

**Missing design system?** If `brand.name` is still the unchanged starter default
AND no `DESIGN.md` exists, pause and suggest the user run
`/mstack-design-system` first. Generating mockups against the template
defaults wastes a round.

## Phase 3 — Generate

Create `.mstack/mockups/<feature-slug>/`:

```
<feature-slug>/
├── BRIEF.md              # the brief from Phase 1
├── COMPARE.html          # side-by-side iframe view of all variants
├── v1/
│   ├── index.html
│   └── NOTES.md          # what makes v1 distinct
├── v2/
│   ├── index.html
│   └── NOTES.md
└── v3/
    ├── …
```

Each `index.html` is a standalone file:

- Pulls Tailwind via Play CDN, pinned to a version
  (`<script src="https://cdn.tailwindcss.com/3.4.16"></script>`) so mockups
  don't shift under an unpinned script. **The Play CDN is Tailwind v3** — do
  not port a v4 `@theme` config into its config block. Drive all
  token-dependent styling through the inlined CSS variables instead:
  arbitrary-value classes (`bg-[var(--primary)]`,
  `text-[var(--muted-foreground)]`) or a small `<style>` block. Use the CDN
  only for layout/spacing utilities. (Mockups are local design artifacts —
  never ship this tag in `src/`.)
- Inlines the project's CSS variables (copied from `globals.css`)
- Uses real copy from `src/config/brand.ts` where the screen needs branded text
- Renders at desktop (1280px) and mobile (375px) — use a CSS grid or flex
  layout that adapts; show both via responsive viewport, no separate files

Variants must differ on the **variant axis** the user picked, not just colour
swaps. Examples:

- **Layout density** → cards vs table vs single-column list
- **Hierarchy** → hero-led vs grid-led vs sidebar-led
- **Visual style** → minimalist vs editorial vs dashboard

**Native screens (Expo).** When `_resolved.hasExpo` and the screen being
designed is a native app screen (not a web page), render each variant
inside a device frame instead of the responsive web layout: 390×844
viewport, drawn status bar and home indicator, safe-area insets respected,
and native chrome (header, tab bar) following platform conventions — and
the `building-native-ui` skill's rules when it's available in the
environment. Still plain standalone HTML: these frames approximate native
for layout/hierarchy/copy decisions; the implementation follows the
project's native UI conventions, not this HTML's CSS.

`COMPARE.html` is a simple page with N iframes side-by-side and the variant
name above each, so the user can scan all options in one view.

## Phase 4 — Feedback + iterate

Open `COMPARE.html` (just print the absolute path; don't shell out to a browser).
Use AskUserQuestion to collect feedback:

- **Pick a winner** (v1, v2, v3, or "none — try again")
- **What works / what doesn't** — free-form
- **Iterate?** — yes (refine the winner) | no (we're done)

If iterating, generate `<feature-slug>/v<N+1>/` from the winner with the
adjustments. Repeat until the user says "done" or hits max 5 variants.

When done, write `<feature-slug>/FEEDBACK.md` with the winning variant + the
final feedback summary, so a future `/mstack-plan` for this feature can pick
it up.

**Next-step suggestion based on invocation:**

- If invoked standalone → "Mockup complete. Use `/mstack-plan` to turn the
  chosen variant into an implementation plan."
- If invoked with `--from-review <slug>` → "Mockup complete. Reference
  `.mstack/mockups/<feature-slug>/FEEDBACK.md` (winner: vN) and run
  `/mstack-code` on review `<slug>` next."

Append a learning if a variant axis or pattern worked well (or notably failed)
— useful for future mockup runs.

## Anti-patterns

- **Don't edit anything under `src/`.** Mockups are exploration, not
  implementation. Implementation comes via `/mstack-plan` → `/mstack-review` →
  `/mstack-code`, with the chosen mockup as input.
- **Don't generate variants that only differ cosmetically** unless the user
  explicitly picked "visual style" as the axis. Three colour-swapped versions
  of the same layout is not a useful design exploration.
- **Don't invent brand tokens.** Pull from `src/config/design.ts` and
  `globals.css`. If a token is missing for what you need, ask the user
  whether to add it (later, via `/mstack-plan`) or pick the closest.
- **Don't ship variants with placeholder text** like "Lorem ipsum" or "Brand
  Name". Use real copy from `src/config/brand.ts` or ask the user.
