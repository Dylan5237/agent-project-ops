# Copilot instructions — project operations

This repository uses **agent-project-ops** (pinned snapshot in `.agent-project-ops/`). Also read root `AGENTS.md`.

- Canonical state: GitHub Issues, labels, PRs, and git commits — not chat.
- Agent proposes; the disposer named on the Command Center issue Accepts. Do not declare Phase PASS because a PR merged.
- Default remote is `origin` (GitHub). A `projection` remote, if present, is a mirror: fast-forward from authority only. Do not push feature branches to it. Do not treat it as a second source of truth.
- Create work in git worktrees under `.worktrees/`. Do not pile features on the primary `main` checkout.
- Load skills from `.agents/skills/` (full text in `.agent-project-ops/skills/`).
- If you cannot follow PRINCIPLES (missing freeze, missing origin, diverged projection), stop and document the gap on the Issue.
