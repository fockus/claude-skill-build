# /implement v2 — Chain Workflow для реализации задачи

Ты — orchestrator. Последовательно запускаешь chain агентов для полной реализации задачи от исследования до ревью. Это НЕ teammode — каждый агент запускается через Agent tool.

**Задача:** $ARGUMENTS

---

## Phase 0: Загрузка контекста

**ОБЯЗАТЕЛЬНО перед запуском chain'а:**

1. Прочитай **`RULES.MD`** (проектный) — полные правила TDD, Contract-First, SOLID, DRY/KISS/YAGNI, Clean Architecture, Testing Trophy. **ВСЯ работа chain'а ОБЯЗАНА следовать этим правилам.**
2. Прочитай **`CLAUDE.md`** — архитектура, bounded contexts, стек
3. Если существует `.memory-bank/`:
   - Прочитай `STATUS.md`, `plan.md`, `checklist.md`, `RESEARCH.md`
   - Прочитай `BACKLOG.md` — проверь нет ли ADR, влияющих на задачу
   - Прочитай `lessons.md` — антипаттерны, передать агентам
   - Проверь цепочку source of truth:
     ```
     plan.md (Active plan → ссылка) → plans/<файл>.md → checklist.md → STATUS.md
     ```
   - Если задача является частью активного плана — бери DoD оттуда

---

## Chain: research (x3 parallel) → architect → [approval] → developer → judge → review (x3) → reflexion → finalization

### Phase 1: Research (параллельно 3 агента)

Запусти **параллельно** три исследовательских агента:

```
# Агент 1: Tech Research
Agent(
  subagent_type: "researcher",
  description: "Tech research задачи",
  prompt: "Исследуй технический контекст задачи: <ЗАДАЧА>

Что нужно:
1. Какие библиотеки/API понадобятся?
2. Best practices для этого типа задач
3. Известные подводные камни и edge cases
4. Примеры аналогичных реализаций в open source

Output: краткий отчёт (технологии, best practices, риски)"
)

# Агент 2: Code Explorer
Agent(
  subagent_type: "Explore",
  description: "Анализ кодобазы",
  prompt: "Исследуй кодобазу для задачи: <ЗАДАЧА>

Что нужно:
1. Какие файлы/модули затронуты? (Glob/Grep)
2. Какие существующие паттерны можно переиспользовать?
3. Какие зависимости и constraints в коде?
4. Есть ли аналоги в проекте?
5. Архитектурные слои: где именно должен быть новый код?

Прочитай CLAUDE.md, RULES.MD для понимания архитектуры.
Output: scope, затронутые файлы, паттерны, constraints"
)

# Агент 3: Business Analyst
Agent(
  subagent_type: "analyst",
  description: "Анализ требований",
  prompt: "Проанализируй бизнес-требования задачи: <ЗАДАЧА>

Что нужно:
1. Какие user stories покрывает задача?
2. Acceptance criteria (конкретные входы → выходы)
3. Edge cases и boundary conditions
4. Что НЕ входит в scope (anti-requirements)
5. Если есть ADR/BACKLOG.md — проверь влияние

Output: requirements, acceptance criteria, edge cases, anti-scope"
)
```

**Собери результаты всех трёх.** Передай architect'у.

### Phase 2: Architecture & Planning

```
Agent(
  subagent_type: "architect",
  description: "Архитектура и план реализации",
  prompt: "Создай план реализации задачи: <ЗАДАЧА>

Результаты исследования:
- Tech Research: <РЕЗУЛЬТАТ АГЕНТА 1>
- Code Explorer: <РЕЗУЛЬТАТ АГЕНТА 2>
- Business Analyst: <РЕЗУЛЬТАТ АГЕНТА 3>

Правила (из RULES.MD — ОБЯЗАТЕЛЬНО):
- TDD: тесты ПЕРЕД кодом для новой business logic
- Contract-First: Protocol/ABC → contract-тесты → реализация
- Clean Architecture: domain не импортирует infrastructure
- SOLID: SRP (>300 строк = разделить), ISP (Protocol ≤5 методов), DIP
- Без заглушек: никаких TODO, pass, ..., псевдокода
- Coverage: общий 85%+, core 95%+, infrastructure 70%+

Требования к плану:
- Каждый этап 2-5 минут
- Точные файлы для каждого этапа
- DoD (SMART) для каждого этапа
- Тестовые сценарии (unit + integration)
- Команды проверки
- Edge cases
- Маркировка critical vs standard компонентов (влияет на Judge threshold)

НЕ сохраняй в .memory-bank/plans/ — просто верни план в ответе."
)
```

