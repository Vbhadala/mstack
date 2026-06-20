#!/usr/bin/env bash
# Resolve the consuming project's paths / commands / conventions for mstack skills.
#
# Precedence (lowest -> highest):
#   1. Auto-detected defaults  (package manager from lockfile, layout from dir
#      structure, mobile presence)
#   2. <repo-root>/.mstack/config.json  (deep-merged on top; explicit wins)
#
# Prints the merged config as JSON to stdout. Skills read the keys:
#   .packageScope
#   .paths.{designTokens,globalsCss,brandSource,webApp,mobileApp}
#   .commands.{dev,build,lint,typecheck,test,genMobileTw}
#   .conventions.{brandStringLiteralRule,serviceLayer,apiPrefix}
#   ._resolved.{packageManager,layout,hasMobile,source}   (informational)
#
# Usage: resolve-config.sh        (run from anywhere inside the target repo)

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo '{"error":"jq is required (brew install jq)"}' >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# --- 1. package manager (from lockfile) ---------------------------------------
if   [ -f "$ROOT/pnpm-lock.yaml" ];    then PM=pnpm
elif [ -f "$ROOT/yarn.lock" ];         then PM=yarn
elif [ -f "$ROOT/package-lock.json" ]; then PM=npm
elif [ -f "$ROOT/bun.lockb" ];         then PM=bun
else PM=pnpm; fi

case "$PM" in
  pnpm) RUN=pnpm     ;;   # `pnpm <script>` runs package scripts directly
  yarn) RUN=yarn     ;;
  npm)  RUN="npm run";;
  bun)  RUN="bun run";;
esac

# --- 2. layout (monorepo vs flat) ---------------------------------------------
if   [ -d "$ROOT/apps/web" ] || [ -f "$ROOT/pnpm-workspace.yaml" ]; then LAYOUT=monorepo
elif [ -d "$ROOT/src" ];                                            then LAYOUT=flat
else LAYOUT=monorepo; fi

# --- 3. mobile target ----------------------------------------------------------
if [ -d "$ROOT/apps/mobile" ]; then HASMOBILE=true; else HASMOBILE=false; fi

# --- defaults by layout --------------------------------------------------------
if [ "$LAYOUT" = monorepo ]; then
  DESIGN="packages/config/src/design.ts"
  GLOBALS="apps/web/src/app/globals.css"
  BRAND="packages/config/src/brand.ts"
  WEBAPP="apps/web"
  SERVICE="packages/services"
else
  DESIGN="src/config/design.ts"
  GLOBALS="src/app/globals.css"
  BRAND="src/config/brand.ts"
  WEBAPP="."
  SERVICE="src/services"
fi
if [ "$HASMOBILE" = true ]; then MOBILEAPP="apps/mobile"; else MOBILEAPP=""; fi

# --- build defaults JSON -------------------------------------------------------
DEFAULTS="$(jq -n \
  --arg ds "$DESIGN" --arg gc "$GLOBALS" --arg bs "$BRAND" \
  --arg wa "$WEBAPP" --arg ma "$MOBILEAPP" --arg svc "$SERVICE" \
  --arg dev "$RUN dev" --arg build "$RUN build" --arg lint "$RUN lint" \
  --arg tc "$RUN typecheck" --arg test "$RUN test" --arg gmt "$RUN gen:mobile-tw" \
  --arg pm "$PM" --arg layout "$LAYOUT" --argjson mob "$HASMOBILE" \
  '{
    packageScope: "@your-scope",
    paths: {
      designTokens: $ds, globalsCss: $gc, brandSource: $bs,
      webApp: $wa, mobileApp: ($ma | if . == "" then null else . end)
    },
    commands: {
      dev: $dev, build: $build, lint: $lint, typecheck: $tc,
      test: $test, genMobileTw: $gmt
    },
    conventions: { brandStringLiteralRule: true, serviceLayer: $svc, apiPrefix: "/api/v1" },
    _resolved: { packageManager: $pm, layout: $layout, hasMobile: $mob, source: "auto" }
  }')"

# --- merge user config on top (explicit wins) ---------------------------------
CFG="$ROOT/.mstack/config.json"
if [ -f "$CFG" ] && jq empty "$CFG" >/dev/null 2>&1; then
  jq -s '.[0] * .[1] | ._resolved.source = "config+auto"' \
    <(printf '%s' "$DEFAULTS") "$CFG"
else
  printf '%s\n' "$DEFAULTS"
fi
