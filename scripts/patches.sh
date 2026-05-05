#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# scripts/patches.sh — Apply our customizations to NeoLabHQ skills
# wherever they live. Supports two layouts:
#
#   1. Vendored layout: <base>/sdd-brainstorm/SKILL.md
#      (used by our repo's skills/ + install destinations)
#
#   2. Kit layout: <base>/brainstorm/SKILL.md
#      (used by `npx skills add NeoLabHQ/context-engineering-kit`)
#
# Patches applied per file:
#   - name: <bare> → name: <plugin>:<skill>
#   - .specs/ → .memory-bank/specs/
#   - cross-skill refs (sdd-brainstorm: 3, sdd-plan: 2)
#
# Idempotent: if a substitution finds nothing to change, warns but
# doesn't fail (means already patched or upstream wording changed).
#
# Usage: scripts/patches.sh [<skills-base-dir>]
#        default: skills/  (our repo's vendored copies)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SKILLS_DIR="${1:-skills}"
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

if [ ! -d "$SKILLS_DIR" ]; then
  echo -e "${RED}✗${NC} skills dir not found: $SKILLS_DIR"
  exit 1
fi

# Format: <vendored-dir>:<kit-bare-dir>:<our-namespace>:<our-skill-name>
# vendored-dir = our prefixed name, what we ship pre-patched in skills/
# kit-bare-dir = name as installed by `npx skills add NeoLabHQ/...`
SKILLS_TABLE="
sdd-add-task:add-task:sdd:add-task
sdd-brainstorm:brainstorm:sdd:brainstorm
sdd-create-ideas:create-ideas:sdd:create-ideas
sdd-implement:implement-task:sdd:implement
sdd-plan:plan-task:sdd:plan
reflexion-critique:critique:reflexion:critique
reflexion-memorize:memorize:reflexion:memorize
reflexion-reflect:reflect:reflexion:reflect
kaizen-analyse:analyse:kaizen:analyse
kaizen-analyse-problem:analyse-problem:kaizen:analyse-problem
kaizen-cause-and-effect:cause-and-effect:kaizen:cause-and-effect
kaizen-kaizen:kaizen:kaizen:kaizen
kaizen-plan-do-check-act:plan-do-check-act:kaizen:plan-do-check-act
kaizen-root-cause-tracing:root-cause-tracing:kaizen:root-cause-tracing
kaizen-why:why:kaizen:why
sadd-do-and-judge:do-and-judge:sadd:do-and-judge
sadd-do-competitively:do-competitively:sadd:do-competitively
sadd-do-in-parallel:do-in-parallel:sadd:do-in-parallel
sadd-do-in-steps:do-in-steps:sadd:do-in-steps
sadd-judge:judge:sadd:judge
sadd-judge-with-debate:judge-with-debate:sadd:judge-with-debate
sadd-launch-sub-agent:launch-sub-agent:sadd:launch-sub-agent
sadd-multi-agent-patterns:multi-agent-patterns:sadd:multi-agent-patterns
sadd-subagent-driven-development:subagent-driven-development:sadd:subagent-driven-development
sadd-tree-of-thoughts:tree-of-thoughts:sadd:tree-of-thoughts
"

# Apply sed expression to file. Hash before/after to detect actual change.
patch_file() {
  local file="$1" expr="$2"
  [ -f "$file" ] || return 0
  local before after
  before=$(shasum "$file" | awk '{print $1}')
  sed -i.bak -E "$expr" "$file" && rm -f "$file.bak"
  after=$(shasum "$file" | awk '{print $1}')
  [ "$before" != "$after" ]  # return 0 if changed, 1 if no-op
}

# Resolve actual skill dirs for an entry. Returns 0..2 paths separated by newline.
# Both layouts may coexist (vendored + kit) — patch both.
resolve_skill_dirs() {
  local vendored="$1" kit="$2"
  [ -d "$SKILLS_DIR/$vendored" ] && echo "$SKILLS_DIR/$vendored"
  [ -d "$SKILLS_DIR/$kit" ] && [ "$vendored" != "$kit" ] && echo "$SKILLS_DIR/$kit"
  return 0  # never propagate test failures (we only care about emitted paths)
}

echo -e "${BLUE}═══ patches.sh on $SKILLS_DIR ═══${NC}"

found=0; patched=0; skipped=0
while IFS=: read -r vendored bare ns_prefix ns_name; do
  [ -z "$vendored" ] && continue

  dirs=$(resolve_skill_dirs "$vendored" "$bare")
  if [ -z "$dirs" ]; then
    skipped=$((skipped + 1))
    continue
  fi
  full_ns="${ns_prefix}:${ns_name}"

  IFS=$'\n'
  for dir in $dirs; do
    [ -z "$dir" ] && continue
    found=$((found + 1))
    skill_file="$dir/SKILL.md"

    # Pattern 1: name namespacing — applies to any layout
    if patch_file "$skill_file" "s|^name: ${bare}\$|name: ${full_ns}|"; then
      patched=$((patched + 1))
    fi

    # Pattern 2: .specs/ → .memory-bank/specs/ — applies to all .md files in skill dir
    for f in "$dir"/*.md; do
      [ -f "$f" ] || continue
      patch_file "$f" 's|\.specs/|.memory-bank/specs/|g' || true
    done
  done
  unset IFS
done < <(echo "$SKILLS_TABLE" | grep -v '^$')

echo "  $found skill dirs patched, $patched name-renamed, $skipped not present"

# Pattern 3: cross-skill reference rewrites (skill-specific)
echo ""
echo "  Cross-skill refs:"

# sdd-brainstorm — apply to all detected layouts
brainstorm_dirs="$(resolve_skill_dirs "sdd-brainstorm" "brainstorm")"
IFS=$'\n'
for dir in $brainstorm_dirs; do
  [ -z "$dir" ] && continue
  f="$dir/SKILL.md"
  patch_file "$f" 's|Use write-concisely skill if available|Use docs:write-concisely skill if available|' \
    && echo -e "    ${GREEN}✓${NC} $(basename "$dir"): write-concisely → docs:write-concisely" || true
  patch_file "$f" 's|/worktrees create|git:create-worktree|' \
    && echo -e "    ${GREEN}✓${NC} $(basename "$dir"): /worktrees create → git:create-worktree" || true
  patch_file "$f" 's|`/add-task`|sdd:add-task|' \
    && echo -e "    ${GREEN}✓${NC} $(basename "$dir"): /add-task → sdd:add-task" || true
done
unset IFS

# sdd-plan — apply to all detected layouts
plan_dirs="$(resolve_skill_dirs "sdd-plan" "plan-task")"
IFS=$'\n'
for dir in $plan_dirs; do
  [ -z "$dir" ] && continue
  f="$dir/SKILL.md"
  patch_file "$f" 's|skills/plan-task/analyse-business-requirements\.md|skills/plan/analyse-business-requirements.md|' \
    && echo -e "    ${GREEN}✓${NC} $(basename "$dir"): plan-task → plan path" || true
  # Idempotent: mask already-patched, replace, restore (BSD sed has no lookbehind)
  patch_file "$f" 's|code-review:bug-hunter|__BUG_HUNTER_KEEP__|g; s|review:bug-hunter|code-review:bug-hunter|g; s|__BUG_HUNTER_KEEP__|code-review:bug-hunter|g' \
    && echo -e "    ${GREEN}✓${NC} $(basename "$dir"): review:bug-hunter → code-review:bug-hunter" || true
done
unset IFS

echo ""
echo -e "${GREEN}═══ patches.sh done ═══${NC}"
