#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# claude-skill-build — Installer
# Build pipeline + 18 agents + 7 hooks + 33 bundled skills
# Requires: claude-skill-memory-bank (external)
# Optional: claude-skill-find-skill (external)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
MANIFEST="$SKILL_DIR/.installed-manifest.json"
AUTO=false
INSTALL_MODE="full"  # full | core
GSD_VERSION="1.14.0"  # Pin to known good version

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) AUTO=true; shift ;;
    --core) INSTALL_MODE="core"; shift ;;
    --full) INSTALL_MODE="full"; shift ;;
    *) shift ;;
  esac
done

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

INSTALLED_FILES=()
BACKED_UP_FILES=()

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}   Claude Skill Build — Installer${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo ""

# ═══ Step 0: Check external dependencies ═══
echo -e "${BLUE}[0/8] Checking dependencies${NC}"
DEPS_OK=true

# Memory Bank (REQUIRED)
if [ -d "$CLAUDE_DIR/skills/memory-bank" ] || [ -d "$CLAUDE_DIR/skills/claude-skill-memory-bank" ]; then
  echo -e "  ${GREEN}✓${NC} Memory Bank installed"
else
  echo -e "  ${RED}✗${NC} Memory Bank NOT installed (REQUIRED)"
  echo ""
  echo "    Install it first:"
  echo "    git clone https://github.com/fockus/claude-skill-memory-bank.git ~/.claude/skills/claude-skill-memory-bank"
  echo "    cd ~/.claude/skills/claude-skill-memory-bank && ./install.sh"
  echo ""
  DEPS_OK=false
fi

# Find Skill (OPTIONAL)
if [ -d "$CLAUDE_DIR/skills/find-skill" ] || [ -d "$CLAUDE_DIR/skills/claude-skill-find-skill" ]; then
  echo -e "  ${GREEN}✓${NC} Find Skill installed"
else
  echo -e "  ${YELLOW}~${NC} Find Skill not installed (optional)"
  echo "    Install: git clone https://github.com/fockus/claude-skill-find-skill.git ~/.claude/skills/claude-skill-find-skill && cd ~/.claude/skills/claude-skill-find-skill && ./install.sh"
fi

# GSD
GSD_DIR="$CLAUDE_DIR/get-shit-done"
if [ -f "$GSD_DIR/VERSION" ]; then
  echo -e "  ${GREEN}✓${NC} GSD v$(cat "$GSD_DIR/VERSION")"
else
  echo -e "  ${YELLOW}~${NC} GSD not installed (will install in step 7)"
fi

if [ "$DEPS_OK" = false ]; then
  echo ""
  echo -e "${RED}Aborting: required dependencies missing.${NC}"
  exit 1
fi
echo ""

# ═══ Wizard ═══
if [ "$AUTO" = false ]; then
  echo -e "${BLUE}Installation mode:${NC}"
  echo "  1) ${BOLD}Full${NC} (recommended) — agents + hooks + build + pipeline + 33 skills"
  echo "  2) ${BOLD}Core${NC} — agents + hooks + build + pipeline + SDD only"
  echo ""
  read -rp "Choose [1/2] (default: 1): " choice
  case "$choice" in 2) INSTALL_MODE="core" ;; *) INSTALL_MODE="full" ;; esac
  echo ""
fi
echo -e "  Mode: ${BOLD}$INSTALL_MODE${NC}"
echo ""

backup_if_exists() {
  if [ -f "$1" ] && [ ! -L "$1" ]; then
    local backup="$1.pre-build-backup.$(date +%s)"
    cp "$1" "$backup"
    BACKED_UP_FILES+=("$1|$backup")
  fi
}

install_file() {
  mkdir -p "$(dirname "$2")"
  backup_if_exists "$2"
  cp "$1" "$2"
  [[ "$2" == *.sh ]] && chmod +x "$2"
  INSTALLED_FILES+=("$2")
}

# ═══ Step 1: Core Agents ═══
echo -e "${BLUE}[1/8] Core Agents${NC}"
count=0
for f in "$SKILL_DIR/core/agents/"*.md; do
  [ -f "$f" ] || continue
  install_file "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
  count=$((count + 1))
done
echo -e "  ${GREEN}✓${NC} $count agents"

# ═══ Step 2: Hooks ═══
echo -e "${BLUE}[2/8] Quality Hooks${NC}"
count=0
for f in "$SKILL_DIR/core/hooks/"*.sh; do
  [ -f "$f" ] || continue
  install_file "$f" "$CLAUDE_DIR/hooks/$(basename "$f")"
  count=$((count + 1))
done
echo -e "  ${GREEN}✓${NC} $count hooks"

# ═══ Step 3: Build Commands ═══
echo -e "${BLUE}[3/8] Build Commands${NC}"
mkdir -p "$CLAUDE_DIR/commands/build"
count=0
for f in "$SKILL_DIR/core/commands/build/"*.md; do
  [ -f "$f" ] || continue
  install_file "$f" "$CLAUDE_DIR/commands/build/$(basename "$f")"
  count=$((count + 1))
done
echo -e "  ${GREEN}✓${NC} $count build commands"

# ═══ Step 4: Pipeline & Implement ═══
echo -e "${BLUE}[4/8] Pipeline Commands${NC}"
count=0
for f in "$SKILL_DIR/core/commands/"*.md; do
  [ -f "$f" ] || continue
  install_file "$f" "$CLAUDE_DIR/commands/$(basename "$f")"
  count=$((count + 1))
