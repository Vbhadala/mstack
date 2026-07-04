#!/usr/bin/env bash
# Check files for raw color literals outside the design-token layer.
#
# Usage:
#   check-token-drift.sh <file>...   check the given files (repo-relative or absolute)
#   check-token-drift.sh             check files changed vs HEAD (git diff --name-only)
#
# Mode from resolved config (conventions.tokenDrift):
#   off   -> exit 0 silently, no scan
#   warn  -> findings to stderr, exit 0
#   block -> findings to stderr, exit 1 if any
#
# Scans .ts/.tsx/.js/.jsx/.css/.scss, skipping the resolved token files
# (designTokens, globalsCss, brandSource), tests/specs, tailwind configs.
# Detects: hex colors (#fff, #ff0000, #ff0000cc), rgb()/rgba()/hsl()/hsla().

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

CFG_JSON="$("$DIR/resolve-config.sh")"
MODE="$(printf '%s' "$CFG_JSON" | jq -r '.conventions.tokenDrift // "off"')"
if [ "$MODE" = off ]; then
  exit 0
fi

TOKENS="$(printf '%s' "$CFG_JSON" | jq -r '.paths.designTokens // empty')"
GLOBALS="$(printf '%s' "$CFG_JSON" | jq -r '.paths.globalsCss // empty')"
BRAND="$(printf '%s' "$CFG_JSON" | jq -r '.paths.brandSource // empty')"

if [ "$#" -gt 0 ]; then
  FILES="$(printf '%s\n' "$@")"
else
  FILES="$(git -C "$ROOT" diff --name-only HEAD 2>/dev/null || true)"
fi
if [ -z "$FILES" ]; then
  exit 0
fi

findings=0
while IFS= read -r f; do
  if [ -z "$f" ]; then continue; fi
  rel="${f#"$ROOT"/}"
  case "$rel" in
    "$TOKENS" | "$GLOBALS" | "$BRAND") continue ;;
    *.test.* | *.spec.* | *node_modules* | *tailwind.config.*) continue ;;
    *.ts | *.tsx | *.js | *.jsx | *.css | *.scss) ;;
    *) continue ;;
  esac
  abs="$f"
  if [ ! -f "$abs" ]; then abs="$ROOT/$rel"; fi
  if [ ! -f "$abs" ]; then continue; fi
  hits="$(grep -nE '#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?\b|#[0-9a-fA-F]{3}\b|rgba?\(|hsla?\(' "$abs" 2>/dev/null | grep -vE '(rgba?|hsla?)\( *var\(' || true)"
  if [ -n "$hits" ]; then
    while IFS= read -r line; do
      echo "token-drift: $rel:$line" >&2
      findings=$((findings + 1))
    done <<EOF
$hits
EOF
  fi
done <<EOF
$FILES
EOF

if [ "$findings" -gt 0 ]; then
  echo "token-drift: $findings raw color literal(s) outside the token layer (mode: $MODE) — use design tokens instead" >&2
  if [ "$MODE" = block ]; then
    exit 1
  fi
fi
exit 0
