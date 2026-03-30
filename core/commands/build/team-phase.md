---
name: build:team-phase
description: GSD planning + Pipeline team execution + MB sync — full hybrid cycle
argument-hint: "<phase-number> [--skip-discuss] [--skip-verify] [--debate] [--sdd]"
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
Гибрид GSD + Pipeline: GSD = мозг (discuss + plan), Pipeline = руки (team execution), MB = память (sync).

1. GSD discuss → CONTEXT.md (если нет)
2. GSD plan → PLAN.md с XML-задачами
3. **Конвертация** GSD tasks → Pipeline TaskCreate (с RULES, lessons, DoD)
4. **Pipeline team execution** (TeamCreate → developers + testers → architect review → verifier)
5. GSD verify + MB verify + MB sync

Ключевое отличие от `/build:phase`: execution через Team Mode (параллельные агенты),
а не через GSD executor (один агент per plan).
</objective>

<context>
Phase: $ARGUMENTS
</context>

<process>

## Step 0: Load Context

**Deps Check:** запусти `~/.claude/hooks/build-deps-check.sh`. Если exit code ≠ 0 → предложи `~/.claude/hooks/build-install-deps.sh` и прервись.

1. Прочитай `.memory-bank/STATUS.md`, `checklist.md`, `plan.md`, `RESEARCH.md`
2. Прочитай `.planning/STATE.md`, `ROADMAP.md`
3. Прочитай `.pipeline.yaml`
4. Прочитай `.memory-bank/lessons.md` (передать тиммейтам)
5. Выведи краткое резюме: фаза, scope, ключевые файлы
6. Прочитай `~/.claude/RULES.md` (глобальные правила) → `{GLOBAL_RULES}`
7. Если существует `./RULES.md` в корне проекта → прочитай → `{PROJECT_RULES}`. Если нет → пустая строка

## Step 1: Discuss (unless CONTEXT.md exists or --skip-discuss)

Проверь: `.planning/phases/{NN}-*/1-CONTEXT.md` существует?

- **Нет** → вызови `/gsd:discuss-phase {phase}`. Дождись завершения.
- **Да** → используй существующий CONTEXT.md

**MB Sync:** ADR → BACKLOG, гипотезы → RESEARCH (как в `/build:phase`)

## Step 1.5: SDD Spec Generation (if --sdd)

**Пропускается без --sdd.** Когда: API фичи, business logic, чёткие requirements.

1. Создай `.planning/phases/{NN}-*/specs/`
2. `/sdd-brainstorm` (optional exploration)
3. `/sdd-plan` с CONTEXT.md
4. Сгенерируй specs по шаблонам `~/.claude/skills/build-sdd/templates/`:
   - **requirements.md** — EARS: `WHEN ... THEN ... SHALL`
   - **design.md** — архитектура, DD-XX decisions
5. Сгенерируй `spec-verify-phase-{N}.sh`
6. Specs → input для GSD planning

## Step 2: Plan

Вызови `/gsd:plan-phase {phase}`. Дождись завершения.

**Если --sdd:** GSD получает specs как контекст. Задачи интегрируются в PLAN.md.
**Без --sdd:** стандартный GSD planning.

GSD создаст `{phase}-{N}-PLAN.md` файлы с XML-задачами.

**MB Sync:** обнови `checklist.md` (⬜ задачи), `plan.md` (Active plan), `STATUS.md` (В процессе)

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

Meta-Judge работает в фоне пока идёт execution. Его результат нужен только в Step 4.5.

## Step 3: Convert GSD Plans → Pipeline Tasks

**Это ключевой bridge step.**

3.1 Прочитай все `{phase}-*-PLAN.md` файлы
3.2 Извлеки XML-задачи (`<task>` блоки) из каждого плана
3.3 Оцени scope:

