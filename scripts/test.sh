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

# append-todo: creates file with header, appends entry
r=$(make_repo)
(cd "$r" && "$BIN/append-todo.sh" "qa 2026-07-04 issue 3" "Fix login redirect loop on Safari" >/dev/null)
assert_contains "$r/.mstack/TODOS.md" "# TODOS" "append-todo: header created"
assert_contains "$r/.mstack/TODOS.md" "- [ ] Fix login redirect loop on Safari — *qa 2026-07-04 issue 3, " "append-todo: entry format"

# append-todo: dedupes on exact text
(cd "$r" && "$BIN/append-todo.sh" "user" "Fix login redirect loop on Safari" >/dev/null)
n="$(grep -c 'Fix login redirect loop' "$r/.mstack/TODOS.md")"
if [ "$n" = 1 ]; then ok "append-todo: dedupe"; else err "append-todo: dedupe — $n entries"; fi
rm -rf "$r"

# append-todo: honours config paths.todos override
r=$(make_repo)
mkdir -p "$r/.mstack"
echo '{ "paths": { "todos": "BACKLOG.md" } }' > "$r/.mstack/config.json"
(cd "$r" && "$BIN/append-todo.sh" "user" "Rate-limit invite endpoint" >/dev/null)
assert_contains "$r/BACKLOG.md" "Rate-limit invite endpoint" "append-todo: paths.todos override"
rm -rf "$r"

# append-todo: usage error without args
if "$BIN/append-todo.sh" onlyone >/dev/null 2>&1; then
  err "append-todo: should exit 2 without two args"
else
  ok "append-todo: usage error"
fi

# append-todo: shorter text that is a substring of an existing entry is NOT deduped
r=$(make_repo)
(cd "$r" && "$BIN/append-todo.sh" "user" "Fix login redirect loop on Safari" >/dev/null)
(cd "$r" && "$BIN/append-todo.sh" "user" "Fix login" >/dev/null)
n="$(grep -c '^- \[ \]' "$r/.mstack/TODOS.md")"
if [ "$n" = 2 ]; then ok "append-todo: substring text not deduped"; else err "append-todo: substring text not deduped — $n entries"; fi
rm -rf "$r"

# pipeline-status: table row per plan with next-step recommendation
r=$(make_repo)
mkdir -p "$r/.mstack/plans" "$r/.mstack/reviews" "$r/.mstack/code/2026-07-01-billing"
printf '# Plan: billing\n\n**Status:** reviewed\n' > "$r/.mstack/plans/2026-07-01-billing.md"
printf '# Review: billing\n\n**Status:** approved\n' > "$r/.mstack/reviews/2026-07-01-billing.md"
printf '**Status:** in_progress\n\n- [x] **Task 1:** a\n- [ ] **Task 2:** b\n' > "$r/.mstack/code/2026-07-01-billing/tasks.md"
printf '# Plan: onboarding\n\n**Status:** draft\n' > "$r/.mstack/plans/2026-07-02-onboarding.md"
if out="$(cd "$r" && "$BIN/pipeline-status.sh")"; then ok "pipeline-status: exit 0 without qa runs"; else err "pipeline-status: nonzero exit without qa runs"; fi
if echo "$out" | grep -q '2026-07-01-billing | reviewed | approved | in_progress (1/2) | /mstack-code'; then
  ok "pipeline-status: billing row"
else
  err "pipeline-status: billing row missing/wrong: $out"
fi
if echo "$out" | grep -q '2026-07-02-onboarding | draft | — | — | /mstack-review'; then
  ok "pipeline-status: draft row"
else
  err "pipeline-status: draft row missing/wrong"
fi
if echo "$out" | grep -q 'Do not edit'; then
  ok "pipeline-status: generated header"
else
  err "pipeline-status: generated header missing"
fi
rm -rf "$r"

# pipeline-status: counts open todos
r=$(make_repo)
mkdir -p "$r/.mstack/plans"
printf '# Plan: x\n\n**Status:** draft\n' > "$r/.mstack/plans/2026-07-01-x.md"
printf '# TODOS\n\n- [ ] one\n- [ ] two\n- [x] done\n' > "$r/.mstack/TODOS.md"
out="$(cd "$r" && "$BIN/pipeline-status.sh")"
if echo "$out" | grep -q 'Open todos:\*\* 2'; then
  ok "pipeline-status: todo count"
else
  err "pipeline-status: todo count wrong"
fi
rm -rf "$r"

# pipeline-status: graceful with no .mstack
r=$(make_repo)
out="$(cd "$r" && "$BIN/pipeline-status.sh")"
if echo "$out" | grep -q 'No .mstack directory'; then
  ok "pipeline-status: empty repo message"
else
  err "pipeline-status: empty repo message missing"
fi
rm -rf "$r"