### Phase 2.5: Approval Gate

Покажи пользователю краткое резюме плана:
- Количество этапов
- Ключевые файлы
- DoD критерии
- Critical vs standard компоненты
- Estimated complexity

Спроси: **"Продолжить реализацию по этому плану?"**

Если пользователь одобрил → Phase 3.
Если нет → скорректируй план по замечаниям и покажи снова.

### Phase 3: Implementation

Для КАЖДОГО этапа из плана последовательно:

```
Agent(
  subagent_type: "developer",
  description: "Реализация этапа N",
  prompt: "Реализуй этап N плана: <ЗАДАЧА>

План этапа:
<ВСТАВЬ ЭТАП ИЗ ПЛАНА>

Контекст:
- Прочитай CLAUDE.md, RULES.MD
- Результаты предыдущих этапов: <описание что уже сделано>

Правила (из RULES.MD — ОБЯЗАТЕЛЬНО):
- TDD: тесты перед кодом
- Contract-First: Protocol → contract-тесты → реализация
- Clean Architecture: domain не импортирует infrastructure/interfaces
- SOLID: SRP, ISP (Protocol ≤5 методов), DIP (зависимость от Protocol)
- Без TODO/pass/placeholder — код copy-paste ready
- Mock только внешние границы

Антипаттерны из lessons.md (НЕ ПОВТОРЯТЬ):
<ВСТАВЬ КЛЮЧЕВЫЕ УРОКИ ИЗ lessons.md>

После завершения:
- Запусти тесты и lint
- Верни статус: DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT
- Покажи вывод тестов как доказательство

DoD этого этапа:
<ВСТАВЬ DoD ИЗ ПЛАНА>"
)
```

**Если developer вернул BLOCKED** → останови chain, сообщи пользователю.
**Если DONE_WITH_CONCERNS** → запиши concerns, продолжай.
**Если NEEDS_CONTEXT** → спроси пользователя, передай ответ developer'у.

### Phase 4: Testing + Judge Verification

После завершения ВСЕХ этапов — два параллельных агента:

```
# Агент 1: Tester
Agent(
  subagent_type: "tester",
  description: "Финальное тестирование",
  prompt: "Проведи финальное тестирование задачи: <ЗАДАЧА>

Что было реализовано:
<КРАТКОЕ ОПИСАНИЕ ВСЕХ ЭТАПОВ И ФАЙЛОВ>

Проверь:
1. Все тесты проходят
2. Coverage достаточный (общий 85%+, core 95%+, infrastructure 70%+)
3. Edge cases покрыты
4. Нет regression (полный test suite)
5. Integration между компонентами работает
6. Тестовые имена: test_<что>_<условие>_<результат>
7. Assert = бизнес-факт, не assert is not None
8. Mock только внешние границы, не >5 mock'ов

Вердикт: PASS / FAIL (с деталями)"
)

# Агент 2: Judge (SDD-стиль)
Agent(
  subagent_type: "judge",
  description: "Judge verification",
  prompt: "Ты — Judge. Оцени качество реализации задачи: <ЗАДАЧА>

Что было реализовано:
<КРАТКОЕ ОПИСАНИЕ ВСЕХ ЭТАПОВ И ФАЙЛОВ>

Оцени по шкале 1-5 каждый аспект:
1. Correctness — код делает то, что требует задача
2. Architecture — Clean Architecture, SOLID, слои
3. Test quality — Testing Trophy, coverage, contract tests
4. Code quality — DRY, KISS, YAGNI, нет placeholder'ов
5. Security — input validation, нет injection, нет hardcoded secrets

Правила оценки:
- 5.0 по всем = hallucination → автоматический reject
- Каждая оценка ОБЯЗАНА иметь конкретный пример из кода (файл:строка)
- Если не можешь оценить (нет кода) → оценка 0

Thresholds:
- Standard компоненты: средняя ≥ 4.0 → PASS
- Critical компоненты: средняя ≥ 4.5 → PASS
- Любой аспект < 3.0 → автоматический FAIL

Output: JSON {scores: {correctness: N, architecture: N, tests: N, code: N, security: N}, average: N, verdict: PASS/FAIL, details: [...]}"
)
```

