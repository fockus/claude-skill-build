# claude-skill-build

Multi-agent build pipeline for Claude Code. Phase orchestration, quality gates, calibrated judge verification, team execution with parallel AI agents. Scales from one-line fixes to full autonomous multi-phase delivery.

## Architecture

Build is a three-layer system:

```
┌─────────────────────────────────────────────┐
│  Build Commands (/build:phase, /build:quick) │
├───────────┬───────────────┬─────────────────┤
│    GSD    │   Pipeline    │  Memory Bank    │
│ execution │  team mode    │ long-term memory│
│  engine   │ parallel agents│ project state  │
└───────────┴───────────────┴─────────────────┘
```

- **GSD** (Get Shit Done) — execution engine: planning, phase management, roadmaps, atomic commits
- **Pipeline** — team mode: parallel agent orchestration via Claude Code Team Mode
- **Memory Bank** — long-term project memory: STATUS, checklist, plans, research, lessons learned

Build commands orchestrate all three, adding quality gates (judge, reviewer, hooks) on top.

## Dependencies

| Dependency | Required | What it does | Install |
|-----------|----------|-------------|---------|
| [skill-memory-bank](https://github.com/fockus/skill-memory-bank) | **Yes** | Project memory, rules, CLAUDE.md generation | See below |
| [GSD](https://www.npmjs.com/package/get-shit-done-cc) | **Yes** | Execution engine (phases, plans, roadmaps) | Auto-installed by `install.sh` |
| [claude-skill-find-skill](https://github.com/fockus/claude-skill-find-skill) | No | Skill discovery and installation | See below |

### Install dependencies

```bash
# 1. Memory Bank (REQUIRED — install first)
git clone https://github.com/fockus/skill-memory-bank.git ~/.claude/skills/skill-memory-bank
cd ~/.claude/skills/skill-memory-bank && chmod +x install.sh uninstall.sh && ./install.sh

# 2. Find Skill (optional — skill discovery)
git clone https://github.com/fockus/claude-skill-find-skill.git ~/.claude/skills/claude-skill-find-skill
cd ~/.claude/skills/claude-skill-find-skill && chmod +x install.sh && ./install.sh
```

GSD is installed automatically during build installation (step 7).

## Install

```bash
git clone https://github.com/fockus/claude-skill-build.git ~/.claude/skills/claude-skill-build
cd ~/.claude/skills/claude-skill-build && chmod +x install.sh uninstall.sh update.sh && ./install.sh
```

### Install modes

```bash
./install.sh          # Interactive wizard
./install.sh --full   # Everything (recommended)
./install.sh --core   # Build + SDD only (no reflexion/kaizen/sadd/harness)
./install.sh --auto   # Full, non-interactive
```

### Update

```bash
~/.claude/skills/claude-skill-build/update.sh         # Pull + reinstall
~/.claude/skills/claude-skill-build/update.sh --core   # Pull + reinstall core only
```

## What gets installed

**Build pipeline — Claude Code only** (relies on Claude's subagent dispatch + hooks):

| Component | Count | Target |
|-----------|-------|--------|
| Core agents | 18 | `~/.claude/agents/` |
| Quality hooks | 9 | `~/.claude/hooks/` |
| Build commands | 9 | `~/.claude/commands/build/` |
| Pipeline commands | 2 | `~/.claude/commands/` |

**Bundled skills — multi-agent**: install.sh auto-detects Codex, OpenCode, Cursor and copies bundled skills to all of them (in addition to Claude Code). Pure markdown — works everywhere:

| Skill set | Count | Targets |
|-----------|-------|---------|
| SDD skills | 5 + build-sdd templates | `~/.claude/skills/`, `~/.codex/skills/`, `~/.config/opencode/skills/`, `~/.cursor/skills/` (always) |
| Reflexion | 3 | All detected agents (full mode) |
| Kaizen | 7 | All detected agents (full mode) |
| SADD | 10 | All detected agents (full mode) |
| Harness | 6 | All detected agents (full mode) |
| Breezing | 1 | All detected agents (full mode) |

**Why split?** `/build:phase` etc. dispatch parallel subagents (`judge`, `reviewer`, `architect`) and rely on PreToolUse hooks — features only Claude Code has. Bundled skills (SDD, kaizen, etc.) are just markdown and work in any agent that supports the `skills/` convention.

## Getting started

### 1. Set up project

```
# In Claude Code:
/mb init                # Initialize Memory Bank (if not exists)
/mb:setup-project       # Generate CLAUDE.md from project analysis
/build:init             # Initialize GSD + create roadmap + bridge to MB
```

### 2. Create `.pipeline.yaml`

Every project using build needs a `.pipeline.yaml` in the project root:

```yaml
project:
  name: my-project
  language: python  # or typescript, go, rust, etc.

commands:
  test: "pytest -q"
  lint: "ruff check ."
  typecheck: "mypy src"

context:
  loader: memory-bank
  plan_file: .memory-bank/plan.md
  checklist_file: .memory-bank/checklist.md

judge:
  standard_threshold: 4.0
  critical_threshold: 4.5
  panel_size: 1

model_tiering:
  developer: opus
  tester: opus
  architect: opus
  reviewer: opus
  judge: opus
```

See `/build:help` for the full `.pipeline.yaml` reference.

### 3. Start building

```
/build:phase 1          # Execute first phase (discuss → plan → execute → verify)
/build:status           # Dashboard: where are we, what's next
```

## Choose by scope

```
Task
  │
  ├─ Typo, 1-file fix
  │   └─ /build:fast "description"
  │
  ├─ Ad-hoc, 2-5 files, TDD
  │   └─ /build:quick "description"
  │       ├─ --discuss   (clarify gray areas first)
  │       ├─ --research  (explore approaches first)
  │       └─ --reflexion (self-critique after execution)
  │
  ├─ ROADMAP phase, 1-3 tasks
  │   └─ /build:phase N
  │       ├─ --sdd      (spec-driven: EARS requirements → design → verify)
  │       └─ --debate   (3 judges with debate for critical phases)
  │
  ├─ ROADMAP phase, 4+ tasks (parallel agents)
  │   └─ /build:team-phase N
  │
  ├─ All remaining phases (autopilot)
  │   └─ /build:autonomous-all
  │
  ├─ Single task, full chain
  │   └─ /implement "task"
  │       └─ research x3 → architect → dev → judge → review x3 → reflexion
  │
  ├─ Team pipeline by master plan
  │   └─ /pipeline
  │
  ├─ Code review
  │   └─ /build:review "scope" [--lite|--standard|--full] [--active]
  │
  └─ Where are we?
      └─ /build:status
```

## Phase lifecycle

```
/build:phase N

  Step 0: Load Context ─── MB (STATUS, checklist, plan) + GSD (STATE, ROADMAP)
     │
  Step 1: Discuss ──────── /gsd:discuss-phase N (skip with --skip-discuss)
     │
  Step 1.5: SDD Spec ───── requirements.md + design.md (only with --sdd)
     │
  Step 2: Plan ─────────── /gsd:plan-phase N
     │
  Step 3: Execute ──────── GSD executor (phase) or Pipeline team (team-phase)
     │
  Step 4: Judge Gate ───── Calibrated 1-5 scoring
     │                      score < 4.0 → retry (max 5)
     │                      score ≥ 4.0 → JUDGE_PASS.md
     │
  Step 5: Review ───────── Code review (LITE/STANDARD/FULL)
     │
  Step 6: Verify ───────── GSD verify + MB verify (skip with --skip-verify)
     │
  Step 7: Finalize ─────── MB sync (checklist, STATUS, progress) + commit
```

## Agents (18)

| Role | Purpose |
|------|---------|
| `judge` | Calibrated 1-5 scoring with weighted criteria, hallucination detection |
| `reviewer` | 11-section deep analysis (architecture, SOLID, contract drift, coverage) |
| `developer` | TDD implementation, Contract-First |
| `tester` | Test writing, coverage verification |
| `architect` | System design, decomposition, final audit |
| `planner` | Task breakdown with SMART DoD |
| `analyst` | Business requirements, specifications |
| `researcher` | Best practices, approach exploration |
| `critic` | Devil's advocate, alternative analysis |
| `debugger` | 4-phase root cause analysis |
| `designer` | UI/UX design, wireframes, design systems |
| `frontend` | React/Vue/Angular, responsive UI, accessibility |
| `mobile` | iOS/Android, React Native, Flutter |
| `security` | OWASP Top 10, vulnerability scanning |
| `explorer` | Codebase exploration, documentation generation |
| `documentor` | API reference, architecture docs |
| `integrator` | Branch merging, conflict resolution |
| `verifier` | DoD verification, contract checks, production wiring |

### Judge calibration

The judge uses weighted scoring derived from known-good/known-bad samples:

| Criterion | Weight |
|-----------|--------|
| Correctness | 0.30 |
| Architecture | 0.25 |
| Test Quality | 0.20 |
| Code Quality | 0.15 |
| Security | 0.10 |

Calibration data in `core/calibration/` — known-good samples (score >= 4.5) and known-bad samples (score < 4.0).

### Reviewer deep analysis (11 sections)

1. Architecture & design
2. Logic & correctness
3. Tests
4. Code quality & style
5. Error handling
6. Performance
7. Dead code & partial implementations
8. **Architecture compliance** — bounded contexts, dependency direction, import-linter
9. **Test coverage thresholds** — reads thresholds from project config, verifies critical paths
10. **SOLID compliance** — SRP (>300 LOC), ISP (>5 methods), DIP, OCP, LSP
11. **Contract drift detection** — Protocol vs implementation signature mismatches

## Quality hooks (9)

| Hook | Trigger | What it does |
|------|---------|--------------|
| `quality-gate.sh` | Every Write/Edit/Bash | AI residuals scan (TODO, FIXME, localhost, console.log), test tampering detection (BLOCK) |
| `judge-findings-gate.sh` | Bash (commit) | Blocks commit without JUDGE_PASS.md or with unresolved SERIOUS findings |
| `spec-verify.sh` | Manual | Verifies AC/EC from requirements.md have matching tests |
| `go-quality.sh` | Write/Edit .go files | Go linting (vet, staticcheck) |
| `py-quality.sh` | Write/Edit .py files | Python linting (ruff) |
| `build-deps-check.sh` | Session start | Verifies GSD, MB, pipeline config installed |
| `build-install-deps.sh` | Auto | Installs missing dependencies |
| `active-test.sh` | `/build:review --active` | Browser-based assertion testing via Playwright MCP |
| `arch-review.sh` | Write/Edit .py files | Architecture compliance: import-linter, SRP (>300 LOC), ISP (>5 methods) |

## Bundled skills (33)

### SDD (Spec-Driven Development) — always installed
- `/sdd-brainstorm` — ideation, explore alternatives before planning
- `/sdd-plan` — multi-agent spec planning (researcher + analyst + architect)
- `/sdd-implement` — implement from spec with LLM-as-Judge verification
- `/sdd-create-ideas` — generate ideas in one shot
- `/sdd-add-task` — add task to spec

### Reflexion — self-refinement (full mode)
- `/reflexion-critique` — multi-perspective review with debate between judges
- `/reflexion-reflect` — self-refinement of current solution
- `/reflexion-memorize` — capture learnings into CLAUDE.md

### Kaizen — root cause analysis (full mode)
- `/kaizen-why` — 5 Whys analysis
- `/kaizen-analyse-problem` — A3 one-page problem analysis
- `/kaizen-root-cause-tracing` — trace from error to root cause
- `/kaizen-cause-and-effect` — fishbone diagram
- `/kaizen-plan-do-check-act` — PDCA cycle
- `/kaizen-kaizen` — continuous improvement
- `/kaizen-analyse` — auto-select best analysis method

### SADD (Sub-Agent Driven Development) — full mode
- `/sadd-do-competitively` — competitive generation + LLM-as-Judge
- `/sadd-tree-of-thoughts` — Tree of Thoughts for complex decisions
- `/sadd-do-in-parallel` — parallel agent execution
- `/sadd-do-in-steps` — sequential pipeline
- `/sadd-judge` — LLM judge evaluation
- `/sadd-judge-with-debate` — judge with multi-round debate
- `/sadd-launch-sub-agent` — launch sub-agent with auto model selection
- `/sadd-do-and-judge` — execute + judge with retry
- `/sadd-multi-agent-patterns` — architecture patterns reference
- `/sadd-subagent-driven-development` — full SADD workflow

### Harness — release management (full mode)
- `/harness-plan` — structured planning with Plans.md
- `/harness-work` — auto-mode execution (solo / parallel / breezing)
- `/harness-review` — 4-perspective review (security + perf + quality + a11y)
- `/harness-release` — SemVer bump + CHANGELOG + GitHub Release + git tag
- `/harness-setup` — project setup
- `/harness-sync` — sync Plans.md with implementation progress

### Breezing — team execution mode (full mode)
- Fast-track team coordination alias for `/harness-work`

## Memory Bank integration

Build deeply integrates with Memory Bank for cross-session project continuity:

```
Session start:  /mb start → load STATUS, checklist, plan, RESEARCH
During work:    checklist.md updated on each task completion
                STATUS.md updated on milestones
Phase end:      /mb verify → /mb done → progress.md append
```

Key MB commands used by build:
- `/mb init` — initialize Memory Bank in project
- `/mb start` — load context at session start
- `/mb update` — sync core files (checklist, plan, STATUS)
- `/mb verify` — verify plan vs implementation
- `/mb done` — end-of-session sync (checklist + progress + note)

## GSD integration

Build wraps GSD commands with quality gates and MB sync:

| Build command | Wraps GSD | Adds |
|--------------|-----------|------|
| `/build:fast` | `/gsd:fast` | MB checklist sync |
| `/build:quick` | `/gsd:quick` | Rules injection, MB sync, optional reflexion |
| `/build:phase N` | `/gsd:discuss-phase` → `/gsd:plan-phase` → `/gsd:execute-phase` | Judge gate, review, MB sync |
| `/build:team-phase N` | Same as phase | Pipeline team mode, model tiering |
| `/build:autonomous-all` | All remaining phases | Audit before/after, MB sync |
| `/build:init` | `/gsd:new-project` | MB bridge, hook verification |
| `/build:status` | `/gsd:progress` | MB context, deps health |

## Model policy

All agents run on **Opus** by default (1M context). Override per role in `.pipeline.yaml`:

```yaml
model_tiering:
  developer: opus    # default and recommended
  tester: opus
  architect: opus    # always opus
  reviewer: opus
  judge: opus
```

## Typical scenarios

**New project:**
```
/mb init → /mb:setup-project → /build:init → /build:phase 1
```

**Continue work:**
```
/build:status → /build:phase N
```

**Autopilot:**
```
/build:autonomous-all --max-phases 5
```

**Quick fix outside roadmap:**
```
/build:quick "add health check endpoint"
```

**Critical bug:**
```
/build:fast "fix NPE in UserService.get_by_id"
```

**Debug with root cause:**
```
/kaizen-why → /gsd:debug
```

**Release:**
```
/harness-release patch|minor|major
```

## Troubleshooting

| Problem | Solution |
|---------|---------|
| "`.pipeline.yaml` not found" | Create from template above or see `/build:help` |
| "`.planning/` does not exist" | Run `/build:init` |
| "`.memory-bank/` does not exist" | Run `/mb init` |
| Gate RED after execution | Fix manually or `/gsd:execute-phase N --gaps-only` |
| Judge score < 4.0 on retry | Check `core/calibration/` for scoring reference |
| Hook blocks commit | Fix SERIOUS findings in JUDGE_PASS.md first |

## Uninstall

```bash
cd ~/.claude/skills/claude-skill-build && ./uninstall.sh
```

## License

MIT
