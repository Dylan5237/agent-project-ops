# Playbook: Git worktree / 工作树

## Goal

Isolate each in-flight task in its own worktree so Agents do not clobber each other’s index, and so one task maps to one PR branch.

## When

- Starting implementation or evidence work.
- Running a second Agent in parallel.
- Need a clean tree without stashing unrelated work on `main`.

## Preconditions

- Business repo clone exists; `origin` is configured (`playbooks/git-branch-and-remote.md`). If a projection remote exists, also load `playbooks/git-authority-and-projection.md`. Colleague GitLab is `playbooks/share-export.md`, not a worktree base.
- Target Issue exists; Phase is Freeze-ACK’d if this is implementation.
- `.worktrees/` is gitignored in the business repo (add it if missing). Do **not** commit worktree contents as a nested repo.

## Steps

1. **Name the slot.** `{issue-or-phase}-{owner}-{slug}`
   - `issue-or-phase`: `p12` or `123` (issue number) or `p12-t3` for a child task.
   - `owner`: short agent or handle slug (`agent`, `dylan`).
   - `slug`: kebab-case, ≤ 40 chars, from the issue title.
2. **Path:** `{repo}/.worktrees/{issue-or-phase}-{owner}-{slug}`  
   Example: `~/src/app/.worktrees/42-agent-add-healthcheck`
3. **Base = approved task origin ref.** Fetch `origin`. Resolve an explicit `--base`, otherwise the reviewed `.agent-project-ops/project-config` (`task_base=origin/BRANCH`), otherwise GitHub origin's verified remote default. A task may use `origin/develop` without changing the repository's default branch or write authority. If ambiguous, stop and ask rather than guessing `origin/main`.
4. **Create** (helper): from the **primary clone** (keep that checkout on the default branch and **clean**, for fetch/sync only — no long-lived feature work there),

   ```bash
   # Auto-detect reviewed project base or verified remote default:
   scripts/new-worktree.sh 42 agent add-healthcheck feat
   # For an explicitly chosen development base:
   scripts/new-worktree.sh 43 agent another-task feat --base origin/develop
   # Record that choice as this project's new default on the *task branch*:
   scripts/new-worktree.sh 44 agent third-task feat --base origin/develop --save-base
   ```

5. **Bind.** Comment on the Issue: worktree path, branch, selected origin base, its source, and HEAD SHA. With `--save-base`, review/commit the generated `.agent-project-ops/project-config` through the task PR. The primary checkout must remain unchanged.
6. **Work only in that directory.** `cd` into the worktree for commits and `git push -u origin <branch>` (never to a projection remote).
7. **End of task:** after PR merge or abandon:

   ```bash
   git worktree remove .worktrees/42-agent-add-healthcheck
   # if dirty and abandoned: commit or discard explicitly, then remove
   ```

8. **List:** `git worktree list` — every extra path should match an `in-progress` or `verification` issue. The primary path should remain a clean sync checkout, not a second feature tree.

## Done when

- [ ] Path matches `{repo}/.worktrees/{issue-or-phase}-{owner}-{slug}`.
- [ ] Branch in that worktree is the PR branch, created from the verified origin base approved for this task.
- [ ] Primary clone is not the long-lived feature checkout.
- [ ] Issue comment records the path.
- [ ] Removed or parked when the PR is done.

## Anti-patterns

- Extra clones in random directories instead of `.worktrees/`.
- Using the primary `main` checkout for a long-lived feature (it stays clean for sync).
- Basing a worktree on projection or on a superseded transitional branch after the authority tip has merged.
- Two issues, one worktree.
- Committing `.worktrees/` into git.
- Creating a worktree before Freeze on an implementation task.
- Assuming `origin/main` despite contrary project state, or silently saving a task override as a project default.