done
echo -e "  ${GREEN}✓${NC} $count commands (pipeline, implement)"

# ═══ Step 5: Bundled Skills ═══
echo -e "${BLUE}[5/8] Bundled Skills${NC}"

# SDD — always install (required for pipeline)
sdd_count=0
for skill_dir in "$SKILL_DIR/skills/sdd-"* "$SKILL_DIR/skills/build-sdd"; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  dest="$CLAUDE_DIR/skills/$skill_name"
  mkdir -p "$dest"
  for f in "$skill_dir"/*; do
    [ -f "$f" ] || continue
    install_file "$f" "$dest/$(basename "$f")"
  done
  sdd_count=$((sdd_count + 1))
done
echo -e "  ${GREEN}✓${NC} SDD: $sdd_count skills (required)"

if [ "$INSTALL_MODE" = "full" ]; then
  opt_count=0
  for skill_dir in "$SKILL_DIR/skills/"*/; do
    skill_name="$(basename "$skill_dir")"
    case "$skill_name" in sdd-*|build-sdd) continue ;; esac
    dest="$CLAUDE_DIR/skills/$skill_name"
    mkdir -p "$dest"
    for f in "$skill_dir"/*; do
      [ -f "$f" ] || continue
      install_file "$f" "$dest/$(basename "$f")"
    done
    opt_count=$((opt_count + 1))
  done
  echo -e "  ${GREEN}✓${NC} Extra: $opt_count skills (reflexion, kaizen, sadd, harness)"
else
  echo -e "  ${YELLOW}~${NC} Extra skills skipped (core mode). ./install.sh --full to add later."
fi

# ═══ Step 6: Settings ═══
echo -e "${BLUE}[6/8] Settings${NC}"
if [ -f "$SKILL_DIR/core/settings/hooks-build.json" ] && command -v python3 &>/dev/null; then
  python3 "$SKILL_DIR/core/settings/merge-hooks.py" \
    "$CLAUDE_DIR/settings.json" \
    "$SKILL_DIR/core/settings/hooks-build.json" \
    2>/dev/null && echo -e "  ${GREEN}✓${NC} Build hooks merged" \
    || echo -e "  ${YELLOW}~${NC} Manual hook setup needed"
fi

# Ensure agent teams env
python3 -c "
import json, sys
p = sys.argv[1]
with open(p) as f: s=json.load(f)
s.setdefault('env',{})['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS']='1'
with open(p,'w') as f: json.dump(s,f,indent=2,ensure_ascii=False)
" "$CLAUDE_DIR/settings.json" 2>/dev/null && echo -e "  ${GREEN}✓${NC} AGENT_TEAMS enabled" || true

# ═══ Step 7: GSD ═══
echo -e "${BLUE}[7/8] GSD (Get Shit Done)${NC}"
if [ -f "$GSD_DIR/VERSION" ]; then
  echo -e "  ${GREEN}✓${NC} Already installed"
else
  if [ "$AUTO" = true ]; then
    DO_GSD=true
  else
    read -rp "  Install GSD via npx? (y/n): " answer
    DO_GSD=false; [ "$answer" = "y" ] || [ "$answer" = "Y" ] && DO_GSD=true
  fi
  if [ "$DO_GSD" = true ]; then
    npx -y "get-shit-done-cc@${GSD_VERSION}" --global 2>/dev/null \
      && echo -e "  ${GREEN}✓${NC} GSD installed" \
      || echo -e "  ${RED}✗${NC} Failed. Run: npx get-shit-done-cc@$GSD_VERSION --global"
  else
    echo -e "  ${YELLOW}~${NC} Skipped. Some /build:* commands need GSD."
  fi
fi

# ═══ Step 8: Manifest ═══
echo -e "${BLUE}[8/8] Manifest${NC}"
INSTALLED_FILES_STR="$(printf '%s\n' "${INSTALLED_FILES[@]}")" \
BACKED_UP_STR="$(printf '%s\n' "${BACKED_UP_FILES[@]}")" \
MANIFEST_PATH="$MANIFEST" \
INSTALL_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
INSTALL_MODE="$INSTALL_MODE" \
python3 << 'PYEOF' 2>/dev/null || echo '  Manifest skipped'
import json, os
files = [f for f in os.environ.get("INSTALLED_FILES_STR", "").split("\n") if f]
backups = [b for b in os.environ.get("BACKED_UP_STR", "").split("\n") if b]
manifest = {
    "installed_at": os.environ["INSTALL_DATE"],
    "skill": "claude-skill-build",
    "mode": os.environ.get("INSTALL_MODE", "full"),
    "files": list(set(files)),
    "backups": list(set(backups))
}
with open(os.environ["MANIFEST_PATH"], "w") as f:
    json.dump(manifest, f, indent=2)
print("  Manifest saved")
PYEOF

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Build skill installed!${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo ""
echo "  Mode: $INSTALL_MODE"
echo "  Files: ${#INSTALLED_FILES[@]}"
echo ""
echo "  Order of setup in Claude Code:"
echo "    1. /mb:setup-project — init memory bank + CLAUDE.md"
echo "    2. /build:init — init GSD + roadmap"
echo "    3. /build:help — see all commands"
echo ""
echo "  Uninstall: $SKILL_DIR/uninstall.sh"
echo ""
