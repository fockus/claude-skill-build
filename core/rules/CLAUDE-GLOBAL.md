# CRITICAL RULES — НЕ ЗАБЫВАТЬ ПРИ COMPACTION

> **Contract-First** — Protocol/ABC → contract-тесты → реализация. Тесты проходят для ЛЮБОЙ корректной реализации.
> **TDD** — сначала тесты, потом код. Пропуск: только опечатки, форматирование, exploratory prototypes.
> **Clean Architecture** — `Infrastructure → Application → Domain` (никогда обратно). Domain = 0 внешних зависимостей.
> **SOLID пороги** — SRP: >300 строк или >3 публичных метода разной природы = разделить. ISP: Interface ≤5 методов. DIP: конструктор принимает абстракцию.
> **DRY / KISS / YAGNI** — дубль >2 раз → извлечь. Три одинаковых строки лучше преждевременной абстракции. Не писать код "на будущее".
> **Testing Trophy** — интеграционные > unit > e2e. Mock только внешние сервисы. >5 mock'ов → кандидат на интеграционный.
> **Качество тестов** — имя: `test_<что>_<условие>_<результат>`. Assert = бизнес-факт. Arrange-Act-Assert. `@parametrize` вместо копипасты.
> **Coverage** — общий 85%+, core/business 95%+, infrastructure 70%+.
> **Fail Fast** — не уверен → план 3-5 строк, спроси.
> **Язык** — ответы на русском, техтермины на английском.
> **Без placeholder'ов** — никаких TODO, `...`, псевдокода. Код copy-paste ready. Исключение: staged stub за feature flag с docstring.
> **Планы** — подробные DoD (SMART) на каждый этап, требования по TDD и нашим правилам кода, сценарии проверки, edge cases.
> **Защищённые файлы** — `.env`, `ci/**`, Docker/K8s/Terraform — не трогать без запроса.
> **Подробные правила:** `~/.claude/RULES.md` + `RULES.md` в корне проекта.


---

# Global Rules

## Coding
- No new libraries/frameworks without explicit request
- New business logic → tests FIRST, then implementation
- Full imports, valid syntax, complete functions — copy-paste ready
- Multi-file changes → план сначала
- Specification by Example: требования как конкретные входы/выходы = готовые test cases
- Рефакторинг через Strangler Fig: поэтапно, тесты проходят на каждом шаге
- Значимое решение → ADR (контекст → решение → альтернативы → последствия)
— У каждой задачи которую ты пишешь, должны быть критерии готовности (по SMART) которые ты проверяешь (DoD)

## Testing — Testing Trophy
- **Покрытие тестами:**: 85%+ (core 95%+, infrastructure 70%+)
- **Интеграционные (основной фокус):** реальные компоненты вместе, mock только внешнее
- **Unit (вторичный):** чистая логика, edge cases. 5+ mock'ов → кандидат на интеграционный
- **E2E (точечно):** только критические user flows
- **Static:** go vet, golangci-lint, type checking — всегда

## Reasoning
- Complex tasks: analysis → plan → implementation → verification
- Before editing: search the project, don't guess
- Response format: Цель → Действие → Результат
- Destructive actions — only after explicit confirmation
- Do not expand scope without request

## Planning

When creating plans (including built-in plan mode):
- Write plans to `./.memory-bank/plans/` if Memory Bank active
- Every stage has DoD criteria by SMART
- Every stage has test requirements BEFORE implementation (TDD)
- Tests: unit + integration + e2e where applicable
- Stages are atomic and ordered by dependencies


## Memory Bank

**Если `./.memory-bank/` существует → `[MEMORY BANK: ACTIVE]`.**
Если, папки нет, создай ее с внутренней структурой. и напиши `[MEMORY BANK: INITIALIZED]`

**Skill:** `memory-bank`. **Команда:** `/mb`. **Subagent:** MB Manager (sonnet).
**Глобальные правила**: `~/.claude/RULES.md` (TDD, SOLID, DRY, KISS, YAGNI, Clean Architecture, Testing Trophy, MB workflow — для ВСЕХ проектов)
**Проект-специфичные правила**: `RULES.MD` в корне проекта
**Шаблоны**: `~/.claude/skills/memory-bank/references/templates.md`
**Workflow**: `~/.claude/skills/memory-bank/references/workflow.md`

### Команды /mb

| Команда | Описание |
|---------|----------|
| `/mb` или `/mb context` | Собрать контекст проекта (статус, чеклист, план) |
| `/mb start` | Расширенный старт сессии (контекст + активный план целиком) |
| `/mb search <query>` | Поиск информации в банке по ключевым словам |
| `/mb note <topic>` | Создать заметку по теме |
| `/mb update` | Актуализировать core files (checklist, plan, status) |
| `/mb tasks` | Показать незавершённые задачи |
| `/mb index` | Реестр всех записей (core files + notes/plans/experiments/reports) |
| `/mb done` | Завершение сессии (actualize + note + progress) |
| `/mb plan <type> <topic>` | Создать план (type: feature, fix, refactor, experiment) |
| `/mb verify` | Верификация плана vs код. **ОБЯЗАТЕЛЬНО** перед `/mb done` если работа по плану |
| `/mb init` | Инициализировать Memory Bank в новом проекте |

### Ключевые правила

- progress.md = **append-only** (никогда не удалять/редактировать старое)
- Нумерация сквозная: H-NNN, EXP-NNN, ADR-NNN (не переиспользовать)
- notes/ = знания и паттерны (5-15 строк), **не хронология**. Не создавать для тривиальных изменений
- reports/ = подробные отчёты, полезные будущим сессиям (анализ, post-mortem, сравнения)
- checklist: ✅ = done, ⬜ = todo. Обновлять **сразу** при завершении задачи

