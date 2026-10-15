---
name: Architecture Exception
about: 已冻结的合同要改，且命中大改动清单、超出已确认目标或放宽验收标准时使用
title: "[Exception] "
labels: "type:exception, status:backlog"
---

## Linked Phase

- Phase issue #:
- Freeze comment URL / date:

## Why fail closed / 为何不能继续实现

<!-- Missing knowledge, contradiction, unsafe assumption, blocked integration, etc. -->

## Frozen text (current)

```text

```

## Proposed text (new freeze)

```text

```

## Impact on in-flight work

- PRs to close / retarget:
- Worktrees:
- Split into a new Phase instead?: yes / no

## Decision

Post the request on this issue with `.agent-project-ops/templates/decision-request.md` (methodology repository: `templates/decision-request.md`), type `例外`. The disposer replies:

- [ ] `批准 A` (legacy `EXCEPTION ACCEPT`) → new `CONTRACT FREEZE` on the Phase
- [ ] `改用 B` → adjust as chosen, then new `CONTRACT FREEZE`
- [ ] `退回：<原因>` (legacy `EXCEPTION REJECT`) — keep the original freeze

Agents propose only and never answer their own request.
