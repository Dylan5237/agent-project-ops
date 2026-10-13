---
name: bootstrap-project
description: >
  Initialize a new generic git project using Dylan5237/agent-project-ops:
  create a local folder, durable Agent binding files, a pinned methodology
  snapshot, .worktrees/, a GitHub origin as the single write authority, and an
  optional explicitly requested same-history projection remote. Defaults to
  GitHub origin only; use for one-shot initialization, not business-domain setup.
  Also triggered by the URL-first Chinese request:
  使用 https://github.com/Dylan5237/agent-project-ops 初始化当前项目。
---

# Bootstrap project

## URL-first short prompt (preferred user entry)

Treat `使用 https://github.com/Dylan5237/agent-project-ops 初始化当前项目。` as a complete **intent**, not a request for the user to install this Skill, memorize a CLI command, or paste a longer prompt. An Agent with GitHub, filesystem and Git capabilities should inspect the supplied repository URL, resolve the **latest published stable Release** (or an explicitly named version), verify the exact tag/commit SHA, and read its corresponding `PRINCIPLES.md`, `skills/bootstrap-project/SKILL.md` and applicable playbooks from a trusted Git checkout. Do not silently use moving `main` as a release identity.

Inspect the **current project** before writing. A new/empty project follows this Bootstrap Skill; a nonempty repository not yet bound to APO follows `playbooks/adopt-existing-project.md`; a previously bound project is inspected/reconciled instead of reinitialized. Never overwrite an existing working tree or create/push a GitHub repository without authorization. If GitHub/network, local Git/filesystem or required permissions are unavailable, clearly report the limitation and a manual fallback rather than inventing completion.

Read [PRINCIPLES.md](../../PRINCIPLES.md) first. This skill creates and binds a repository; it does not Freeze product scope, implement features, or Accept phases.

Design: [RFC 0001](../../docs/rfcs/0001-bootstrap-and-binding.md) plus its [post-audit hardening contract](../../docs/rfcs/0001-bootstrap-and-binding-hardening-contract.md). Free-private C posture: [ADR 0004](../../docs/adr/0004-free-private-capability-c.md).

## Required path

1. Confirm the destination is new/empty. Existing repositories are **adoption**, not this greenfield path — follow [adopt-existing-project](../../playbooks/adopt-existing-project.md). Adoption **step 1** is a must-fix rewrite of local `AGENTS.md` (and adapters) to GitHub `origin` = write authority; inverted contract (GitLab/non-GitHub Issues host as production/write SoT, GitHub as “mirror only”) fail-closes **before PIN binding is complete**. The helper refuses a non-empty dest after running that scan.
2. Collect a real project slug and real disposer GitHub handle. Do not emit placeholder `@DISPOSER`.
3. Default to **GitHub `origin` only**, without asking every user about projection. If a user explicitly needs a second same-history mirror, take a credential-free `--projection-url` and verify its role. A filtered colleague export is a separate advanced path, **not** a projection; see [export-remote](../export-remote/SKILL.md) and [share-export](../share-export/SKILL.md).
4. Run `scripts/bootstrap-project.sh --dry-run ...` first when environment behavior is uncertain, then the real command.
5. After scaffold, verify `.agent-project-ops/PIN` contains a real SHA and `.agent-project-ops/remotes` classifies authority/projection.
6. Verify `git config --get core.hooksPath` is `.githooks` in the bootstrap checkout. Remember a later clone will not inherit it; root `AGENTS.md` instructs the next Agent to run the installer.
7. If GitHub creation is enabled, read the reported protection capability: A (code-owner review enforced), B (PR-only), or C (unprotected/unverifiable). Never upgrade the wording beyond what was verified. On GitHub Free **private** repos, C is **expected**: record C on Command Center and continue. Do not treat C as init failure or “do not start feature work.” Do not require Pro to finish init.
8. Run `playbooks/start-project.md` next (labels, Command Center, first Phase). No `feat/` / `fix/` implementation before Freeze.

## Important identity limit

If the local Agent and the human disposer use the **same GitHub identity**, GitHub cannot distinguish which one clicked/pushed/merged. CODEOWNERS cannot create a human-vs-Agent security boundary in that configuration. Default bootstrap therefore requests PR-only protection (B); request code-owner review (A) only when the repository has a genuinely independent reviewer/identity and the user wants that gate.

## Protection honesty

- Report A/B/C as verified. Never claim B/A when only C was verified.
- GitHub Free **private** → C is expected. Record C on Command Center and continue. Do not require Pro to finish init. Do not treat C as bootstrap failure.
- Client hooks + PR discipline still apply under C. Do not claim server protection exists.

## Fail closed

- Methodology source is not a git checkout / SHA cannot be determined → stop; supported bootstrap never writes silent `sha=unknown`.
- GitHub creation requested but `gh` is unavailable/unauthenticated → stop.
- Unknown remote → no push.
- Projection candidate is not current authority tip → no projection push.
- Colleague GitLab URL used as `--projection-url` → stop; that is export / share-export, not projection.
- Destination exists and is not empty → stop; that is [adoption](../../playbooks/adopt-existing-project.md). Inverted `AGENTS.md` SoT → fail closed (PIN not complete).
- Do not use `--no-verify` as a workflow shortcut.