| Scope | Задач | Команда |
|-------|-------|---------|
| **S** (1-3) | 1-3 | architect + dev-main + tester |
| **M** (4-8) | 4-8 | architect + dev-domain + dev-infra + tester-1 + tester-2 + verifier |
| **L** (9+) | 9+ | + dev-api |

3.3b **Model Selection:**

**ВСЕ агенты запускаются на Opus с 1M контекстом.** Sonnet/Haiku вызывали context exhaustion
и потерю Judge gate в Phase 2 v2. Экономия токенов не стоит потери качества и пропуска quality gates.

```
Model Assignment (FIXED — no dynamic selection):

  ALL roles → opus (1M context)

  Roles: developer, tester, architect, reviewer, judge, meta-judge, verifier, reflexion

  Override: .pipeline.yaml model_tiering.<role> = конкретная модель
    → использовать override ТОЛЬКО если явно указана. Default = opus.
    → НИКОГДА не понижать до haiku для production phases.
```

3.4 Распредели файлы по тиммейтам (один файл = один owner):

```
dev-domain  → domain/, application/
dev-infra   → infrastructure/, interfaces/
tester-1/2  → tests/
```

3.5 Конвертируй каждую GSD XML-задачу в Pipeline TaskCreate:

```
TaskCreate(
  subject: "<task name from GSD plan>",
  description: "
    WORKFLOW: По завершении → TaskUpdate(status='completed') + SendMessage team-lead с отчётом → TaskList для следующей задачи. НЕ ЖДИ team-lead.

    ## Из GSD Plan
    <action content from XML task>

    ## Verify (из GSD plan)
    <verify content from XML task>

    ## Done (из GSD plan)
    <done criteria from XML task>

    Files (exclusive): <файлы этого owner>
    Critical: yes/no  (влияет на Judge threshold: 4.5 vs 4.0)

    Constraints:
    - TDD: тесты ПЕРЕД реализацией
    - Clean Architecture: domain НЕ импортирует infrastructure
    - Contract-First: Protocol → тесты → реализация
    - Без TODO/pass/placeholder
    - Coverage: core 95%+, overall 85%+

    Verification: команды lint + typecheck из .pipeline.yaml
  ",
  owner: "<teammate name>"
)
```

Для каждой impl-задачи создай парную test-задачу (blocked by impl).

**Quality Gate перед execute:**
- Покажи пользователю: число задач, команда, file mapping
- Спроси: "Запускать team execution? (y/n)"

## Step 4: Pipeline Team Execution

4.1 **TeamCreate**
```
TeamCreate(team_name: "gsd-phase-{N}", description: "GSD Phase {N}: {name}")
```

4.2 **Запусти агентов** (ПОСЛЕ создания ВСЕХ задач)

**Model Tiering (ALL OPUS):**

| Роль | Модель | Причина |
|------|--------|---------|
| Developer | **Opus** | 1M context предотвращает exhaustion mid-task |
| Tester | **Opus** | 1M context для полного coverage analysis |
| Architect/Reviewer | **Opus** | Deep analysis |
| Judge | **Opus** | Objective evaluation |
| Meta-Judge | **Opus** | Criteria generation |
| Reflexion | **Opus** | Process analysis |
| Verifier | **Opus** | Goal-backward verification |

**Все агенты на Opus.** Lesson L-006: sonnet agents exhaust context → team-lead takeover → Judge skip.
Override: `.pipeline.yaml` `model_tiering.<role>` фиксирует модель, но понижение не рекомендуется.

