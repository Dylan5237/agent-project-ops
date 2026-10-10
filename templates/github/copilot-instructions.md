Read root `AGENTS.md` and `.agent-project-ops/PRINCIPLES.md` before changing repository state.

GitHub `origin` is the single write authority. Push topic branches to `origin` only. Any explicitly configured projection is same-history mirror/fast-forward only; optional filtered exports are distinct and never a second write authority. Unknown remotes fail closed. Use `.worktrees/` for task work and keep the primary checkout clean. PR merge is not Phase PASS; the named disposer owns Freeze/Accept/Exception decisions.

On a fresh clone, verify `core.hooksPath=.githooks` before first push and run `.agent-project-ops/scripts/install-hooks.sh` if needed.
