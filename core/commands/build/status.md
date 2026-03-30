---
name: build:status
description: Project status dashboard — MB context + GSD progress + deps health
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
---

<objective>
Единая точка входа для понимания состояния проекта. Собирает контекст из Memory Bank и GSD, показывает deps health, текущий фокус и рекомендует следующий шаг.
</objective>

<process>

## 1. Deps Health

Запусти `~/.claude/hooks/build-deps-check.sh` и выведи результат.

**Pipeline config:** проверь `.pipeline.yaml` существует:
- **Да** → извлеки `project.name`, `project.language`, список `commands.*`
- **Нет** → вывести: "`.pipeline.yaml` не найден. Создай по шаблону из `/build:help`."

## 2. Memory Bank Context

Если `.memory-bank/` существует:

1. Прочитай `.memory-bank/STATUS.md` → извлеки:
   - Текущий этап / milestone
   - Ключевые метрики (тесты, coverage)
   - Roadmap статус (что завершено, что в процессе)

2. Прочитай `.memory-bank/checklist.md` → извлеки:
   - Сколько ⬜ (todo) и ✅ (done)
   - Текущие незавершённые задачи (первые 5)

3. Прочитай `.memory-bank/plan.md` → извлеки:
   - Active plan (если есть)
   - Текущий фокус

4. Прочитай `.memory-bank/RESEARCH.md` → извлеки:
   - Активные гипотезы (H-NNN со статусом testing/open)

Если `.memory-bank/` не существует → вывести: "Memory Bank не инициализирован. Запусти `/mb init`."

## 3. GSD Context

Если `.planning/` существует:

1. Прочитай `.planning/STATE.md` → текущая позиция в GSD workflow
2. Прочитай `.planning/ROADMAP.md` → обзор фаз (completed / current / upcoming)
3. Посчитай файлы:
   ```bash
   # Фазы
   ls -d .planning/phases/*/ 2>/dev/null | wc -l
   # Планы в текущей фазе
   ls .planning/phases/*/PLAN*.md 2>/dev/null | wc -l
   # Незавершённые SUMMARY
   ls .planning/phases/*/SUMMARY*.md 2>/dev/null | wc -l
   ```

Если `.planning/` не существует → вывести: "GSD не инициализирован. Запусти `/build:init`."

## 4. Git Context

```bash
# Текущая ветка
git branch --show-current 2>/dev/null

# Uncommitted changes
git status --short 2>/dev/null | wc -l | tr -d ' '

# Последний коммит
git log --oneline -1 2>/dev/null
```

## 5. Dashboard Output

Выведи единый dashboard:

```
═══ BUILD STATUS ═══

📦 Dependencies
  GSD: v{version} ✅ | ❌ (npx get-shit-done-cc@1.14.0 --global)
  MB:  ✅ installed | ⚠️ not found
  Commands: {N} GSD commands

📋 Memory Bank
  Status: {текущий этап из STATUS.md}
  Checklist: {done}/{total} задач ({percent}%)
  Focus: {из plan.md}
  Hypotheses: {N} active

🗺️ GSD Roadmap
  Phases: {completed}/{total}
  Current: Phase {N} — {name}
  Plans: {N} plans, {N} summaries

🔀 Git
  Branch: {branch}
  Uncommitted: {N} files
  Last commit: {hash} {message}

═══ NEXT STEP ═══
{рекомендация}
```

## 6. Next Step Recommendation

На основе собранного контекста определи рекомендацию:

| Ситуация | Рекомендация |
|----------|-------------|
| Нет `.planning/` | `/build:init` |
| Нет `.memory-bank/` | `/mb init` |
| Есть PLAN без SUMMARY в текущей фазе | `/build:phase {N}` или `/build:team-phase {N}` |
| Все фазы завершены | `/gsd:complete-milestone` |
| Есть uncommitted changes | Рассмотри коммит |
| Checklist 100% для текущей фазы | `/gsd:verify-work {N}` |
| Есть ⬜ задачи в checklist | Продолжить работу по checklist |
| Нет активного плана | `/gsd:plan-phase {next}` |

</process>
