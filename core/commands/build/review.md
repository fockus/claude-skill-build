---
name: build:review
description: "Multi-agent code review — LITE (1 reviewer), STANDARD (3 focused), FULL (6 specialized + architect). Accepts review scope as argument."
argument-hint: "<what to review> [--lite|--standard|--full] [--active]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Agent
  - AskUserQuestion
---

<objective>
Multi-agent review с 3 tier'ами. Каждый tier запускает специализированных ревьюверов параллельно.
Принимает свободный prompt описывающий ЧТО ревьювить.
</objective>

<process>

## 1. Parse Arguments

Из `$ARGUMENTS` извлеки:
- **Prompt** — всё что не флаг = описание scope ревью (файлы, модули, фичи, git range)
- **Tier flag** — `--lite`, `--standard`, `--full`. Если нет → `--standard` (default)
- **Active flag** — `--active`. If present, run browser-based assertion checks after code review. Requires Playwright MCP. Skipped gracefully if unavailable.

**Примеры:**
```
/build:review src/code_factory/shared/ --lite
/build:review "все изменения Phase 1" --full
/build:review git diff HEAD~3 --standard
/build:review src/code_factory/execution/domain.py
/build:review "проверь архитектуру bounded contexts"
```

**Default tier: STANDARD** (3 reviewers — лучший баланс цена/качество).

## 2. Resolve Review Scope

Из prompt'а определи КОНКРЕТНЫЕ файлы для review:

- Если prompt содержит пути файлов/директорий → использовать их
- Если "git diff" / "незакоммиченный" → `git diff --name-only`
- Если "Phase N" / "фаза N" → `git log --oneline` найти коммит фазы, `git diff` от него
- Если "все" / "всё" / "весь проект" → все source файлы (`src/` + `tests/`)
- Иначе → `git diff --name-only HEAD~1` (default: последний коммит)

Результат: `{FILE_LIST}` — конкретные файлы для ревью.

## 3. Load Context

Прочитай (если существуют):
- `~/.claude/RULES.md` → `{GLOBAL_RULES}`
- `./RULES.md` → `{PROJECT_RULES}`
- `.memory-bank/lessons.md` → `{LESSONS}`
- `CLAUDE.md` → проектные конвенции

## 4. Execute Review Tier

---

### LITE (1 reviewer)

Один `subagent_type: "reviewer"` (L0 agent, 174 строки, 7 секций).

```
Agent(name: "reviewer", subagent_type: "reviewer", model: "opus",
      prompt: "
Review scope: {USER_PROMPT}
Files: {FILE_LIST}

<RULES_INJECT>
{GLOBAL_RULES}
{PROJECT_RULES}
</RULES_INJECT>

<LESSONS>{LESSONS}</LESSONS>

<CONTEXT_OVERRIDE>
CONTEXT BUDGET: max 15 tool calls. VERDICT FIRST.
</CONTEXT_OVERRIDE>

<EFFICIENT_WORKFLOW>
1. ONE bash script — все automated checks
2. BATCH read changed files
3. VERDICT с findings
</EFFICIENT_WORKFLOW>
")
```

Дождись результата → выведи отчёт → готово.

---

### STANDARD (3 reviewers + architect)

**Запусти 3 reviewers параллельно:**

**1. Code Quality & RULES compliance** (`subagent_type: "reviewer"`, opus)
```
FOCUS: RULES compliance, SOLID, TDD, KISS, DRY, YAGNI, placeholders, incomplete logic.
Review scope: {USER_PROMPT}
Files: {FILE_LIST}
<RULES_INJECT>{GLOBAL_RULES}\n{PROJECT_RULES}</RULES_INJECT>
<LESSONS>{LESSONS}</LESSONS>

Проверь ТОЛЬКО:
1. SOLID violations (SRP: >300 LOC, ISP: >5 methods, DIP: concrete imports)
2. TDD compliance (тесты есть? покрытие?)
3. KISS/DRY/YAGNI (лишние абстракции? дублирование? код на будущее?)
4. Placeholder audit (TODO, FIXME, pass, NotImplementedError)
5. Incomplete logic (определены но не вызваны, partial implementations)
6. RULES.md violations

CONTEXT BUDGET: max 12 tool calls. VERDICT FIRST.
```

