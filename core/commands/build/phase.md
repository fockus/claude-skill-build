---
name: build:phase
description: Full phase cycle — GSD execution engine + MB quality layer + MB memory sync
argument-hint: "<phase-number> [--skip-discuss] [--skip-verify] [--interactive] [--debate] [--sdd]"
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
Полный цикл реализации фазы: GSD execution engine + проектные правила (TDD, SOLID, Contract-First) + Memory Bank синхронизация.

Оркестратор связывает GSD (свежий контекст, параллелизм, субагенты) с MB (долгосрочная память, планы с DoD, верификация).

**Принцип:** GSD делает execution, ты контролируешь quality и memory.
</objective>

<context>
Phase: $ARGUMENTS
</context>

<process>

## Step 0: Load Context (MB + GSD)

**Deps Check:** запусти `~/.claude/hooks/build-deps-check.sh`. Если exit code ≠ 0 → предложи `~/.claude/hooks/build-install-deps.sh` и прервись.

1. Прочитай `.memory-bank/STATUS.md`, `.memory-bank/checklist.md`, `.memory-bank/plan.md`, `.memory-bank/RESEARCH.md`
2. Прочитай `.planning/STATE.md` если существует
3. Прочитай `~/.claude/RULES.md` (глобальные правила) — сохрани содержимое как `{GLOBAL_RULES}`
4. Если существует `./RULES.md` в корне проекта → прочитай и сохрани как `{PROJECT_RULES}`. Если нет → `{PROJECT_RULES}` = пустая строка
5. Прочитай `.planning/ROADMAP.md` если существует
6. Выведи краткое резюме: где мы, что делаем, какая фаза

**Если `.planning/` не существует** → предложи сначала `/build:init`

## Step 1: Discuss (unless --skip-discuss)

**Проверь:** существует ли `{phase}-CONTEXT.md` в `.planning/`

- **Нет** → вызови `/gsd:discuss-phase {phase}`. Дождись завершения.
- **Да** → спроси пользователя: "CONTEXT.md уже есть. Обновить, просмотреть или пропустить?"

**MB Sync после discuss:**
- Если были приняты архитектурные решения → записать ADR-NNN в `.memory-bank/BACKLOG.md`
- Если выявлены гипотезы → записать H-NNN в `.memory-bank/RESEARCH.md`

## Step 1.5: SDD Spec Generation (if --sdd)

**Пропускается без --sdd.** Когда использовать: фичи с чёткими requirements, API, business logic.

1. Создай директорию `.planning/phases/{NN}-*/specs/`
2. Вызови `/sdd-brainstorm` с контекстом фазы (optional — если нужен exploration)
3. Вызови `/sdd-plan` с CONTEXT.md как входом
4. Сгенерируй spec-файлы по шаблонам из `~/.claude/skills/build-sdd/templates/`:

   **requirements.md** — User Stories + EARS Acceptance Criteria:
   ```
   - AC-01.1: WHEN {condition} THEN the system SHALL {behavior}
   - EC-01: WHEN {edge case} THEN the system SHALL {graceful handling}
   - UB-01: WHEN {existing} THEN the system SHALL CONTINUE TO {unchanged}
   ```

   **design.md** — Architecture, Components, Data Flow, Design Decisions (DD-XX)

5. Сгенерируй `spec-verify-phase-{N}.sh` — кастомный скрипт верификации для этой фазы:
   ```bash
   #!/bin/bash
   # Auto-generated spec verification for Phase {N}
   # Checks each AC-XX.XX has a corresponding test

   ~/.claude/hooks/spec-verify.sh \
     .planning/phases/{NN}-*/specs/ \
     src/ \
     tests/
   ```

6. Задачи из SDD specs → input для GSD planning (Step 2)

**Spec files коммитятся в репо** — служат документацией и reference для будущих фаз.

## Step 2: Plan

Вызови `/gsd:plan-phase {phase}`. Дождись завершения.

