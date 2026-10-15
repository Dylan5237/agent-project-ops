---
name: issues-prs-and-evidence
description: >
  Keep GitHub Issues as canonical state, use status labels, split implementation
  PRs from evidence PRs, and fail closed when blocked or the freeze must change.
  Use when filing phases, Command Center, Architecture Exception, verification,
  or PR templates.
---

# Issues, PRs, and evidence

**Chat ≠ state.** If it is not on the Issue, PR, or git object, it did not happen.

## Playbooks

- [playbooks/issues-and-prs.md](../../playbooks/issues-and-prs.md)
- [playbooks/verification-and-evidence.md](../../playbooks/verification-and-evidence.md)
- [playbooks/blocked-and-exceptions.md](../../playbooks/blocked-and-exceptions.md)
- Templates: [templates/](../../templates/) · Labels: [templates/labels.md](../../templates/labels.md)

## Status (exactly one per issue)

`status:backlog` | `status:in-progress` | `status:blocked` | `status:verification` | `status:done`

## PR split (Principle 9)

| PR kind | Branch prefix | Template | Contains |
| --- | --- | --- | --- |
| Implementation | `feat/` `fix/` `docs/` | `templates/PULL_REQUEST_TEMPLATE/implementation.md` | product/library/test **code** |
| Evidence | `evidence/` | `templates/PULL_REQUEST_TEMPLATE/evidence.md` | replayable proofs only |

PR merge ≠ Phase PASS. The lead Agent posts one final-acceptance request ([templates/decision-request.md](../../templates/decision-request.md)); the disposer's reply (or legacy `PHASE ACCEPT`) is the PASS.

## Agent checklist

1. Link every branch to an Issue. Empty issue bodies are invalid.
2. Copy the freeze text, its `大改动检查` line and (on a §11 hit) the start-confirmation link into the implementation PR.
3. Map each frozen acceptance test → proof (table).
4. On gaps: `BLOCKED:` comment + `status:blocked`.
5. Frozen field wrong → if the change hits §11, goes beyond the confirmed goal or loosens a confirmed acceptance test: exception issue + request (type `例外`); otherwise a new `CONTRACT FREEZE` with a one-line diff note. Never edit-and-continue silently.
6. Redact secrets from logs.
7. On every status/gate flip: update Command Center **section 1** and the Phase status label. [ ] **CC §1 updated**. Cannot edit CC → `BLOCKED:` on GitHub, not chat-only.
8. Before asking for merge/review, check required CI and reviewer conditions for the current PR SHA and record missing or pending checks. No vendor-specific bot is assumed. A passing review is not `PHASE ACCEPT`.

Do not add a second control plane (chat logs, unofficial boards) as a substitute.
