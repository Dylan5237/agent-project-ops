---
name: Command Center
about: 项目指挥中心 — single index, roster, and policy for Agent-owned ops
title: "[Command Center] Project control plane"
labels: "type:command-center, status:in-progress"
---

## 目的 / Purpose

Canonical **control plane** for this **business** repository. Chat is not state. Methodology: https://github.com/Dylan5237/agent-project-ops (`PRINCIPLES.md` v0.1.1). If a snapshot exists, pin it below — do not float an unrecorded `main`.

## Disposer / 拍板人

- Handle:
- May `FREEZE ACK` / `PHASE ACCEPT` / `EXCEPTION ACCEPT`: **yes**

## Project-ops Agent / 日常 Owner（仍为 propose）

- Agent id:
- May merge to `main`: no
- May self-Accept phases: **no** (unless explicitly listed as disposer above)

## Roster

| Role | Handle / Agent | Notes |
| --- | --- | --- |
| Disposer | | |
| Implementer | | |
| Reviewer | | |

## Git policy

- Default branch: `main`
- Remote: **origin only** (default). Optional `projection` remote: mirror/FF from origin only; never a topic-push target (`playbooks/git-authority-and-projection.md`)
- Branch names: `feat|fix|docs|evidence/{issue}-{slug}`
- Worktrees: `{repo}/.worktrees/{issue-or-phase}-{owner}-{slug}`
- Direct push to default branch: **forbidden**

## Phase index

| Phase issue | Core problem (one sentence) | Status | Result |
| --- | --- | --- | --- |
| # | | backlog | |

## Open exceptions

| Exception issue | Phase | Status |
| --- | --- | --- |
| | | |

## Methodology pin

- Snapshot path: `.agent-project-ops/` (or n/a — load from URL only)
- PIN url / sha / ref: (copy from `.agent-project-ops/PIN`)
- Binding present?: `AGENTS.md` / `.agents/skills/` / `.cursor/rules/` — yes / no

## Adopt notes

- Skills to load: `.agents/skills/` wrappers → `.agent-project-ops/skills/`, or `skills/*/SKILL.md` in agent-project-ops
- Templates copied into `.github/`?: yes / no
