#!/usr/bin/env bash
# build-install-deps.sh — Install missing build pipeline dependencies
# Usage: ~/.claude/hooks/build-install-deps.sh [--auto]
# --auto: skip confirmation prompts

set -euo pipefail

AUTO=false
[ "${1:-}" = "--auto" ] && AUTO=true

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

GSD_DIR="$HOME/.claude/get-shit-done"
MB_SKILL="$HOME/.claude/skills/memory-bank"

echo "=== Build Pipeline Dependencies ==="
echo ""

# 1. GSD
if [ -f "$GSD_DIR/VERSION" ]; then
    echo -e "${GREEN}[OK]${NC} GSD v$(cat "$GSD_DIR/VERSION") already installed"
else
    echo -e "${YELLOW}[MISSING]${NC} GSD (Get Shit Done)"

    if [ "$AUTO" = true ]; then
        INSTALL=true
    else
        read -rp "Install GSD via npx? (y/n) " answer
        INSTALL=false
        [ "$answer" = "y" ] || [ "$answer" = "Y" ] && INSTALL=true
    fi

    if [ "$INSTALL" = true ]; then
        echo "Installing GSD..."
        npx -y get-shit-done-cc@1.14.0 --global
        if [ -f "$GSD_DIR/VERSION" ]; then
            echo -e "${GREEN}[OK]${NC} GSD v$(cat "$GSD_DIR/VERSION") installed"
        else
            echo -e "${RED}[FAIL]${NC} GSD installation failed"
            exit 1
        fi
    else
        echo -e "${YELLOW}[SKIP]${NC} GSD not installed"
    fi
fi

echo ""

# 2. Memory Bank
if [ -d "$MB_SKILL" ]; then
    echo -e "${GREEN}[OK]${NC} Memory Bank skill installed"
else
    echo -e "${YELLOW}[WARN]${NC} Memory Bank skill not found"
    echo "  Memory Bank is a custom skill not yet published."
    echo "  Build commands will work without it (MB sync skipped)."
    echo "  To install: copy memory-bank skill to ~/.claude/skills/memory-bank/"
fi

echo ""
echo "=== Done ==="
