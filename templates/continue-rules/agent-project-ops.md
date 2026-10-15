---
name: agent-project-ops
alwaysApply: true
---

Read root `AGENTS.md` and follow the pinned `.agent-project-ops/PRINCIPLES.md`. GitHub `origin` is the single write authority; unknown remotes fail closed; a single task may use the idle primary checkout, parallel tasks use `.worktrees/`; finished work is retired by `.agent-project-ops/scripts/tidy-worktrees.sh`, never by hand; PR merge is not Phase PASS. Colleague GitLab is share-export, not a full-tree projection.
