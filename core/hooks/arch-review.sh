#!/bin/bash
# arch-review.sh — Architecture compliance checks
# Runs import-linter (if configured), bounded context validation, SRP/ISP checks
# Usage: invoked as PostToolUse hook after Write/Edit on source files
# Exit codes: 0 = pass, 2 = fail (feedback to agent)
set -euo pipefail

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
FILE_PATH="${CLAUDE_FILE_PATH:-}"

# Only run on Write/Edit of source files
if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
  exit 0
fi

# Only check .py source files (not tests, not configs)
if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *.py ]] || [[ "$FILE_PATH" == *test* ]]; then
  exit 0
fi

VIOLATIONS=""

# 1. Import-linter check (if pyproject.toml has [tool.importlinter])
if [ -f "pyproject.toml" ] && grep -q "tool.importlinter" pyproject.toml 2>/dev/null; then
  LINT_RESULT=$(lint-imports 2>&1 | tail -5)
  LINT_EXIT=$?
  if [ $LINT_EXIT -ne 0 ]; then
    VIOLATIONS="${VIOLATIONS}\n🏗️ Architecture: import-linter violations:\n${LINT_RESULT}"
  fi
fi

# 2. Module size check (SRP: >300 LOC)
if [ -f "$FILE_PATH" ]; then
  LOC=$(wc -l < "$FILE_PATH" | tr -d ' ')
  if [ "$LOC" -gt 300 ]; then
    VIOLATIONS="${VIOLATIONS}\n🏗️ Architecture: $FILE_PATH has ${LOC} lines (SRP limit: 300)"
  fi
fi

# 3. Protocol ISP check (>5 methods in Protocol class)
if [ -f "$FILE_PATH" ]; then
  PROTOCOL_METHODS=$(python3 -c "
import ast, sys
try:
    tree = ast.parse(open(sys.argv[1]).read())
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            bases = [getattr(b, 'id', getattr(b, 'attr', '')) for b in node.bases]
            if 'Protocol' in bases:
                methods = [n for n in node.body if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) and not n.name.startswith('_')]
                if len(methods) > 5:
                    print(f'{node.name}: {len(methods)} methods (ISP limit: 5)')
except Exception:
    pass
" "$FILE_PATH" 2>/dev/null) || true
  if [ -n "$PROTOCOL_METHODS" ]; then
    VIOLATIONS="${VIOLATIONS}\n🏗️ Architecture: ISP violation in $FILE_PATH:\n${PROTOCOL_METHODS}"
  fi
fi

if [ -n "$VIOLATIONS" ]; then
  echo -e "$VIOLATIONS" >&2
  exit 2  # feedback to agent — architecture violations detected
fi

exit 0