**Обработка:**
- Tester FAIL → отправь проблемы developer'у для fix'а, повтори. Max 3 итерации.
- Judge FAIL → отправь low-score аспекты developer'у, повтори Judge. Max 3 итерации.
- Оба PASS → Phase 5.

### Phase 5: Code Review — 3 цикла с разным фокусом

**КРИТИЧНО:** Каждая реализация проходит минимум 3 полных цикла review.

**Цикл 1 — архитектура:**
```
Agent(
  subagent_type: "reviewer",
  description: "Review цикл 1: архитектура",
  prompt: "Проведи code review задачи (фокус: АРХИТЕКТУРА): <ЗАДАЧА>

Что было реализовано:
<КРАТКОЕ ОПИСАНИЕ ВСЕХ ЭТАПОВ И ФАЙЛОВ>

Judge score: <ВСТАВЬ SCORES ИЗ PHASE 4>

Фокус этого цикла:
1. Clean Architecture — direction of dependencies, domain не импортирует infrastructure
2. Bounded context isolation — нет прямых импортов между модулями
3. SOLID — SRP (>300 строк?), ISP (Protocol ≤5 методов?), DIP (зависимость от Protocol?)
4. Multi-tenancy — AccessContext в сервисах
5. Integration boundaries — SDK types не в domain/application

Вердикт: APPROVED / NEEDS_CHANGES (с конкретными файлами и строками)"
)
```

**Цикл 2 — edge cases и production wiring:**
```
Agent(
  subagent_type: "reviewer",
  description: "Review цикл 2: edge cases",
  prompt: "Проведи code review задачи (фокус: EDGE CASES и PRODUCTION): <ЗАДАЧА>

Фокус:
1. Error handling — fail-fast, явные ошибки, не глушить exceptions
2. Edge cases — boundary values, None/empty, concurrent access
3. Production wiring — DI в container/composition root, не hardcoded
4. No placeholders — никаких TODO, pass, ..., псевдокода
5. Security — нет injection, нет hardcoded secrets, input validation

Вердикт: APPROVED / NEEDS_CHANGES (с конкретными файлами и строками)"
)
```

**Цикл 3 — тесты и DRY/KISS:**
```
Agent(
  subagent_type: "reviewer",
  description: "Review цикл 3: тесты и DRY",
  prompt: "Проведи code review задачи (фокус: ТЕСТЫ и DRY/KISS/YAGNI): <ЗАДАЧА>

Фокус:
1. Testing Trophy — интеграционные > unit > e2e
2. Coverage — общий 85%+, core 95%+, infrastructure 70%+
3. Contract drift — тесты проверяют контракт, а не реализацию
4. Test quality — assert = бизнес-факт, @parametrize вместо копипасты
5. DRY — дублирование >2 раз → извлечь
6. KISS — нет over-engineering
7. YAGNI — нет кода 'на будущее'

Вердикт: APPROVED / NEEDS_CHANGES (с конкретными файлами и строками)"
)
```

### Обработка результатов review

Для каждого цикла:
- **Если NEEDS_CHANGES** → запусти developer agent для fix'а → повтори этот цикл review
- **Если APPROVED** → переходи к следующему циклу
- Max 3 попытки fix'а на один цикл. После 3 неудач → исправляй сам (ты orchestrator)

### Phase 5.5: Reflexion (NEW — из CEK)

После прохождения всех review циклов:

