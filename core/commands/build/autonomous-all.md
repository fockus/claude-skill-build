---
name: build:autonomous-all
description: Full autonomous pipeline — audit → execute remaining phases → final audit, all in team mode
argument-hint: "[--skip-initial-audit] [--skip-final-audit] [--phases 12-20] [--max-phases N]"
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
Полностью автономный pipeline: обнаруживает оставшиеся фазы из ROADMAP.md, для каждой проходит полный цикл (discuss → plan → team execute → 3-iteration audit → MB sync), затем финальный аудит.

**Ключевые принципы:**
- **Team Mode обязателен** — каждая фаза через TeamCreate + TaskCreate + параллельные агенты
- **GSD planning** — discuss + plan через GSD workflow перед каждой фазой
- **3-iteration audit** после каждой фазы (не только в конце)
- **Pipeline workflow** — pull-model, self-claim tasks, architect review, verifier
- **Динамические фазы** — из ROADMAP.md, не hardcoded

Пользователь может уйти. Pipeline работает автономно.
</objective>

<context>
$ARGUMENTS
</context>

<process>

## Step 0: Load Context + Detect Phases

### 0.1 Load MB + GSD context
```
Прочитай:
- .memory-bank/STATUS.md, checklist.md, plan.md
- .planning/STATE.md, ROADMAP.md, REQUIREMENTS.md
- RULES.MD, CLAUDE.md
- .memory-bank/lessons.md
- .pipeline.yaml
```

### 0.2 Detect remaining phases

Парси ROADMAP.md таблицу Progress → найди все фазы со статусом `○ Pending`.
Если аргумент `--phases 12-20` → используй указанный диапазон.
Если `--max-phases N` → обработай первые N pending фаз.
По умолчанию → все pending фазы последовательно.

### 0.3 Verify baseline

Запусти все `commands.*` из `.pipeline.yaml` (test, lint, typecheck, format_check).

Если baseline RED → СТОП. Сначала исправь gate.

### 0.4 Output plan

```
Обнаружено {N} pending фаз: {список}
Baseline: {тестов} passed, gate {GREEN/RED}
Порядок: {фаза 12} → {фаза 13} → ...
Estimated scope: {общее число фаз}
```

---

## PHASE A: Initial Audit (3 iterations)

**Skip if --skip-initial-audit**

Аудит ТОЛЬКО уже завершённых фаз (не pending). Scope определяется динамически.

### A.1-A.3 Три iteration аудита

Для каждой iteration N (1, 2, 3):

```
Agent(name: "auditor-{N}", subagent_type: "reviewer", model: "opus",
      prompt: "
Проведи code audit завершённых фаз проекта.

Прочитай .planning/ROADMAP.md — найди все фазы со статусом ✓ Complete.
Для каждой завершённой фазы:
1. Прочитай её PLAN.md в .planning/phases/{NN}-*/
2. Проверь файлы указанные в плане

Ищи: BUGS, PLAN MISMATCHES, GAPS, QUALITY, TESTS, WIRING.

Формат: ## Audit Iteration {N} → CRITICAL / WARNING / INFO → Verdict
Запиши в .planning/AUDIT-INITIAL-{N}.md
")
```

Если NEEDS_FIXES → spawn fix team (см. секцию Fix Team ниже).

---

## PHASE B: Execute Remaining Phases

Для каждой pending фазы N:

### B.1 Discuss (GSD)

Проверь: `.planning/phases/{NN}-*/CONTEXT.md` существует?

- **Нет** → вызови `/gsd:discuss-phase {N} --auto` (Claude решает сам, без вопросов)
- **Да** → используй существующий CONTEXT.md

### B.2 Plan (GSD)

Проверь: `.planning/phases/{NN}-*/*-PLAN.md` существует?

- **Нет** → вызови `/gsd:plan-phase {N}`
  ИЛИ запусти gsd-planner agent:
  ```
  Agent(name: "planner-{N}", subagent_type: "gsd-planner",
        prompt: "Создай план для Phase {N}. Прочитай CONTEXT.md и ROADMAP.md для этой фазы.")
  ```
- **Да** → используй существующие планы

### B.3 Team Execute (Pipeline)

**Это ключевой шаг — полный Pipeline workflow из `/pipeline`.**

#### B.3.1 Декомпозиция

Прочитай все PLAN.md файлы для фазы. Извлеки задачи. Оцени scope (S/M/L).

#### B.3.2 TeamCreate + TaskCreate (ВСЕ задачи ДО агентов)

```
TeamCreate(team_name: "phase-{N}", description: "Phase {N}: {name}")
```

Конвертируй каждую задачу из PLAN.md в TaskCreate:

```
TaskCreate(
  subject: "<task name>",
  description: "
    WORKFLOW: По завершении → TaskUpdate(status='completed') + SendMessage team-lead.
    НЕ ЖДИ team-lead. TaskList → следующая задача.

    ## Задача
    <action из плана>

    ## Verify
    <verify из плана>

    ## DoD
    <done criteria из плана>

    Files (exclusive): <файлы>

    Constraints (из RULES.MD):
    - TDD: тесты ПЕРЕД реализацией
    - Contract-First: Protocol → contract-тесты → реализация
    - Clean Architecture: domain НЕ импортирует infrastructure
    - Testing Trophy: integration > unit > E2E
    - Без TODO/pass/placeholder
    - Coverage: core 95%+, overall 85%+

    Lessons: <из lessons.md>

    Verification: команды lint + typecheck из .pipeline.yaml
  ",
  owner: "<teammate>"
)
```

Для каждой impl-задачи создай парную test-задачу (blocked by impl).

**Файловые exclusive zones:** определяются из `team.dev_layers` в `.pipeline.yaml` и структуры проекта.

**Проверь:** `TaskList` показывает все задачи ПЕРЕД запуском агентов.

#### B.3.3 Запуск агентов (ПОСЛЕ backlog ready)

```
Agent(name: "dev-domain", subagent_type: "developer", model: "opus",
      team_name: "phase-{N}", run_in_background: true,
      prompt: "Ты dev-domain в Phase {N}: {name}.

<CRITICAL_CONSTRAINTS>
- TDD: тесты ПЕРЕД реализацией
- Clean Architecture: domain НЕ импортирует infrastructure
- Contract-First: Protocol → тесты → реализация
- Без TODO/pass/placeholder
- Coverage: core 95%+, overall 85%+
</CRITICAL_CONSTRAINTS>

<RULES_INJECT>
{GLOBAL_RULES}
{PROJECT_RULES}
</RULES_INJECT>

TaskList → claim unblocked задачу с owner=dev-domain → реализуй → TaskUpdate(completed) → отчёт team-lead → TaskList → следующая. НЕ ЖДИ team-lead.
Lessons: {lessons}")

Agent(name: "dev-infra", subagent_type: "developer", model: "opus",
      team_name: "phase-{N}", run_in_background: true,
      prompt: "Ты dev-infra в Phase {N}: {name}.

<CRITICAL_CONSTRAINTS>
- TDD: тесты ПЕРЕД реализацией
- Clean Architecture: domain НЕ импортирует infrastructure
- Contract-First: Protocol → тесты → реализация
- Без TODO/pass/placeholder
- Coverage: core 95%+, overall 85%+
</CRITICAL_CONSTRAINTS>

<RULES_INJECT>
{GLOBAL_RULES}
{PROJECT_RULES}
</RULES_INJECT>

TaskList → claim unblocked задачу с owner=dev-infra → реализуй → TaskUpdate(completed) → отчёт team-lead → TaskList → следующая. НЕ ЖДИ team-lead.
Lessons: {lessons}")

Agent(name: "tester-1", subagent_type: "tester", model: "opus",
      team_name: "phase-{N}", run_in_background: true,
      prompt: "Ты tester-1.

<CRITICAL_CONSTRAINTS>
- Testing Trophy: интеграционные > unit > e2e
- Mock только внешние сервисы. >5 mock'ов → кандидат на интеграционный
- Имя: test_<что>_<условие>_<результат>
- Arrange-Act-Assert. @parametrize вместо копипасты
- Coverage: core 95%+, overall 85%+
</CRITICAL_CONSTRAINTS>

<RULES_INJECT>
{GLOBAL_RULES}
{PROJECT_RULES}
</RULES_INJECT>

TaskList → claim unblocked test-задачу → пиши тесты → TaskUpdate(completed) → следующая.")

Agent(name: "tester-2", subagent_type: "tester", model: "opus",
      team_name: "phase-{N}", run_in_background: true,
      prompt: "Ты tester-2.

<CRITICAL_CONSTRAINTS>
- Testing Trophy: интеграционные > unit > e2e
- Mock только внешние сервисы. >5 mock'ов → кандидат на интеграционный
- Имя: test_<что>_<условие>_<результат>
- Arrange-Act-Assert. @parametrize вместо копипасты
- Coverage: core 95%+, overall 85%+
</CRITICAL_CONSTRAINTS>

<RULES_INJECT>
{GLOBAL_RULES}
{PROJECT_RULES}
</RULES_INJECT>

TaskList → claim unblocked test-задачу → пиши тесты → TaskUpdate(completed) → следующая.")
```