```
Agent(name: "dev-domain", subagent_type: "developer", model: "opus", team_name: "gsd-phase-{N}",
      run_in_background: true,
      prompt: "
<CRITICAL_CONSTRAINTS>
- TDD: тесты ПЕРЕД реализацией
- Clean Architecture: domain НЕ импортирует infrastructure
- Contract-First: Protocol → тесты → реализация
- Без TODO/pass/placeholder
- Coverage: core 95%+, overall 85%+
</CRITICAL_CONSTRAINTS>

<RULES>
## Global Rules
{GLOBAL_RULES}

## Project Rules
{PROJECT_RULES}
</RULES>

<TASK>
Ты dev-domain в GSD Phase {N}. Контекст проекта: ...
Lessons из прошлых сессий: {lessons}
</TASK>

<OUTPUT_FORMAT>
По завершении каждой задачи: TaskUpdate(status='completed') + SendMessage team-lead с отчётом.

## Self-Critique (MANDATORY)
Before completing each task, verify:
1. Does solution address ALL requirements?
2. Did I follow existing patterns?
3. Are there edge cases I missed?
4. Is this the simplest approach?
5. Would this pass code review?
6. Does my code comply with RULES (TDD, SOLID, Clean Architecture, coverage)?

If ANY gap found → FIX → RE-VERIFY → then submit.
</OUTPUT_FORMAT>
")

Agent(name: "dev-infra", subagent_type: "developer", model: "opus", team_name: "gsd-phase-{N}",
      run_in_background: true,
      prompt: "
<CRITICAL_CONSTRAINTS>
- TDD: тесты ПЕРЕД реализацией
- Clean Architecture: domain НЕ импортирует infrastructure
- Contract-First: Protocol → тесты → реализация
- Без TODO/pass/placeholder
- Coverage: core 95%+, overall 85%+
</CRITICAL_CONSTRAINTS>

<RULES>
## Global Rules
{GLOBAL_RULES}

## Project Rules
{PROJECT_RULES}
</RULES>

<TASK>
Ты dev-infra в GSD Phase {N}. Контекст проекта: ...
Lessons из прошлых сессий: {lessons}
</TASK>

<OUTPUT_FORMAT>
По завершении каждой задачи: TaskUpdate(status='completed') + SendMessage team-lead с отчётом.

## Self-Critique (MANDATORY)
Before completing each task, verify:
1. Does solution address ALL requirements?
2. Did I follow existing patterns?
3. Are there edge cases I missed?
4. Is this the simplest approach?
5. Would this pass code review?
6. Does my code comply with RULES (TDD, SOLID, Clean Architecture, coverage)?

If ANY gap found → FIX → RE-VERIFY → then submit.
</OUTPUT_FORMAT>
")

Agent(name: "tester-1", subagent_type: "tester", model: "opus", team_name: "gsd-phase-{N}",
      run_in_background: true,
      prompt: "
<CRITICAL_CONSTRAINTS>
- Testing Trophy: интеграционные > unit > e2e
- Mock только внешние сервисы. >5 mock'ов → кандидат на интеграционный
- Имя: test_<что>_<условие>_<результат>
- Arrange-Act-Assert. @parametrize вместо копипасты
- Coverage: core 95%+, overall 85%+
</CRITICAL_CONSTRAINTS>

<RULES>
## Global Rules
{GLOBAL_RULES}

## Project Rules
{PROJECT_RULES}
</RULES>

<TASK>
Ты tester-1. Пиши тесты для завершённых impl-задач...
</TASK>

<OUTPUT_FORMAT>
## Self-Critique (MANDATORY)
Before completing each task, verify:
1. Does solution address ALL requirements?
2. Did I follow existing patterns?
3. Are there edge cases I missed?
4. Is this the simplest approach?
5. Would this pass code review?
6. Does my code comply with RULES (TDD, SOLID, Clean Architecture, coverage)?

If ANY gap found → FIX → RE-VERIFY → then submit.
</OUTPUT_FORMAT>
")
```

4.3 **Отправь стартовые сообщения** с контекстом (RULES, lessons, architecture)

4.4 **Мониторинг** (Team Lead роль):
- Следи за отчётами тиммейтов
- Broadcast при завершении задач (разблокировка зависимых)
- Fix-задачи если тесты красные (max 3 итерации)