**Если --sdd:** GSD planning получает SDD specs как контекст — requirements.md и design.md подаются в plan prompt. Задачи из SDD tasks интегрируются в GSD PLAN.md.

**Без --sdd:** стандартный GSD planning как раньше.

**MB Sync после plan:**
1. Прочитай созданные `{phase}-*-PLAN.md` файлы
2. Обнови `.memory-bank/checklist.md`:
   - Добавь секцию `### Phase {N}: <название> (GSD)`
   - Каждая задача из планов → ⬜ пункт с ссылкой на план
3. Обнови `.memory-bank/plan.md`:
   - Поле "Active plan" → ссылка на `.planning/` планы
   - Обнови фокус
4. Обнови `.memory-bank/STATUS.md`:
   - Roadmap секция "В процессе" → добавь фазу

**Meta-Judge Dispatch (параллельно с execution):**

После завершения планирования, ДО начала execution, запусти Meta-Judge в фоне:

```
Agent(subagent_type: "general-purpose", model: "opus",
      name: "meta-judge-phase-{N}",
      run_in_background: true,
      description: "Meta-Judge: evaluation spec для фазы {N}",
      prompt: "
<CRITICAL_CONSTRAINTS>
- Criteria MUST be measurable with concrete evidence
- Include RULES compliance as evaluation dimension
- Weights must sum to 1.0
- Produce ONLY valid YAML
</CRITICAL_CONSTRAINTS>

<RULES>
## Global Rules
{GLOBAL_RULES}

## Project Rules
{PROJECT_RULES}
</RULES>

<TASK>
Generate evaluation specification YAML for Phase {N}: {name}.

Plan summary:
{план фазы — задачи, DoD, ключевые файлы}

Artifact type: code implementation
Project language: {language из .pipeline.yaml}
Architecture: {architecture_rules из .pipeline.yaml}
</TASK>

<OUTPUT_FORMAT>
Return ONLY the evaluation specification YAML. No prose. Format:

evaluation_specification:
  task: 'Phase {N}: {name}'
  criteria:
    - name: correctness
      weight: 0.30
      rubric: '...'
      checklist: ['...', '...']
    - name: architecture
      weight: 0.25
      rubric: '...'
      checklist: ['...']
    - name: test_quality
      weight: 0.20
      rubric: '...'
      checklist: ['...']
    - name: code_quality
      weight: 0.15
      rubric: '...'
      checklist: ['...']
    - name: security
      weight: 0.10
      rubric: '...'
      checklist: ['...']
</OUTPUT_FORMAT>
")
```

Meta-Judge работает в фоне пока идёт execution. Его результат нужен только в Step 3b.

**Quality Gate перед execute:**
- Покажи пользователю: сколько планов, сколько задач, волновая структура
- Спроси: "Запускать execution? (y/n)"

## Step 3: Execute

### 3a. Effort Scoring (из Harness)

Оцени сложность каждой задачи фазы:
```
+1 если 4+ файлов затронуто
+1 если затрагивает core/, domain/, security/
+1 если keywords: architecture, migration, security, redesign
+2 если в lessons.md есть прошлые failures на аналогичных задачах
```
Score ≥ 3 → передай GSD executor флаг для усиленного мышления.

Вызови `/gsd:execute-phase {phase}`. Дождись завершения.

Если `--interactive` → вызови `/gsd:execute-phase {phase} --interactive`

**MB Sync после execute:**
1. Обнови `.memory-bank/checklist.md`: все задачи фазы → ✅
2. Обнови `.memory-bank/STATUS.md`:
   - Метрики: запусти `commands.test` из `.pipeline.yaml` и запиши число тестов
   - Roadmap: если фаза завершена → перенеси в "Завершено"
### 3a.5 Spec Verification (if --sdd was used)

Если SDD specs существуют для этой фазы:

```bash
~/.claude/hooks/spec-verify.sh \
  .planning/phases/{NN}-*/specs/ \
  src/ \
  tests/
```

