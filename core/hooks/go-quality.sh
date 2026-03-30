#!/bin/bash
# PostToolUse hook: Go quality — format + lint + test
export PATH="$HOME/go/bin:$HOME/.pyenv/shims:/opt/homebrew/bin:$PATH"

FILE_PATH="$CLAUDE_FILE_PATH"
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# 1. Format (быстро, всегда)
command -v gofmt >/dev/null && gofmt -w "$FILE_PATH" 2>/dev/null
command -v goimports >/dev/null && goimports -w "$FILE_PATH" 2>/dev/null

# 2. Lint (golangci-lint --fast, только ошибки)
if command -v golangci-lint >/dev/null; then
  PKG_DIR=$(dirname "$FILE_PATH")
  LINT_OUT=$(golangci-lint run --fast \
    --max-issues-per-linter=3 --max-same-issues=2 \
    "$PKG_DIR/..." 2>&1)
  if [ -n "$LINT_OUT" ]; then
    echo "[LINT]"
    echo "$LINT_OUT" | head -15
  fi
fi

# 3. Test (short mode, только пакет, timeout 30s)
PKG_DIR=$(dirname "$FILE_PATH")
if ls "$PKG_DIR"/*_test.go >/dev/null 2>&1; then
  TEST_OUT=$(cd "$PKG_DIR" && go test -short -count=1 -timeout=30s ./... 2>&1)
  TEST_EXIT=$?
  if [ $TEST_EXIT -ne 0 ]; then
    echo "[TEST FAIL]"
    echo "$TEST_OUT" | tail -15
  fi
fi

exit 0
