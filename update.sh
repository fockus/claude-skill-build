#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# claude-skill-build — Unified Updater
# Updates everything: build repo + bundled skills (NeoLabHQ upstream)
# + kit (if installed) + re-applies patches + re-injects rules.
#
# Usage:
#   ./update.sh                  # full: build + bundled + kit + reinstall
#   ./update.sh --skip-bundled   # skip upstream sync of bundled skills
#   ./update.sh --skip-kit       # skip kit refresh (if installed)
#   ./update.sh --core           # core install mode (no extras)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

SKIP_BUNDLED=false
SKIP_KIT=false
CORE=false
for a in "$@"; do
  case "$a" in
    --skip-bundled) SKIP_BUNDLED=true ;;
    --skip-kit)     SKIP_KIT=true ;;
    --core)         CORE=true ;;
  esac
done

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}   Claude Skill Build — Unified Update${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo ""

# ═══ 1. Check for uncommitted changes ═══
if ! git -C "$SKILL_DIR" diff --quiet 2>/dev/null || ! git -C "$SKILL_DIR" diff --cached --quiet 2>/dev/null; then
  echo -e "${YELLOW}[WARN]${NC} Uncommitted changes detected in $SKILL_DIR"
  echo "  Stash or commit them first, then re-run."
  echo ""
  git -C "$SKILL_DIR" status --short
  exit 1
fi

# ═══ 2. Pull build repo ═══
echo -e "${BLUE}[1/4]${NC} Pulling build repo..."
BEFORE=$(git -C "$SKILL_DIR" rev-parse HEAD)
git -C "$SKILL_DIR" pull --ff-only origin main 2>&1 | sed 's/^/  /'
AFTER=$(git -C "$SKILL_DIR" rev-parse HEAD)

if [ "$BEFORE" = "$AFTER" ]; then
  echo -e "  ${GREEN}✓${NC} Build repo already at HEAD"
else
  echo -e "  ${GREEN}✓${NC} Build repo updated:"
  git -C "$SKILL_DIR" log --oneline "$BEFORE".."$AFTER" | sed 's/^/    /'
fi
echo ""

# ═══ 3. Sync bundled skills from NeoLabHQ upstream ═══
if [ "$SKIP_BUNDLED" = false ]; then
  echo -e "${BLUE}[2/4]${NC} Syncing bundled skills from NeoLabHQ upstream..."
  bash "$SKILL_DIR/update-bundled-skills.sh" --auto 2>&1 | tail -10 | sed 's/^/  /'
  if ! git -C "$SKILL_DIR" diff --quiet -- skills/ 2>/dev/null; then
    echo -e "  ${YELLOW}~${NC} skills/ has changes from upstream — review and commit:"
    git -C "$SKILL_DIR" diff --stat -- skills/ | tail -5 | sed 's/^/    /'
  fi
else
  echo -e "${BLUE}[2/4]${NC} Skipping bundled-skills upstream sync (--skip-bundled)"
fi
echo ""

# ═══ 4. Refresh kit if installed ═══
KIT_INSTALLED=false
if [ -d "$HOME/.claude/skills/sdd" ] || [ -d "$HOME/.claude/skills/brainstorm" ]; then
  KIT_INSTALLED=true
fi

if [ "$KIT_INSTALLED" = true ] && [ "$SKIP_KIT" = false ]; then
  echo -e "${BLUE}[3/4]${NC} NeoLabHQ kit detected — refreshing via 'npx skills update'..."
  if command -v npx &>/dev/null; then
    npx -y skills update -g -y 2>&1 | tail -5 | sed 's/^/  /' || true
    echo -e "  ${GREEN}✓${NC} Kit refreshed"
  else
    echo -e "  ${YELLOW}~${NC} npx not found, skipping kit refresh"
  fi
else
  if [ "$KIT_INSTALLED" = false ]; then
    echo -e "${BLUE}[3/4]${NC} NeoLabHQ kit not installed — skipping refresh"
  else
    echo -e "${BLUE}[3/4]${NC} Skipping kit refresh (--skip-kit)"
  fi
fi
echo ""

# ═══ 5. Re-run install.sh ═══
echo -e "${BLUE}[4/4]${NC} Re-running install.sh (re-applies patches + rules + skill copies)..."
echo ""
INSTALL_FLAGS=("--auto")
[ "$CORE" = true ] && INSTALL_FLAGS+=("--core")
# If kit was installed, ensure install.sh re-applies patches via DO_KIT=true
[ "$KIT_INSTALLED" = true ] && export DO_KIT=true
bash "$SKILL_DIR/install.sh" "${INSTALL_FLAGS[@]}"
