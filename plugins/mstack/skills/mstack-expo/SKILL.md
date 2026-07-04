---
name: mstack-expo
description: |
  The Expo release/operate runway: decide OTA update vs native store build,
  run a go/no-go preflight gate (expo-doctor, versioning coherence, secrets
  per profile, native-diff check), then execute the chosen runway — EAS
  build/submit for stores or EAS Update for OTA — with explicit confirm
  gates before anything that costs money or reaches users. Also covers
  runtimeVersion policy, unified versioning, rollback, monitoring, and
  agency credential/handoff practices. Writes a release report to
  .mstack/releases/. Never edits app source code.
  Use when the user says "release the app", "ship the mobile app", "push an
  OTA update", "submit to the store", "eas build", or invokes /mstack-expo.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Bash
  - AskUserQuestion
  - WebFetch
  - WebSearch
---

# mstack-expo

Release and operate an Expo app: preflight → OTA-vs-build decision →
runway → verify → report. **No app source edits** — if the preflight finds
a code problem, hand it to `/mstack-fix` (or `/mstack-plan` when the fix
implies real scope).

## Gate — Expo target required

Run `${CLAUDE_PLUGIN_ROOT}/shared/bin/resolve-config.sh`. If
`_resolved.hasExpo` is false, abort: "No Expo target detected — /mstack-expo
needs an Expo app (expo dependency + app.json/app.config)." Keys this skill
uses: `expo.{runtimeVersionPolicy,updateChannels,monitoring}`,
`_resolved.{layout,packageManager}`, `paths.todos`. For
monorepos, work from `paths.mobileApp`.

## Knowledge rules (read before doing anything)

1. **Freshness.** EAS CLI flags, SDK behaviours, store policies, and pricing
   change constantly. For any version-sensitive fact, verify against the
   live docs (docs.expo.dev via WebFetch/WebSearch) and cite URL + date in
   the release report — same rule as `/mstack-research`. Cached knowledge
   alone is not a source for a command that spends money or publishes.
2. **Defer, don't duplicate.** If these skills are available in the
   environment, use them for their domain instead of re-deriving:
   `expo-deployment` (build/submit mechanics, store checklists, metadata),
   `expo-cicd-workflows` (workflow YAML — its live-schema validation is
   MANDATORY for any `.eas/workflows/*.yml` you touch; never trust
   hand-written YAML examples), `upgrading-expo` (SDK upgrades),
   `expo-dev-client` (internal/dev builds).
3. **Styling note for monorepo/web parity work:** `building-native-ui`'s
   "no Tailwind, inline styles" default and `expo-tailwind-setup`'s
   NativeWind stack conflict by design — the project's existing setup
   decides, never this skill.

## Phase 1 — Mode

AskUserQuestion (one batch):

- **Mode** — `release` (store build + submit) | `ota` (EAS Update push) |
  `preflight` (go/no-go check only) | `setup` (first-time release infra)
- **Platform** (release mode) — iOS | Android | both
- **Environment** — which channel/profile (offer `expo.updateChannels`;
  default the non-production channel for first runs)

Initialise `.mstack/releases/<YYYY-MM-DD-HHMM>/report.md` (scaffold below).

## Phase 2 — Preflight gate (all modes; go/no-go)

Run every check; the report records each with its evidence. ANY failure =
no-go: stop, report, and route the fix (config fixes you may propose;
source fixes go to `/mstack-fix`, or `/mstack-plan` when they imply real
scope). **Setup-mode
exception:** on a project with no release infra yet, checks 3–6 are
EXPECTED to fail — in `setup` mode their findings become the setup
worklist instead of a no-go.

1. **Doctor:** `npx expo-doctor` — must pass (warnings are findings).
2. **Git state:** clean tree, and confirm the branch/commit the user
   intends to release.
3. **Versioning coherence** (see table below): read `app.json`/
   `app.config.*` + `eas.json`; confirm `version`, iOS `buildNumber` /
   Android `versionCode` handling (`autoIncrement` + `appVersionSource`),
   and that `runtimeVersion` policy matches `expo.runtimeVersionPolicy`
   from config. Mismatch = no-go.
4. **Secrets per profile:** `eas env:list --environment <env>` for the
   target profile — every `EXPO_PUBLIC_`/server var the app reads must
   exist in that profile, and no secret may live in the repo.
5. **Native-diff check (ota mode only):** compare against the native build
   currently in users' hands (its git tag/commit if recorded in the last
   release report): any change to native modules (package.json deps with
   native code), `app.json`/`app.config.*` plugins or permissions, or the
   Expo SDK version since that build = **OTA-unsafe** → switch to release
   mode (see decision table).
6. **Store metadata completeness (release mode only):** defer to
   `expo-deployment`'s store checklists; verify the blocking items
   (privacy policy URL, screenshots, age rating, release notes).

## The OTA vs native-build decision

| Change since the shipped native build | OTA safe? |
|---|---|
| JS/TS code, styles, assets, copy | yes — OTA |
| JS-only dependency added/updated | yes — OTA |
| Native module added/removed/updated | **no — native build** |
| `app.json` plugin, permission, entitlement, icon/splash change | **no — native build** |
| Expo SDK upgrade | **no — native build** |
| `expo-updates` config or `runtimeVersion` change | **no — native build** |

