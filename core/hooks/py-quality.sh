#!/bin/bash
# PostToolUse hook: Python quality — format + lint + security
export PATH="$HOME/.pyenv/shims:$HOME/.local/bin:/opt/homebrew/bin:$PATH"

FILE_PATH="$CLAUDE_FILE_PATH"
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# 1. Format (быстро, всегда)
command -v black >/dev/null && black --quiet "$FILE_PATH" 2>/dev/null
command -v isort >/dev/null && isort --quiet "$FILE_PATH" 2>/dev/null

# 2. Lint (ruff, быстрый linter)
if command -v ruff >/dev/null; then
  # fix автоматически исправляемые проблемы
  ruff check --fix --quiet "$FILE_PATH" 2>/dev/null
  # показать оставшиеся проблемы
  LINT_OUT=$(ruff check "$FILE_PATH" 2>&1)
  if [ -n "$LINT_OUT" ]; then
    echo "[LINT]"
    echo "$LINT_OUT" | head -15
  fi
fi

# 3. Security (bandit, только high severity)
if command -v bandit >/dev/null; then
  SEC_OUT=$(bandit -q -ll "$FILE_PATH" 2>&1)
  if [ -n "$SEC_OUT" ] && ! echo "$SEC_OUT" | grep -q "No issues identified"; then
    echo "[SECURITY]"
    echo "$SEC_OUT" | head -10
  fi
fi

exit 0
