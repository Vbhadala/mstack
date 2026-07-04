---
name: mstack-research
description: |
  Structured tech-choice research using parallel Anthropic subagents. Produces
  a decision doc with sources (URL + date checked) and an adversarial second
  opinion, then hands off to /mstack-plan. Three scope tiers (quick / standard /
  deep) gate cost. Never edits code, never installs deps.
  Use when the user says "research X", "should we use Y or Z", "compare A vs
  B", "look up best practices for", or invokes /mstack-research. For internal
  bug investigation → /mstack-fix instead (it escalates to /mstack-debug
  when the cause isn't evident).
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - AskUserQuestion
  - Agent
  - WebSearch
  - WebFetch
---

# mstack-research

External research with parallel Anthropic subagents and a written decision
doc. Output goes to `.mstack/research/<YYYY-MM-DD-slug>.md` and feeds
`/mstack-plan`. **No code edits. No installs. No `Bash`.**

## Phase 1 — Frame the question

Use AskUserQuestion to lock down:

1. **The decision** — one sentence. ("Resend vs Postmark for transactional
   email", not "look into email".)
2. **Constraints** — pick from the checklist (multi-select):
   - bundle size / install size
   - free-tier requirement
   - license (OSS only, commercial OK, etc.)
   - data residency / EU hosting
   - the project's hard rules: `import "server-only"` boundary, Zod-compatible types,
     Drizzle-friendly schema, Next.js app router compatibility
   - existing repo patterns (don't introduce a second HTTP client, etc.)
3. **Success criteria** — what makes a winner? ("Cheapest free tier that
   supports inbound parsing", "Lowest p95 latency from EU", etc.)
4. **Scope tier** (single-select):
   - **quick** — 1 subagent, WebSearch only, ~5 min. Use for sanity-check
     questions where the answer is probably known.
   - **standard** — 2–3 subagents in parallel (WebSearch + WebFetch),
     ~15 min. Default tier.
   - **deep** — 3 subagents + adversarial second-opinion pass, ~30 min. Use
     for high-stakes decisions (auth provider, DB, billing, infra).

Write the frame to a stub file `.mstack/research/<slug>.md` so subagents can
read it.

## Phase 2 — Fan out (single message, parallel `Agent` calls)

Tier-gated. All subagents are `general-purpose` (or `Explore` for the
repo-local one). Each receives the frame stub + their lane.

**quick** — one call:
- *Docs + pricing + changelog* — WebSearch for docs/pricing/recent changes;
  WebFetch for canonical docs.

**standard** — three calls in one message:
- *Docs + pricing + changelog* (as above)
- *Community signal* — WebSearch + WebFetch for GitHub issues, HN/Reddit
  threads, recent blog posts. Surface common complaints and breakage patterns.
- *Repo-local context* — Grep the current codebase for what's already
  installed, existing patterns to extend, and any conflicting choices.

**deep** — same three + an *integration cost* call: skim each finalist's
quickstart and estimate concrete integration steps in this repo.

Each subagent prompt must demand: every fact returned carries (a) the source
URL and (b) the date the source was checked. Cached LLM knowledge alone is
not a source.

## Phase 3 — Synthesise

Collate findings into a single options table in `.mstack/research/<slug>.md`:

| Option | Free tier | Pricing at scale | License | EU hosting | Bundle size | Integration cost | Sources |

Every cell that contains a fact (not an opinion) must reference a numbered
footnote pointing to a source URL + date.

Form a **provisional recommendation** with a one-paragraph rationale tied to
the success criteria from Phase 1.

## Phase 4 — Second opinion (standard + deep)

Single `Agent` call (general-purpose). Brief it adversarially: "Here is the
recommendation and reasoning. Find the strongest counter-argument. What would
change the answer? What's the weakest fact in the table? What's a non-obvious
deal-breaker?"

If the adversary identifies a real flaw → loop back to Phase 2 with a
targeted follow-up question (one subagent, narrow scope) before finalising.
Do not bury a real counter-argument.

If the adversary's challenge holds up → mark it as a **taste decision** in
the doc and surface to the user via AskUserQuestion before finalising.

## Phase 5 — Write the doc

Final `.mstack/research/<YYYY-MM-DD-<slug>>.md` (scaffold below). Include:

- Frame (question + constraints + success criteria + tier)
- Options table with sourced facts
- Tradeoffs paragraph
- Recommendation
- Adversarial pass — what the counter-argument said and why it didn't change
  the answer (or why it did)
- Open questions — anything the doc cannot answer that `/mstack-plan` should
  surface to the user
- **Next step**: "Run `/mstack-plan` with this research doc as input."

Append a learning via `${CLAUDE_PLUGIN_ROOT}/shared/bin/append-learning.sh` if
something non-obvious surfaced (a hidden constraint, a deprecated API, a
pricing surprise).

## Phase 6 — Exit

Tell the user: "Research at `.mstack/research/<slug>.md`. Recommendation:
**<X>**. Next: `/mstack-plan` with this doc." **No code edits. No installs.**

## report.md scaffold

```markdown
# Research — <decision in one line>

**Started:** YYYY-MM-DD HH:MM
**Tier:** quick | standard | deep
**Researcher:** /mstack-research
**Status:** in_progress | ready-for-plan | needs-decision

## Frame

**Question:** …
**Constraints:** …
**Success criteria:** …

## Options

| Option | Free tier | Pricing | License | EU | Bundle | Integration | Sources |
|---|---|---|---|---|---|---|---|
| A | … | … | … | … | … | … | [1][2] |
| B | … | … | … | … | … | … | [3][4] |

### Sources

1. <url> — checked YYYY-MM-DD — <one-line summary>
2. …

## Tradeoffs

<paragraph>

## Recommendation

**<Winner>** because <one paragraph tied to success criteria>.

## Adversarial pass

**Strongest counter-argument:** …
**Outcome:** held / changed the answer / surfaced as taste decision

## Open questions

- …

## Next step

Run `/mstack-plan` and reference this doc as input.
```

## Anti-patterns

- **Don't trust cached LLM knowledge alone.** Every fact carries a URL + date.
  Pricing, free-tier limits, and API contracts change frequently.
- **Don't skip the second-opinion pass on standard or deep.** That's the whole
  point of the tier.
- **Don't edit code.** Not `package.json`, not anything. Research only.
- **Don't install dependencies** to "try it out". That belongs in
  `/mstack-plan` → `/mstack-review` → `/mstack-code`.
- **Don't fan out beyond the tier.** Quick is quick. Don't sneak two extra
  agents in because "it'd be nice to know".
- **Don't recommend without sources.** A recommendation with no sourced facts
  is an opinion, not research.
- **Don't bury the counter-argument.** If the adversarial pass found
  something real, the user sees it.