**Context Exhaustion Recovery (CRITICAL):**
Если ЛЮБОЙ агент исчерпал контекст до завершения задач:
1. Team-lead дозавершает оставшиеся задачи вручную
2. Прогоняет `uv run pytest tests/ -x -q && uv run ruff check src/ && uv run lint-imports`
3. **ОБЯЗАТЕЛЬНО переходит к Step 4.5 (Judge Gate)** — НЕ ПРОПУСКАТЬ
4. Context exhaustion агентов НЕ является причиной пропуска Judge
5. Даже если все агенты упали — Judge Gate MUST execute

**4.4.5 Spec Verification (if --sdd was used):**

Если SDD specs существуют:
```bash
~/.claude/hooks/spec-verify.sh .planning/phases/{NN}-*/specs/ src/ tests/
```
FAIL → написать недостающие тесты для AC-XX.XX. PASS → продолжить к Judge.

**Получи Meta-Judge результат:**
Дождись завершения `meta-judge-phase-{N}` (запущен в Step 2). Извлеки evaluation specification YAML → `{EVAL_SPEC_YAML}`.

---

### JUDGE GATE INVARIANT (NEVER SKIP)

**Это абсолютный инвариант workflow. Нарушение = фаза НЕ завершена.**

```
INVARIANT: Step 4.5 (Judge Gate) MUST execute before Step 4.8 (Commit).
ENFORCEMENT: State file `.planning/phases/{NN}-*/JUDGE_PASS.md`

State file is created ONLY by Step 4.5 when Judge returns PASS (avg >= 4.0).
Step 4.8 (Commit) MUST verify this file exists before committing.
If file is missing → ABORT commit → return to Step 4.5.

NO EXCEPTIONS:
- Agent context exhaustion → still run Judge
- Team-lead completed tasks manually → still run Judge
- All tests pass and ruff clean → still run Judge
- Session running low on context → run Judge with LITE review tier
- Previous session skipped Judge → run Judge retroactively before next phase

JUDGE_PASS.md format:
  Phase: {N}
  Score: {weighted_average}/5.0
  Verdict: PASS
  Date: {ISO UTC}
  Iteration: {which cycle passed}
  Reviewer: {APPROVED/NEEDS_CHANGES}
```

---

4.5 **Code Review + Judge Gate (max 5 cycles)**

**Review Tier Selection (auto by scope, override by flag):**
- S-scope (1-3 задачи) → **LITE** (1 reviewer + judge)
- M-scope (4-8 задач) → **STANDARD** (3 reviewers + architect-aggregator + judge)
- L-scope (9+ задач) → **STANDARD** (3 reviewers + architect-aggregator + judge)
- `--full-review` flag → **FULL** (6 reviewers + architect-aggregator + judge)
- `--lite` flag → **LITE** (force)

**Review выполняется по процессу из `/build:review`** (см. `~/.claude/commands/build/review.md`).
Scope prompt для review: `"Phase {N}: {phase_name}. Files: git diff HEAD~1 --name-only"`.

**Judge Mode selection:**
- Если `--debate` ИЛИ `.pipeline.yaml` `judge.panel_size: 3` → **Debate Mode** (3 judges)
- Иначе → **Single Judge Mode** (1 judge)

**Debate Mode:**

Заменяет только Judge часть. Review tier остаётся как определено выше.

Judge часть заменяется на 3-judge debate flow:

**Phase 1: 3 independent judges (параллельно с reviewer):**

```
# Reports directory
mkdir -p .planning/phases/{NN}-*/reports/

# Judge 1 (использует L0 agent ~/.claude/agents/judge.md — calibrated scoring)
Agent(name: "judge-1", subagent_type: "judge", model: "opus",
      run_in_background: true,
      prompt: "
You are Judge 1. Score INDEPENDENTLY from other judges.

<EVAL_SPEC>
\`\`\`yaml
{EVAL_SPEC_YAML}
\`\`\`
</EVAL_SPEC>

<RULES_INJECT>
{GLOBAL_RULES}
{PROJECT_RULES}
</RULES_INJECT>

Phase {N}. Iteration {iteration}/5.
Write report to: .planning/phases/{NN}-{name}/reports/judge-1.md
Следуй workflow из agent definition: automated checks → batch read → JSON verdict.
")

# Judge 2, Judge 3 — аналогично (subagent_type: 'judge', model: 'opus')
```