**Если FAIL:** Есть acceptance criteria без тестов. Исправить перед Judge:
1. Для каждого AC без теста — написать тест, ссылающийся на AC-XX.XX в имени
2. Перезапустить spec-verify → должен быть PASS
3. Только потом → Judge

**Если PASS:** Все AC покрыты тестами → продолжить к Judge.

### 3b. Judge Verification (после execute)

**Получи Meta-Judge результат:**
Дождись завершения `meta-judge-phase-{N}` (запущен в Step 2). Извлеки evaluation specification YAML из его ответа. Сохрани как `{EVAL_SPEC_YAML}`.

Запусти Judge agent для числовой оценки качества:

```
Agent(subagent_type: "judge", model: "opus", description: "Judge verification",
      prompt: "
Phase {N} evaluation. Iteration {iteration}/3.

<EVAL_SPEC>
```yaml
{EVAL_SPEC_YAML}
```
</EVAL_SPEC>

<RULES_INJECT>
{GLOBAL_RULES}
{PROJECT_RULES}
</RULES_INJECT>

Implementation summary: {файлы изменённые executor'ом, ключевые изменения}
Thresholds: standard >= 4.0, critical >= 4.5.

Следуй workflow из agent definition: automated checks → batch read → JSON verdict.
")

**Review (MANDATORY LITE):** `/build:phase` ОБЯЗАТЕЛЬНО запускает LITE review (1 reviewer L0) параллельно с Judge.
Для более глубокого review используй standalone `/build:review "Phase {N}" --standard` или `--full`.
```

