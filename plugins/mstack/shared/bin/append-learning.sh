#!/usr/bin/env bash
# Append a learning entry to .mstack/learnings.jsonl
#
# Usage:
#   append-learning.sh <skill> <kind> <text>
#
# Args:
#   skill — invoking skill name (mstack-plan, mstack-review, …)
#   kind  — one of: constraint, gotcha, decision, deviation, pattern
#   text  — single-line summary (quote it)
#
# Writes JSONL: {"ts":"…","skill":"…","kind":"…","branch":"…","text":"…"}

set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: append-learning.sh <skill> <kind> <text>" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required (brew install jq)" >&2
  exit 1
fi

SKILL="$1"
KIND="$2"
TEXT="$3"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LEARN_FILE="$REPO_ROOT/.mstack/learnings.jsonl"
mkdir -p "$(dirname "$LEARN_FILE")"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BRANCH="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo unknown)"

jq -cn \
  --arg ts "$TS" \
  --arg skill "$SKILL" \
  --arg kind "$KIND" \
  --arg branch "$BRANCH" \
  --arg text "$TEXT" \
  '{ts:$ts, skill:$skill, kind:$kind, branch:$branch, text:$text}' \
  >> "$LEARN_FILE"

echo "appended to $LEARN_FILE"
