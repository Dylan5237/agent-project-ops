---
name: github-multi-agent-project-ops
description: >
  Operate a business git repo as a local coding Agent that often owns day-to-day
  project ops. GitHub Issues/PRs are the control plane; chat is not state.
  Use when starting ops on an existing business repo, staffing Agents,
  running Freeze→Implement→Verify→Accept, or when the user mentions Command
  Center, phases, or agent-project-ops. If there is no git repo yet and the
  user wants to initialize/scaffold using agent-project-ops, use
  bootstrap-project instead.
---

# GitHub multi-agent project ops

Load **[PRINCIPLES.md](../../PRINCIPLES.md) v0.1.1** first. Invariants beat this skill.

You are usually the **project-ops Agent**: you keep Issues honest and **propose**. You do not Freeze-ACK or `PHASE ACCEPT` unless the Command Center explicitly names you as disposer.

## 必读 / Required reading

1. [PRINCIPLES.md](../../PRINCIPLES.md)
2. [playbooks/bootstrap-project.md](../../playbooks/bootstrap-project.md) — if there is **no** business git repo yet
3. [playbooks/start-project.md](../../playbooks/start-project.md) — if no Command Center
4. [playbooks/phase-lifecycle.md](../../playbooks/phase-lifecycle.md)
5. [playbooks/staff-and-dispatch.md](../../playbooks/staff-and-dispatch.md)
6. [playbooks/blocked-and-exceptions.md](../../playbooks/blocked-and-exceptions.md)

Companion skills: `bootstrap-project`, `git-worktree-and-branch`, `git-authority-and-projection`, `issues-prs-and-evidence`.

Git landing / remotes (worktrees, `origin`, optional projection): do **not** duplicate here — follow `git-worktree-and-branch` plus [playbooks/git-authority-and-projection.md](../../playbooks/git-authority-and-projection.md) when a second remote exists.

## 工作循环 / Loop

1. If this folder is not a git repo (or the user asked to initialize a **new** project) → [bootstrap-project](../bootstrap-project/SKILL.md). Then continue.
2. Find Command Center. If missing → start-project playbook. Stop implementation.
3. Confirm disposer + roster. If missing → fail closed, comment on a new Command Center draft.
4. One Phase = one core problem. No Freeze ACK → no `feat/` / `fix/` branch.
5. Dispatch: Issue comment with owner, worktree, branch; `status:in-progress`.
6. Implement in one worktree / one PR. Verify with **separate** evidence.
7. Propose PASS with evidence table. Wait for `PHASE ACCEPT`.
8. Update Command Center index. Never treat merge as PASS.

## Fail closed

- No methodology (this repo) loaded → refuse to invent a process.
- No business-product content belongs **in** agent-project-ops. Link out only.
- Unknown architecture after Freeze → Architecture Exception issue, not a silent refactor.

## Do not

- Add Notion, bots, CI bootstrap, or deploy stacks as part of this skill.
- Copy business SOP into the methodology repository.
- Self-label a Phase `status:done` without disposer Accept.
