#!/bin/bash
# quality-gate.sh — AI Residuals Scan + Test Tampering Detection
# Вдохновлён claude-code-harness guardrails (R01-R13), адаптирован под наш стек.
# Режим: warn (не block) для .env/.pem/.key — агент МОЖЕТ работать с ними.
#
# Использование: вызывается как PostToolUse hook после Write/Edit
# Exit codes: 0 = pass, 2 = fail (feedback агенту)

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
FILE_PATH="${CLAUDE_FILE_PATH:-}"
COMMAND="${CLAUDE_COMMAND:-}"

# Определяем файл для проверки
TARGET_FILE=""
if [ -n "$FILE_PATH" ]; then
  TARGET_FILE="$FILE_PATH"
elif [ -n "$COMMAND" ]; then
  # Извлечь файл из bash-команды (грубо)
  TARGET_FILE=""
fi

# ═══════════════════════════════════════════════════
# 1. AI Residuals Scan (после Write/Edit)
# ═══════════════════════════════════════════════════
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  if [ -n "$TARGET_FILE" ] && [ -f "$TARGET_FILE" ]; then
    RESIDUALS=""

    # TODO/FIXME/HACK в production коде (не в тестах)
    if [[ "$TARGET_FILE" != *test* ]] && [[ "$TARGET_FILE" != *spec* ]]; then
      FOUND=$(grep -n "TODO\|FIXME\|HACK\|XXX" "$TARGET_FILE" 2>/dev/null | head -5)
      if [ -n "$FOUND" ]; then
        RESIDUALS="${RESIDUALS}\n⚠️ AI Residuals — placeholder'ы в production коде:\n$FOUND"
      fi
    fi

    # localhost URLs (не в тестах и не в конфигах)
    if [[ "$TARGET_FILE" != *test* ]] && [[ "$TARGET_FILE" != *config* ]] && [[ "$TARGET_FILE" != *.env* ]] && [[ "$TARGET_FILE" != *.yaml ]]; then
      FOUND=$(grep -n "localhost\|127\.0\.0\.1" "$TARGET_FILE" 2>/dev/null | grep -v "^#\|^//" | head -3)
      if [ -n "$FOUND" ]; then
        RESIDUALS="${RESIDUALS}\n⚠️ AI Residuals — localhost URL в production коде:\n$FOUND"
      fi
    fi

    # mockData/dummyData/fakeData
    FOUND=$(grep -n "mockData\|dummyData\|fakeData\|mock_data\|dummy_data\|fake_data" "$TARGET_FILE" 2>/dev/null | head -3)
    if [ -n "$FOUND" ]; then
      RESIDUALS="${RESIDUALS}\n⚠️ AI Residuals — mock/dummy/fake data:\n$FOUND"
    fi

    # console.log в production (не тестах)
    if [[ "$TARGET_FILE" != *test* && "$TARGET_FILE" != *spec* ]] && \
       [[ "$TARGET_FILE" == *.ts || "$TARGET_FILE" == *.js || "$TARGET_FILE" == *.tsx || "$TARGET_FILE" == *.jsx ]]; then
      FOUND=$(grep -n "console\.log\|console\.debug" "$TARGET_FILE" 2>/dev/null | head -3)
      if [ -n "$FOUND" ]; then
        RESIDUALS="${RESIDUALS}\n⚠️ AI Residuals — console.log в production:\n$FOUND"
      fi
    fi

    # print() в production Python (не тестах)
    if [[ "$TARGET_FILE" != *test* ]] && [[ "$TARGET_FILE" == *.py ]]; then
      FOUND=$(grep -n "^\s*print(" "$TARGET_FILE" 2>/dev/null | head -3)
      if [ -n "$FOUND" ]; then
        RESIDUALS="${RESIDUALS}\n⚠️ AI Residuals — print() в production Python:\n$FOUND"
      fi
    fi

    if [ -n "$RESIDUALS" ]; then
      echo -e "$RESIDUALS" >&2
      # warn, не block — агент получит feedback
    fi
  fi
