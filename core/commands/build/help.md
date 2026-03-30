---
name: build:help
description: Show build workflow guide — how to use /build commands, prerequisites, and decision tree
allowed-tools:
  - Read
---

<objective>
Покажи пользователю руководство по использованию build workflow.
</objective>

<guide>

# Build Workflow — Руководство

Build = GSD (execution engine) + Pipeline (team mode) + Memory Bank (долгосрочная память).

## Предварительные требования

Каждый проект, использующий build, должен иметь:

1. **`.pipeline.yaml`** — конфигурация проекта (обязательно)
2. **`.memory-bank/`** — долгосрочная память (`/mb init` если нет)
3. **`.planning/`** — GSD артефакты (`/build:init` если нет)
4. **`RULES.MD`** — правила кода (опционально, но рекомендуется)
5. **`CLAUDE.md`** — архитектура проекта (опционально)

### Минимальный `.pipeline.yaml`

```yaml
project:
  name: my-project
  language: python  # или typescript, go, rust, etc.

commands:
  test: "pytest -q"              # как запускать тесты
  lint: "ruff check ."           # как запускать линтер
  typecheck: "mypy src"          # как запускать type checker
  format_check: "black --check ." # как проверять форматирование (опционально)

context:
  loader: memory-bank
  plan_file: .memory-bank/plan.md
  checklist_file: .memory-bank/checklist.md
  lessons_file: .memory-bank/lessons.md

team:
  dev_layers:
    - domain     # основной слой (domain + business logic)
    - infra      # инфраструктурный слой (DB, API, adapters)

architecture_rules:
  - "Clean Architecture: domain НЕ импортирует infrastructure"
  - "TDD: тесты ПЕРЕД реализацией"

boundary_checks:
  - 'grep -r "from myproject.infrastructure" src/myproject/domain/ 2>/dev/null | head -5'

placeholder_patterns:
  - 'grep -rn "TODO\\|FIXME\\|HACK" src/ 2>/dev/null | head -10'

judge:
  standard_threshold: 4.0
  critical_threshold: 4.5
  panel_size: 1            # 2 для critical компонентов

model_tiering:
  developer: opus     # L-006: sonnet caused context exhaustion → Judge skip
  tester: opus        # L-006: all agents on opus by default
  architect: opus
  reviewer: opus
  judge: opus
  reflexion: opus

quality_hooks:
  ai_residuals: true       # scan TODO, FIXME, localhost, mockData
  test_tampering: true     # detect it.skip, describe.skip
  judge_findings_gate: true # BLOCK commit при SERIOUS findings в JUDGE_PASS.md
  protected_warn:          # warn (не block) при правке
    - package.json
    - Dockerfile
    - docker-compose.yml
    - .github/workflows/
```

## Какую команду выбрать

```
Задача
  │
  ├─ Опечатка, мелкий фикс, 1 файл
  │   └─ /build:fast "описание"
  │
  ├─ Ad-hoc задача, 2-5 файлов, нужен TDD
  │   └─ /build:quick "описание"
  │       ├─ --discuss  (обсудить серые зоны)
  │       ├─ --research (исследовать подходы)
  │       └─ --full     (план-чекер + верификация)
  │
  ├─ Нужен brainstorm/ideation перед задачей
  │   └─ /sdd-brainstorm
  │
  ├─ Spec-driven фаза (EARS requirements → design → verified implementation)
  │   └─ /build:phase N --sdd  или  /build:team-phase N --sdd
  │       ├─ /sdd-brainstorm (optional exploration)
  │       ├─ /sdd-plan → requirements.md + design.md
  │       ├─ GSD execution по спецификации
  │       └─ spec-verify.sh → каждый AC имеет тест
  │
  ├─ Фаза из ROADMAP, 1-3 задачи (scope S)
  │   └─ /build:phase N
  │       ├─ --debate    (3 judges с дебатом для critical фаз)
  │       └─ GSD executor (один агент на план)
  │
  ├─ Фаза из ROADMAP, 4+ задач (scope M/L)
  │   └─ /build:team-phase N
  │       ├─ --debate    (3 judges с дебатом для critical фаз)
  │       └─ Pipeline team (параллельные агенты)
  │
  ├─ Автономный прогон всех оставшихся фаз
  │   └─ /build:autonomous-all
  │       ├─ --phases 12-20   (диапазон фаз)
  │       ├─ --max-phases 5   (лимит фаз)
  │       └─ --skip-initial-audit / --skip-final-audit
  │
  ├─ Новый проект, нет .planning/
  │   └─ /build:init
  │       └─ Создаёт .planning/ и связывает с MB
  │
  ├─ Code review (standalone, любой код)
  │   └─ /build:review "scope" [--lite|--standard|--full]
  │       ├─ --lite      (1 reviewer — мелкие изменения)
  │       ├─ --standard  (3 reviewers + architect — default)
  │       └─ --full      (6 reviewers + architect — аудит)
  │
  └─ Где мы? Что дальше?
      └─ /build:status
          └─ Dashboard: deps + MB + GSD + git + next step
```

