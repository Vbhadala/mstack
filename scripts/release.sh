#!/usr/bin/env bash
# Cut a release: bump the plugin version everywhere it must stay in sync,
# require a matching CHANGELOG section, then validate + test.
#
# Usage: scripts/release.sh <new-version>     e.g. scripts/release.sh 0.3.0

set -euo pipefail
cd "$(dirname "$0")/.."

NEW="${1:?usage: scripts/release.sh <new-version>}"
if ! [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: '$NEW' is not X.Y.Z semver" >&2
  exit 1
fi

PLUGIN=plugins/mstack/.claude-plugin/plugin.json
MARKET=.claude-plugin/marketplace.json
CHANGELOG=plugins/mstack/CHANGELOG.md

if ! grep -q "^## \[$NEW\]" "$CHANGELOG"; then
  echo "error: $CHANGELOG has no '## [$NEW]' section — write it first" >&2
  exit 1
fi

jq --arg v "$NEW" '.version = $v' "$PLUGIN" > "$PLUGIN.tmp" && mv "$PLUGIN.tmp" "$PLUGIN"
jq --arg v "$NEW" \
  '(.plugins[] | select(.name == "mstack") | .version) = $v | .metadata.version = $v' \
  "$MARKET" > "$MARKET.tmp" && mv "$MARKET.tmp" "$MARKET"

scripts/validate.sh
scripts/test.sh

echo
echo "Bumped to $NEW (plugin.json + marketplace.json). Review the diff, then:"
echo "  git add -A && git commit -m 'mstack v$NEW: <summary>'"
