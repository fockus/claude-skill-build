#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# claude-skill-build — Unified Updater
# Updates everything: build repo + bundled skills (NeoLabHQ upstream)
# + kit (if installed) + re-applies patches + re-injects rules.
#
# Usage:
#   ./update.sh                  # full: build + bundled + kit + reinstall
#   ./update.sh --check          # only check if update available, don't apply
#   ./update.sh --yes            # skip pre-pull confirmation prompt
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
CHECK_ONLY=false
ASSUME_YES=false
for a in "$@"; do
  case "$a" in
    --skip-bundled) SKIP_BUNDLED=true ;;
    --skip-kit)     SKIP_KIT=true ;;
    --core)         CORE=true ;;
    --check)        CHECK_ONLY=true ;;
    --yes|-y)       ASSUME_YES=true ;;
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

# ═══ 2. Check for new version (pre-pull preview) ═══
echo -e "${BLUE}[1/4]${NC} Checking for updates..."
LOCAL_VERSION=$(cat "$SKILL_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
git -C "$SKILL_DIR" fetch --quiet origin main 2>&1 | sed 's/^/  /'
BEFORE=$(git -C "$SKILL_DIR" rev-parse HEAD)
REMOTE=$(git -C "$SKILL_DIR" rev-parse origin/main)
REMOTE_VERSION=$(git -C "$SKILL_DIR" show origin/main:VERSION 2>/dev/null | tr -d '[:space:]' || echo "unknown")

if [ "$BEFORE" = "$REMOTE" ]; then
  echo -e "  ${GREEN}✓${NC} Already at latest (v${LOCAL_VERSION})"
  if [ "$CHECK_ONLY" = true ]; then exit 0; fi
else
  AHEAD=$(git -C "$SKILL_DIR" rev-list --count HEAD..origin/main)
  echo -e "  ${YELLOW}↑${NC} Update available: v${LOCAL_VERSION} → v${REMOTE_VERSION} (${AHEAD} commits)"
  echo ""
  echo -e "${BOLD}  Changelog preview:${NC}"
  git -C "$SKILL_DIR" log --oneline --no-decorate "HEAD..origin/main" | head -20 | sed 's/^/    /'
  if [ "$AHEAD" -gt 20 ]; then echo "    ... and $((AHEAD - 20)) more"; fi
  echo ""

  if [ "$CHECK_ONLY" = true ]; then
    echo "  Run without --check to apply the update."
    exit 0
  fi

  if [ "$ASSUME_YES" = false ]; then
    read -rp "  Apply update? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
      echo -e "  ${YELLOW}Cancelled.${NC}"
      exit 0
    fi
  fi
fi

echo ""
echo -e "${BLUE}[1/4]${NC} Pulling build repo..."
git -C "$SKILL_DIR" pull --ff-only origin main 2>&1 | sed 's/^/  /'
AFTER=$(git -C "$SKILL_DIR" rev-parse HEAD)

if [ "$BEFORE" = "$AFTER" ]; then
  echo -e "  ${GREEN}✓${NC} Build repo at v${LOCAL_VERSION} (no changes)"
else
  NEW_VERSION=$(cat "$SKILL_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
  echo -e "  ${GREEN}✓${NC} Build repo: v${LOCAL_VERSION} → v${NEW_VERSION}"
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
