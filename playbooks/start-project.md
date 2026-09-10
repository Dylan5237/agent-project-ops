# Playbook: Start project / 启动项目

## Goal

Stand up a **control plane** in the **business** git repository so a local Agent can own day-to-day ops without treating chat as state.

## When

- A business git repo **already exists** (or bootstrap just created it) and has no Command Center.
- You are adopting `agent-project-ops` for the first time on that repo.

If there is **no** repository yet, run [bootstrap-project.md](./bootstrap-project.md) first, then return here.

## Preconditions

- You can create Issues and labels on the business repo.
- You can set branch protection on `main` (or the default branch).
- Agent can load PRINCIPLES + skills: either this methodology clone/URL, **or** a pinned snapshot at `.agent-project-ops/` plus root `AGENTS.md` (see [docs/rfcs/0001-bootstrap-and-binding.md](../docs/rfcs/0001-bootstrap-and-binding.md)).
- `PRINCIPLES.md` v0.1.1 is in force. Methodology files are **not** product code (a `.agent-project-ops/` snapshot is a pin, not a domain tree).

## Steps

1. **Point the Agent.** Prefer files **in this repo**: `AGENTS.md`, `.agent-project-ops/PRINCIPLES.md`, `.agents/skills/`. If those are missing, instruct the Agent to load this methodology’s `PRINCIPLES.md` and `skills/*/SKILL.md`, or run bootstrap binding. Confirm it restates: Chat ≠ state; Agent proposes / control plane disposes.
2. **Create labels.** Apply the dictionary in `templates/labels.md` (status, type, phase). Do not invent overlapping status names.
3. **Protect `main`.** Require pull requests; disallow direct pushes from Agents. `main` is integration history, not a work branch. See `playbooks/git-branch-and-remote.md`.
4. **Open the Command Center issue.** Use `templates/ISSUE_TEMPLATE/command-center.md`. Fill: disposer (human or named owner), default branch, Agent roster, methodology **PIN** (URL @ SHA) if a snapshot exists, “how we freeze / Accept.” Pin it if the host allows.
5. **Record remotes.** Default: Command Center states **only `origin`**. No second remote for “backup workflow.” If a **projection** mirror is required, name it on Command Center as projection-only and follow `playbooks/git-authority-and-projection.md` (Principle 10) — still not a backup or second SoT.
6. **Open Phase-0 (or Phase-1) issue.** One core problem only. Use `templates/ISSUE_TEMPLATE/phase.md`. Label `type:phase` + `status:backlog`.
7. **Do not implement yet.** Run Freeze on that Phase (`playbooks/phase-lifecycle.md`) before any `feat/` / `fix/` branch.
8. **Optional:** copy `templates/ISSUE_TEMPLATE` and `templates/PULL_REQUEST_TEMPLATE` into the business repo `.github/` so humans get the same forms.

## Done when

- [ ] Command Center issue exists, is the single index, and names the disposer.
- [ ] Status labels `backlog` / `in-progress` / `blocked` / `verification` / `done` exist.
- [ ] Default branch rejects direct Agent pushes.
- [ ] At least one Phase issue exists with a single core problem and is not yet implementing.
- [ ] Agent can find playbooks from the Command Center body (URL or path).

## Anti-patterns

- Treating the methodology clone as the product repo.
- Skipping bootstrap binding and relying only on a chat URL (later Agents will not auto-load `skills/` from this methodology).
- Skipping Command Center and tracking work only in chat.
- Opening three Phases that are actually one problem (or one Phase that is a roadmap).
- Pushing “just this once” to `main`.
- Embedding business SOP into this methodology repository.
