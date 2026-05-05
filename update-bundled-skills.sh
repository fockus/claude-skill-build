#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# update-bundled-skills.sh
# Pulls latest 25 NeoLabHQ skills (sdd, reflexion, kaizen, sadd)
# from upstream context-engineering-kit, applies our patches,
# tracks upstream commit SHA.
#
# Usage:  ./update-bundled-skills.sh           # interactive
#         ./update-bundled-skills.sh --auto    # no prompts
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM_REPO="https://github.com/NeoLabHQ/context-engineering-kit.git"
WORK_DIR="$(mktemp -d -t cek-update-XXXXXX)"
VERSION_FILE="$SKILL_DIR/skills/.upstream-version"
AUTO=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) AUTO=true; shift ;;
    *) shift ;;
  esac
done

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

echo ""
echo -e "${BOLD}═══ Updating bundled skills from NeoLabHQ/context-engineering-kit ═══${NC}"
echo ""

# ═══ 1. Clone upstream ═══
echo -e "${BLUE}[1/4]${NC} Cloning upstream..."
git clone --depth 1 "$UPSTREAM_REPO" "$WORK_DIR" 2>&1 | tail -2
NEW_SHA=$(git -C "$WORK_DIR" rev-parse HEAD)
NEW_SHA_SHORT=$(echo "$NEW_SHA" | cut -c1-7)

OLD_SHA=""
[ -f "$VERSION_FILE" ] && OLD_SHA=$(grep -oE '[a-f0-9]{40}' "$VERSION_FILE" | head -1 || true)

if [ -n "$OLD_SHA" ] && [ "$OLD_SHA" = "$NEW_SHA" ]; then
  echo -e "  ${GREEN}✓${NC} Already at upstream HEAD ($NEW_SHA_SHORT)"
  if [ "$AUTO" = false ]; then
    read -rp "  Re-sync anyway? (y/n): " ans
    [[ "$ans" =~ ^[Yy] ]] || exit 0
  else
    exit 0
  fi
elif [ -n "$OLD_SHA" ]; then
  echo -e "  ${BLUE}→${NC} Upstream changed: $(echo "$OLD_SHA" | cut -c1-7) → $NEW_SHA_SHORT"
else
  echo -e "  ${BLUE}→${NC} First sync (current upstream: $NEW_SHA_SHORT)"
fi
echo ""

# ═══ 2. Sync 25 skills ═══
echo -e "${BLUE}[2/4]${NC} Syncing 25 skills..."

# Format: <our-dir>:<upstream-relpath>
SKILL_MAP="
sdd-add-task:plugins/sdd/skills/add-task
sdd-brainstorm:plugins/sdd/skills/brainstorm
sdd-create-ideas:plugins/sdd/skills/create-ideas
sdd-implement:plugins/sdd/skills/implement-task
sdd-plan:plugins/sdd/skills/plan-task
reflexion-critique:plugins/reflexion/skills/critique
reflexion-memorize:plugins/reflexion/skills/memorize
reflexion-reflect:plugins/reflexion/skills/reflect
kaizen-analyse:plugins/kaizen/skills/analyse
kaizen-analyse-problem:plugins/kaizen/skills/analyse-problem
kaizen-cause-and-effect:plugins/kaizen/skills/cause-and-effect
kaizen-kaizen:plugins/kaizen/skills/kaizen
kaizen-plan-do-check-act:plugins/kaizen/skills/plan-do-check-act
kaizen-root-cause-tracing:plugins/kaizen/skills/root-cause-tracing
kaizen-why:plugins/kaizen/skills/why
sadd-do-and-judge:plugins/sadd/skills/do-and-judge
sadd-do-competitively:plugins/sadd/skills/do-competitively
sadd-do-in-parallel:plugins/sadd/skills/do-in-parallel
sadd-do-in-steps:plugins/sadd/skills/do-in-steps
sadd-judge:plugins/sadd/skills/judge
sadd-judge-with-debate:plugins/sadd/skills/judge-with-debate
sadd-launch-sub-agent:plugins/sadd/skills/launch-sub-agent
sadd-multi-agent-patterns:plugins/sadd/skills/multi-agent-patterns
sadd-subagent-driven-development:plugins/sadd/skills/subagent-driven-development
sadd-tree-of-thoughts:plugins/sadd/skills/tree-of-thoughts
"

count=0
while IFS=: read -r ours upstream_rel; do
  [ -z "$ours" ] && continue
  src_dir="$WORK_DIR/$upstream_rel"
  dst_dir="$SKILL_DIR/skills/$ours"
  if [ ! -d "$src_dir" ]; then
    echo -e "  ${RED}✗${NC} $ours: upstream missing ($upstream_rel)"
    continue
  fi
  mkdir -p "$dst_dir"
  # Copy ALL files in upstream skill dir (SKILL.md + auxiliaries like analyse-business-requirements.md)
  while IFS= read -r f; do
    rel="${f#$src_dir/}"
    target="$dst_dir/$rel"
    mkdir -p "$(dirname "$target")"
    cp "$f" "$target"
  done < <(find "$src_dir" -type f)
  count=$((count + 1))
done < <(echo "$SKILL_MAP" | grep -v '^$')
echo -e "  ${GREEN}✓${NC} Synced $count skills"
echo ""

# ═══ 3. Apply patches ═══
echo -e "${BLUE}[3/4]${NC} Applying patches..."
bash "$SKILL_DIR/scripts/patches.sh" "$SKILL_DIR/skills" 2>&1 | sed 's/^/  /'
echo ""

# ═══ 4. Save version + show diff ═══
echo -e "${BLUE}[4/4]${NC} Bookkeeping"
cat > "$VERSION_FILE" <<EOF
upstream: NeoLabHQ/context-engineering-kit
commit: $NEW_SHA
synced: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
echo -e "  ${GREEN}✓${NC} Saved version: $VERSION_FILE"
echo ""

# Show summary diff
if git -C "$SKILL_DIR" diff --quiet -- skills/ 2>/dev/null; then
  echo -e "${GREEN}═══ No changes — already in sync ═══${NC}"
else
  echo -e "${BOLD}═══ Files changed ═══${NC}"
  git -C "$SKILL_DIR" diff --stat -- skills/ | tail -30
  echo ""
  echo -e "${YELLOW}Next:${NC}  review with 'git diff skills/' and commit."
fi
