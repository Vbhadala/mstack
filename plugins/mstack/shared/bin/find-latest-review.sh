#!/usr/bin/env bash
# Find the most recent review doc in .mstack/reviews/
#
# Usage:
#   find-latest-review.sh
#
# Prints the absolute path of the newest *.md file (by filename — YYYY-MM-DD prefix), or exits 1
# with a message if .mstack/reviews/ is empty or missing.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REVIEWS_DIR="$REPO_ROOT/.mstack/reviews"

if [ ! -d "$REVIEWS_DIR" ]; then
  echo "error: $REVIEWS_DIR does not exist — run /mstack-review first" >&2
  exit 1
fi

# Filenames are YYYY-MM-DD-<slug>.md, so lexicographic order == date order.
# Sorting by name (not mtime) survives fresh clones, which reset mtimes.
LATEST="$(find "$REVIEWS_DIR" -maxdepth 1 -type f -name '*.md' \
  | sort | tail -n 1)"

if [ -z "$LATEST" ]; then
  echo "error: no review docs in $REVIEWS_DIR — run /mstack-review first" >&2
  exit 1
fi

echo "$LATEST"