**Consensus check:** all scores within 0.5 → consensus. Else → debate round (max 3).

**Debate Round:**
Each judge reads others' reports, defends/revises, appends "Debate Round {R}" section.

**Decision table (debate mode):**

| Reviewer | Judge (debate) | Findings | Action |
|----------|---------------|----------|--------|
| APPROVED | Consensus PASS (avg ≥ 4.0) | 0 SERIOUS | Exit loop → Step 4.6 |
| APPROVED | Consensus PASS (avg ≥ 4.0) | SERIOUS exist | Fix ALL findings → re-judge (все 3, тот же YAML) |
| APPROVED | Consensus FAIL | — | Fix judge findings → re-judge (все 3, тот же YAML) |
| NEEDS_CHANGES | Consensus PASS | — | Fix reviewer findings → re-review |
| NEEDS_CHANGES | Consensus FAIL | — | Fix ALL → re-both |
| ANY | No consensus (3 rounds) | — | Flag for user review |

**При retry в debate mode:** все 3 judges запускаются заново с тем же `{EVAL_SPEC_YAML}`.

**Single Judge Mode:** текущий flow без изменений.

Это **blocking quality gate** — фаза НЕ завершается без Judge PASS.

**Цикл (iteration = 1..5):**

```
┌─────────────────────────────────────────────────┐
│  4.5.1  Запусти параллельно reviewer + judge    │
│  4.5.2  Дождись обоих результатов               │
│  4.5.3  Оцени verdict                           │
│         ├─ PASS (avg ≥ 4.0) → exit loop → 4.6  │
│         └─ FAIL → 4.5.4                         │
│  4.5.4  Исправь все findings (CRITICAL first)   │
│  4.5.5  Прогони тесты + lint (must pass)        │
│  4.5.6  Коммит fixes                            │
│  4.5.7  iteration += 1                          │
│         ├─ iteration ≤ 5 → go to 4.5.1          │
│         └─ iteration > 5 → ABORT PHASE          │
└─────────────────────────────────────────────────┘
```

**4.5.1 Запуск (параллельно):**

**CRITICAL: Agent Context Management**
Reviewer и Judge агенты ДОЛЖНЫ использовать контекст эффективно:
- НЕ читать файлы по одному — использовать `Bash("cat file1 file2 file3")` для batch-чтения
- НЕ запускать десятки отдельных grep/проверок — объединять в один bash-скрипт
- VERDICT FIRST: сначала выдать verdict/scores, потом детали
- Если агент исчерпает контекст без verdict → retry (см. 4.5.1b)

