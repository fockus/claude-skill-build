---
name: build:init
description: Initialize GSD for existing project with Memory Bank bridge
argument-hint: "[--map-first]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Task
  - AskUserQuestion
  - Agent
---

<objective>
Инициализировать GSD (.planning/) для существующего проекта, сохраняя и связывая с Memory Bank (.memory-bank/).

Создаёт мост между GSD артефактами и MB долгосрочной памятью.
</objective>

<context>
$ARGUMENTS
</context>

<process>

## Step 0: Pre-flight Check

1. Проверь `.memory-bank/` существует → `[MEMORY BANK: ACTIVE]`
   - Нет → вызови `/mb init` сначала
2. Проверь `.planning/` существует
   - Да → "GSD уже инициализирован. Хотите переинициализировать?" (СТОП если нет)
3. Прочитай `.memory-bank/STATUS.md`, `checklist.md`, `plan.md` — собери контекст

## Step 1: Map Codebase (if --map-first or recommended)

Если проект имеет существующий код (>10 файлов в src/):

```
Кодовая база уже содержит код. Рекомендую сначала `/gsd:map-codebase`
чтобы GSD понял архитектуру перед инициализацией.

Запустить маппинг? (y/n)
```

Если да → вызови `/gsd:map-codebase`. Дождись завершения.

## Step 1.5: Verify Build Hooks

Проверь что build-specific hooks установлены:

```bash
# Judge Findings Gate — блокирует commit при SERIOUS findings
if [ ! -f ~/.claude/hooks/judge-findings-gate.sh ]; then
  echo "MISSING: judge-findings-gate.sh — создай из build skill template"
fi

# Проверь регистрацию в settings.json
grep -q "judge-findings-gate" ~/.claude/settings.json
```

Если hook отсутствует — создай его:
- `~/.claude/hooks/judge-findings-gate.sh` — блокирует `git commit` если JUDGE_PASS.md содержит SERIOUS findings
- Зарегистрируй в `settings.json` как PostToolUse Bash hook

**Build hooks:**
| Hook | Trigger | Action |
|------|---------|--------|
| `judge-findings-gate.sh` | `git commit` (PostToolUse Bash) | BLOCK если SERIOUS findings в JUDGE_PASS.md |
| `quality-gate.sh` | Write/Edit (PostToolUse) | WARN AI residuals, BLOCK test tampering |

## Step 2: Initialize GSD

Вызови `/gsd:new-project`.

**ВАЖНО:** Во время интерактивных вопросов GSD, используй контекст из MB:
- STATUS.md → текущая фаза, roadmap, метрики
- plan.md → текущий фокус и направление
- RESEARCH.md → активные гипотезы и findings
- BACKLOG.md → идеи и ADR

Это позволит GSD создать PROJECT.md, REQUIREMENTS.md, ROADMAP.md, согласованные с уже существующим контекстом проекта.

## Step 3: Sync GSD → MB

После завершения `/gsd:new-project`:

1. Прочитай `.planning/ROADMAP.md` — извлеки фазы
2. Обнови `.memory-bank/STATUS.md`:
   - Roadmap секция: добавь GSD фазы как 📋 Следующее
   - Не перезаписывай существующие ✅ Завершено пункты
3. Обнови `.memory-bank/plan.md`:
   - Добавь ссылку на `.planning/ROADMAP.md`
   - Обнови фокус если изменился
4. Обнови `.memory-bank/checklist.md`:
   - Добавь секцию "GSD Phases" со ⬜ для каждой фазы
5. Запиши в `.memory-bank/progress.md` (APPEND-ONLY):

```markdown
## {date}

### GSD Initialized
- PROJECT.md: {краткое описание}
- Phases: {число} phases в ROADMAP
- Bridge: GSD (.planning/) ↔ MB (.memory-bank/) connected
```

## Step 4: Verify Bridge

Покажи пользователю:
- GSD: PROJECT.md, REQUIREMENTS.md, ROADMAP.md — summary
- MB: STATUS.md, plan.md, checklist.md — что обновлено
- Предложи: "Начать с `/build:phase 1` (discuss → plan → execute → verify)"

</process>

<notes>
- GSD PROJECT.md != MB STATUS.md. Они дополняют друг друга:
  - PROJECT.md = видение и цели (GSD)
  - STATUS.md = текущее положение и метрики (MB)
- ROADMAP.md (GSD) и plan.md (MB) могут расходиться:
  - ROADMAP = макро-уровень (фазы milestone)
  - plan.md = микро-уровень (текущий фокус и ближайшие шаги)
- При конфликте — MB как source of truth для текущего состояния, GSD для будущего плана
</notes>
