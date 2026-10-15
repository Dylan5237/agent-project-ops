---
name: git-worktree-and-branch
description: >
  Create and retire git worktrees and origin-only topic branches for Agent-owned
  work. Use when starting a task, running parallel Agents, naming feat/fix/docs/evidence
  branches, after a PR merges or closes (retire its folder and branch), parking or
  abandoning a task, or when tempted to commit on main. Also use when a second remote,
  projection/mirror, multi-remote setup, or authority-vs-projection tip
  reconciliation appears — then load git-authority-and-projection before any
  non-origin push. Colleague-share GitLab is export / share-export, not a projection.
---

# Git worktree and branch

Follow **[PRINCIPLES.md](../../PRINCIPLES.md)** §8 (one task ≈ one branch ≈ one PR; a single task uses the idle primary checkout; finished work is retired automatically, only with proof), §5 fail-closed remotes, and §10 (one write authority).

## Playbooks

- [playbooks/git-worktree.md](../../playbooks/git-worktree.md)
- [playbooks/git-branch-and-remote.md](../../playbooks/git-branch-and-remote.md)
- [playbooks/git-authority-and-projection.md](../../playbooks/git-authority-and-projection.md) — when a projection/second remote exists
- [playbooks/export-remote.md](../../playbooks/export-remote.md) — colleague export remote (`export=`)
- [playbooks/share-export.md](../../playbooks/share-export.md) — colleague GitLab / filtered snapshot
- Companion skill: [git-authority-and-projection](../git-authority-and-projection/SKILL.md)
- Companion skill: [export-remote](../export-remote/SKILL.md)
- Companion skill: [share-export](../share-export/SKILL.md)
- Helper: [scripts/new-worktree.sh](../../scripts/new-worktree.sh) — start or resume a task (runs tidy first)
- Helper: [scripts/tidy-worktrees.sh](../../scripts/tidy-worktrees.sh) — retire finished work; `--park` / `--abandon`

## Conventions (do not improvise)

| Item | Rule |
| --- | --- |
| Working directory | single task: the idle primary checkout (`mode: here`); parallel tasks: `{repo}/.worktrees/{issue-or-phase}-{owner}-{slug}` |
| Folder cap | `max_worktrees` in `.agent-project-ops/project-config` (default 3, `0` = unlimited); exit 3 = queue the task, never bypass |
| Remote | `origin` only for topic pushes; extra remotes are projection (same-history) or export (`authority − strip`), never a second SoT |
| Branch | `feat\|fix\|docs\|evidence/{issue}-{slug}` |
| Base | approved origin task base: explicit selection, reviewed project config, or verified remote default |
| `main` | never push; the primary checkout carries at most one task branch and returns to the default branch when that task lands |
| Retire | `scripts/tidy-worktrees.sh --apply`: merged PR → delete folder + branches; closed PR → push `archive/<branch>-<sha7>`, then delete; uncommitted, unmerged, open, no-PR or unverifiable → keep and list |
| Evidence vs impl | `evidence/` branches contain no feature diff |

## Agent checklist

1. `git remote -v` → expect `origin` for this workflow. If a **projection** (or any non-origin) remote is configured, follow [git-authority-and-projection](../git-authority-and-projection/SKILL.md) and its playbook **before any non-origin push**. If that host is colleague share, follow [export-remote](../export-remote/SKILL.md) or [share-export](../share-export/SKILL.md) instead of projecting.
2. Implementation requires Phase **Freeze ACK**. Else stop.
3. Determine the task base from the approved Issue/Phase, reviewed `.agent-project-ops/project-config`, or the real GitHub origin default. If ambiguous, offer *verified* `origin/*` candidates via the host's native choice tool (or ordinary conversation); in headless mode require explicit `--base origin/BRANCH`. Use `scripts/new-worktree.sh <issue> <owner> <slug> [kind] [--base origin/BRANCH] [--save-base] [--here|--worktree]`; work where its `workdir:` / `worktree:` line says. Exit 3 = folder cap reached, nothing created: queue the task or park one; do not raise the cap or delete folders by hand.
4. Comment mode + working directory + branch on the Issue.
5. `git push -u origin HEAD`. Open PR to default branch. Never push topic branches to projection.
6. After merge or close: `scripts/tidy-worktrees.sh --apply` (it also runs before every new task) and quote its `apo-tidy:` line. Pause = commit + push, then `--park <branch>`; abandon (disposer decision) = `--abandon <branch>`, which archives before deleting. Never `git worktree remove --force` or `git branch -D` by hand. Next task bases on the new authority tip.

Ignore `.worktrees/` in the **business** repo. Do not vendor this methodology into app packages.