## Жизненный цикл фазы

```
/build:phase N  или  /build:team-phase N

  Step 0: Load Context (MB + GSD)
     │
  Step 1: Discuss  ←── /gsd:discuss-phase N
     │                  (можно --skip-discuss)
  Step 2: Plan     ←── /gsd:plan-phase N
     │
  Step 3: Execute  ←── /gsd:execute-phase N  (phase)
     │                  Pipeline team mode    (team-phase)
     │
  Step 4: Verify   ←── GSD verify + MB verify
     │                  (можно --skip-verify)
  Step 5: Finalize ←── MB sync (checklist, STATUS, progress)
```

## build:phase vs build:team-phase

| | `/build:phase` | `/build:team-phase` |
|---|---|---|
| **Когда** | 1-3 задачи, простая фаза | 4+ задач, параллельная работа |
| **Execution** | GSD executor (1 agent) | Pipeline team (N agents) |
| **Code review** | LITE mandatory (1 reviewer L0) | Architect review обязателен (STANDARD/FULL) |
| **Тесты** | Executor пишет сам | Отдельные tester агенты |
| **Коммиты** | Per task | Per phase (после review) |
| **Стоимость** | Меньше tokens | Больше tokens, но быстрее |
| **Meta-Judge** | YAML evaluation spec | YAML evaluation spec |
| **Judge** | 1 judge (или 3 с --debate) | 1 judge (или 3 с --debate) |
| **Model Tiering** | Нет (один агент) | ALL Opus (L-006: sonnet/haiku → context exhaustion) |
| **Reflexion** | После verify | После verify |
| **RULES.md** | Injected в все agent prompts | Injected в все agent prompts |

## Типичные сценарии

### Новый проект
```
/build:init          # Создать .planning/ + связать с MB
/build:phase 1       # Первая фаза
```

### Продолжение работы
```
/gsd:progress        # Где мы? Что дальше?
/build:phase N       # Следующая фаза
```

### Автопилот (уйти и вернуться)
```
/build:autonomous-all --max-phases 5
```

### Мелкая задача вне roadmap
```
/build:quick "добавить endpoint для health check"
```

### Критический баг
```
/build:fast "fix NPE в UserService.get_by_id"
```

### Debug с root cause analysis
```
/kaizen-why             # 5 Whys анализ
/gsd:debug              # Debug через GSD executor
```

### Release (версия + changelog + tag)
```
/harness-release minor|patch|major
```

### Одна задача, full chain
```
/implement задача       # research x3 → architect → judge → review x3 → reflexion
```

## Build Hooks

Build skill использует hooks для автоматического enforcement качества. Устанавливаются через `/build:init`.

