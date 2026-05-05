#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# bootstrap.sh — one-liner installer for claude-skill-build
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/fockus/claude-skill-build/main/bootstrap.sh | bash
#
# With install flags:
#   curl -fsSL https://raw.githubusercontent.com/fockus/claude-skill-build/main/bootstrap.sh | bash -s -- --auto --full
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

INSTALL_DIR="${HOME}/.claude/skills/claude-skill-build"
REPO="https://github.com/fockus/claude-skill-build.git"
BOLD='\033[1m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

echo ""
echo -e "${BOLD}═══ claude-skill-build bootstrap ═══${NC}"
echo ""

# Pre-flight
command -v git >/dev/null 2>&1 || { echo "git is required"; exit 1; }

if [ -d "$INSTALL_DIR/.git" ]; then
  echo -e "${BLUE}→${NC} Existing install detected at $INSTALL_DIR"
  echo -e "${BLUE}→${NC} Pulling latest..."
  git -C "$INSTALL_DIR" pull --ff-only origin main 2>&1 | sed 's/^/  /'
else
  echo -e "${BLUE}→${NC} Cloning $REPO"
  echo -e "${BLUE}→${NC} Target: $INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone "$REPO" "$INSTALL_DIR" 2>&1 | sed 's/^/  /'
fi

cd "$INSTALL_DIR"
chmod +x install.sh uninstall.sh update.sh update-bundled-skills.sh bootstrap.sh build 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}✓${NC} Bootstrap complete. Running installer..."
echo ""

exec ./install.sh "$@"
