#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# scripts/patches.sh — Applies our customizations on top of upstream
# NeoLabHQ/context-engineering-kit skills after they're synced.
#
# Patches are deterministic sed substitutions. If a substitution
# matches zero lines, we warn (means upstream changed wording or
# patch already applied).
#
# Usage:  scripts/patches.sh [<skills-dir>]
#         default: skills/
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SKILLS_DIR="${1:-skills}"
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'

# Apply sed expression to file. Warn if pattern didn't match anything.
# Args: <file> <sed-expr> <human-readable-label>
patch_file() {
  local file="$1" expr="$2" label="$3"
  if [ ! -f "$file" ]; then
    echo -e "  ${RED}✗${NC} $label: file missing — $file"
    return 1
  fi
  # Compute hash before/after to detect actual change
  local before after
  before=$(shasum "$file" | awk '{print $1}')
  sed -i.bak -E "$expr" "$file" && rm "$file.bak"
  after=$(shasum "$file" | awk '{print $1}')
  if [ "$before" = "$after" ]; then
    echo -e "  ${YELLOW}~${NC} $label: no-op (already applied or upstream changed)"
  else
    echo -e "  ${GREEN}✓${NC} $label"
  fi
}

# Maps our skill dir → upstream bare name (used in `name:` frontmatter).
# Also serves as the canonical list of NeoLabHQ-derived skills.
echo "═══ Pattern 1: name namespacing (25 skills) ═══"

# Format: <our-dir>:<bare-upstream-name>:<our-namespaced-name>
NAMESPACE_MAP="
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

while IFS=: read -r dir bare ns_prefix ns_name; do
  [ -z "$dir" ] && continue
  full_ns="${ns_prefix}:${ns_name}"
  file="$SKILLS_DIR/$dir/SKILL.md"
  patch_file "$file" "s|^name: ${bare}\$|name: ${full_ns}|" "$dir → name: $full_ns"
done < <(echo "$NAMESPACE_MAP" | grep -v '^$')

echo ""
echo "═══ Pattern 2: .specs/ → .memory-bank/specs/ (all SDD/SADD files) ═══"

# Replace artifact directory across all 25 files (143 references upstream)
for dir_entry in "$SKILLS_DIR"/sdd-* "$SKILLS_DIR"/sadd-*; do
  [ -d "$dir_entry" ] || continue
  for f in "$dir_entry"/*.md; do
    [ -f "$f" ] || continue
    patch_file "$f" 's|\.specs/|.memory-bank/specs/|g' "$(basename "$dir_entry")/$(basename "$f"): .specs/ → .memory-bank/specs/"
  done
done

echo ""
echo "═══ Pattern 3: cross-skill reference rewrites ═══"

# sdd-brainstorm: skill cross-refs
patch_file "$SKILLS_DIR/sdd-brainstorm/SKILL.md" \
  's|Use write-concisely skill if available|Use docs:write-concisely skill if available|' \
  "sdd-brainstorm: write-concisely → docs:write-concisely"
patch_file "$SKILLS_DIR/sdd-brainstorm/SKILL.md" \
  's|/worktrees create|git:create-worktree|' \
  "sdd-brainstorm: /worktrees create → git:create-worktree"
patch_file "$SKILLS_DIR/sdd-brainstorm/SKILL.md" \
  's|`/add-task`|sdd:add-task|' \
  "sdd-brainstorm: /add-task → sdd:add-task"

# sdd-plan: paths and agent name refs
patch_file "$SKILLS_DIR/sdd-plan/SKILL.md" \
  's|skills/plan-task/analyse-business-requirements\.md|skills/plan/analyse-business-requirements.md|' \
  "sdd-plan: plan-task path → plan path"
patch_file "$SKILLS_DIR/sdd-plan/SKILL.md" \
  's|review:bug-hunter|code-review:bug-hunter|g' \
  "sdd-plan: review:bug-hunter → code-review:bug-hunter"

echo ""
echo -e "${GREEN}═══ All patches applied ═══${NC}"