| Hook | Trigger | Action | Severity |
|------|---------|--------|----------|
| `judge-findings-gate.sh` | `git commit` (PostToolUse Bash) | BLOCK если JUDGE_PASS.md содержит SERIOUS findings | **BLOCK** |
| `judge-findings-gate.sh` | Agent completion | WARN если output содержит SERIOUS/CRITICAL findings | WARN |
| `quality-gate.sh` | Write/Edit | WARN AI residuals (TODO, FIXME, localhost) | WARN |
| `quality-gate.sh` | Write/Edit тестов | BLOCK test tampering (it.skip, describe.skip) | **BLOCK** |

**Ключевое правило:** Judge PASS + SERIOUS findings = fix + re-judge. Hook блокирует коммит пока findings открыты.

## Quality Gates

Все `build:*` команды автоматически:
- Читают `commands.*` из `.pipeline.yaml` для lint/test/typecheck
- Синхронизируют `.memory-bank/` (checklist, STATUS, progress)
- Проверяют `boundary_checks` и `placeholder_patterns`
- Не продолжают при RED gate (тесты/lint/types fail)
- **Judge Findings Gate:** блокирует коммит при SERIOUS findings в JUDGE_PASS.md

## Вспомогательные скилы (можно вызывать на любом этапе)

| Скил | Когда использовать |
|------|-------------------|
| `/sdd-brainstorm` | Перед planning — ideation, exploration альтернатив |
| `/sdd-plan` | Spec-driven planning с multi-agent pipeline |
| `/reflexion-critique` | После review — multi-perspective анализ с debate |
| `/reflexion-reflect` | Self-refinement текущего решения |
| `/kaizen-why` | Root cause analysis (5 Whys) при баге |
| `/kaizen-analyse-problem` | A3 one-page анализ проблемы |
| `/sadd-do-competitively` | Конкурентная генерация + LLM-as-Judge |
| `/sadd-tree-of-thoughts` | Tree of Thoughts для сложных решений |
| `/harness-review` | 4-perspective review (security + perf + quality + a11y) |
| `/harness-release` | SemVer bump + CHANGELOG + GitHub Release |
| `/implement` | Full chain: research x3 → architect → judge → review x3 → reflexion |

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| "`.pipeline.yaml` не найден" | Создай файл по шаблону выше |
| "`.planning/` не существует" | Запусти `/build:init` |
| "`.memory-bank/` не существует" | Запусти `/mb init` |
| Gate RED после execution | Fix вручную или `/gsd:execute-phase N --gaps-only` |
| Context pressure >70% | Автоматически вызывается `/mb update` |

## SADD/CET Integration (v2)

Новые возможности, интегрированные из SADD и CET:

| Feature | Что делает | Где |
|---------|-----------|-----|
| **Meta-Judge** | Генерирует structured YAML evaluation spec перед оценкой | phase, team-phase, quick --full |
| **Model Policy** | ALL Opus by default (L-006); `.pipeline.yaml` override available | team-phase |
| **--debate** | 3 независимых judges с дебатом до консенсуса | phase, team-phase |
| **CET Prompt Structure** | U-shaped attention: critical info на edges промптов | Все agent prompts |
| **RULES.md Injection** | Global + project rules во все code-touching agents | Все agent prompts |
| **Self-Critique** | 6-вопросный verification loop для developer/tester agents | team-phase |

### Model Policy

По умолчанию все агенты запускаются на **Opus** (1M context). Lesson L-006: sonnet/haiku вызывали context exhaustion и пропуск Judge Gate.

`.pipeline.yaml` `model_tiering` позволяет override для конкретных ролей:
```yaml
model_tiering:
  developer: opus    # default: opus (recommended)
  tester: opus       # default: opus (recommended)
  architect: opus    # always opus
  # Override to sonnet only if explicitly accepted risk of context exhaustion:
  # developer: sonnet
```

### --debate

Опция для критических фаз. Авто-предлагается при effort score ≥ 4.
Стоимость: ~5-10x tokens vs single judge. Используй осознанно.

</guide>

<process>
Выведи содержимое секции `<guide>` пользователю как есть.
</process>
