#!/usr/bin/env bash
# Fixture-based tests for the mstack shared scripts.
# Creates throwaway repos under $TMPDIR and asserts on script output.
#
# Usage: scripts/test.sh   (run from the marketplace root)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

BIN="$PWD/plugins/mstack/shared/bin"
fail=0
err() { echo "FAIL  $*"; fail=1; }
ok()  { echo "ok    $*"; }

# make_repo — print the path of a fresh temp fixture dir
make_repo() { mktemp -d "${TMPDIR:-/tmp}/mstack-test.XXXXXX"; }

# assert_json <json> <jq-filter> <expected> <label>
assert_json() {
  local got
  got="$(printf '%s' "$1" | jq -r "$2" 2>/dev/null)"
  if [ "$got" = "$3" ]; then ok "$4"; else err "$4 — expected '$3' got '$got'"; fi
}

# assert_contains <file> <fixed-string> <label>
assert_contains() {
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else err "$3 — '$2' not found in $1"; fi
}

# --- tests ---

# resolver: pnpm monorepo with mobile
r=$(make_repo)
mkdir -p "$r/apps/web" "$r/apps/mobile"
touch "$r/pnpm-lock.yaml" "$r/pnpm-workspace.yaml"
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '._resolved.layout' monorepo "resolver: monorepo layout"
assert_json "$out" '._resolved.packageManager' pnpm "resolver: pnpm detected"
assert_json "$out" '.commands.dev' "pnpm dev" "resolver: pnpm dev command"
assert_json "$out" '._resolved.hasMobile' true "resolver: hasMobile from apps/mobile"
assert_json "$out" '.paths.designTokens' "packages/config/src/design.ts" "resolver: monorepo tokens path"
rm -rf "$r"

# resolver: flat npm app
r=$(make_repo)
mkdir -p "$r/src"
touch "$r/package-lock.json"
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '._resolved.layout' flat "resolver: flat layout"
assert_json "$out" '.commands.dev' "npm run dev" "resolver: npm run dev command"
assert_json "$out" '.paths.webApp' "." "resolver: flat webApp is ."
assert_json "$out" '._resolved.hasMobile' false "resolver: flat has no mobile"
rm -rf "$r"

# resolver: config override wins over auto-detection
r=$(make_repo)
mkdir -p "$r/src" "$r/.mstack"
touch "$r/package-lock.json"
cat > "$r/.mstack/config.json" <<'EOF'
{ "paths": { "designTokens": "lib/theme.ts" } }
EOF
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '.paths.designTokens' "lib/theme.ts" "resolver: config override wins"
assert_json "$out" '.paths.webApp' "." "resolver: unset keys keep auto values"
assert_json "$out" '._resolved.source' "config+auto" "resolver: source marks merge"
rm -rf "$r"

# --- summary ---
echo
if [ "$fail" = 0 ]; then echo "ALL TESTS PASSED"; else echo "TESTS FAILED"; fi
exit $fail