Отправь стартовые сообщения с контекстом ПАРАЛЛЕЛЬНО.

#### B.3.4 Мониторинг (Team Lead)

- Следи за отчётами тиммейтов
- Broadcast при завершении задач: `SendMessage(to: "*", message: "Task #X done. TaskList.")`
- Fix-задачи если тесты fail (max 3 итерации)
- Перебалансировка если один dev закончил, другой перегружен

#### B.3.5 Code Review (architect one-shot)

**HARD GATE:** все задачи completed.

```
**Per-phase review использует tier system из `/build:review`:**
- S-scope → LITE (1 reviewer L0)
- M/L-scope → STANDARD (3 reviewers + architect-aggregator)

Scope определяется по количеству задач в фазе (из PLAN.md).

Agent(name: "reviewer-{N}", subagent_type: "reviewer", model: "opus",
      prompt: "Phase {N} review. Scope: {USER_PROMPT}. Files: git diff HEAD~1.
<RULES_INJECT>{GLOBAL_RULES}\n{PROJECT_RULES}</RULES_INJECT>
CONTEXT BUDGET: max 15 tool calls. VERDICT FIRST.
Вердикт: APPROVED / NEEDS_CHANGES")
```

NEEDS_CHANGES → fix → re-review (max 3).

#### B.3.6 Verifier (для M/L scope)

```
Agent(name: "verifier-{N}", subagent_type: "verifier", model: "opus",
      prompt: "Верифицируй Phase {N}. Чек: DoD, pytest, ruff, mypy, boundaries, placeholders, contract drift, production wiring.")
```

FAIL → fix CRITICAL → re-verify (max 5).

#### B.3.7 Judge Gate (MANDATORY — NEVER SKIP)

**Это обязательный шаг. Без Judge PASS коммит запрещён.**

```
Agent(name: "judge-{N}", subagent_type: "judge", model: "opus",
      prompt: "
Phase {N} evaluation.

<EVAL_SPEC>
Generate lightweight eval spec (3 criteria: correctness 0.40, test_quality 0.30, code_quality 0.30)
based on PLAN.md for Phase {N}.
</EVAL_SPEC>

<RULES_INJECT>
{GLOBAL_RULES}
{PROJECT_RULES}
</RULES_INJECT>

Thresholds: standard >= 4.0, critical >= 4.5.
Следуй workflow из agent definition: automated checks → batch read → JSON verdict.
")
```

- **PASS (avg ≥ 4.0) + 0 SERIOUS** → B.3.8
- **PASS + SERIOUS findings** → fix ALL → re-judge
- **FAIL** → fix low-score aspects → re-judge (max 3 iterations)
- **3 iterations FAIL** → ABORT phase, статус = BLOCKED

**State file:** создай `.planning/phases/{NN}-*/JUDGE_PASS.md` при PASS:
```
Phase: {N}
Score: {weighted_average}/5.0
Verdict: PASS
Date: {ISO UTC}
```

#### B.3.8 Full Gate

Запусти все `commands.*` из `.pipeline.yaml` (test, lint, typecheck, format_check).

RED → fix → re-gate. НЕ продолжать к следующей фазе с красным gate.

#### B.3.9 Коммит (REQUIRES JUDGE_PASS.md)

**PRE-COMMIT CHECK:**
```bash
judge_pass_file=$(ls .planning/phases/*-*/JUDGE_PASS.md 2>/dev/null | tail -1)
if [ -z "$judge_pass_file" ]; then
  echo "ABORT: JUDGE_PASS.md not found. Return to B.3.7."
  exit 1
fi
```

```bash
git add <конкретные файлы — НЕ git add -A>
git commit -m "feat(phase-{N}): {phase name} [Judge: {score}/5.0]

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

#### B.3.10 TeamDelete

```
# Shutdown protocol: notify agents before deletion
SendMessage(to: "dev-domain", message: "shutdown_request: phase complete")
SendMessage(to: "dev-infra", message: "shutdown_request: phase complete")
SendMessage(to: "tester-1", message: "shutdown_request: phase complete")
SendMessage(to: "tester-2", message: "shutdown_request: phase complete")

