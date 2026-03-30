# claude-skill-build

Multi-agent build pipeline for Claude Code. Phase orchestration, quality gates, judge verification, team execution with parallel AI agents. Scales from one-line fixes to full autonomous multi-phase delivery.

## Prerequisites

```bash
# Required: Memory Bank skill
git clone https://github.com/fockus/claude-skill-memory-bank.git ~/.claude/skills/claude-skill-memory-bank
cd ~/.claude/skills/claude-skill-memory-bank && chmod +x install.sh uninstall.sh && ./install.sh
```

## Install

```bash
git clone https://github.com/fockus/claude-skill-build.git ~/.claude/skills/claude-skill-build
cd ~/.claude/skills/claude-skill-build && chmod +x install.sh uninstall.sh && ./install.sh
```

### Install Modes

```bash
./install.sh          # Interactive wizard
./install.sh --full   # Everything (recommended)
./install.sh --core   # Build + SDD only (no reflexion/kaizen/sadd/harness)
./install.sh --auto   # Full, non-interactive
```

## What Gets Installed

| Component | Count | Description |
|-----------|-------|-------------|
| Build commands | 9 | `/build:fast` through `/build:autonomous-all` |
| Pipeline commands | 2 | `/pipeline`, `/implement` |
| Core agents | 18 | judge, reviewer, developer, tester, architect, etc. |
| Quality hooks | 7 | quality-gate, judge-findings-gate, spec-verify, etc. |
| SDD skills | 5 | Spec-Driven Development (always installed) |
| Reflexion skills | 3 | Self-refinement and critique |
| Kaizen skills | 7 | Root cause analysis |
| SADD skills | 10 | Sub-Agent Driven Development |
| Harness skills | 6 | Release management |
| Breezing | 1 | Fast-track workflow |

## Quick Start

```
# In Claude Code:
/mb:setup-project       # Init memory bank + CLAUDE.md
/build:init             # Init GSD + roadmap
/build:phase 1          # Execute first phase
```

## Commands — Choose by Scope

```
Typo, 1 file fix              → /build:fast "description"
Ad-hoc with TDD, 2-5 files    → /build:quick "description"
Phase, 1-3 tasks               → /build:phase N
Phase, 4+ tasks (parallel)     → /build:team-phase N
All remaining phases            → /build:autonomous-all
Full chain for one task         → /implement "task"
Team pipeline by master plan    → /pipeline
Code review                     → /build:review "scope"
Dashboard                       → /build:status
Help                            → /build:help
```

## Pipeline Flow

```
/build:phase N executes:

  Plan → Team Compose → Execute → Test → Judge Gate → Review → Reflexion
                                           │
                                    score < 4.0 → retry (max 5)
                                    score ≥ 4.0 → JUDGE_PASS.md → commit
```

## Agents (18)

| Role | Purpose |
|------|---------|
| `judge` | Calibrated 1-5 scoring, hallucination detection |
| `reviewer` | Multi-perspective code review |
| `developer` | TDD implementation |
| `tester` | Test writing, coverage verification |
| `architect` | System design, decomposition |
| `planner` | Task breakdown with SMART DoD |
| `analyst` | Business requirements, specifications |
| `researcher` | Best practices, approach exploration |
| `critic` | Devil's advocate, alternative analysis |
| `debugger` | 4-phase root cause analysis |
| `designer` | UI/UX design, wireframes |
| `frontend` | React/Vue/Angular, responsive UI |
| `mobile` | iOS/Android, React Native, Flutter |
| `security` | OWASP Top 10, vulnerability scanning |
| `explorer` | Codebase exploration, documentation |
| `documentor` | API reference, architecture docs |
| `integrator` | Branch merging, conflict resolution |
| `verifier` | DoD verification, contract checks |

## Quality Hooks

| Hook | Trigger | What it does |
|------|---------|--------------|
| `quality-gate.sh` | Every Write/Edit/Bash | AI residuals scan, test tampering detection |
| `judge-findings-gate.sh` | Bash (commit) | Blocks commit without JUDGE_PASS.md |
| `spec-verify.sh` | Manual | Verifies AC/EC coverage in tests |
| `go-quality.sh` | Write/Edit .go files | Go linting (vet, staticcheck) |
| `py-quality.sh` | Write/Edit .py files | Python linting (ruff) |
| `build-deps-check.sh` | Session start | Verifies dependencies installed |
| `build-install-deps.sh` | Auto | Installs missing deps |

## Bundled Skills

### SDD (Spec-Driven Development) — always installed
- `/sdd-brainstorm` — ideation, explore alternatives
- `/sdd-plan` — multi-agent spec planning
- `/sdd-implement` — implement from spec
- `/sdd-create-ideas` — generate ideas
- `/sdd-add-task` — add task to spec

### Reflexion — self-refinement (optional)
- `/reflexion-critique` — multi-perspective review with debate
- `/reflexion-reflect` — self-refinement of current solution
- `/reflexion-memorize` — capture learnings

### Kaizen — root cause analysis (optional)
- `/kaizen-why` — 5 Whys analysis
- `/kaizen-analyse-problem` — A3 one-page problem analysis
- `/kaizen-root-cause-tracing` — trace to root cause
- `/kaizen-cause-and-effect` — cause-and-effect diagram
- `/kaizen-plan-do-check-act` — PDCA cycle
- `/kaizen-kaizen` — continuous improvement
- `/kaizen-analyse` — structured analysis

### SADD (Sub-Agent Driven Development) — optional
- `/sadd-do-competitively` — competitive generation + LLM-as-Judge
- `/sadd-tree-of-thoughts` — Tree of Thoughts for complex decisions
- `/sadd-do-in-parallel` — parallel agent execution
- `/sadd-do-in-steps` — sequential pipeline
- `/sadd-judge` — LLM judge evaluation
- `/sadd-judge-with-debate` — judge with debate
- `/sadd-launch-sub-agent` — launch sub-agent
- `/sadd-do-and-judge` — execute + judge
- `/sadd-multi-agent-patterns` — patterns reference
- `/sadd-subagent-driven-development` — full SADD workflow

### Harness — release management (optional)
- `/harness-plan` — structured planning
- `/harness-work` — auto-mode execution (solo/parallel/breezing)
- `/harness-review` — 4-perspective review
- `/harness-release` — SemVer bump + CHANGELOG + GitHub Release
- `/harness-setup` — project setup
- `/harness-sync` — sync state

### Breezing — fast-track (optional)
- Quick execution mode for rapid iteration

## Uninstall

```bash
cd ~/.claude/skills/claude-skill-build && ./uninstall.sh
```

## License

MIT
