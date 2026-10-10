---
name: apo-project-assistant
description: >
  User-facing entrypoint for adopting an existing or new project, continuing
  work after a session/Agent switch, or checking whether a change really met
  its acceptance criteria. Keep GitHub as the sole state source and ask only
  when a consequential choice remains.
---

# APO project assistant — goal-driven entrypoint

Use when the user asks to **manage this project**, **continue the project**, or
**check whether this change is done**, even if they do not know Git terminology.
This Skill is a router, not another runtime, task database, or permission grant.

## Always establish trusted context first

1. Identify whether the working folder is new, a nonempty existing Git repo, an
   already-bound APO repo, or an inconsistent/partially bound repo. Do **not**
   run greenfield bootstrap over an existing project.
2. In an APO repo, load root `AGENTS.md`, the pinned `.agent-project-ops/PIN`
   and `PRINCIPLES.md`, then discover its Command Center, current Phase,
   linked Issues/PRs, and Git ref status. Fetch only the required evidence,
   not the entire project history. Chat and Agent memory are **not** state.
3. Check what the current Agent host can actually do: Git, GitHub, tool access,
   auth, and interactive choice facilities. State missing permissions and
   observed protection A/B/C honestly. Never claim a hook is a server gate.
4. Distinguish **observed**, **user-approved**, **proposed**, and **unknown**.
   When CC, Issue, branch, PR, or verification sources disagree, show links
   and block the affected write; do not invent a consensus.

## Intent A — "Use APO to manage this project"

- **New empty repository:** load `bootstrap-project`, show the repository
  name/visibility/disposer and planned writes, get real authorization, then
  bootstrap and run `start-project`.
- **Existing nonempty repository:** load `adopt-existing-project.md`.
  Read-only scan first, present proposed file and remote changes, never overwrite
  dirty business files or silently invert authority/PIN.
- **Already APO-bound:** reconcile PIN, hooks, current CC, and remotes; do not
  duplicate binding files, CC Issues, or project registration.
- **Incomplete or inconsistent binding:** report the gap and a recoverable plan;
  no fabricated "initialized" result.
- Return: repository/CC location, policy/protection limitations, actions actually
  performed, what still needs authorization, and **one next action**.

## Intent B — "Continue this project"

- Read the pinned project binding, CC section 1 and active Phase/Issue, then
  inspect relevant PR SHAs, branches, accepted decisions and pending gates.
- Give a short, source-linked handoff: **goal, most recent accepted outcome,
  current work, boundaries, verified/unverified facts, pending human decisions,
  one next action**.
- Default to read-only takeover. If multiple plausible tasks exist, ask the user
  to choose using the Agent host's native selection tool when available, else
  ordinary dialogue. Do not silently reprioritize or modify a frozen scope.
- Only begin implementation after the project's real Freeze/authorization
  conditions are met, using a dedicated task branch/worktree.

## Intent C — "Check whether this change is complete"

- Map each *frozen* acceptance criterion to the **tested commit SHA, environment,
  command or observable behavior, result, and evidence URL**.
- Mark criteria as **VERIFIED**, **FAILED**, **UNVERIFIED**, or
  **NEEDS USER EXPERIENCE CONFIRMATION**. CI green can prove only what its
  tests exercised; missing evidence is never an implicit pass.
- Clearly separate implementer self-test, independent replay, code review,
  and the disposer's human acceptance. PR merge / bot output / CI success
  does **not** mean `PHASE ACCEPT`.
- Return a concise user-readable decision brief plus expandable technical
  evidence, exact gaps and the action requiring the user. Do not self-Accept.

## Choose only when choice matters

Use host-native **ask / select / option** tools when there are multiple valid,
consequential paths (e.g., which verified `origin/*` task base to use), or a
permission/visibility consequence. Show a recommendation **with evidence**.
If no structured choice capability exists, ask in plain language. In headless
mode require an explicit saved project setting or command argument; fail
clearly rather than choosing randomly. Do not create a UI framework or hardcode
any host-specific tool name.

Approved choices must be written to an existing authoritative repository
binding or Issue in the correct scope; a chat reply is not permanent state.
Project defaults require explicit consent and a normal PR. A task override
does not become a project-wide rule by accident.

## Invariants

GitHub `origin` remains the sole write authority. Unknown remotes fail
closed. Keep one task/one worktree/one PR, replayable evidence, separation
between implementation and Accept, and human authorization for high-impact
actions. Never use this entrypoint to bypass a missing Freeze, merge approval,
data deletion authorization, or deployment permission.
