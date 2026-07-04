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

# resolver: standalone Expo app (yarn, scoped name)
r=$(make_repo)
mkdir -p "$r/app"
cat > "$r/package.json" <<'EOF'
{ "name": "@acme/client-app", "dependencies": { "expo": "~52.0.0" } }
EOF
touch "$r/app.json" "$r/yarn.lock"
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '._resolved.layout' expo "resolver: expo layout"
assert_json "$out" '._resolved.hasExpo' true "resolver: hasExpo"
assert_json "$out" '._resolved.hasMobile' true "resolver: expo implies mobile"
assert_json "$out" '.devUrl' "http://localhost:8081" "resolver: expo devUrl 8081"
assert_json "$out" '.commands.dev' "yarn start" "resolver: expo dev is start script"
assert_json "$out" '.packageScope' "@acme" "resolver: scope from package name"
assert_json "$out" '.paths.mobileApp' "." "resolver: expo mobileApp is ."
rm -rf "$r"

# resolver: monorepo with expo in apps/mobile
r=$(make_repo)
mkdir -p "$r/apps/web" "$r/apps/mobile"
touch "$r/pnpm-lock.yaml"
cat > "$r/apps/mobile/package.json" <<'EOF'
{ "name": "mobile", "dependencies": { "expo": "~52.0.0" } }
EOF
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '._resolved.layout' monorepo "resolver: monorepo beats expo"
assert_json "$out" '._resolved.hasExpo' true "resolver: hasExpo in monorepo mobile"
assert_json "$out" '.devUrl' "http://localhost:3000" "resolver: monorepo devUrl 3000"
rm -rf "$r"

# resolver: ORM detection — prisma
r=$(make_repo)
mkdir -p "$r/src"
touch "$r/package-lock.json"
cat > "$r/package.json" <<'EOF'
{ "name": "app", "dependencies": { "@prisma/client": "^5.0.0" } }
EOF
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '.conventions.orm' prisma "resolver: prisma from deps"
rm -rf "$r"

# resolver: ORM detection — drizzle in a workspace package
r=$(make_repo)
mkdir -p "$r/apps/web" "$r/packages/db"
touch "$r/pnpm-lock.yaml"
cat > "$r/packages/db/package.json" <<'EOF'
{ "name": "db", "dependencies": { "drizzle-orm": "^0.36.0" } }
EOF
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '.conventions.orm' drizzle "resolver: drizzle in workspace pkg"
rm -rf "$r"

# resolver: ORM detection — none
r=$(make_repo)
mkdir -p "$r/src"; touch "$r/package-lock.json"
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '.conventions.orm' none "resolver: orm none by default"
assert_json "$out" '.conventions.hardRules | length' 0 "resolver: hardRules default empty"
assert_json "$out" '.paths.todos' ".mstack/TODOS.md" "resolver: todos default path"
assert_json "$out" '.paths.prd' ".mstack/product/PRD.md" "resolver: prd default path"
rm -rf "$r"

# resolver: devUrl + hardRules config override
r=$(make_repo)
mkdir -p "$r/src" "$r/.mstack"; touch "$r/package-lock.json"
cat > "$r/.mstack/config.json" <<'EOF'
{ "devUrl": "http://localhost:4000", "conventions": { "hardRules": ["No fetch in components"] } }
EOF
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '.devUrl' "http://localhost:4000" "resolver: devUrl override"
assert_json "$out" '.conventions.hardRules[0]' "No fetch in components" "resolver: hardRules override"
rm -rf "$r"

# resolver: unknown top-level config key warns on stderr
r=$(make_repo)
mkdir -p "$r/src" "$r/.mstack"; touch "$r/package-lock.json"
echo '{ "pathz": {} }' > "$r/.mstack/config.json"
(cd "$r" && "$BIN/resolve-config.sh" >/dev/null 2>"$r/stderr.txt")
assert_contains "$r/stderr.txt" "unknown config key" "resolver: unknown key warning"
rm -rf "$r"

# resolver: empty dir defaults to flat (0.3.0 contract change)
r=$(make_repo)
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '._resolved.layout' flat "resolver: empty dir defaults flat"
rm -rf "$r"

# find-latest-plan: newest by filename date, not mtime
r=$(make_repo)
mkdir -p "$r/.mstack/plans"
echo x > "$r/.mstack/plans/2026-03-01-newer.md"
echo x > "$r/.mstack/plans/2026-01-01-older.md"
# equalise mtimes the wrong way round (older file touched later)
touch -t 202601010000 "$r/.mstack/plans/2026-03-01-newer.md"
touch -t 202606010000 "$r/.mstack/plans/2026-01-01-older.md"
got="$(cd "$r" && "$BIN/find-latest-plan.sh")"
case "$got" in
  */2026-03-01-newer.md) ok "find-latest-plan: name order wins" ;;
  *) err "find-latest-plan: expected 2026-03-01-newer.md, got $got" ;;
esac
rm -rf "$r"

# find-latest-plan: errors when empty
r=$(make_repo)
mkdir -p "$r/.mstack/plans"
if (cd "$r" && "$BIN/find-latest-plan.sh" >/dev/null 2>&1); then
  err "find-latest-plan: should exit 1 on empty dir"
else
  ok "find-latest-plan: errors on empty dir"
fi
rm -rf "$r"

# --- summary ---
echo
if [ "$fail" = 0 ]; then echo "ALL TESTS PASSED"; else echo "TESTS FAILED"; fi
exit $fail
