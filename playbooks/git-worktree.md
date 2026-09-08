# Playbook: Git worktree / 工作树

## Goal

Isolate each in-flight task in its own worktree so Agents do not clobber each other’s index, and so one task maps to one PR branch.

## When

- Starting implementation or evidence work.
- Running a second Agent in parallel.
- Need a clean tree without stashing unrelated work on `main`.

## Preconditions

- Business repo clone exists; `origin` is configured (`playbooks/git-branch-and-remote.md`).
- Target Issue exists; Phase is Freeze-ACK’d if this is implementation.
- `.worktrees/` is gitignored in the business repo (add it if missing). Do **not** commit worktree contents as a nested repo.

## Steps

1. **Name the slot.** `{issue-or-phase}-{owner}-{slug}`
   - `issue-or-phase`: `p12` or `123` (issue number) or `p12-t3` for a child task.
   - `owner`: short agent or handle slug (`agent`, `dylan`).
   - `slug`: kebab-case, ≤ 40 chars, from the issue title.
2. **Path:** `{repo}/.worktrees/{issue-or-phase}-{owner}-{slug}`  
   Example: `~/src/app/.worktrees/42-agent-add-healthcheck`
3. **Create** (helper): from the primary clone,

   ```bash
   # optional
   scripts/new-worktree.sh 42 agent add-healthcheck feat
   # or:
   git fetch origin
   git worktree add -b feat/42-add-healthcheck .worktrees/42-agent-add-healthcheck origin/main
   ```

4. **Bind.** Comment on the Issue: worktree absolute/relative path, branch name, HEAD sha after create.
5. **Work only in that directory.** `cd` into the worktree for commits and `git push -u origin <branch>`.
6. **End of task:** after PR merge or abandon:

   ```bash
   git worktree remove .worktrees/42-agent-add-healthcheck
   # if dirty and abandoned: commit or discard explicitly, then remove
   ```

7. **List:** `git worktree list` — every extra path should match an `in-progress` or `verification` issue.

## Done when

- [ ] Path matches `{repo}/.worktrees/{issue-or-phase}-{owner}-{slug}`.
- [ ] Branch in that worktree is the PR branch (not `main`).
- [ ] Issue comment records the path.
- [ ] Removed or parked when the PR is done.

## Anti-patterns

- Extra clones in random directories instead of `.worktrees/`.
- Using the primary `main` checkout for a long-lived feature.
- Two issues, one worktree.
- Committing `.worktrees/` into git.
- Creating a worktree before Freeze on an implementation task.