TeamDelete(team_name: "phase-{N}")
```

### B.4 Post-Phase Audit (3 iterations)

**Обязательно после КАЖДОЙ фазы, не только в конце.**

```
Agent(name: "post-audit-{N}-{iter}", subagent_type: "reviewer", model: "opus",
      prompt: "Audit Phase {N} code. Прочитай PLAN.md, проверь все изменённые файлы.
BUGS, PLAN MISMATCHES, GAPS, QUALITY, TESTS, WIRING.
Запиши в .planning/AUDIT-P{N}-{iter}.md")
```

Iteration 1 → fix if NEEDS_FIXES → Iteration 2 → fix → Iteration 3.
Если iteration 3 = PASS → advance.
Если iteration 3 = NEEDS_FIXES → fix, записать в lessons.md.

Коммит после fixes:
```bash
git commit -m "fix(audit-phase-{N}): {description}"
```

### B.5 MB Sync

1. `checklist.md`: фаза ⬜ → ✅ с подробностями (+N tests, total)
2. `STATUS.md`: обнови метрики (тесты, readiness %)
3. `progress.md`: append entry (НИКОГДА не удалять старое)
4. `ROADMAP.md`: фаза ○ Pending → ✓ Complete
5. `STATE.md`: обнови Phase position и Last activity

### B.6 Auto-advance

Перейди к следующей pending фазе → B.1.

**Context pressure:** если >70% context → `/mb update` + промежуточный коммит MB файлов.

---

## PHASE C: Final Audit (3 iterations)

**Skip if --skip-final-audit**

Scope: ВСЕ фазы выполненные в этом прогоне.

```
**Финальный аудит использует FULL tier из `/build:review`** (6 specialized reviewers + architect-aggregator).
Scope: "Все фазы выполненные в pipeline run. Cross-phase integration."

Эквивалент: `/build:review "cross-phase audit all phases" --full`

Если FULL tier недоступен (context limits), fallback:
Agent(name: "final-auditor-{iter}", subagent_type: "reviewer", model: "opus",
      prompt: "Финальный cross-phase audit. Проверь ВСЕ фазы выполненные в этом pipeline run.
Cross-phase integration: все фазы работают вместе.
Full E2E path: все requirements закрыты.
CONTEXT BUDGET: max 15 tool calls. VERDICT FIRST.
Запиши в .planning/AUDIT-FINAL-{iter}.md")
```

3 iterations: fix if NEEDS_FIXES → PASS.

---

## PHASE D: Finalize

### D.1 Full Gate

Запусти все `commands.*` из `.pipeline.yaml` (test, lint, typecheck, format_check).

### D.2 MB Finalize

1. `checklist.md`: все фазы ✅
2. `STATUS.md`: honest readiness % с code-level evidence
3. `progress.md`: финальная запись
4. `plan.md`: обнови Active plan
5. Commit MB files

### D.3 Итоговый отчёт

```
## Pipeline Complete

| Phase | Tests Added | Total | Audit |
|-------|-------------|-------|-------|
| {N}   | +{X}        | {Y}   | PASS  |
...

Full gate: {status}
Total tests: {N}
Findings fixed: {N}
Remaining: {N} (if any → BACKLOG.md)
```

</process>

<fix_team>
## Fix Team (shared procedure)

Когда аудит нашёл CRITICAL или WARNING:

1. Прочитай audit report
2. Конвертируй findings в fix tasks:
   ```
   TaskCreate(subject: "Fix [{ID}]: {description}", owner: "dev-domain|dev-infra")
   ```
3. Запусти fix агентов параллельно:
   ```
   Agent(name: "fixer-{N}", subagent_type: "developer", mode: "auto",
         prompt: "Исправь finding [{ID}]: {description}. Файл: {file}:{line}. Fix: {suggested fix}")
   ```
4. Full gate после fixes
5. Коммит: `fix(audit-{scope}-{iter}): {summary}`
</fix_team>

<guardrails>
## Hard Gates

- **Team Mode обязателен:** каждая фаза через TeamCreate + TaskCreate. Pipeline = team execution, НЕ solo.
- **GSD planning обязателен:** discuss + plan ПЕРЕД team execution. Не придумывать задачи на лету.
- **3-iteration audit ПОСЛЕ каждой фазы:** не только в конце. CRITICAL = must fix before advance.
- **Full gate между фазами:** НЕ продолжать если commands.* из .pipeline.yaml RED.
- **RULES.MD = hard requirement:** TDD, Contract-First, Clean Architecture, Testing Trophy, SOLID.
- **DoD = фактическая готовность:** не "seam exists" а "feature works end-to-end". Behavioral tests, не hasattr.
- **STATUS.md = факты:** никаких inflated claims. Каждый % проверяем vs code.
- **MB update обязателен:** после каждой фазы. Без MB sync фаза НЕ закрыта.

## Autonomous Decisions

- **Discuss decisions:** Claude picks reasonable defaults (--auto mode)
- **Audit severity:** Claude judges CRITICAL vs WARNING
- **Fix approach:** Claude decides implementation
- **Team sizing:** S/M/L по числу задач, автоматически
- **Context pressure:** при >70% → `/mb update` + промежуточный коммит
</guardrails>
