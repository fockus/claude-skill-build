# Claude Skill Build

Build pipeline: multi-agent phase orchestration with quality gates.

**Requires:** skill-memory-bank (rules, commands, project memory).

## Build Commands

| Command | When |
|---------|------|
| `/build:fast "desc"` | Typo, 1-file fix |
| `/build:quick "desc"` | Ad-hoc, 2-5 files, TDD |
| `/build:phase N` | ROADMAP phase, 1-3 tasks |
| `/build:team-phase N` | ROADMAP phase, 4+ tasks (parallel agents) |
| `/build:autonomous-all` | All remaining phases |
| `/build:review "scope"` | Code review (LITE/STANDARD/FULL) |
| `/build:init` | Init GSD + bridge to Memory Bank |
| `/build:help` | All build commands reference |
| `/build:status` | Dashboard |

## Pipeline Commands

| Command | When |
|---------|------|
| `/pipeline` | Team Pipeline v2 — parallel agents per master plan |
| `/implement "task"` | Full chain: research → architect → dev → judge → review |

## Bundled Skills

SDD, Reflexion, Kaizen, SADD, Harness — always available when build is installed.
