# ADR 0004 — Free-private capability C is expected (record and continue)

- **Status:** Accepted
- **Date:** 2026-09-22
- **Deciders:** disposer `@Dylan5237` `FREEZE ACK` on Phase [#36](https://github.com/Dylan5237/agent-project-ops/issues/36) (2026-09-22); Command Center [#10](https://github.com/Dylan5237/agent-project-ops/issues/10) §1
- **Implements:** Phase [#36](https://github.com/Dylan5237/agent-project-ops/issues/36)
- **Identity:** Methodology protection-reporting policy only. No business SOP.

---

## Context

Bootstrap attempts to enable GitHub branch protection and reports the **observed** capability:

| Level | Meaning |
| --- | --- |
| **A** | PR + independently enforceable reviewer / code-owner gate verified |
| **B** | PR-only; no independent-human-review guarantee |
| **C** | requested protection could not be enabled or verified |

GitHub Free **private** repositories commonly cannot enable the protection this methodology requests. Older bootstrap wording treated that **C** as a hard init failure (“BLOCKED”, “do not start feature work”). Agents then stopped after a successful repo create, or asked the disposer to buy Pro, just to finish bootstrap.

Honesty and “do not start work” were glued together. They are different rules.

## Decision

Keep A/B/C **honest**. Change the **C posture**:

1. **Attempt** to enable the requested protection. Report the observed letter.
2. **Never claim B or A** when only C was verified. Wording cannot upgrade capability.
3. **C is not a hard bootstrap stop.** After the repository exists, warn, record C on Command Center, and continue with client hooks + PR discipline. Do not abort the scaffold as “init failed.”
4. **GitHub Free private → expected C.** Agents must not treat every Free-private C as an accident. The disposer need not buy Pro to finish init.
5. **Public or Pro** remains optional when a real server-side gate is required. That is an upgrade path, not an init prerequisite.
6. Fail closed stays in force for **false claims**, missing Freeze, unknown remotes, and skipped Fleet REGISTRY — not for recording an honest C.

This supersedes the operational reading of RFC 0001 §7 that “C = BLOCKED means stop all work.” The capability letters themselves do not change.

## Consequences

- Command Center templates, bootstrap skill/playbook, Getting Started, and `scripts/bootstrap-project.sh` say **record C and continue**.
- Script exit after a created repo is **success with a warning** when capability is C, not `exit 2`.
- Merge still ≠ Phase PASS. Chat still ≠ state.
- A project on C has no server-side default-branch gate. Hooks remain bypassable. Do not describe that environment as protected.
