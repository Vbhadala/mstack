#!/usr/bin/env bash
# Resolve the consuming project's paths / commands / conventions for mstack skills.
#
# Precedence (lowest -> highest):
#   1. Auto-detected defaults  (package manager from lockfile, layout from dir
#      structure + deps, mobile/expo presence, ORM from deps)
#   2. <repo-root>/.mstack/config.json  (deep-merged on top; explicit wins)
#
# Prints the merged config as JSON to stdout. Skills read the keys:
#   .packageScope
#   .devUrl
#   .paths.{designTokens,globalsCss,brandSource,webApp,mobileApp,prd,roadmap,todos}
#   .commands.{dev,build,lint,typecheck,test,genMobileTw}
#   .conventions.{brandStringLiteralRule,serviceLayer,apiPrefix,orm,hardRules,tokenDrift}
#   .expo.{runtimeVersionPolicy,updateChannels,monitoring}
#   ._resolved.{packageManager,layout,hasMobile,hasExpo,source}   (informational)
#
# Layouts: monorepo (apps/web + packages/*) | flat (single app, src/) |
#          expo (standalone Expo app, expo-router app/ at root)
#
# Usage: resolve-config.sh        (run from anywhere inside the target repo)

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo '{"error":"jq is required (brew install jq)"}' >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PKG="$ROOT/package.json"

# has_dep <package.json path> <dep name> — true if listed in deps or devDeps
has_dep() {
  [ -f "$1" ] && jq -e --arg d "$2" \
    '(.dependencies[$d] // .devDependencies[$d]) != null' "$1" >/dev/null 2>&1
}

# dep_anywhere <dep name> — true if any nearby package.json mentions "<dep>"
dep_anywhere() {
  find "$ROOT" -maxdepth 3 -name package.json -not -path '*/node_modules/*' -print0 2>/dev/null \
    | xargs -0 grep -l "\"$1\"" 2>/dev/null | grep -q .
}

# --- 1. package manager (from lockfile) ---------------------------------------
if   [ -f "$ROOT/pnpm-lock.yaml" ];    then PM=pnpm
elif [ -f "$ROOT/yarn.lock" ];         then PM=yarn
elif [ -f "$ROOT/package-lock.json" ]; then PM=npm
elif [ -f "$ROOT/bun.lockb" ] || [ -f "$ROOT/bun.lock" ]; then PM=bun
else PM=pnpm; fi

case "$PM" in
  pnpm) RUN=pnpm     ;;   # `pnpm <script>` runs package scripts directly
  yarn) RUN=yarn     ;;
  npm)  RUN="npm run";;
  bun)  RUN="bun run";;
esac

# --- 2. expo presence ----------------------------------------------------------
HASEXPO=false
if has_dep "$PKG" expo || has_dep "$ROOT/apps/mobile/package.json" expo; then
  HASEXPO=true
fi

# --- 3. layout (monorepo | expo | flat) ----------------------------------------
if   [ -d "$ROOT/apps/web" ] || [ -f "$ROOT/pnpm-workspace.yaml" ]; then LAYOUT=monorepo
elif [ "$HASEXPO" = true ] && { [ -f "$ROOT/app.json" ] || ls "$ROOT"/app.config.* >/dev/null 2>&1; }; then LAYOUT=expo
else LAYOUT=flat; fi

# --- 4. mobile target ----------------------------------------------------------
if [ "$LAYOUT" = expo ] || [ -d "$ROOT/apps/mobile" ]; then HASMOBILE=true; else HASMOBILE=false; fi

# --- 5. ORM (deps in any nearby package.json, or a schema.prisma) ---------------
if   dep_anywhere drizzle-orm; then ORM=drizzle
elif dep_anywhere @prisma/client \
     || find "$ROOT" -maxdepth 4 -name schema.prisma -not -path '*/node_modules/*' 2>/dev/null | grep -q .; then ORM=prisma
else ORM=none; fi