**Путь**: `./.memory-bank/`

### Структура

**Ядро (читать каждую сессию):**

| Файл | Назначение | Когда обновлять |
|------|-----------|-----------------|
| `STATUS.md` | Где мы, roadmap, ключевые метрики, gates | Завершён этап, сдвинулся roadmap, изменились метрики |
| `checklist.md` | Текущие задачи ✅/⬜ | Каждую сессию, сразу при завершении задачи |
| `plan.md` | Приоритеты, направление | Когда меняется вектор/фокус |
| `RESEARCH.md` | Реестр гипотез + findings + текущий эксперимент | При изменении статуса гипотезы или нового finding |

**Детальные записи (читать по запросу):**

| Файл / Папка | Назначение | Когда обновлять |
|--------------|-----------|-----------------|
| `BACKLOG.md` | Идеи, ADR, отклонённое | Когда появляется идея или архитектурное решение |
| `progress.md` | Выполненная работа по датам | Конец сессии (append-only) |
| `lessons.md` | Повторяющиеся ошибки, антипаттерны | Когда замечен паттерн |
| `experiments/` | `EXP-NNN_<n>.md` — ML эксперименты | При завершении эксперимента |
| `plans/` | `YYYY-MM-DD_<type>_<n>.md` — детальные планы | Перед сложной работой |
| `reports/` | `YYYY-MM-DD_<type>_<n>.md` — отчёты | Когда полезно будущим сессиям |
| `notes/` | `YYYY-MM-DD_HH-MM_<тема>.md` — заметки | По завершении задачи (знания, не хронология) |


### Workflow (кратко)

**Старт**: `/mb start` → читать 4 core files (STATUS, checklist, plan, RESEARCH) → резюме фокуса.
**Работа**: checklist.md обновлять сразу (⬜→✅). STATUS.md — при milestone/метриках. RESEARCH.md — при изменении гипотез.
**Конец**: `/mb verify` (если план) → `/mb done` (checklist + progress + note + STATUS/RESEARCH если нужно).
**Перед compaction**: `/mb update` чтобы не потерять прогресс.

# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (60-90% savings on dev operations)
@RTK.md

## Find Skill — поиск и установка скилов

**Skill:** `find-skill`. **Команда:** вызывай `/find-skill <запрос>`.
**Каталог:** `~/.claude/skills/find-skill/cache/catalogue.json` (12 источников, ранжирование по GitHub stars).

**Когда использовать:**
- Пользователь просит найти/установить скил для конкретной задачи
- Нужен скил для незнакомой технологии или workflow
- Пользователь спрашивает "есть ли скил для X?"

**Как работает:**
1. Ищет в локальном каталоге (быстро, без сети)
2. Если мало результатов — дополняет через SkillsMP API
3. Показывает результаты с источником и уровнем доверия
4. Устанавливает только после подтверждения пользователя

**Приоритет источников (по GitHub stars):** Anthropic (105K) > ComposioHQ (49K) > vercel-labs (24K) > VoltAgent-subagents (15.5K) > VoltAgent (13K) > travisvn (10K) > BehiSecc/alirezarezvani (8K) > heilcheng (3.5K) > daymade/mxyhi > SkillsMP

## Оркестрация и Execution — какой скил когда

**Выбирай инструмент по масштабу задачи:**

```
Тривиальное (опечатка, 1 файл)     → /build:fast
Ad-hoc с TDD (2-5 файлов)          → /build:quick [--reflexion]
Фаза 1-3 задачи                    → /build:phase N (Judge + Reflexion + SDD опция)
Фаза 4+ задач (team mode)          → /build:team-phase N (Model Tiering + Judge + Reflexion)
Автопилот всех оставшихся фаз      → /build:autonomous-all
Одна задача full chain              → /implement (3 researcher → architect → dev → judge → review x3 → reflexion)
Team execution по master plan       → /pipeline (parallel agents + quality gates)
```

**Harness (отдельный проект с полным циклом):**
```
/harness-plan         — structured planning → Plans.md
/harness-work         — auto-mode: solo (1 задача) / parallel (2-3) / breezing (4+)
/harness-review       — 4-perspective review (security + perf + quality + a11y) + AI residuals
/harness-release      — SemVer bump + CHANGELOG + GitHub Release + git tag
```

**Вспомогательные (вызывать на любом этапе):**
```
/sdd-brainstorm          — ideation, exploration альтернатив перед planning
/sdd-plan                — spec-driven multi-agent planning (researcher + analyst + architect)
/reflexion-critique      — multi-perspective review с debate между judges
/reflexion-reflect       — self-refinement текущего решения
/kaizen-why              — 5 Whys root cause analysis при баге
/kaizen-analyse-problem  — A3 one-page анализ проблемы
/sadd-do-competitively   — конкурентная генерация + LLM-as-Judge
/sadd-tree-of-thoughts   — Tree of Thoughts для сложных архитектурных решений
```

**Quality Gate Hook** (`~/.claude/hooks/quality-gate.sh`) — автоматически на каждый Write/Edit/Bash:
- AI residuals scan (TODO, FIXME, localhost, mockData, console.log)
- Test tampering detection (it.skip, describe.skip → BLOCK)
- Protected files warning (package.json, Dockerfile, CI)
- `.env`/`.pem`/`.key` — разрешены (warn режим)

## RULES.md

**Полные правила (edge cases, workflow, шаблоны) → `~/.claude/RULES.md` + `RULES.MD` в корне проекта + skill `memory-bank`.**