# resolver: valid-JSON non-object config degrades to defaults
r=$(make_repo)
mkdir -p "$r/src" "$r/.mstack"; touch "$r/package-lock.json"
echo '[1,2]' > "$r/.mstack/config.json"
if out="$(cd "$r" && "$BIN/resolve-config.sh" 2>"$r/stderr.txt")"; then
  ok "resolver: non-object config exits 0"
else
  err "resolver: non-object config exits 0"
fi
assert_json "$out" '._resolved.source' auto "resolver: non-object config uses defaults"
assert_contains "$r/stderr.txt" "not a JSON object" "resolver: non-object config warns"
rm -rf "$r"

# resolver: expo defaults block present
r=$(make_repo)
mkdir -p "$r/src"; touch "$r/package-lock.json"
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '.expo.runtimeVersionPolicy' appVersion "resolver: expo default policy"
assert_json "$out" '.expo.updateChannels | length' 2 "resolver: expo default channels"
assert_json "$out" '.expo.monitoring' none "resolver: expo default monitoring"
rm -rf "$r"

# resolver: expo config override merges, no unknown-key warning
r=$(make_repo)
mkdir -p "$r/src" "$r/.mstack"; touch "$r/package-lock.json"
echo '{ "expo": { "runtimeVersionPolicy": "fingerprint" } }' > "$r/.mstack/config.json"
out="$(cd "$r" && "$BIN/resolve-config.sh" 2>"$r/stderr.txt")"
assert_json "$out" '.expo.runtimeVersionPolicy' fingerprint "resolver: expo policy override"
assert_json "$out" '.expo.updateChannels | length' 2 "resolver: expo merge keeps defaults"
if grep -q "unknown config key" "$r/stderr.txt"; then
  err "resolver: expo key wrongly flagged unknown"
else
  ok "resolver: expo key known"
fi
rm -rf "$r"

# resolver: tokenDrift auto off / warn by DESIGN.md, block via config
r=$(make_repo)
mkdir -p "$r/src"; touch "$r/package-lock.json"
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '.conventions.tokenDrift' off "resolver: tokenDrift off without DESIGN.md"
mkdir -p "$r/.mstack/design-system"; echo "# design" > "$r/.mstack/design-system/DESIGN.md"
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '.conventions.tokenDrift' warn "resolver: tokenDrift warn with DESIGN.md"
mkdir -p "$r/.mstack"
echo '{ "conventions": { "tokenDrift": "block" } }' > "$r/.mstack/config.json"
out="$(cd "$r" && "$BIN/resolve-config.sh")"
assert_json "$out" '.conventions.tokenDrift' block "resolver: tokenDrift config override"
rm -rf "$r"

# token-drift: off mode is silent and exits 0
r=$(make_repo)
mkdir -p "$r/src"; touch "$r/package-lock.json"
printf 'export const x = { color: "#ff0000" }\n' > "$r/src/foo.ts"
if (cd "$r" && "$BIN/check-token-drift.sh" src/foo.ts 2>"$r/e"); then
  ok "drift: off exits 0"
else
  err "drift: off exits 0"
fi
if [ -s "$r/e" ]; then err "drift: off is silent"; else ok "drift: off is silent"; fi

# token-drift: warn mode reports on stderr, exits 0
mkdir -p "$r/.mstack/design-system"; echo "# d" > "$r/.mstack/design-system/DESIGN.md"
if (cd "$r" && "$BIN/check-token-drift.sh" src/foo.ts 2>"$r/e"); then
  ok "drift: warn exits 0"
else
  err "drift: warn exits 0"
fi
assert_contains "$r/e" "src/foo.ts" "drift: warn reports the file"

# token-drift: block mode exits 1 on findings
mkdir -p "$r/.mstack"
echo '{ "conventions": { "tokenDrift": "block" } }' > "$r/.mstack/config.json"
if (cd "$r" && "$BIN/check-token-drift.sh" src/foo.ts 2>/dev/null); then
  err "drift: block exits 1 on findings"
else
  ok "drift: block exits 1 on findings"
fi

# token-drift: the token file itself is excluded
echo '{ "conventions": { "tokenDrift": "block" }, "paths": { "designTokens": "src/foo.ts" } }' > "$r/.mstack/config.json"
if (cd "$r" && "$BIN/check-token-drift.sh" src/foo.ts 2>/dev/null); then
  ok "drift: token file excluded"
else
  err "drift: token file excluded"
fi

# token-drift: clean file passes block mode
echo '{ "conventions": { "tokenDrift": "block" } }' > "$r/.mstack/config.json"
printf 'export const y = 1\n' > "$r/src/clean.ts"
if (cd "$r" && "$BIN/check-token-drift.sh" src/clean.ts 2>/dev/null); then
  ok "drift: clean file passes block"
else
  err "drift: clean file passes block"
fi
rm -rf "$r"

# --- summary ---
echo
if [ "$fail" = 0 ]; then echo "ALL TESTS PASSED"; else echo "TESTS FAILED"; fi
exit $fail
