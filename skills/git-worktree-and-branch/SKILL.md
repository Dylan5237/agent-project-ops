---
name: git-worktree-and-branch
description: >
  Create and retire git worktrees and origin-only topic branches for Agent-owned
  work. Use when starting a task, running parallel Agents, naming feat/fix/docs/evidence
  branches, or when tempted to commit on main.
---

# Git worktree and branch

Follow **[PRINCIPLES.md](../../PRINCIPLES.md)** §8 (one worktree ≈ one task ≈ one PR branch) and § fail-closed remotes.

## Playbooks

- [playbooks/git-worktree.md](../../playbooks/git-worktree.md)
- [playbooks/git-branch-and-remote.md](../../playbooks/git-branch-and-remote.md)
- Helper: [scripts/new-worktree.sh](../../scripts/new-worktree.sh) (optional)

## Conventions (do not improvise)

| Item | Rule |
| --- | --- |
| Worktree path | `{repo}/.worktrees/{issue-or-phase}-{owner}-{slug}` |
| Remote | `origin` only for this workflow |
| Branch | `feat\|fix\|docs\|evidence/{issue}-{slug}` |
| `main` | never push; never use as a long-lived task checkout |
| Evidence vs impl | `evidence/` branches contain no feature diff |

## Agent checklist

1. `git remote -v` → expect `origin`. Fetch `origin/main`.
2. Implementation requires Phase **Freeze ACK**. Else stop.
3. Add worktree from `origin/main`, not from a dirty unrelated branch.
4. Comment path + branch on the Issue.
5. `git push -u origin HEAD`. Open PR to default branch.
6. After merge/abandon: `git worktree remove …` and delete remote topic branch.

Ignore `.worktrees/` in the **business** repo. Do not vendor this methodology into app packages.
