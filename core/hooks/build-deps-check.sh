#!/usr/bin/env bash
# build-deps-check.sh — Check build pipeline dependencies (GSD + Memory Bank)
# Called from build:* commands Step 0

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

EXIT_CODE=0
MESSAGES=""

# 1. Check GSD
GSD_DIR="$HOME/.claude/get-shit-done"
if [ -f "$GSD_DIR/VERSION" ]; then
    GSD_VERSION=$(cat "$GSD_DIR/VERSION")
    MESSAGES+="${GREEN}[OK]${NC} GSD v${GSD_VERSION} installed\n"
else
    MESSAGES+="${RED}[MISSING]${NC} GSD not found at ${GSD_DIR}\n"
    MESSAGES+="${YELLOW}[ACTION]${NC} Install: npx get-shit-done-cc@1.14.0 --global\n"
    EXIT_CODE=1
fi

# 2. Check Memory Bank skill
MB_SKILL="$HOME/.claude/skills/memory-bank"
if [ -d "$MB_SKILL" ]; then
    MESSAGES+="${GREEN}[OK]${NC} Memory Bank skill installed\n"
else
    MESSAGES+="${YELLOW}[WARN]${NC} Memory Bank skill not found at ${MB_SKILL}\n"
    MESSAGES+="${YELLOW}[INFO]${NC} Build commands will work but MB sync will be skipped\n"
    # Non-blocking — exit code stays 0
fi

# 3. Check GSD commands
GSD_CMDS="$HOME/.claude/commands/gsd"
if [ -d "$GSD_CMDS" ] && [ "$(ls -1 "$GSD_CMDS"/*.md 2>/dev/null | wc -l)" -gt 0 ]; then
    CMD_COUNT=$(ls -1 "$GSD_CMDS"/*.md | wc -l | tr -d ' ')
    MESSAGES+="${GREEN}[OK]${NC} GSD commands: ${CMD_COUNT} commands\n"
else
    MESSAGES+="${RED}[MISSING]${NC} GSD commands not found at ${GSD_CMDS}\n"
    EXIT_CODE=1
fi

echo -e "$MESSAGES"

if [ $EXIT_CODE -ne 0 ]; then
    echo -e "${RED}Build dependencies missing. Run install:${NC}"
    echo "  npx get-shit-done-cc@1.14.0 --global"
    echo ""
    echo "After install, retry your build command."
fi

exit $EXIT_CODE