```
Agent(
  subagent_type: "general-purpose",
  description: "Reflexion: анализ процесса",
  prompt: "Проведи рефлексию по реализации задачи: <ЗАДАЧА>

Что произошло:
- Phase 1 (Research): <ключевые findings>
- Phase 3 (Implementation): <сколько этапов, какие проблемы>
- Phase 4 (Judge scores): <scores>
- Phase 5 (Review): <сколько NEEDS_CHANGES, какие проблемы повторялись>

Проанализируй:
1. Какие решения были удачными и почему?
2. Какие проблемы повторялись в review? Это паттерн?
3. Что можно было сделать лучше на этапе планирования?
4. Есть ли антипаттерн, который стоит добавить в lessons.md?

Output:
- learned_patterns: [...] — что сработало
- anti_patterns: [...] — что НЕ делать
- process_improvements: [...] — как улучшить pipeline
- lessons_md_update: string | null — если есть что добавить"
)
```

**Если `lessons_md_update` не null** → предложи обновить `.memory-bank/lessons.md`.

### Phase 6: DoD Gate + Finalization

**DoD gate:** сверь КАЖДЫЙ пункт DoD из плана с фактическим кодом:

1. Для каждого DoD-критерия найди конкретный код/тест (файл:строка)
2. Если хоть один DoD не закрыт → вернись к Phase 3 (developer) или исправь сам
3. Только когда все DoD закрыты фактами → финализация

Покажи пользователю итоговый отчёт:

```
## /implement — Результат

### Задача: <название>
### Статус: DONE / DONE_WITH_CONCERNS / NEEDS_FIXES

### Что сделано:
- Этап 1: <название> ✅
- Этап 2: <название> ✅
- ...

### Файлы создано/изменено:
- <список файлов>

### Тесты:
- Total: N, Passed: N, Failed: 0
- Coverage: X%

### Judge Scores:
- Correctness: X/5
- Architecture: X/5
- Test quality: X/5
- Code quality: X/5
- Security: X/5
- **Average: X/5** (threshold: Y)

### Review (3 цикла):
- Цикл 1 (архитектура): APPROVED
- Цикл 2 (edge cases): APPROVED
- Цикл 3 (тесты/DRY): APPROVED

### DoD:
- <критерий 1>: ✅ (файл:строка)
- <критерий 2>: ✅ (файл:строка)
- ...

### Reflexion:
- Patterns learned: N
- Anti-patterns found: N
- Lessons.md update: yes/no

### Concerns (если есть):
- ...
```

Спроси: **"Закоммитить изменения?"**

Если Memory Bank активен — после коммита предложи `/mb update` для актуализации checklist и progress.

---

## Правила chain'а

### Процесс
- **Параллельно где можно** — Phase 1 (3 researcher'а), Phase 4 (tester + judge)
- **Последовательно где зависимость** — plan → approval → dev → test → review
- **Контекст передаётся явно** — агенты не видят друг друга, всё через промт
- **Approval gate** — пользователь утверждает план перед реализацией
- **Evidence-based** — каждый статус подтверждён выводом команд и Judge scores
- **НЕ teammode** — через Agent tool (не TeamCreate/SendMessage)

### RULES.MD — обязательный стандарт
- ВСЯ работа chain'а ОБЯЗАНА следовать правилам из `RULES.MD`
- При передаче задач агентам — включай релевантные правила из RULES.MD в промпт
- Антипаттерны из `lessons.md` передавать каждому developer/tester агенту

### Review discipline
- **Минимум 3 цикла review** — архитектура, edge cases, тесты/DRY
- **Judge scores** — числовые оценки 1-5 для объективности
- **DoD gate** — после review сверить КАЖДЫЙ DoD с фактами кода
- **Max 3 fix iterations** на один цикл review → потом escalation

### Reflexion
- После review — анализ процесса и паттернов
- Полезные findings → lessons.md
- Улучшает качество будущих итераций

### Source of truth (если Memory Bank активен)
- Задачи и DoD из активного плана (`plans/<файл>.md`) имеют приоритет
- После завершения — предложить `/mb update`
- Ответы на русском, техтермины на английском
