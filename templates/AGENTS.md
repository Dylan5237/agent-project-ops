# {{PROJECT_NAME}} — project operations binding

This repository is governed by the pinned `agent-project-ops` snapshot under `.agent-project-ops/`.

- Methodology: `{{METHODOLOGY_URL}}`
- PIN: `{{METHODOLOGY_SHA}}` (`{{METHODOLOGY_REF}}`, fetched {{FETCHED_AT}})
- Disposer: `{{DISPOSER}}`
- Write authority remote: `origin`
- Projection remote: `{{PROJECTION_REMOTE}}` (optional, same-history FF only; not a second write authority)

## Always load first

Read `.agent-project-ops/PRINCIPLES.md`. Invariants win over convenience. Load the relevant skill wrapper under `.agents/skills/`; it points to the full pinned skill body.

Core rules:

1. Chat is not project state. Durable decisions/status belong on GitHub Issues/PRs/git objects.
2. Agent proposes; the named disposer freezes/Accepts/exceptions. PR merge is not Phase PASS.
3. `origin` (GitHub) is the only write authority. An explicitly configured projection is same-history FF only; a filtered export, when requested, is a distinct advanced role, never a second source of truth.
4. Unknown remotes fail closed. `.agent-project-ops/remotes` is the clone-portable registry.
5. Topic branches push only to `origin`. Never substitute a projection/export or unclassified remote when the authority is unavailable.
6. One task, one worktree under `.worktrees/`; keep the primary checkout clean for sync/control work.
7. Do not copy business/domain SOP back into the methodology snapshot or upstream methodology repository.

## Before your first push in this clone

`git clone` does **not** inherit `core.hooksPath`.

Run:

```bash
git config --get core.hooksPath
```

It must print `.githooks`. If it is empty or different, run:

```bash
bash .agent-project-ops/scripts/install-hooks.sh
```

Then check `git remote -v` against `.agent-project-ops/remotes`. If an extra remote is unregistered, stop. If the registry names a projection that is not configured locally, restore/confirm it from the recorded project control plane before any projection operation.

A missing client hook is **not** permission to push `main`. The hook is bypassable; server-side repository policy remains the stronger control.

## Starting work

- No Command Center / first project setup: `.agent-project-ops/playbooks/start-project.md`
- New task: use `.agent-project-ops/scripts/new-worktree.sh` and the worktree playbook. Resolve the base from project config or verified origin default; if ambiguous, ask with the Agent host's native choice tool, use plain conversation as fallback, and require `--base` in headless mode. Persist a project default only after explicit user choice and a normal PR.
- Multiple remotes / same-history mirror / divergence: load `git-authority-and-projection` before any non-`origin` push.
- Only if a user asks for a second host or filtered publication: load `git-authority-and-projection`, `export-remote`, or `share-export` as appropriate; never classify a filtered export as a same-history projection.
- Cannot verify an invariant or remote state: fail closed and record `BLOCKED:` on the active Issue.