```
# Architect Review (использует L0 agent ~/.claude/agents/reviewer.md — 174 строки, 7 секций)
Agent(name: "reviewer", subagent_type: "reviewer", model: "opus",
      prompt: "
Phase {N} review. Iteration {iteration}/5.

<CONTEXT_OVERRIDE>
CONTEXT BUDGET: max 15 tool calls. VERDICT FIRST — выдай verdict ДО деталей.
Если не уложишься — verdict всё равно обязателен, даже с пометками [UNVERIFIED].
</CONTEXT_OVERRIDE>

<RULES_INJECT>
{GLOBAL_RULES}
{PROJECT_RULES}
</RULES_INJECT>

<PHASE_SCOPE>
{описание фазы — goal, requirements, success criteria из ROADMAP}
{если iteration > 1: 'PREVIOUS FINDINGS (verify fixes): <list>'}
</PHASE_SCOPE>

<EFFICIENT_WORKFLOW>
1. ONE bash script — все automated checks за 1 вызов:
   uv run pytest tests/ -x -q --no-header 2>&1 | tail -3 &&
   uv run ruff check src/ 2>&1 | tail -5 &&
   uv run lint-imports 2>&1 | tail -3

2. BATCH read — git diff --name-only HEAD~1 → cat all changed files в 1-2 вызова

3. VERDICT — выдай вердикт и findings. Формат из твоего agent definition.
   Дополнительно добавь секцию:
   ### Automated Checks
   - Tests: PASS/FAIL (N passed)
   - Ruff: PASS/FAIL
   - Coverage: N%
   - Lint-imports: PASS/FAIL

4. Если есть время — углубись в детали. Если нет — verdict с [UNVERIFIED] секциями.
</EFFICIENT_WORKFLOW>
",
      run_in_background: true)

# Judge Verification (использует L0 agent ~/.claude/agents/judge.md — calibrated scoring)
Agent(name: "judge", subagent_type: "judge", model: "opus",
      prompt: "
Phase {N} evaluation. Iteration {iteration}/5.

<EVAL_SPEC>
```yaml
{EVAL_SPEC_YAML}
```
</EVAL_SPEC>

<RULES_INJECT>
{GLOBAL_RULES}
{PROJECT_RULES}
</RULES_INJECT>

<PHASE_SCOPE>
{описание фазы — goal, requirements}
{если iteration > 1: 'PREVIOUS SCORE: {prev_avg}. VERIFY FIXES FOR: <list>'}
Thresholds: standard >= 4.0, critical >= 4.5.
</PHASE_SCOPE>

Следуй своему workflow: automated checks → batch read → JSON verdict.
",
      run_in_background: true)
```

**4.5.1b Retry loop для reviewer/judge (max 3 attempts каждый):**

Если agent завершился но НЕ вернул verdict (нет `## Verdict:` для reviewer или нет `\"verdict\"` JSON для judge):

```
retry_count = 0
while retry_count < 3:
  retry_count += 1

  # Перезапуск с укороченным промптом
  Agent(name: "{role}-retry-{retry_count}", subagent_type: "reviewer", model: "opus",
        prompt: "
ПРЕДЫДУЩИЙ ЗАПУСК ИСЧЕРПАЛ КОНТЕКСТ БЕЗ VERDICT.
ЭТО RETRY {retry_count}/3. БУДЬ МАКСИМАЛЬНО КРАТОК.

{role == 'reviewer':
  Запусти: uv run pytest tests/ -x -q && uv run ruff check src/ && uv run lint-imports
  Прочитай ТОЛЬКО файлы с изменениями (git diff --name-only HEAD~1).
  СРАЗУ выдай:
  ## Verdict: APPROVED / NEEDS_CHANGES
  ### Findings
  - [SEVERITY] file:line — description
  ### Automated Checks
  Tests/Ruff/Coverage/Lint-imports: PASS/FAIL
}

{role == 'judge':
  Запусти: uv run pytest tests/ -x -q && uv run lint-imports
  Прочитай git diff --stat HEAD~1.
  Оцени по {len(criteria)} criteria. СРАЗУ выдай JSON:
  {\"scores\": {...}, \"weighted_average\": N, \"verdict\": \"PASS/FAIL\", \"evidence\": {...}}
}
",
        run_in_background: true)

  # Проверить результат
  if verdict найден → break
  if retry_count >= 3 → используй fallback:
    - reviewer: считать APPROVED если все automated checks pass
    - judge: запустить inline verification (команды из eval spec checklist) и подставить scores
```

**4.5.2 Обработка результатов:**

