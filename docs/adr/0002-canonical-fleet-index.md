# ADR 0002 — Canonical fleet index (git SoT + box mirror)

- **Status:** Accepted
- **Date:** 2026-09-20
- **Deciders:** disposer `@Dylan5237` on [#26](https://github.com/Dylan5237/agent-project-ops/issues/26)
- **Implements:** Phase [#27](https://github.com/Dylan5237/agent-project-ops/issues/27) (`FREEZE ACK`); ops [#24](https://github.com/Dylan5237/agent-project-ops/issues/24), [#25](https://github.com/Dylan5237/agent-project-ops/issues/25)
- **Identity:** Methodology ops index only. Rows are `owner/repo` + Command Center pointers, not business SOP.

---

## Context

Agent 舰队晨报 scanned a box-only file:

`/home/box/agent-data/fleet-morning-digest/REGISTRY.md`

That copy is usable on one host, but it is not git, not reviewable, and other Agents cannot discover it. Bootstrap could finish a project that never appeared in the digest.

Issue #26 asked which store is canonical:

1. Git file in this repo (`fleet/REGISTRY.md`), updated by bootstrap/ops PRs
2. Long-lived GitHub Issue as the fleet index
3. Both: git file as source of truth + box file as a runtime mirror

## Decision

**Option 3 — git source of truth + box mirror.**

| Role | Location |
| --- | --- |
| **SoT** | [`fleet/REGISTRY.md`](../../fleet/REGISTRY.md) in `Dylan5237/agent-project-ops` |
| **Mirror** | `/home/box/agent-data/fleet-morning-digest/REGISTRY.md` (Agent 舰队晨报 runtime) |
| **Upsert key** | `owner/repo` (idempotent; one row per repository) |

Rejected for SoT: long-lived Issue-as-index (harder idempotent upsert and review trail). The box path is **not** a second write authority (Principle 10). Drift between SoT and mirror is **fail closed / blocked**, not “chat said it is fine.”

This file is a **project index**, not domain documentation: name, `owner/repo`, Command Center issue, short ops note. Product SOP stays out of this repository (Principle 7). The box path is a named digest-bot mirror, not a product host.

## How writes happen

1. After a project has a GitHub `origin` and a Command Center issue, the bootstrap/project-ops Agent **upserts** one row in `fleet/REGISTRY.md` on a PR to this repository (label `pr:implementation` or the bootstrap/ops PR for that work).
2. Same `owner/repo` → update the existing row; never append a duplicate.
3. Confirm the box mirror matches the SoT tip the digest bot is expected to read. If the Agent cannot write the box path, it still lands the git row and reports `BLOCKED:` on GitHub for the mirror gap — not chat-only.
4. Confirm to the disposer: **「已纳入舰队晨报扫描」**.
5. Bootstrap is **not done** until the git row exists (or an open PR that adds it is linked from the business Command Center). Skipping the register step fails closed.

Morning digest **only** scans rows in this table. Unlisted repos are out of scan unless the disposer explicitly adds them.

## Command Center §1 (companion duty)

Fleet scan reads **Command Center section 1** plus the current Phase status label. A registered row with a stale §1 looks “all green” and is false.

Keeping CC §1 current is a **mandatory Agent duty** on every gate flip / phase status / Freeze / blocked / verification event — not a user habit. See `skills/github-multi-agent-project-ops` and `playbooks/phase-lifecycle.md`. Chat only pings humans to look at GitHub.

## Migration

Seed `fleet/REGISTRY.md` from the 2026-09-20 box REGISTRY (same columns and rows; no silent drops). After this ADR lands:

1. SoT is the git file on the authority default branch (after merge; merge is still not Phase PASS).
2. Box file becomes a mirror of that SoT.
3. Subsequent upserts go to git first, then the mirror.

## Consequences

- Bootstrap and start-project checklists cannot be marked done without a Fleet REGISTRY row.
- Agents that cannot update GitHub Command Center §1 report `status:blocked` on GitHub.
- Digest-bot skill copies on the box are **out of scope** for Phase #27 (follow-up after merge; do not treat box skill text as SoT).

## Non-goals

- Full dashboard UI
- Scanning all of GitHub without a registry
- README showcase (#15) or audit-debt closeout (#14)
- Making a long-lived Issue the SoT
