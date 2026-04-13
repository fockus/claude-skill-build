#!/bin/bash
# active-test.sh — Active testing via Playwright MCP
# Invoked by /build:review --active to run browser-based assertion checks
# Reads assertions from .factory/assertions.yaml or CLAUDE.md
#
# Usage: bash active-test.sh [URL]
# Exit codes: 0 = all assertions pass or skipped, 1 = assertions failed, 2 = no assertions found
set -euo pipefail

URL="${1:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ═══════════════════════════════════════════════════
# 1. Check Playwright MCP availability
# ═══════════════════════════════════════════════════
PLAYWRIGHT_AVAILABLE=false
if command -v npx &>/dev/null; then
  PLAYWRIGHT_AVAILABLE=true
fi

if [ "$PLAYWRIGHT_AVAILABLE" = false ]; then
  echo -e "${YELLOW}[SKIP]${NC} Playwright MCP unavailable (npx not found) — active testing skipped"
  exit 0
fi

# ═══════════════════════════════════════════════════
# 2. Load assertions from config
# ═══════════════════════════════════════════════════
ASSERTIONS_FILE=""
ASSERTIONS=()

# Priority 1: .factory/assertions.yaml
if [ -f ".factory/assertions.yaml" ]; then
  ASSERTIONS_FILE=".factory/assertions.yaml"
# Priority 2: Look for active_testing section in CLAUDE.md
elif [ -f "CLAUDE.md" ]; then
  if grep -q "active_testing\|active-testing\|ActiveTesting" CLAUDE.md 2>/dev/null; then
    ASSERTIONS_FILE="CLAUDE.md"
  fi
fi

if [ -z "$ASSERTIONS_FILE" ]; then
  echo -e "${YELLOW}[SKIP]${NC} No assertions config found (.factory/assertions.yaml or CLAUDE.md active_testing section)"
  exit 0
fi

# ═══════════════════════════════════════════════════
# 3. Parse assertions from YAML
# ═══════════════════════════════════════════════════
if [ "$ASSERTIONS_FILE" = ".factory/assertions.yaml" ]; then
  PARSE_RESULT=$(python3 -c "
import sys
try:
    import yaml
except ImportError:
    import re
    content = open(sys.argv[1]).read()
    urls = re.findall(r'url:\s*[\"'\'']*([^\s\"'\'']+)', content)
    assertions = re.findall(r'-\s*[\"'\'']*([^\"'\''\\n]+)', content)
    for u in urls:
        print(f'URL:{u}')
    for a in assertions:
        if not a.startswith(('url:', 'assertions:')):
            print(f'ASSERT:{a.strip()}')
    sys.exit(0)

data = yaml.safe_load(open(sys.argv[1]))
if isinstance(data, dict):
    entries = data.get('active_testing', data.get('assertions', [data]))
    if isinstance(entries, dict):
        entries = [entries]
    for entry in entries:
        if isinstance(entry, dict):
            url = entry.get('url', '')
            if url:
                print(f'URL:{url}')
            for a in entry.get('assertions', []):
                print(f'ASSERT:{a}')
" "$ASSERTIONS_FILE" 2>/dev/null) || true

  if [ -z "$PARSE_RESULT" ]; then
    echo -e "${YELLOW}[SKIP]${NC} Could not parse assertions from $ASSERTIONS_FILE"
    exit 0
  fi

  # Override URL from config if not provided via argument
  CONFIG_URL=$(echo "$PARSE_RESULT" | grep "^URL:" | head -1 | cut -d: -f2-)
  if [ -z "$URL" ] && [ -n "$CONFIG_URL" ]; then
    URL="$CONFIG_URL"
  fi

  # Collect assertions
  while IFS= read -r line; do
    if [[ "$line" == ASSERT:* ]]; then
      ASSERTIONS+=("${line#ASSERT:}")
    fi
  done <<< "$PARSE_RESULT"
fi

if [ -z "$URL" ]; then
  echo -e "${YELLOW}[SKIP]${NC} No URL specified (pass as argument or set in assertions config)"
  exit 0
fi

if [ ${#ASSERTIONS[@]} -eq 0 ]; then
  echo -e "${YELLOW}[SKIP]${NC} No assertions defined in $ASSERTIONS_FILE"
  exit 0
fi

# ═══════════════════════════════════════════════════
# 4. Output structured test plan for agent
# ═══════════════════════════════════════════════════
# The hook outputs a structured test plan that the review agent uses
# to invoke Playwright MCP tools via Claude Code's tool-calling.
# The agent reads this output and executes the checks.

echo ""
echo -e "${GREEN}[ACTIVE TEST]${NC} Running browser assertions against: $URL"
echo "  Assertions: ${#ASSERTIONS[@]}"
echo ""

echo "## Active Test Plan"
echo ""
echo "Target URL: $URL"
echo "Assertion count: ${#ASSERTIONS[@]}"
echo ""
echo "### Assertions to verify"
for i in "${!ASSERTIONS[@]}"; do
  echo "  $((i+1)). ${ASSERTIONS[$i]}"
done
echo ""
echo "### Instructions for agent"
echo "Use Playwright MCP tools (browser_navigate, browser_snapshot) to:"
echo "1. Navigate to $URL"
echo "2. Take a page snapshot"
echo "3. Verify each assertion against the snapshot text"
echo "4. Report PASS/FAIL for each assertion"
echo ""

# This script generates a test plan — the agent executes checks via Playwright MCP tools
echo -e "${GREEN}[READY]${NC} ${#ASSERTIONS[@]} assertions ready for browser verification"
exit 0
