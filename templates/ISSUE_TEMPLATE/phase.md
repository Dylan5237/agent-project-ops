---
name: Phase
about: 一个阶段只解决一个核心问题 — 先冻结合同，命中大改动清单才等你确认
title: "[Phase] "
labels: "type:phase, status:backlog"
---

## Core problem / 核心问题（仅一个）

<!-- One sentence. If you need two, open two phases. -->

## NON-GOALS / 非目标

-

## Owner (executing Agent)

-

## Freeze contract / 待冻结

### In scope

-

### Interfaces / data contracts

-

### Acceptance tests / 验收口径（可复验）

1.
2.

### Risks

-

## Freeze log

- [ ] Contract written in this body
- [ ] `CONTRACT FREEZE` + date, with `大改动检查：无` or `大改动检查：命中第 N 条` (`PRINCIPLES.md` §11)
- [ ] On a hit: start confirmation approved (link to the disposer's reply; legacy `FREEZE ACK` counts)
- [ ] No `feat/`/`fix/` branch before the above
- [ ] **CC §1 updated** on this Freeze / status change

## Control-plane hygiene

On every gate flip / phase status / Freeze / blocked / verification: update Command Center **section 1** and this Phase status label in the same turn. Agent duty, not user habit. If CC cannot be updated → `BLOCKED:` on GitHub.

- [ ] **CC §1 updated**

## Implementation links

- Working directory (primary checkout or `.worktrees/…`):
- Branch:
- PRs:

## Verification

- Evidence PR or proof comment:
- Repo tidy before the request (`apo-tidy:` line):
- Final-acceptance request (`D-n`, link):
- Disposer reply: `批准 A` / `改用 B` / `退回：<原因>` (legacy `PHASE ACCEPT` / `PHASE RETURN`)

## Notes

<!-- Paste chat decisions here. Chat ≠ state. -->