When in doubt, the fingerprint answers it: with
`runtimeVersion.policy: "fingerprint"`, an incompatible update simply won't
apply — but don't rely on that as a safety net for a knowingly-native
change. **If you're arguing about whether a change is "really" native, it's
a native build.**

## runtimeVersion + versioning (the unified story)

- `expo.runtimeVersionPolicy` = `appVersion` (simple: OTA reaches every
  build sharing the marketing version — bump `version` on every native
  change) or `fingerprint` (safest: computed from native project state).
  `setup` mode writes the chosen policy into `app.json` and records it in
  config.
- One source of truth per release: `version` (marketing, human-bumped) ·
  `buildNumber`/`versionCode` (machine-bumped — use `autoIncrement` with
  `appVersionSource: "remote"`) · `runtimeVersion` (derived by policy,
  never hand-edited). The preflight's coherence check enforces this
  triangle; drift between them is how OTAs silently stop applying.

## Phase 3 — Runways

Every command that **spends money or reaches users** (`eas build`,
`eas submit`, `eas update` to any channel users are on) gets its own
AskUserQuestion confirm showing the exact command first. No exceptions,
even when the user "already said go".

**release:** confirm version bump → `eas build --profile <profile>
--platform <ios|android|all>` → on success `eas submit` (or the build's
auto-submit) → TestFlight / Play track per `expo-deployment`'s checklists →
record build IDs + store status in the report.

**ota:** publish to the preview channel first → verify on a device/simulator
build pointed at that channel → confirm → `eas update --channel <prod>
--message "<slug>"` → record the update group ID → watch monitoring (below)
→ **rollback path:** `eas update:republish` the previous known-good group
(verify the current CLI rollback command against live docs first — it
changes).

**preflight:** stop after Phase 2; report is the deliverable.

**setup:** propose (never silently write): `eas.json` build profiles
(development/preview/production) mapped to `expo.updateChannels`,
`runtimeVersion` policy, `autoIncrement`, monitoring wiring (below), and a
`.eas/workflows/` CI pipeline — validated via `expo-cicd-workflows` before
committing. Config file edits here require explicit user confirmation
per file.

## Monitoring + the rollback trigger

If `expo.monitoring` is `none`, recommend Sentry (`@sentry/react-native`
via its Expo config plugin) in the report — an agency shipping OTA updates
without crash reporting is flying blind. If monitoring exists: after any
production OTA or store release, state the watch rule in the report —
"crash-free sessions drop below ~99% in the first hours → roll back first,
investigate second."

## Agency practices (credentials + client handoff)

- **One client, one account:** each client app lives in its own Apple
  Developer + Google Play account (and its own EAS project). Never submit
  one client's app from another's account; never share distribution certs
  across clients. Credentials live in EAS (`eas credentials`), never in
  the repo.
- **Handoff checklist** (include in the report for a client's first
  release): who owns the Apple/Google accounts; who responds to App Review;
  agreed SLA for hotfix-OTA vs store-review fixes; who holds the EAS org;
  where monitoring alerts go.

## Report + close the loop

`report.md` scaffold:

```markdown
# Release — <mode> <YYYY-MM-DD HH:MM>

**App:** <name> · **Platform:** <ios|android|both> · **Channel/profile:** <x>
**Mode:** release | ota | preflight | setup
**Status:** go | no-go | shipped | rolled-back
**Versions:** version <x> · build <n> · runtimeVersion <policy: value>
**Commit:** <sha> · **Build/Update IDs:** <ids or —>

## Preflight
| Check | Result | Evidence |
|---|---|---|
| expo-doctor | pass/fail | <output tail> |
| … | | |

## Decision
<OTA vs build, and why — cite the table row>

## Execution log
<commands run + confirm gates, with output tails>

## Sources
<url — checked YYYY-MM-DD — fact it verified>

## Follow-ups
<…>
```

Then: append Follow-ups to the backlog
(`${CLAUDE_PLUGIN_ROOT}/shared/bin/append-todo.sh "expo <run>" "<item>"`),
append a learning for anything non-obvious (`append-learning.sh`), and if
this release shipped a plan's feature, remind the user `/mstack-ship`
handles the web PR side.

## Red flags — you are rationalizing

| Thought | Reality |
|---|---|
| "It's a tiny native tweak — OTA will probably work" | The decision table has no "probably" row. Native change = native build. |
| "The user already approved the release — skip the per-command confirm" | `eas build` costs money; `eas update` reaches users in minutes. Show the exact command, every time. |
| "I know the EAS CLI — no need to check the docs" | Flags and rollback commands change between CLI versions. Verify version-sensitive facts live, with URL + date. |
| "Preflight passed last week" | Evidence expires. Every release gets a fresh preflight in this session. |
| "I'll reuse the other client's credentials, it's faster" | Cross-client credentials are a breach of client trust and Apple/Google ToS. One client, one account. |

## Anti-patterns

- **Don't edit app source code.** Preflight findings route to
  `/mstack-fix` / `/mstack-plan`; config-file changes (app.json,
  eas.json) only in `setup` mode with per-file confirmation.
- **Don't publish an OTA to production without a preview-channel pass.**
- **Don't hand-write `.eas/workflows/*.yml` without schema validation**
  (via `expo-cicd-workflows` where available).
- **Don't store secrets or credentials in the repo.** EAS env + EAS
  credentials own them.
- **Don't bypass a failed preflight check** — go/no-go means no-go.
