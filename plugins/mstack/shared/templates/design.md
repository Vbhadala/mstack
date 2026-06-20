# Design System: {{BRAND_NAME}}

**Date:** {{DATE}}
**Slug:** {{SLUG}}
**Status:** locked
**Mode:** {{MODE}}  <!-- from-scratch | rebrand | evolve -->
**References:** {{REFERENCES}}  <!-- short list: "Linear screenshot, Stripe.com, brief" -->

---

## Brand

- **Name:** {{BRAND_NAME}}
- **Tagline:** {{TAGLINE}}
- **Voice:** {{VOICE}}  <!-- e.g. "terse, technical, dry humour" -->
- **Aesthetic:** {{AESTHETIC}}  <!-- minimal | editorial | dense-utility | playful | brutalist | luxe -->

## Color

Source of truth lives in `packages/config/src/design.ts` and mirrors to
`apps/web/src/app/globals.css`. Mobile tokens are **generated** from
`design.ts` via `pnpm gen:mobile-tw`.

### Palette (light)

| Token | OKLCH | Hex (sRGB) | Notes |
| --- | --- | --- | --- |
| background | `oklch(…)` | `#…` | |
| foreground | `oklch(…)` | `#…` | |
| primary | `oklch(…)` | `#…` | |
| primaryForeground | `oklch(…)` | `#…` | |
| secondary | `oklch(…)` | `#…` | |
| muted / mutedForeground | `oklch(…)` | `#…` | |
| accent | `oklch(…)` | `#…` | |
| destructive | `oklch(…)` | `#…` | |
| success | `oklch(…)` | `#…` | project addition |
| warning | `oklch(…)` | `#…` | project addition |
| border / input / ring | `oklch(…)` | `#…` | |

### Palette (dark)

(same shape, dark values)

### Contrast notes

- AA pass / fail for every text-on-surface pair.
- Document deliberate exemptions (e.g. white-on-orange brand CTA) and link
  to `scripts/check-contrast.ts` allowlist.

## Typography

- **Sans:** `{{FONT_SANS}}` (fallback: `system-ui, sans-serif`)
- **Display:** `{{FONT_DISPLAY}}`
- **Mono:** `{{FONT_MONO}}` (fallback: `ui-monospace, monospace`)
- **Where to install:** Next.js `next/font` for web; Expo Font for mobile.
  List font files / Google Fonts handles here.

### Scale

| Step | Size | Line height | Use |
| --- | --- | --- | --- |
| xs | 0.75rem | 1rem | meta, badges |
| sm | 0.875rem | 1.25rem | secondary body |
| base | 1rem | 1.5rem | body |
| lg | 1.125rem | 1.75rem | lead |
| xl | 1.25rem | 1.75rem | section heading |
| 2xl | 1.5rem | 2rem | page heading |
| 3xl | 1.875rem | 2.25rem | hero sub |
| 4xl | 2.25rem | 2.5rem | hero |

## Radius

`--radius` base value drives sm/md/lg/xl via calc. Document the chosen base
and why (sharp = `0.25rem`, modern = `0.625rem`, rounded = `1rem`).

## Spacing

Tailwind defaults are kept. Notable deviations (if any) listed here.

## Motion

| Token | Value | Use |
| --- | --- | --- |
| durations.instant | 75ms | micro-feedback (icon flips) |
| durations.fast | 150ms | hover, focus |
| durations.normal | 250ms | menus, modals |
| durations.slow | 400ms | hero transitions |
| easings.out | `cubic-bezier(0.16, 1, 0.3, 1)` | enter |
| easings.in | `cubic-bezier(0.7, 0, 0.84, 0)` | exit |
| easings.inOut | `cubic-bezier(0.83, 0, 0.17, 1)` | move |

## Surfaces covered

- [ ] Web (Next.js, `apps/web`)
- [ ] Mobile (Expo + NativeWind, `apps/mobile`)
- [ ] Email (React Email — uses `brand.emailColors` hex fallbacks)

## How this flows into code

1. Tokens edited in `packages/config/src/design.ts` (OKLCH).
2. `apps/web/src/app/globals.css` mirrors values as CSS vars.
3. `pnpm gen:mobile-tw` regenerates `apps/mobile/tailwind.config.js`.
4. `pnpm check-contrast` guards AA (with documented exemptions).
5. `packages/config/src/brand.ts` carries name / tagline / hex fallbacks
   for email templates.

`/mstack-mockup` and downstream feature work consume these tokens; do not
fork them per feature.

## Preview

- `.mstack/design-system/preview-light.html`
- `.mstack/design-system/preview-dark.html`

## Decisions worth remembering

- {{DECISIONS}}  <!-- short bullets, what was rejected and why -->

## Open questions

- {{OPEN_QUESTIONS}}
