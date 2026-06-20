#!/usr/bin/env bash
# Validate the mstack marketplace before publishing / installing.
#   - JSON manifests parse
#   - plugin + marketplace versions agree
#   - every skill dir has SKILL.md with name + description frontmatter
#   - no stale `.claude/skills/...` path references survive in skills
#   - shared scripts are executable
#
# Usage: scripts/validate.sh   (run from the marketplace root)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
err() { echo "FAIL  $*"; fail=1; }
ok()  { echo "ok    $*"; }

# 1. JSON validity
for f in .claude-plugin/marketplace.json plugins/mstack/.claude-plugin/plugin.json plugins/mstack/mstack.config.example.json; do
  if jq empty "$f" >/dev/null 2>&1; then ok "json $f"; else err "json $f does not parse"; fi
done

# 2. Versions agree (marketplace entry vs plugin manifest)
mv=$(jq -r '.plugins[] | select(.name=="mstack") | .version' .claude-plugin/marketplace.json 2>/dev/null)
pv=$(jq -r '.version' plugins/mstack/.claude-plugin/plugin.json 2>/dev/null)
if [ -n "$mv" ] && [ "$mv" = "$pv" ]; then ok "version sync ($pv)"; else err "version mismatch: marketplace=$mv plugin=$pv"; fi

# 3. Each skill has SKILL.md with name + description
for d in plugins/mstack/skills/*/; do
  name=$(basename "$d")
  sk="$d/SKILL.md"
  if [ ! -f "$sk" ]; then err "skill $name missing SKILL.md"; continue; fi
  fm=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$sk")
  echo "$fm" | grep -q '^name:'        || err "skill $name: SKILL.md missing 'name:'"
  echo "$fm" | grep -q '^description:' || err "skill $name: SKILL.md missing 'description:'"
  fmname=$(echo "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)
  [ "$fmname" = "$name" ] || err "skill $name: frontmatter name '$fmname' != dir name"
done
ok "skills frontmatter checked ($(ls -1d plugins/mstack/skills/*/ | wc -l | tr -d ' ') skills)"

# 4. No stale hardcoded paths in skills (should resolve via \${CLAUDE_PLUGIN_ROOT})
if grep -rn '\.claude/skills/' plugins/mstack/skills >/dev/null 2>&1; then
  err "stale '.claude/skills/' references found in skills:"; grep -rn '\.claude/skills/' plugins/mstack/skills
else ok "no stale .claude/skills references"; fi

# 5. Shared scripts executable
for s in plugins/mstack/shared/bin/*.sh; do
  [ -x "$s" ] && ok "exec $(basename "$s")" || err "not executable: $s"
done

echo
[ "$fail" = 0 ] && echo "ALL CHECKS PASSED" || echo "VALIDATION FAILED"
exit $fail
