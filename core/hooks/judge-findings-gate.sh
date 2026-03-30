#!/bin/bash
# judge-findings-gate.sh — Blocks commit when judge/reviewer findings are unresolved
# Fires as PostToolUse hook on Bash (git commit) and Agent (judge/reviewer completion)
# Exit codes: 0 = pass, 2 = block with feedback
#
# Logic:
# 1. On git commit: check JUDGE_PASS.md exists + no SERIOUS findings
# 2. On judge/reviewer agent completion: parse report, warn if findings exist

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
COMMAND="${CLAUDE_COMMAND:-}"

# ═══════════════════════════════════════════════════
# 1. Block commit if JUDGE_PASS.md has SERIOUS findings
# ═══════════════════════════════════════════════════
if [ "$TOOL_NAME" = "Bash" ] && [ -n "$COMMAND" ]; then
  # Only check on git commit commands
  if echo "$COMMAND" | grep -qE 'git\s+commit'; then

    # Find active phase directory
    PLANNING_DIR=".planning/phases"
    if [ ! -d "$PLANNING_DIR" ]; then
      exit 0  # No planning dir, skip check
    fi

    # Find the latest JUDGE_PASS.md
    JUDGE_FILE=$(find "$PLANNING_DIR" -name "JUDGE_PASS.md" -newer "$PLANNING_DIR" 2>/dev/null | sort -r | head -1)

    if [ -z "$JUDGE_FILE" ]; then
      # No JUDGE_PASS.md found — check if this is a phase commit
      if echo "$COMMAND" | grep -qE 'feat\(phase-|fix\(phase-'; then
        echo "BLOCK: JUDGE_PASS.md not found. Run Judge Gate before committing phase work." >&2
        exit 2
      fi
      exit 0  # Non-phase commit, skip
    fi

    # Check for SERIOUS findings in JUDGE_PASS.md
    SERIOUS_COUNT=$(grep -c "SERIOUS" "$JUDGE_FILE" 2>/dev/null || echo "0")
    if [ "$SERIOUS_COUNT" -gt 0 ]; then
      # Check if findings are in a "resolved" or "fixed" section
      UNRESOLVED=$(grep "SERIOUS" "$JUDGE_FILE" 2>/dev/null | grep -cv "fixed\|resolved\|closed" || echo "0")
      if [ "$UNRESOLVED" -gt 0 ]; then
        echo "BLOCK: JUDGE_PASS.md contains $SERIOUS_COUNT SERIOUS finding(s)." >&2
        echo "Fix ALL SERIOUS findings and re-judge before committing." >&2
        echo "File: $JUDGE_FILE" >&2
        exit 2
      fi
    fi
  fi
fi

# ═══════════════════════════════════════════════════
# 2. After Agent completion: warn about findings
# ═══════════════════════════════════════════════════
if [ "$TOOL_NAME" = "Agent" ]; then
  # Check if agent output contains judge/review findings
  AGENT_OUTPUT="${CLAUDE_TOOL_OUTPUT:-}"

  if [ -n "$AGENT_OUTPUT" ]; then
    # Count SERIOUS/CRITICAL findings in output
    SERIOUS=$(echo "$AGENT_OUTPUT" | grep -ci "SERIOUS\|CRITICAL" 2>/dev/null || echo "0")
    if [ "$SERIOUS" -gt 0 ]; then
      echo "" >&2
      echo "WARNING: Judge/Reviewer found $SERIOUS SERIOUS/CRITICAL finding(s)." >&2
      echo "DO NOT proceed to commit. Fix ALL findings first, then re-judge." >&2
      echo "Pipeline rule: Judge PASS + SERIOUS findings = fix + re-judge required." >&2
      echo "" >&2
      # Warn, don't block — the Agent tool itself shouldn't be blocked
    fi
  fi
fi

exit 0