**2. Plan Alignment & Verification** (`subagent_type: "verifier"`, opus)
```
FOCUS: Plan alignment, DoD, contract drift, production wiring.
Review scope: {USER_PROMPT}
Files: {FILE_LIST}
<RULES_INJECT>{GLOBAL_RULES}\n{PROJECT_RULES}</RULES_INJECT>

Проверь ТОЛЬКО:
1. DoD — все критерии готовности из плана выполнены?
2. Contract drift — сигнатуры implementations совпадают с interfaces?
3. Production wiring — новые компоненты подключены?
4. Coverage thresholds — 85%+ overall?
5. Automated checks — tests, ruff, lint-imports pass?
6. Missing pieces — функционал из плана но не реализованный?

Прочитай активный план из .memory-bank/plan.md или .planning/phases/.
CONTEXT BUDGET: max 12 tool calls. VERDICT FIRST.
```

**3. Security** (`subagent_type: "security"`, sonnet)
```
FOCUS: Security — OWASP, secrets, injection, input validation.
Review scope: {USER_PROMPT}
Files: {FILE_LIST}

Проверь ТОЛЬКО:
1. OWASP Top 10
2. Hardcoded secrets
3. Input validation на границах
4. SQL/command injection
5. Unsafe deserialization

CONTEXT BUDGET: max 10 tool calls. VERDICT FIRST.
```

**Дождись всех 3 → architect-aggregator** (`subagent_type: "architect"`, opus):
```
MODE: aggregation

<REVIEWER_REPORTS>
Quality: {result_1}
Plan Verification: {result_2}
Security: {result_3}
</REVIEWER_REPORTS>

Собери findings → дедуплицируй → приоритизируй → fix plan (3 этапа).

OUTPUT:
# Review Report
## Overall Verdict: APPROVED / NEEDS_CHANGES
## Summary (N CRITICAL, N SERIOUS, N WARNING)
## Fix Plan
### Stage 1: Blockers | Stage 2: Important | Stage 3: Nice-to-have
```

---

### FULL (6 reviewers + architect)

**Запусти 6 reviewers параллельно:**

| # | Name | subagent_type | Model | Focus |
|---|------|---------------|-------|-------|
| 1 | security-reviewer | `security` | opus | OWASP Top 10, CWE, secrets, injection |
| 2 | architecture-critic | `critic` | opus | Scalability, failure modes, hidden assumptions, alternatives |
| 3 | bug-hunter | `general-purpose` | sonnet | Silent failures, error handling, catch-all blocks, logging gaps |
| 4 | plan-verifier | `verifier` | opus | DoD, contract drift, production wiring, coverage |
| 5 | quality-reviewer | `reviewer` | opus | RULES, SOLID, TDD, KISS, DRY, YAGNI, placeholders |
| 6 | logic-inspector | `debugger` | opus | Correctness, edge cases, race conditions, boundary values |

**Промпты reviewer'ов:**

**1. security-reviewer** (`subagent_type: "security"`, opus):
```
Full security audit. Scope: {USER_PROMPT}. Files: {FILE_LIST}
Полный OWASP Top 10 scan. CWE classification для каждого finding.
CONTEXT BUDGET: max 12 tool calls. VERDICT FIRST.
```

**2. architecture-critic** (`subagent_type: "critic"`, opus):
```
Devil's Advocate review. Scope: {USER_PROMPT}. Files: {FILE_LIST}
<RULES_INJECT>{GLOBAL_RULES}\n{PROJECT_RULES}</RULES_INJECT>
FOCUS: scalability risks, failure modes, hidden assumptions, simpler alternatives.
НЕ ищи баги — ищи архитектурные слабости.
CONTEXT BUDGET: max 12 tool calls. VERDICT FIRST.
```

**3. bug-hunter** (`subagent_type: "general-purpose"`, sonnet):
```
Ты — Silent Failure Hunter. Scope: {USER_PROMPT}. Files: {FILE_LIST}

FOCUS:
1. Catch-all exception handlers (except Exception: pass)
2. Silent data loss (return None вместо raise)
3. Error messages без реальной причины
4. Race conditions в async коде
5. Off-by-one, boundary conditions
6. Missing None checks
7. Functions returning wrong type silently
8. Fallback values маскирующие ошибки

CONTEXT BUDGET: max 10 tool calls. VERDICT FIRST.
Формат: ## Bug Hunt: CLEAN / BUGS_FOUND
```

**4. plan-verifier** (`subagent_type: "verifier"`, opus):
```
Full plan compliance. Scope: {USER_PROMPT}. Files: {FILE_LIST}
<RULES_INJECT>{GLOBAL_RULES}\n{PROJECT_RULES}</RULES_INJECT>
Прочитай ВСЕ планы фазы. Каждый DoD — отдельная проверка.
Contract drift: сравни каждый Protocol с implementations.
CONTEXT BUDGET: max 12 tool calls. VERDICT FIRST.
```

