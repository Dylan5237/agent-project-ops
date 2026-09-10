# RFC 0001 hardening contract — post-audit merge gates

Status: **Binding amendment while RFC 0001 remains Proposed**  
Date: 2026-09-10  
Evidence: `docs/research/2026-09-10-methodology-audit.md` (merged via PR #5)  
Tracking: Issue #4

This file narrows RFC 0001 after the independent audit. If this contract conflicts with an implementation detail or an older acceptance example in RFC 0001, **this contract wins until RFC 0001 is consolidated**. It does not change Principle 10.

## 1. Supported claim

The MVP may claim:

> A local Agent that can already reach `agent-project-ops` can scaffold a generic repository with durable in-repo bindings for supported coding Agents, GitHub as the single write authority, and an optional projection remote.

It must **not** claim that an arbitrary or malicious AI is guaranteed to obey the methodology. Prompt/rule files are context. Client hooks are bypassable. Server-side repository policy is the strongest available control in this design.

## 2. Enforcement model

Controls are intentionally layered:

1. **Binding** (`AGENTS.md`, tool-specific rule files, skill wrappers): tells cooperating Agents what the rules are.
2. **Client hook**: catches common accidental pushes; it is a seatbelt, not a security boundary.
3. **Server policy**: protects authority history independently of local hook installation where the hosting plan and permissions support it.

No layer may be reported as stronger than it actually is.

## 3. Merge blockers for enforcement

Before the enforcement implementation may merge, automated behavior tests must prove at least:

| Case | Required result |
| --- | --- |
| topic → registered authority (`origin`) | ALLOW |
| first authority default-branch publish during bootstrap | ALLOW |
| later direct update → authority default branch | DENY locally; server policy should also deny when available |
| topic → registered projection | DENY |
| topic → unregistered remote | DENY |
| first default-branch push → unregistered remote | DENY |
| delete default branch through hook | DENY |
| first projection seed equal to current authority tip | ALLOW |
| first projection seed not equal to current authority tip | DENY |
| non-fast-forward projection update | DENY |

Remote classification is **deny by default**. A remote is authority, projection, or unknown. Unknown never falls through to authority behavior.

## 4. Clone portability gate

`core.hooksPath` is local Git configuration and is not inherited by clone. Therefore:

- the tracked hook file is not evidence that the hook is active;
- the methodology must ship an idempotent install/check path;
- a later Agent must be told to verify hook activation before its first push;
- missing hook activation must never be interpreted as permission to push `main`.

Fresh-clone tests must demonstrate both the missing setting and the successful explicit installation path.

## 5. Projection first-seed gate

An empty projection is not exempt from authority validation. Its first default-branch seed may proceed only when the candidate commit equals the current registered authority default-branch tip. If the authority tip cannot be resolved or fetched, fail closed.

After the first seed, normal projection updates must remain fast-forward from the current projection tip and must be derived from authority history.

## 6. Methodology provenance gate

A generated `.agent-project-ops/PIN` must contain a real methodology commit SHA for the supported path.

Default behavior when the methodology source is not a Git checkout: **fail closed**. An explicit unsupported/diagnostic override may record a visibly non-authoritative value such as `local:unknown`, but it must emit a warning and must not be described as a provenance guarantee.

Silent `sha=unknown` with successful bootstrap is forbidden.

## 7. Repository-protection capability states

Bootstrap must report the **observed protection capability**, not a binary marketing label. At minimum distinguish:

- **A — disposer/code-owner enforced:** PR required and independent/code-owner review gate is actually enabled.
- **B — PR-only:** direct default-branch pushes are blocked, but an identity with write permission may be able to self-merge; do not claim disposer enforcement.
- **C — unprotected/BLOCKED:** requested server policy could not be enabled or verified.

Plan/permission limitations are environment capability, not a reason to pretend Level A exists.

## 8. Credential and disposer gates

- Git remote URLs written to the repository must not contain embedded credentials or query strings carrying secrets.
- The bootstrap path must use one shared URL guard rather than divergent checks in the bootstrap and hook.
- If an operation depends on a disposer/CODEOWNER, a missing or placeholder disposer must fail; generating an inert `@DISPOSER` configuration is forbidden.

## 9. PR decomposition

The implementation from superseded PR #3 is intentionally split into semantic review units:

1. **RFC/research** — this package; no runnable bootstrap or hook implementation.
2. **Enforcement** — remote registry, hook, hook installer, URL guard, behavior tests, CI.
3. **Bootstrap/binding** — scaffold script, binding templates, PIN, GitHub create/protection reporting, local/fresh-clone/live smoke paths.

PR #3 must not be merged as a shortcut around these gates.

## 10. What remains unguaranteed

Even after all gates pass, this methodology cannot guarantee:

- a malicious/non-compliant Agent will obey instruction files;
- `--no-verify` cannot bypass client hooks;
- an administrator/maintainer cannot deliberately defeat host protections they control;
- every coding Agent vendor will keep the same auto-load behavior forever;
- every GitHub plan/private-repo combination exposes the same protection features;
- a pinned methodology snapshot is the latest version;
- PR merge means the project Phase passed acceptance.

The supported objective is narrower: make common accidental multi-repository divergence materially harder, observable, and recoverable while preserving one write authority.