---
name: build:fast
description: Trivial task inline — GSD fast + MB checklist sync
argument-hint: "<description>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

<objective>
Тривиальная задача без планирования. GSD fast mode + обновление MB checklist.

Для: опечатки, мелкий рефакторинг, добавление одного теста, обновление конфига.
НЕ для: новая business logic (нужен TDD → `/build:quick` минимум).
</objective>

<context>
$ARGUMENTS
</context>

<process>

## Step 0: Pre-flight (minimal)

Проверь что `.planning/` существует. Если нет → предложи `/build:init` и прервись.

## Step 1: Execute

Вызови `/gsd:fast $ARGUMENTS`. Дождись завершения.

## Step 2: MB Sync (minimal)

1. Если задача была в `.memory-bank/checklist.md` → пометь ✅
2. Если изменились тесты → обнови метрики в `.memory-bank/STATUS.md`

Не создавать note, не писать в progress для тривиальных задач.

</process>