fi

# ═══════════════════════════════════════════════════
# 2. Test Tampering Detection (после Write/Edit тестовых файлов)
# ═══════════════════════════════════════════════════
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  if [ -n "$TARGET_FILE" ] && [ -f "$TARGET_FILE" ]; then
    IS_TEST=false
    [[ "$TARGET_FILE" == *test* ]] && IS_TEST=true
    [[ "$TARGET_FILE" == *spec* ]] && IS_TEST=true
    [[ "$TARGET_FILE" == *_test.* ]] && IS_TEST=true

    if [ "$IS_TEST" = true ]; then
      TAMPERING=""

      # JavaScript/TypeScript skip patterns
      FOUND=$(grep -n "it\.skip\|describe\.skip\|test\.skip\|xit(\|xdescribe(" "$TARGET_FILE" 2>/dev/null | head -5)
      if [ -n "$FOUND" ]; then
        TAMPERING="${TAMPERING}\n🚫 Test Tampering — skipped tests:\n$FOUND"
      fi

      # Python skip patterns
      FOUND=$(grep -n "@pytest\.mark\.skip\|@unittest\.skip\|pytest\.skip(" "$TARGET_FILE" 2>/dev/null | head -5)
      if [ -n "$FOUND" ]; then
        TAMPERING="${TAMPERING}\n🚫 Test Tampering — skipped Python tests:\n$FOUND"
      fi

      # Assertion на true (подозрительно)
      FOUND=$(grep -n "assert True\|expect(true)\|assert_equal(true" "$TARGET_FILE" 2>/dev/null | head -3)
      if [ -n "$FOUND" ]; then
        TAMPERING="${TAMPERING}\n🚫 Test Tampering — suspicious assert true:\n$FOUND"
      fi

      if [ -n "$TAMPERING" ]; then
        echo -e "$TAMPERING" >&2
        exit 2  # BLOCK — тесты нельзя скипать
      fi
    fi
  fi
fi

# ═══════════════════════════════════════════════════
# 3. Protected Files Warning (warn, не block)
# ═══════════════════════════════════════════════════
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  if [ -n "$TARGET_FILE" ]; then
    case "$TARGET_FILE" in
      */package.json|*/Dockerfile|*/docker-compose.yml|*/docker-compose.yaml)
        echo "⚠️ Protected file warning: правка $TARGET_FILE — убедись что изменение необходимо" >&2
        ;;
      */.github/workflows/*)
        echo "⚠️ Protected file warning: правка CI workflow $TARGET_FILE" >&2
        ;;
      */schema.prisma|*/wrangler.toml)
        echo "⚠️ Protected file warning: правка инфраструктурного файла $TARGET_FILE" >&2
        ;;
    esac
    # .env, .pem, .key — разрешены без warning (по запросу пользователя)
  fi
fi

# ═══════════════════════════════════════════════════
# 4. Dangerous Bash Commands (warn)
# ═══════════════════════════════════════════════════
if [ "$TOOL_NAME" = "Bash" ] && [ -n "$COMMAND" ]; then
  # sudo
  if echo "$COMMAND" | grep -qE '(^|\s)sudo\s'; then
    echo "⚠️ sudo detected: $COMMAND" >&2
  fi

  # git push --force (warn, не block)
  if echo "$COMMAND" | grep -qE 'git\s+push.*--force|git\s+push.*-f\b'; then
    echo "⚠️ Force push detected: $COMMAND" >&2
  fi

  # --no-verify
  if echo "$COMMAND" | grep -qE '\-\-no-verify'; then
    echo "⚠️ --no-verify detected — hooks будут пропущены: $COMMAND" >&2
  fi

  # rm -rf (warn)
  if echo "$COMMAND" | grep -qE 'rm\s+(-[^\s]*r[^\s]*f|--recursive)'; then
    echo "⚠️ rm -rf detected: $COMMAND" >&2
  fi
fi

exit 0
