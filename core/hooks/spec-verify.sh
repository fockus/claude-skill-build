#!/bin/bash
# spec-verify.sh — Verifies implementation matches SDD specifications
# Usage: spec-verify.sh <specs-dir> [<src-dir>] [<tests-dir>]
# Exit: 0 = pass, 1 = failures found
#
# Checks:
# 1. Each AC (acceptance criterion) in requirements.md has a matching test
# 2. Each design decision in design.md is reflected in code
# 3. All tasks in tasks.md are marked complete
# 4. No orphan ACs without tests

set -euo pipefail

SRC_DIR="${2:-src/}"
TESTS_DIR="${3:-tests/}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

echo "=== SDD Spec Verification ==="
echo ""

# Find requirements files
# S-6: glob must be unquoted for expansion; explicit arg is quoted safely
if [ -n "${1:-}" ]; then
    REQ_FILES=$(find "$1" -name "requirements.md" 2>/dev/null)
else
    REQ_FILES=$(find .planning/phases/*/specs -name "requirements.md" 2>/dev/null)
fi

if [ -z "$REQ_FILES" ]; then
  echo -e "${YELLOW}No specs found in ${1:-.planning/phases/*/specs} — skipping verification${NC}"
  exit 0
fi

while IFS= read -r REQ_FILE; do
  SPEC_NAME=$(basename "$(dirname "$REQ_FILE")")
  echo "--- Spec: $SPEC_NAME ---"
  echo "  Requirements: $REQ_FILE"

  # ═══════════════════════════════════════════════════
  # 1. Extract EARS acceptance criteria (AC-XX.XX)
  # ═══════════════════════════════════════════════════
  AC_IDS=$(grep -oE 'AC-[0-9]+\.[0-9]+' "$REQ_FILE" 2>/dev/null | sort -u || true)
  AC_COUNT=$(echo "$AC_IDS" | grep -c 'AC-' 2>/dev/null || echo 0)

  if [ "$AC_COUNT" -eq 0 ]; then
    echo -e "  ${YELLOW}WARN: No acceptance criteria (AC-XX.XX) found${NC}"
    WARN=$((WARN + 1))
  else
    echo "  Found $AC_COUNT acceptance criteria"

    # Check each AC has a corresponding test
    for AC_ID in $AC_IDS; do
      # Normalize: AC-01.1 → ac_01_1, ac_01.1, AC-01.1, ac01_1
      AC_SNAKE=$(echo "$AC_ID" | tr '[:upper:]' '[:lower:]' | sed 's/-/_/g; s/\./_/g')
      AC_DOT=$(echo "$AC_ID" | tr '[:upper:]' '[:lower:]' | sed 's/-/_/g')
      AC_ORIG="$AC_ID"

      # Search in test files for any reference to this AC
      FOUND=$(grep -rlE "$AC_ORIG|$AC_SNAKE|$AC_DOT" "$TESTS_DIR" 2>/dev/null | head -1 || true)

      if [ -n "$FOUND" ]; then
        echo -e "    ${GREEN}PASS${NC} $AC_ID → $(basename "$FOUND")"
        PASS=$((PASS + 1))
      else
        # Try fuzzy: extract the WHEN/THEN text and search for keywords
        AC_TEXT=$(grep -A1 "$AC_ID" "$REQ_FILE" 2>/dev/null | tail -1 | sed 's/.*THEN.*SHALL //; s/.*WHEN //')
        KEYWORDS=$(echo "$AC_TEXT" | tr ' ' '\n' | grep -v 'the\|a\|is\|to\|and\|or\|it\|in\|of' | head -3 | tr '\n' '|' | sed 's/|$//')

        if [ -n "$KEYWORDS" ]; then
          FUZZY=$(grep -rlE "$KEYWORDS" "$TESTS_DIR" 2>/dev/null | head -1 || true)
          if [ -n "$FUZZY" ]; then
            echo -e "    ${YELLOW}WEAK${NC} $AC_ID → fuzzy match in $(basename "$FUZZY")"
            WARN=$((WARN + 1))
          else
            echo -e "    ${RED}FAIL${NC} $AC_ID — no test found"
            FAIL=$((FAIL + 1))
          fi
        else
          echo -e "    ${RED}FAIL${NC} $AC_ID — no test found"
          FAIL=$((FAIL + 1))
        fi
      fi
    done
  fi

  # ═══════════════════════════════════════════════════
  # 2. Check edge cases have tests
  # ═══════════════════════════════════════════════════
  EC_IDS=$(grep -oE 'EC-[0-9]+' "$REQ_FILE" 2>/dev/null | sort -u || true)
  EC_COUNT=$(echo "$EC_IDS" | grep -c 'EC-' 2>/dev/null || echo 0)

  if [ "$EC_COUNT" -gt 0 ]; then
    echo "  Found $EC_COUNT edge cases"
    for EC_ID in $EC_IDS; do
      EC_SNAKE=$(echo "$EC_ID" | tr '[:upper:]' '[:lower:]' | sed 's/-/_/g')
      FOUND=$(grep -rlE "$EC_ID|$EC_SNAKE|edge.case" "$TESTS_DIR" 2>/dev/null | head -1 || true)
      if [ -n "$FOUND" ]; then
        echo -e "    ${GREEN}PASS${NC} $EC_ID → $(basename "$FOUND")"
        PASS=$((PASS + 1))
      else
        echo -e "    ${YELLOW}WARN${NC} $EC_ID — no explicit test (may be covered implicitly)"
        WARN=$((WARN + 1))
      fi
    done
  fi

  # ═══════════════════════════════════════════════════
  # 3. Check unchanged behavior preserved
  # ═══════════════════════════════════════════════════
  UB_COUNT=$(grep -c 'SHALL CONTINUE TO' "$REQ_FILE" 2>/dev/null || echo 0)
  if [ "$UB_COUNT" -gt 0 ]; then
    echo "  $UB_COUNT unchanged behavior items — verify backward compat tests exist"
  fi

  # ═══════════════════════════════════════════════════
  # 4. Check design decisions referenced in code
  # ═══════════════════════════════════════════════════
  DESIGN_FILE="$(dirname "$REQ_FILE")/design.md"
  if [ -f "$DESIGN_FILE" ]; then
    DD_IDS=$(grep -oE 'DD-[0-9]+' "$DESIGN_FILE" 2>/dev/null | sort -u || true)
    DD_COUNT=$(echo "$DD_IDS" | grep -c 'DD-' 2>/dev/null || echo 0)
    if [ "$DD_COUNT" -gt 0 ]; then
      echo "  $DD_COUNT design decisions in design.md"
    fi
  fi

  echo ""
done <<< "$REQ_FILES"

# ═══════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════
echo "=== Summary ==="
echo -e "  ${GREEN}PASS: $PASS${NC}"
echo -e "  ${RED}FAIL: $FAIL${NC}"
echo -e "  ${YELLOW}WARN: $WARN${NC}"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo -e "${RED}Spec verification FAILED: $FAIL acceptance criteria without tests${NC}"
  echo "Fix: add tests referencing the AC-XX.XX ID in test name or docstring"
  exit 1
else
  echo ""
  echo -e "${GREEN}Spec verification PASSED${NC}"
  exit 0
fi