# --- 6. package scope (from root package.json name) -----------------------------
SCOPE="@your-scope"
if [ -f "$PKG" ]; then
  NAME="$(jq -r '.name // empty' "$PKG" 2>/dev/null || true)"
  case "$NAME" in @*/*) SCOPE="${NAME%%/*}" ;; esac
fi

# --- 7. token drift mode (off unless a locked design system exists) -------------
if [ -f "$ROOT/.mstack/design-system/DESIGN.md" ]; then TOKENDRIFT=warn; else TOKENDRIFT=off; fi

# --- defaults by layout ----------------------------------------------------------
DEVSCRIPT=dev
case "$LAYOUT" in
  monorepo)
    DESIGN="packages/config/src/design.ts"
    GLOBALS="apps/web/src/app/globals.css"
    BRAND="packages/config/src/brand.ts"
    WEBAPP="apps/web"
    SERVICE="packages/services"
    ;;
  expo)
    DESIGN="src/config/design.ts"
    GLOBALS="global.css"
    BRAND="src/config/brand.ts"
    WEBAPP="."
    SERVICE="src/services"
    DEVSCRIPT=start
    ;;
  flat)
    DESIGN="src/config/design.ts"
    GLOBALS="src/app/globals.css"
    BRAND="src/config/brand.ts"
    WEBAPP="."
    SERVICE="src/services"
    ;;
esac

if [ "$HASMOBILE" = true ]; then
  if [ "$LAYOUT" = expo ]; then MOBILEAPP="."; else MOBILEAPP="apps/mobile"; fi
else
  MOBILEAPP=""
fi

if [ "$LAYOUT" = expo ]; then DEVURL="http://localhost:8081"; else DEVURL="http://localhost:3000"; fi

# --- build defaults JSON ---------------------------------------------------------
DEFAULTS="$(jq -n \
  --arg scope "$SCOPE" --arg devurl "$DEVURL" \
  --arg ds "$DESIGN" --arg gc "$GLOBALS" --arg bs "$BRAND" \
  --arg wa "$WEBAPP" --arg ma "$MOBILEAPP" --arg svc "$SERVICE" \
  --arg dev "$RUN $DEVSCRIPT" --arg build "$RUN build" --arg lint "$RUN lint" \
  --arg tc "$RUN typecheck" --arg test "$RUN test" --arg gmt "$RUN gen:mobile-tw" \
  --arg orm "$ORM" \
  --arg td "$TOKENDRIFT" \
  --arg pm "$PM" --arg layout "$LAYOUT" \
  --argjson mob "$HASMOBILE" --argjson expo "$HASEXPO" \
  '{
    packageScope: $scope,
    devUrl: $devurl,
    paths: {
      designTokens: $ds, globalsCss: $gc, brandSource: $bs,
      webApp: $wa, mobileApp: ($ma | if . == "" then null else . end),
      prd: ".mstack/product/PRD.md",
      roadmap: ".mstack/product/ROADMAP.md",
      todos: ".mstack/TODOS.md"
    },
    commands: {
      dev: $dev, build: $build, lint: $lint, typecheck: $tc,
      test: $test, genMobileTw: $gmt
    },
    conventions: {
      brandStringLiteralRule: true, serviceLayer: $svc, apiPrefix: "/api/v1",
      orm: $orm, hardRules: [], tokenDrift: $td
    },
    expo: {
      runtimeVersionPolicy: "appVersion",
      updateChannels: ["production", "preview"],
      monitoring: "none"
    },
    _resolved: { packageManager: $pm, layout: $layout, hasMobile: $mob, hasExpo: $expo, source: "auto" }
  }')"

# --- merge user config on top (explicit wins) -------------------------------------
CFG="$ROOT/.mstack/config.json"
if [ -f "$CFG" ] && jq -e 'type == "object"' "$CFG" >/dev/null 2>&1; then
  jq -r 'keys - ["$schema","_comment","_flatLayoutExample","packageScope","devUrl","paths","commands","conventions","expo"] | .[]' "$CFG" \
    | while IFS= read -r k; do
        echo "warning: unknown config key \"$k\" in .mstack/config.json — no skill reads it (typo?)" >&2
      done
  jq -s '.[0] * .[1] | ._resolved.source = "config+auto"' \
    <(printf '%s' "$DEFAULTS") "$CFG"
else
  if [ -f "$CFG" ]; then
    echo "warning: $CFG is not a JSON object — using auto-detected defaults" >&2
  fi
  printf '%s\n' "$DEFAULTS"
fi
