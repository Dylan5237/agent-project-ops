---
name: Command Center
about: 项目指挥中心 — single index, roster, and policy for Agent-owned ops
title: "[Command Center] Project control plane"
labels: "type:command-center, status:in-progress"
---

## 1. 一眼状态

<!-- Agent: this table is the fixed status format (PRINCIPLES.md §12). Rewrite it in the same turn as every gate flip / phase status / freeze / blocked / verification / decision request / reply. Agent duty, not a user habit. Field meaning: current work, status word, pending decisions, last closed work, blockers, single next action, latest apo-tidy line. If it cannot be updated → `BLOCKED:` on GitHub. -->

| 项目 | 现在 |
| --- | --- |
| **当前工作** | #编号 + 一句话 |
| **状态** | 未开工 / 进行中 / 卡住 / 待验收 / 已完成 |
| **待你决定** | 无，或 `D-n`（类型）+ 链接 |
| **最近完成** | — |
| **卡点** | 无，或缺什么 |
| **下一步**（只写一件） | |
| **收尾检查** | 最新 `apo-tidy:` 行 |

更新于 YYYY-MM-DD。聊天里说的不算状态，以这里为准。

## 目的 / Purpose

Canonical **control plane** for this business repository. Chat is not state. Methodology: {{METHODOLOGY_URL}} (PIN {{METHODOLOGY_SHA}}, ref {{METHODOLOGY_REF}}).

## Methodology binding

- PIN URL:
- PIN SHA:
- PIN ref/date:
- Root binding files present: yes / no

## Project settings / 项目设置

Chosen by the disposer at initialization; changing them later is `PRINCIPLES.md` §11 item 7.

- Process mode / 流程档位: `standard` / `light` (`process_mode` in `.agent-project-ops/project-config`; unrecorded = `standard`)
- Agent tools / Agent 工具:
- External tools / 外部工具: none

## Disposer / 拍板人

- Handle:
- Decides (`PRINCIPLES.md` §1): start confirmations for §11 hits, final acceptance, exceptions — nothing else
- Replies to fixed-format requests with `批准 A` / `改用 B` / `退回：<原因>` (legacy `FREEZE ACK` / `PHASE ACCEPT` / `EXCEPTION ACCEPT` still count)
- Distinct GitHub identity from day-to-day Agent credentials?: yes / no / unknown

## Lead Agent / 主 Agent

- Agent id:
- GitHub identity used for git/PR operations (if known):
- May push directly to `main`: no
- May merge task PRs after required checks: **yes** (a merge that releases or deploys is §11 item 4)
- May accept: tasks implemented by other Agents; **never** its own work, a Phase or a release

## Roster

| Role | Handle / Agent | Notes |
| --- | --- | --- |
| Disposer | | |
| Lead Agent | | |
| Executing Agent(s) | | |
| Reviewer (optional) | | |

## Git authority / remotes

- Default branch: (read from the real GitHub repository; do not assume `main` for adopted projects)
- Authority remote: `origin`
- Projection remote(s): `(none)` or names — **same-history** FF mirror only
- Export remote(s): `(none)` or names — **export** = `authority − strip list`; not a second write authority; not on the auto-push whitelist
- Colleague-share GitLab: **export** (`scripts/export-sync.sh`) or **share-export** snapshot (`scripts/share-export.sh`). Not a projection; bound-clone push denied.
- `.agent-project-ops/remotes` matches the lines above: yes / no / n/a
- Unknown extra remotes: **BLOCKED until classified**
- Branch names: `feat|fix|docs|evidence/{issue}-{slug}`
- Worktrees: `{repo}/.worktrees/{issue-or-phase}-{owner}-{slug}`
- Direct push to default branch: **forbidden**

## Protection capability

Record what was actually verified, not what was requested:

- Capability: **A / B / C**
  - A = PR + code-owner/independent review gate verified
  - B = PR-only; no independent-human-review guarantee
  - C = unprotected or protection could not be verified. On GitHub Free **private** this is **expected**. Record C and continue. Do not claim B/A. Do not treat C as init failure. Optional Pro/public when a real server gate is required.
- Force push disabled: yes / no / unknown
- Default-branch deletion disabled: yes / no / unknown
- Notes / plan limitation:

If Agent and disposer use the same GitHub identity, GitHub cannot distinguish human from Agent actions; do not describe CODEOWNERS as a human-vs-Agent security boundary in that configuration.

## Hook state for this clone

- `git config --get core.hooksPath` = `.githooks`: yes / no
- If this was a fresh clone and value was missing, installer run: yes / no / n/a

## Phase index

| Phase issue | Core problem (one sentence) | Status | Result |
| --- | --- | --- | --- |
| # | | backlog | |

## Open exceptions / blocks

| Issue / block | Phase | Status |
| --- | --- | --- |
| | | |

## Adopt notes

- Binding path: root `AGENTS.md` → pinned `.agent-project-ops/PRINCIPLES.md`
- Relevant project skills: `.agents/skills/*/SKILL.md`
- Projection operations require `git-authority-and-projection` before non-origin push.
- Colleague GitLab requires `export-remote` (ADR 0005) or `share-export` (ADR 0003); never full-tree mirror of ops bindings; never a second write authority.
