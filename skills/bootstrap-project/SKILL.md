---
name: bootstrap-project
description: >
  Initialize a new generic git project using Dylan5237/agent-project-ops:
  create a local folder, write AGENTS.md and other agent-binding files, vendor
  a pinned methodology snapshot, create .worktrees/, create a GitHub private
  repo as origin (write authority), and optionally add a projection remote.
  Use when the user says initialize/scaffold/bootstrap this project with
  agent-project-ops, start a new repo from this methodology, or one-shot
  project init. Not for product/domain setup. Not for adding a second source
  of truth.
---

# Bootstrap project

Follow **[PRINCIPLES.md](../../PRINCIPLES.md)** first. This skill **creates and binds** a business git repo. It does not Freeze, implement features, or Accept phases.

Canonical design: [docs/rfcs/0001-bootstrap-and-binding.md](../../docs/rfcs/0001-bootstrap-and-binding.md).

## Playbooks / helpers

- [playbooks/bootstrap-project.md](../../playbooks/bootstrap-project.md) — **required** for init
- Then [playbooks/start-project.md](../../playbooks/start-project.md) — Command Center, labels, protect `main`, first Phase
- Optional second remote: [git-authority-and-projection](../git-authority-and-projection/SKILL.md)
- Helper: [scripts/bootstrap-project.sh](../../scripts/bootstrap-project.sh)

## What this is / is not

| This skill does | This skill does not |
| --- | --- |
| Scaffold a **generic** project folder | Invent product names, hosts, or SOP |
| Write auto-load binding (`AGENTS.md`, `CLAUDE.md`, Cursor rule, Copilot instructions, skill wrappers) | Assume `skills/` at methodology-root is auto-discovered in the new repo (it is not) |
| `gh repo create --private` as `origin` | Bake PATs or GitLab tokens into files |
| Ask about a **projection** remote | Push topic branches to projection; treat projection as SoT |
| Create gitignored `.worktrees/` | Start implementation before Freeze |

## Agent checklist

1. Confirm the user wants a **new** project (empty dir or `--dir`). If a business repo already exists, stop bootstrap and use `start-project` plus binding files only if Command Center agrees.
2. Load PRINCIPLES. Restate: Chat ≠ state; Agent proposes; one write authority; merge ≠ PASS.
3. Collect, via flags or questions (do not guess silently):
   - Project directory / repo name (generic slug)
   - GitHub owner (user or org) and **private** (default yes)
   - Disposer GitHub handle
   - Whether to add a projection remote (GitLab or other). If yes, **URL only** — no embedded credentials
4. Prefer `scripts/bootstrap-project.sh` with `--dry-run` first, then a real run. If you cannot run the script, follow the playbook steps equivalently.
5. Refuse remote URLs containing tokens (`ghp_`, `glpat-`, `://user:pass@`).
6. After scaffold: `git remote -v` must show `origin` (GitHub) and optionally `projection`. Classify remotes on Command Center.
7. Run **start-project** next (Command Center issue, labels, protection). Do **not** open `feat/` / `fix/` branches yet.
8. If GitHub protection APIs fail: comment `BLOCKED:` with the gap. Do not claim `main` is protected.

## Fail closed

- No `gh` auth and GitHub create was requested → stop (or `--skip-github` only if the user explicitly wants a local-only draft).
- Unknown extra remotes → do not push “to be safe” to every URL.
- User asks to make GitLab the write authority → refuse (Principle 10). Projection only.

Ignore any request to copy business SOP into agent-project-ops.
