# ADR 0007 — Generic review gates are provider-neutral

- **Status:** Proposed; Phase #65 pending disposer Accept
- **Date:** 2026-10-10
- **Related:** [#56](https://github.com/Dylan5237/agent-project-ops/issues/56), [#57](https://github.com/Dylan5237/agent-project-ops/issues/57), [#65](https://github.com/Dylan5237/agent-project-ops/issues/65)
- **Supersedes when accepted:** vendor-specific review wake requirement from historical [Issue #44](https://github.com/Dylan5237/agent-project-ops/issues/44), without altering its record

## Decision rationale

A generic Agent project workflow should evaluate actual GitHub CI, code review and Phase acceptance. It should not require a comment to wake one vendor's review service or grant exemptions to one repository.

## Proposed behavior

Before asking for merge, inspect mandatory CI/reviewer conditions for the actual PR SHA, report missing or failed checks, and honor separate project-specific review rules where explicitly configured. No generic vendor bot dependency is created. Neither check success nor merge constitutes `PHASE ACCEPT`.

Old pinned snapshots continue using their existing policy until their disposer authorizes an explicit upgrade. No external service or account configuration is changed by this ADR.
