---
name: build:quick
description: Quick task with GSD execution + project rules + MB sync
argument-hint: "[--discuss] [--research] [--full] [--reflexion]"
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
Быстрая задача через GSD quick mode с соблюдением проектных правил и синхронизацией Memory Bank.

Для ad-hoc задач, которые не требуют полного phase-цикла, но должны:
- Следовать TDD/Contract-First/SOLID
- Получить atomic commit
- Обновить Memory Bank
</objective>

<context>
$ARGUMENTS

Flags (передаются в GSD):
- `--discuss` — обсудить серые зоны перед планированием
- `--research` — исследовать подходы перед планированием
- `--full` — план-чекер + верификация после execute
- `--reflexion` — после execution запустить рефлексию и root cause analysis при ошибках
</context>

<process>

## Step 0: Load MB Context

**Deps Check:** запусти `~/.claude/hooks/build-deps-check.sh`. Если exit code ≠ 0 → предложи `~/.claude/hooks/build-install-deps.sh` и прервись.

1. Прочитай `.memory-bank/STATUS.md` и `.memory-bank/checklist.md`
2. Краткое резюме текущего состояния (1-2 предложения)
3. Прочитай `~/.claude/RULES.md` → `{GLOBAL_RULES}`
4. Если существует `./RULES.md` → прочитай → `{PROJECT_RULES}`. Если нет → пустая строка

## Step 1: Execute GSD Quick

Вызови `/gsd:quick` с переданными флагами и описанием задачи от пользователя.

Дождись завершения.

## Step 1.5: Judge Verification (только при --full)

Если `--full` не указан → пропустить, перейти к Step 2.

### 1.5a. Meta-Judge (лёгкий)

```
Agent(subagent_type: "general-purpose", model: "opus",
      description: "Meta-Judge: quick task evaluation spec",
      prompt: "
<CRITICAL_CONSTRAINTS>
- Lightweight evaluation — only 3 criteria
- Criteria MUST be measurable
- Include RULES compliance
</CRITICAL_CONSTRAINTS>

<RULES>
## Global Rules
{GLOBAL_RULES}
## Project Rules
{PROJECT_RULES}
</RULES>

<TASK>
Generate lightweight evaluation specification YAML for quick task:
'{task description}'

Only 3 criteria: correctness (0.40), test_quality (0.30), code_quality (0.30).
</TASK>

<OUTPUT_FORMAT>
Return ONLY evaluation specification YAML. No prose.
</OUTPUT_FORMAT>
")
```

### 1.5b. Judge

```
Agent(subagent_type: "judge", model: "opus",
      description: "Judge: quick task verification",
      prompt: "
<CRITICAL_CONSTRAINTS>
- Score based ONLY on evaluation specification
- Each score REQUIRES file:line evidence
- 5.0 on ALL = reject
</CRITICAL_CONSTRAINTS>

<RULES>
## Global Rules
{GLOBAL_RULES}
## Project Rules
{PROJECT_RULES}
</RULES>

<TASK>
Evaluate quick task implementation:

\`\`\`yaml
{EVAL_SPEC_YAML}
\`\`\`

Changes summary: {GSD quick execution report}
</TASK>

<OUTPUT_FORMAT>
Output: JSON {scores, weighted_average, verdict: PASS/FAIL, evidence, issues}
VERIFY: каждая оценка подкреплена file:line evidence.
</OUTPUT_FORMAT>
")
```

### 1.5c. Decision

- Score ≥ 3.5 → PASS → Step 2 (threshold 3.5 vs 4.0 для phase — quick tasks меньше scope, 3 criteria вместо 5)
- Score < 3.5 → 1 retry с feedback из Judge issues → Score ≥ 3.5 → Step 2 (1 retry vs 3/5 для phase/team-phase — пропорционально scope)
- Retry тоже FAIL → сообщить пользователю issues, предложить manual fix

**При retry:** используй тот же `{EVAL_SPEC_YAML}` — НЕ пересоздавай Meta-Judge.

## Step 2: MB Sync

После завершения GSD quick:

1. **checklist.md** — если задача была в списке → ⬜→✅. Если новая → не добавлять (quick tasks вне roadmap)
2. **STATUS.md** — обнови метрики если изменились (тесты, coverage)
3. **progress.md** — APPEND запись:

```markdown
## {date}

### Quick: {название задачи}
- {что сделано — 2-3 пункта}
- Тесты: {число} green
```

4. **lessons.md** — если обнаружен антипаттерн во время работы
5. **BACKLOG.md** — если принято архитектурное решение (ADR)

## Step 2.5: Reflexion (опционально)

Если во время execution были проблемы (failed tests, multiple retries, unexpected issues):

Вызови `/reflexion-reflect` для self-analysis:
- Что пошло не так и почему
- Как избежать в будущем
- Нужно ли обновить lessons.md

Если проблема глубокая (причина неочевидна):
- Вызови `/kaizen-why` для 5 Whys root cause analysis
- Результат → `.memory-bank/lessons.md`

## Step 3: Report

Выведи краткий итог:
- Что сделано
- Commit hash
- Следующий шаг (если есть)

</process>
