#!/usr/bin/env bash
# Append a work item to the project's todo backlog (default .mstack/TODOS.md).
#
# Usage:
#   append-todo.sh <source> <text>
#
# Args:
#   source — where the item came from, e.g. "review 2026-07-04-billing",
#            "qa 2026-07-04-1030 issue 3", "code <slug>", "user"
#   text   — single-line description (quote it)
#
# Dedupes on exact text match. Creates the file with a header if missing.
# Honours paths.todos from .mstack/config.json when set.

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: append-todo.sh <source> <text>" >&2
  exit 2
fi

SOURCE="$1"
TEXT="$2"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TODOS="$ROOT/.mstack/TODOS.md"

CFG="$ROOT/.mstack/config.json"
if [ -f "$CFG" ] && command -v jq >/dev/null 2>&1; then
  OVERRIDE="$(jq -r '.paths.todos // empty' "$CFG" 2>/dev/null || true)"
  [ -n "$OVERRIDE" ] && TODOS="$ROOT/$OVERRIDE"
fi

mkdir -p "$(dirname "$TODOS")"

if [ ! -f "$TODOS" ]; then
  cat > "$TODOS" <<'EOF'
# TODOS

Captured work items — deferred review concerns, out-of-scope bugs, skipped
tasks, ideas. One line each. Prune freely. `/mstack-plan` reads this before
planning; check items off with a pointer to the plan that absorbed them.

EOF
fi

if grep -qF -- "] $TEXT — " "$TODOS"; then
  echo "already present: $TEXT"
  exit 0
fi

printf -- '- [ ] %s — *%s, %s*\n' "$TEXT" "$SOURCE" "$(date +%Y-%m-%d)" >> "$TODOS"
echo "appended to $TODOS"