**5. quality-reviewer** (`subagent_type: "reviewer"`, opus):
```
FOCUS: RULES, SOLID, TDD, incomplete logic.
Scope: {USER_PROMPT}. Files: {FILE_LIST}
<RULES_INJECT>{GLOBAL_RULES}\n{PROJECT_RULES}</RULES_INJECT>
<LESSONS>{LESSONS}</LESSONS>
Проверь КАЖДОЕ правило из RULES. Placeholder audit. Dead code.
CONTEXT BUDGET: max 12 tool calls. VERDICT FIRST.
```

**6. logic-inspector** (`subagent_type: "debugger"`, opus):
```
MODE: Review (НЕ debugging — ищи потенциальные проблемы).
Scope: {USER_PROMPT}. Files: {FILE_LIST}

FOCUS:
1. Бизнес-логика корректна? Все ветки обработаны?
2. Edge cases: пустые коллекции, None, пустые строки
3. Race conditions, shared mutable state
4. Boundary values: off-by-one, overflow
5. State management: невалидные состояния возможны?
6. Error propagation: ошибки не теряются?

НЕ запускай код — только анализ.
CONTEXT BUDGET: max 12 tool calls. VERDICT FIRST.
```

**Дождись всех 6 → architect-aggregator** (`subagent_type: "architect"`, opus):
```
MODE: full aggregation (6 reports)

<REVIEWER_REPORTS>
Security: {result_1}
Architecture: {result_2}
Bug Hunt: {result_3}
Plan Alignment: {result_4}
Code Quality: {result_5}
Logic: {result_6}
</REVIEWER_REPORTS>

1. Собери findings из ВСЕХ 6 отчётов
2. Cross-reference: issue от 2+ ревьюверов → повысить severity
3. Приоритизируй: CRITICAL → SERIOUS → WARNING
4. Fix plan в 3 этапа

OUTPUT:
# Full Review Report
## Overall Verdict: APPROVED / NEEDS_CHANGES / REJECTED

## Reviewer Verdicts
| Reviewer | Verdict | Findings |

## Summary (N CRITICAL, N SERIOUS, N WARNING)
## Cross-referenced issues (flagged by 2+ reviewers)

## Fix Plan
### Stage 1: Blockers | Stage 2: Important | Stage 3: Nice-to-have

## Positive Highlights
## Recommendations for Next Phase
```

---

## 5. Retry Logic

Для КАЖДОГО reviewer agent: если завершился без verdict:
- Retry до 3 раз с укороченным промптом
- Fallback после 3 retry: пометить `[UNREVIEWED]` в aggregation report

## 6. Save Report

Если `.memory-bank/reports/` существует:
```bash
# Filename: YYYY-MM-DD_review_{tier}_{short_scope}.md
```

## 7. Active Testing (if --active)

**Only runs when `--active` flag is present.** Skipped otherwise.

1. Run the active-test hook to check Playwright MCP availability and load assertions:
```bash
bash "$(dirname "$0")/../../hooks/active-test.sh" 2>&1
```

If the hook outputs `[SKIP]` — report "Active testing skipped: {reason}" and continue.

2. If assertions are loaded, use Playwright MCP tools to verify:
   - `browser_navigate` to target URL from assertions config
   - `browser_snapshot` to capture page content
   - Check each assertion against snapshot text

3. Append active test results to the review report:
```
### Active Testing Results
- URL: {url}
- Assertions: {pass_count}/{total_count} passed
- Details: {per-assertion PASS/FAIL}
```

If active testing fails (assertions not met), add to findings:
```
### SERIOUS (active test failures)
N. **[Active Test]** Assertion "{assertion}" failed against {url}
   - Impact: UI/functional regression detected
   - Fix: Verify the assertion text is present/visible on the page
```

## 8. Output

Выведи: tier, количество reviewers, aggregated verdict, findings по severity, fix plan.

</process>

<tier_selection_in_team_phase>
## Интеграция с /build:team-phase

При вызове из team-phase (Step 4.5), tier определяется автоматически:
- S-scope (1-3 задачи) → LITE
- M-scope (4-8 задач) → STANDARD
- L-scope (9+ задач) → STANDARD
- `--full-review` flag → FULL
- `/gsd:audit-milestone` → FULL
- `/build:autonomous-all` (финал) → FULL
</tier_selection_in_team_phase>
