#!/usr/bin/env bash
# Find the most recent plan doc in .mstack/plans/
#
# Usage:
#   find-latest-plan.sh
#
# Prints the absolute path of the newest *.md file (by mtime), or exits 1
# with a message if .mstack/plans/ is empty or missing.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PLANS_DIR="$REPO_ROOT/.mstack/plans"

if [ ! -d "$PLANS_DIR" ]; then
  echo "error: $PLANS_DIR does not exist — run /mstack-plan first" >&2
  exit 1
fi

LATEST="$(find "$PLANS_DIR" -maxdepth 1 -type f -name '*.md' -print0 \
  | xargs -0 ls -t 2>/dev/null \
  | head -n 1)"

if [ -z "$LATEST" ]; then
  echo "error: no plan docs in $PLANS_DIR — run /mstack-plan first" >&2
  exit 1
fi

echo "$LATEST"