| Reviewer | Judge | Findings | Action |
|----------|-------|----------|--------|
| APPROVED | PASS (≥ 4.0) | 0 SERIOUS | Exit loop → Step 4.6 |
| APPROVED | PASS (≥ 4.0) | SERIOUS/WARNING exist | Fix ALL findings → re-judge (Step 4.5.4) |
| APPROVED | FAIL (< 4.0) | — | Fix Judge findings → re-judge |
| NEEDS_CHANGES | PASS | — | Fix reviewer findings → re-review |
| NEEDS_CHANGES | FAIL | — | Fix ALL findings → re-both |

**CRITICAL RULE: Judge PASS ≠ "можно коммитить".**
Если Judge дал PASS но есть SERIOUS или WARNING findings → исправить ВСЕ → re-judge.
НЕ спрашивать пользователя "фиксить или пропускать?" для SERIOUS findings.
Цикл продолжается пока не будет PASS с 0 SERIOUS findings.
WARNING фиксятся без re-judge если не затрагивают архитектуру.

**4.5.4 Fix protocol:**
1. Парсить findings из reviewer + judge (ВСЕ severity levels)
2. Приоритет: CRITICAL → SERIOUS → WARNING
3. Исправить ВСЕ findings (SERIOUS обязательно, WARNING рекомендовано)
4. `pytest + ruff` must pass
5. Коммит: `fix(phase-{N}): review iteration {iteration} fixes`
6. Re-judge обязателен после SERIOUS fixes

**4.5 ABORT (iteration > 5):**
Если после 5 циклов Judge всё ещё FAIL:
1. Обнови `STATUS.md`: фаза = **BLOCKED** (Judge FAIL after 5 iterations)
2. Обнови `progress.md`: запиши все iterations, scores, unresolved findings
3. Обнови `lessons.md`: запиши что пошло не так
4. НЕ коммитить как "done" — фаза **не завершена**
5. Выведи пользователю:
   ```
   ❌ Phase {N} BLOCKED: Judge FAIL after 5 fix cycles.
   Last score: {avg}/5.0 (threshold: 4.0)
   Unresolved: <list of remaining findings>
   Action: manual review required before retry.
   ```
6. Заверши сессию. НЕ предлагай `/build:team-phase {N+1}`.

**При retry:** используй тот же `{EVAL_SPEC_YAML}` — НЕ пересоздавай Meta-Judge.

4.6 **Verifier** (для M/L scope):
- Запусти verifier one-shot (DoD, lint, mypy, tests, boundaries)
- PASS → Step 4.6b. FAIL → fix CRITICAL, повтор

4.6b **Reflexion** (после verifier):

```
Agent(name: "reflexion", subagent_type: "general-purpose", model: "opus",
      prompt: "
<TASK>
Рефлексия team-phase {N}.
Scope: {S/M/L}, задач: {N}, fix-задач: {N}
Judge scores: {scores}, Review iterations: {N}, Verifier iterations: {N}

Проанализируй: удачные решения, повторяющиеся проблемы, model tiering эффективность, декомпозиция.
</TASK>

<OUTPUT_FORMAT>
Output: JSON {learned_patterns: [...], anti_patterns: [...], lessons_md_update: string|null}
</OUTPUT_FORMAT>
")
```

Если `lessons_md_update` → обнови `.memory-bank/lessons.md`.

4.7 **Финальный аудит** (Team Lead):
- Запусти все `commands.*` из `.pipeline.yaml` (test, lint, typecheck, format_check)
- Boundary checks из `.pipeline.yaml`
- Placeholder checks из `.pipeline.yaml`

4.8 **Коммит (REQUIRES JUDGE_PASS):**

**PRE-COMMIT CHECK (MANDATORY):**
```
# Verify JUDGE_PASS.md exists — ABORT if missing
judge_pass_file=".planning/phases/{NN}-*/JUDGE_PASS.md"
if [ ! -f $judge_pass_file ]; then
  echo "ABORT: JUDGE_PASS.md not found. Judge Gate (Step 4.5) was NOT executed."
  echo "Return to Step 4.5 and run Judge Gate before committing."
  exit 1
fi
```

