# AGENTS.md — project operations binding

This file is **always-on** for coding agents. It is not chat. It is not the product.

**Methodology snapshot:** `.agent-project-ops/` (pin: see `.agent-project-ops/PIN`).
Canonical upstream: {{METHODOLOGY_URL}} @ {{METHODOLOGY_SHA}}

If a playbook step conflicts with `.agent-project-ops/PRINCIPLES.md`, the principle wins.

## Load

1. Read `.agent-project-ops/PRINCIPLES.md` before proposing work.
2. Use project skills under `.agents/skills/` (wrappers) and the full bodies under `.agent-project-ops/skills/`.
3. Claude Code: this repo also has `CLAUDE.md` importing this file; use `.claude/skills/` as well.

## Invariants (short)

- **Chat ≠ state.** Durable facts go on GitHub Issues/PRs and git objects.
- **Agent proposes / disposer disposes.** Disposer: {{DISPOSER}}. No self-`PHASE ACCEPT`.
- **PR merge ≠ Phase PASS.**
- **Freeze before implementation.** No `feat/` / `fix/` without Freeze ACK.
- **Fail closed.** Missing evidence, auth, freeze, owner, or reachable `origin` → stop. Do not invent a second SoT.
- **One worktree ≈ one task ≈ one PR.** Path: `.worktrees/{issue-or-phase}-{owner}-{slug}`. Primary checkout stays **clean** for fetch/sync — not a long-lived feature tree.
- **Evidence PRs ≠ implementation PRs.**

## Remotes

- **Write authority:** GitHub remote `origin` (Issues/PRs live there).
- **Default:** origin-only. Topic push: `git push -u origin HEAD`. Never `git push origin main`. Never force `main`.
- **Optional projection:** remote name `projection` ({{PROJECTION_REMOTE}}). Read or **fast-forward from authority** only. Never push `feat/` `fix/` `docs/` `evidence/` there. If projection is required and cannot FF → fail closed (stop release). If projection is **ahead** of authority → Blocked; backfill on origin or disposer-written abandon **before** projecting.
- Unknown remotes → stop until the Command Center names them.

Full rules: `.agent-project-ops/playbooks/git-branch-and-remote.md` and `.agent-project-ops/playbooks/git-authority-and-projection.md`.

## Do not

- Copy business SOP into the methodology upstream.
- Use `--force` on the default branch without disposer SHAs on the Issue.
- Treat a Cloud Agent sandbox or local `main` as caught-up SoT without fetching `origin`.
- Skip hooks with `--no-verify` to dodge remotes policy.

Command Center issue is the index. If it does not exist, run start-project (not ad-hoc chat process).
