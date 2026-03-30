#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# claude-skill-build — Unified uninstaller
# Removes all installed files, restores backups, cleans settings
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SKILL_DIR/.installed-manifest.json"
CLAUDE_DIR="$HOME/.claude"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}   Claude Skill Build — Uninstaller${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo ""

if [ ! -f "$MANIFEST" ]; then
  echo -e "${RED}[ERROR]${NC} Manifest not found: $MANIFEST"
  echo "  The skill was not installed via install.sh, or manifest was deleted."
  echo ""
  echo "  Manual cleanup:"
  echo "    rm ~/.claude/agents/{analyst,architect,critic,debugger,designer,developer,documentor,explorer,frontend,integrator,judge,mobile,planner,researcher,reviewer,security,tester,verifier}.md"
  echo "    rm ~/.claude/hooks/{build-deps-check,build-install-deps,go-quality,judge-findings-gate,py-quality,quality-gate,spec-verify}.sh"
  echo "    rm -rf ~/.claude/commands/build/"
  echo "    rm ~/.claude/commands/{pipeline,implement}.md"
  echo "    rm -rf ~/.claude/skills/{sdd-*,reflexion-*,kaizen-*,sadd-*,harness-*,build-sdd,breezing}"
  exit 1
fi

echo -n "This will remove all files installed by claude-skill-build. Continue? (y/n): "
read -r confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Cancelled."
  exit 0
fi
echo ""

REMOVED=0
RESTORED=0

# ═══ Step 1: Remove installed files ═══
echo -e "${BLUE}Step 1: Removing installed files${NC}"
while read -r filepath; do
  if [ -f "$filepath" ]; then
    case "$filepath" in
      "$HOME/.claude/"*) rm "$filepath"; echo -e "  ${GREEN}[rm]${NC} $(basename "$filepath")" ;;
      *) echo -e "  ${YELLOW}[SKIP]${NC} $filepath (outside ~/.claude/)" ;;
    esac
  fi
done < <(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    manifest = json.load(f)
for f in manifest.get('files', []):
    print(f)
" "$MANIFEST")
echo -e "  ${GREEN}[OK]${NC} Files removed"

# Remove empty directories created by skills
for skill_dir in "$CLAUDE_DIR/skills/"*/; do
  [ -d "$skill_dir" ] && rmdir "$skill_dir" 2>/dev/null || true
done
rmdir "$CLAUDE_DIR/commands/build" 2>/dev/null || true
echo ""

# ═══ Step 2: Restore backups ═══
echo -e "${BLUE}Step 2: Restoring backups${NC}"
while read -r backup_pair; do
  if [ -n "$backup_pair" ] && echo "$backup_pair" | grep -q '|'; then
    original="${backup_pair%%|*}"
    backup="${backup_pair##*|}"
    if [ -f "$backup" ]; then
      mv "$backup" "$original"
      echo -e "  ${GREEN}[RESTORED]${NC} $(basename "$original")"
      RESTORED=$((RESTORED + 1))
    fi
  fi
done < <(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    manifest = json.load(f)
for b in manifest.get('backups', []):
    print(b)
" "$MANIFEST")
echo ""

# ═══ Step 3: Clean settings.json hooks ═══
echo -e "${BLUE}Step 3: Cleaning settings.json${NC}"
if [ -f "$CLAUDE_DIR/settings.json" ] && command -v python3 &>/dev/null; then
  SETTINGS_PATH="$CLAUDE_DIR/settings.json" python3 << 'PYEOF'
import json, os

settings_path = os.environ["SETTINGS_PATH"]

try:
    with open(settings_path) as f:
        settings = json.load(f)
except FileNotFoundError:
    print("  No settings.json found")
    exit(0)

hooks = settings.get("hooks", {})
removed = 0

for event in list(hooks.keys()):
    if isinstance(hooks[event], list):
        original_len = len(hooks[event])
        hooks[event] = [entry for entry in hooks[event]
                        if not isinstance(entry, dict) or not any(
                            '[build-skill]' in h.get('command', '')
                            for h in entry.get('hooks', []) if isinstance(h, dict)
                        )]
        removed += original_len - len(hooks[event])

settings['hooks'] = hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print(f"  Removed {removed} hook entries")
PYEOF
fi

# Remove [SKILL-BUILD-MANAGED] section from CLAUDE.md
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  if grep -q "\[SKILL-BUILD-MANAGED\]" "$CLAUDE_DIR/CLAUDE.md"; then
    CLAUDE_MD_PATH="$CLAUDE_DIR/CLAUDE.md" python3 << 'PYEOF' 2>/dev/null
import os
p = os.environ["CLAUDE_MD_PATH"]
content = open(p).read()
marker = '# [SKILL-BUILD-MANAGED]'
if marker in content:
    open(p, 'w').write(content[:content.index(marker)].rstrip() + '\n')
    print('  Cleaned CLAUDE.md')
PYEOF
  fi
fi
echo ""

# ═══ Step 4: Cleanup ═══
echo -e "${BLUE}Step 4: Cleanup${NC}"
rm -f "$MANIFEST"
echo -e "  ${GREEN}[OK]${NC} Manifest removed"
echo ""

# ═══ Summary ═══
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Uninstall complete${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo ""
echo "  Note: GSD (Get Shit Done) was NOT removed. To remove:"
echo "    rm -rf ~/.claude/get-shit-done ~/.claude/commands/gsd"
echo ""
echo "  Note: Project-level files (.memory-bank/, CLAUDE.md) were NOT touched."
echo ""
