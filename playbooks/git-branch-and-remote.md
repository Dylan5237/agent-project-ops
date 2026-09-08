# Playbook: Git branch and remote / 分支与远端

## Goal

Use **one remote (`origin`)** and **named topic branches** so Agents never push `main` and never invent a shadow remote.

## When

- Creating or pushing any branch.
- Configuring a new clone.
- An Agent is tempted to “just commit on main.”

## Preconditions

- Default branch is protected (see start-project).
- Worktree playbook followed for in-flight work.
- Issue number known (used in the branch name).

## Steps

1. **Remotes.** `git remote -v` must show `origin` only for this workflow. If another remote exists for forks, do not push workflow branches there unless Command Center says so. Default: **origin only**.
2. **Update base.**

   ```bash
   git fetch origin
   git merge --ff-only origin/main   # only on a throwaway sync; topic branches rebase/merge per Command Center
   ```

   Prefer: create branches from `origin/main`, not from a dirty local `main`.
3. **Name the branch:** `{type}/{issue}-{slug}` where `type` is one of:
   - `feat` — new behavior
   - `fix` — defect
   - `docs` — documentation only
   - `evidence` — verification artifacts only (no product behavior change)
4. **Slug:** kebab-case, from the issue; keep it short. Example: `feat/42-add-healthcheck`, `evidence/42-healthcheck-logs`.
5. **Push:**

   ```bash
   git push -u origin HEAD
   ```

   Never: `git push origin main`. Never: `--force` on `main`. Force-with-lease on a **topic** branch only if the Issue comments that the branch is Agent-private and not under review.
6. **PR target:** `main` (or the default branch named on Command Center).
7. **After merge:** delete the remote topic branch; remove worktree; do not keep pushing the old name.

## Done when

- [ ] Branch matches `feat|fix|docs|evidence/{issue}-{slug}`.
- [ ] `origin` is the push target.
- [ ] `main` has no direct Agent commits from this workflow.
- [ ] Evidence work is not on a `feat/` / `fix/` branch (and vice versa).

## Anti-patterns

- `git push origin main` “because protection isn’t set yet.”
- Unnamed branches (`tmp`, `asdf`, `agent-1`).
- Mixing evidence files and feature code on `feat/…`.
- Adding `upstream`/`backup` remotes as a substitute for Issues.
- Rewriting `main` history.
