# Frontend craft

The shared definition of "good" for every mstack skill that designs,
implements, or critiques UI (`/mstack-mockup`, `/mstack-code` on
UI-significant tasks, `/mstack-ux-audit`). One taste, three enforcement
points. Every rule is checkable — if you can't check it, it's not here.

## Hierarchy

- One primary action per screen. If two things scream, nothing does.
- Size, weight, and color encode importance — in that order. Don't reach
  for color when weight would do.
- Heading levels are structure, not styling: no skipped levels, no h3
  because "h2 looked too big".
- The most important content sits where the eye lands first (top-left in
  LTR, first card, above the fold). Decoration never does.

## Spacing

- Every gap comes from the spacing scale. If the scale lacks the gap you
  want, the design is wrong or the scale is — flag it, don't hardcode.
- Whitespace is grouping: related things closer, unrelated things farther.
  A screen with uniform gaps everywhere has no structure.
- Density is a decision per surface (dashboards dense, marketing airy),
  not an accident per component.

## States first

- Design/implement empty, loading, and error BEFORE the happy path. The
  happy path is the easy 20%.
- Every empty state names the next action ("No invoices yet — create your
  first"), never just "No data".
- Loading: skeletons that hold layout over spinners that don't. No layout
  shift when content lands.
- Errors say what happened AND what to do next, in the user's words.

## Typography

- Sizes and weights come from the type scale only. Emphasis within a level
  uses weight, not a one-off size.
- Body line length 45–75 characters. Line height ≥1.4 for body, tighter
  for headings.
- Never more than two typefaces on a screen (the tokens define them).

## Color

- Semantic tokens only (`--primary`, `--destructive`, `--muted`…) — never
  raw hex in components (the token-drift check enforces this).
- One accent per screen does the "look here" work; the rest is neutral
  spine.
- Text contrast meets WCAG AA. A deliberate brand exemption is documented
  in DESIGN.md, not improvised per screen.

## Copy

- CTAs are verb-led and specific: "Start free trial", not "Click here" or
  "Submit".
- No jargon the persona wouldn't use. No "please" padding, no exclamation
  marks doing enthusiasm's job.
- Buttons say what happens; titles say what this is; errors say what to do.

## Motion

- Fast (150–250ms) and purposeful (enter/exit, state change) — never
  decorative loops.
- Respect `prefers-reduced-motion`: everything must work with motion off.

## Mobile / touch

- Tap targets ≥44px. Primary actions in thumb reach (bottom half).
- Safe areas respected — nothing under the notch or home indicator.
- Test the 320px-width case: if it breaks, the layout was rigid, not
  responsive.

## Anti-slop (never ship these)

- Gradient hero + emoji bullets + "Supercharge your workflow" copy — the
  generic AI-landing-page look.
- Emoji as icons, stock illustrations as filler, decorative blobs.
- Glassmorphism/heavy shadows by default — effects need a reason.
- Centered-everything layouts that dodge hierarchy decisions.
- Five shades of the accent color doing jobs the neutral spine should do.
- "Modern dashboard" tropes: stat cards nobody asked for, charts without a
  question they answer.

## The check

Before calling any screen done, answer: What's the ONE primary action?
Which state am I looking at, and do the other three exist? Does every
color/size/gap come from a token? Would the persona understand every word?