- **PASS + 0 SERIOUS findings** → Step 4
- **PASS + SERIOUS/WARNING findings** → fix ALL findings → re-judge. SERIOUS fixes обязательны. НЕ спрашивать "фиксить или пропустить?".
- **FAIL** → исправить low-score аспекты, повторить Judge. Max 3 итерации (build:phase = lightweight, меньше iterations чем team-phase's 5 — пропорционально scope).

**CRITICAL RULE:** Judge PASS ≠ "можно коммитить". Цикл: Judge → fix ALL findings → re-judge, пока PASS с 0 SERIOUS.

**При retry:** используй тот же `{EVAL_SPEC_YAML}` — НЕ пересоздавай Meta-Judge.

### 3b-alt. Debate Judge Verification (если --debate или auto-suggest)

**Auto-suggest:** если effort score фазы ≥ 4:
```
Effort score для фазы {N}: {score}/5 (critical domain, architecture change).
Рекомендую --debate для более объективной оценки. Использовать? (y/n)
```

Если `--debate` или user подтвердил auto-suggest:

**Создай директорию для отчётов:**
```bash
mkdir -p .planning/phases/{NN}-*/reports/
```

**Phase 1: Independent Analysis (3 judges параллельно):**

Запусти 3 Judge агента параллельно. Каждый получает тот же `{EVAL_SPEC_YAML}` от Meta-Judge:

```
Agent(name: "judge-1", subagent_type: "judge", model: "opus",
      run_in_background: true,
      description: "Judge 1: independent analysis фазы {N}",
      prompt: "
<CRITICAL_CONSTRAINTS>
- You are Judge 1. Score INDEPENDENTLY
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
Evaluate Phase {N} implementation against specification:

```yaml
{EVAL_SPEC_YAML}
```

Write report to: .planning/phases/{NN}-{name}/reports/judge-1.md
</TASK>

<OUTPUT_FORMAT>
Report: Done by Judge 1, Per-Criterion Scores with evidence, Overall Weighted Score, Strengths, Weaknesses, Verdict.
Reply with: overall score and verdict.
</OUTPUT_FORMAT>
")
```

Аналогично для `judge-2` и `judge-3` (идентичные промпты, другие имена).

**Consensus Check:**

После завершения всех 3 judges:
1. Извлеки overall scores из ответов
2. max - min ≤ 0.5 → **consensus achieved**
3. Нет → Debate Round (max 3 раунда)

**Debate Round:**

```
Agent(name: "judge-{N}-debate-r{R}", subagent_type: "judge", model: "opus",
      run_in_background: true,
      description: "Judge {N}: debate round {R}",
      prompt: "
<CRITICAL_CONSTRAINTS>
- Read other judges' reports from filesystem
- Defend your position with evidence from eval spec
- Only revise if their evidence is compelling
- Quote specific code from the solution
</CRITICAL_CONSTRAINTS>

<TASK>
You are Judge {N} in debate round {R}.
Your previous report: .planning/phases/{NN}-{name}/reports/judge-{N}.md
Other reports: judge-1.md, judge-2.md, judge-3.md
Identify disagreements (>1 point gap), defend or revise with evidence.
Append 'Debate Round {R}' section to your report.
</TASK>

<OUTPUT_FORMAT>
Reply: revised overall score, whether you reached agreement.
</OUTPUT_FORMAT>
")
```

**After consensus or max rounds:**
- Consensus → average score → PASS/FAIL per threshold → Step 4
- No consensus after 3 rounds → report to user, flag for manual review. НЕ auto-PASS и НЕ auto-FAIL.

**Если НЕ --debate:** используй обычный single judge из Step 3b (без изменений).

3. Запиши в `.memory-bank/progress.md` (APPEND-ONLY):

```markdown
## {date}

### GSD Phase {N}: {название}
- {3-5 пунктов что сделано}
- Plans: {список планов}
- Тесты: {число} green
- Следующий шаг: {что дальше}
```

## Step 4: Verify (unless --skip-verify)

**Двойная верификация:**

### 4a. GSD Verify (goal-backward)
Вызови `/gsd:verify-work {phase}`. Проведи UAT с пользователем.

Если найдены проблемы:
- GSD создаст fix-планы
- Вызови `/gsd:execute-phase {phase} --gaps-only` для исправлений
- Повтори verify

### 4b. MB Verify (plan-forward, DoD check)
Если в `.memory-bank/plans/` есть активный план, относящийся к этой фазе:
- Вызови `/mb verify` для проверки плана vs код

Если есть CRITICAL issues → исправить обязательно.

### 4c. Lessons Check
Если во время verify обнаружены повторяющиеся проблемы:
- Записать в `.memory-bank/lessons.md`

### 4d. Reflexion (после verify)

Запусти рефлексию процесса:

```
Agent(subagent_type: "general-purpose", model: "opus",
      description: "Reflexion фазы",
      prompt: "
<TASK>
Проведи рефлексию по фазе {N}.

Данные: Judge scores: {scores}, Verify: {verdict}, Iterations: {N}

Проанализируй:
1. Какие решения удачные?
2. Какие проблемы повторялись?
3. Что улучшить в планировании?
4. Антипаттерн для lessons.md?
</TASK>

<OUTPUT_FORMAT>
Output: JSON {learned_patterns: [...], anti_patterns: [...], lessons_md_update: string|null}
</OUTPUT_FORMAT>
")
```

Если `lessons_md_update` не null → обнови `.memory-bank/lessons.md`.

## Step 5: Finalize

1. Обнови `.memory-bank/plan.md`: убери completed plan если все задачи фазы закрыты
2. Обнови `.memory-bank/STATUS.md`: финальные метрики
3. Создай `.memory-bank/notes/{date}_{time}_phase-{N}-complete.md` с кратким резюме (5-15 строк)
4. Выведи итог:
   - Что сделано
   - Сколько тестов
   - Какие файлы затронуты
   - Предложи следующий шаг: `/build:phase {N+1}` или `/gsd:ship {N}`

</process>

<error_handling>
- Если GSD-команда упала → покажи ошибку пользователю, предложи варианты (retry, skip, debug)
- Если тесты красные после execute → НЕ переходить к verify. Сначала исправить через `/gsd:execute-phase --gaps-only` или вручную
- Если MB файлы не в sync → вызови MB Doctor: прочитай `.memory-bank/` core files и исправь рассинхроны
- При compaction risk → вызови `/mb update` чтобы сохранить прогресс
</error_handling>