Если `JUDGE_PASS.md` НЕ существует → **НЕ КОММИТИТЬ**. Вернуться к Step 4.5.
Это последний барьер — даже если workflow сбился, коммит не пройдёт без Judge PASS.

```bash
git add <конкретные файлы>
git commit -m "feat(phase-{N}): {phase name} [Judge: {score}/5.0]"
```

4.9 **Shutdown team:**

**Shutdown protocol (MANDATORY):** отправь shutdown_request ПЕРЕД TeamDelete.
```
SendMessage(to: "dev-domain", message: "shutdown_request: phase complete, stop work")
SendMessage(to: "dev-infra", message: "shutdown_request: phase complete, stop work")
SendMessage(to: "tester-1", message: "shutdown_request: phase complete, stop work")
SendMessage(to: "tester-2", message: "shutdown_request: phase complete, stop work")

TeamDelete(team_name: "gsd-phase-{N}")
```

## Step 5: GSD Verify + MB Sync

5.1 **GSD SUMMARY.md:**
Создай `.planning/phases/{NN}-name/{phase}-{N}-SUMMARY.md` с результатами execution

5.2 **GSD Verify (goal-backward):**
Вызови `/gsd:verify-work {phase}`. Проведи UAT.
Если проблемы → fix-задачи → повторный execution

5.3 **MB Verify (plan-forward):**
Вызови `/mb verify` если есть MB план

5.4 **MB Sync:**
1. `checklist.md`: все задачи фазы → ✅
2. `STATUS.md`: обнови метрики (тесты, coverage)
3. `progress.md`: APPEND запись
4. `lessons.md`: если обнаружены антипаттерны
5. `STATE.md` в `.planning/`: обнови позицию

5.5 **Итог:**
- Что сделано, сколько тестов, файлы
- Предложи: `/build:team-phase {N+1}`

</process>

<error_handling>
- **Тиммейт не отвечает:** ping → ping → kill & replace
- **Developer застрял 3+ раз:** забрать задачу
- **Agent context exhaustion (CRITICAL):** team-lead дозавершает задачи → прогоняет тесты → **ОБЯЗАТЕЛЬНО** переходит к Step 4.5 Judge Gate. Context exhaustion НЕ является причиной пропуска Judge.
- **Judge FAIL после fix:** re-judge обязателен. НЕ идти дальше без PASS.
- **Judge FAIL 5 раз подряд:** ABORT фазу. Статус = BLOCKED. Сессия завершена.
- **Judge Gate пропущен (detected at commit):** JUDGE_PASS.md отсутствует → коммит блокирован → вернуться к Step 4.5
- **Session context low перед Judge:** запустить Judge с --lite tier (1 reviewer + 1 judge). НЕ пропускать.
- **Tests красные после execution:** НЕ переходить к review, fix сначала
- **Tests красные после review fix:** НЕ запускать re-judge, fix тесты сначала
- **MB файлы не в sync:** MB Doctor
- **Compaction risk:** `/mb update` немедленно
- **ABSOLUTE RULE:** Фаза НИКОГДА не считается завершённой без JUDGE_PASS.md. Ни при каких обстоятельствах.
</error_handling>

<key_differences_from_build_phase>
## Отличия от /build:phase

| Aspect | /build:phase | /build:team-phase |
|--------|-------------|-------------------|
| **Execution** | GSD executor (1 agent per plan) | Pipeline team (N agents parallel) |
| **Parallelism** | Wave-level (plans parallel) | Task-level (developers parallel) |
| **Quality gates** | GSD verify only | Automated hooks + architect review + verifier |
| **Code review** | None (trust executor) | Architect reviews all changes |
| **Testing** | Executor writes own tests | Separate tester agents |
| **Commits** | Per task (executor) | Per phase (after review) |
| **Best for** | Small phases (1-3 tasks) | Medium+ phases (4+ tasks, multiple files) |
</key_differences_from_build_phase>
