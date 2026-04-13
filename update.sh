#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# claude-skill-build — Updater
# Pulls latest from origin and re-runs install.sh
# Usage: ./update.sh [--core]
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}   Claude Skill Build — Update${NC}"
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

# ═══ 2. Pull latest ═══
echo -e "[1/3] Pulling latest..."
BEFORE=$(git -C "$SKILL_DIR" rev-parse HEAD)
git -C "$SKILL_DIR" pull --ff-only origin main 2>&1 | sed 's/^/  /'
AFTER=$(git -C "$SKILL_DIR" rev-parse HEAD)

if [ "$BEFORE" = "$AFTER" ]; then
  echo -e "  ${GREEN}Already up to date.${NC}"
  echo ""
  echo "  Re-install anyway? (y/n)"
  read -rp "  > " answer
  if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo -e "  ${GREEN}Nothing to do.${NC}"
    exit 0
  fi
else
  echo ""
  echo -e "[2/3] Changes since last update:"
  git -C "$SKILL_DIR" log --oneline "$BEFORE".."$AFTER" | sed 's/^/  /'
fi

# ═══ 3. Re-install ═══
echo ""
echo -e "[3/3] Re-installing..."
echo ""
bash "$SKILL_DIR/install.sh" --auto "$@"
