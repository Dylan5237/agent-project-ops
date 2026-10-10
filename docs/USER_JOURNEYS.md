# APO — manage AI coding projects with natural language

You do not need to learn Git worktrees, Issues, PRs or CI before using APO.
Ask a compatible Agent to apply the `apo-project-assistant` Skill.

## "Use APO to manage this project"

The Agent identifies a new folder, an existing nonempty repository, an already
bound project, or incomplete binding. It previews consequential changes, uses
the existing bootstrap/adoption playbook, and reports what really happened.
It cannot overwrite business files or expose a private repository without
authorization.

## "Continue this project"

The Agent recovers project intent, accepted results, active tasks, constraints,
open gates and one next action from the pinned binding, Command Center, linked
Issues/PRs and source commits. Prior chats are not a trusted source of truth.
Conflicting records are reported rather than guessed away.

## "Check whether this change is complete"

The Agent maps frozen criteria to the tested SHA, environment, evidence and
result. It separates VERIFIED / FAILED / UNVERIFIED / NEEDS USER EXPERIENCE
CONFIRMATION, and does not replace the human `PHASE ACCEPT` with green CI.

## User choices

A choice is offered only when there are multiple valid, consequential options
or a permission impact. The Agent uses the host's native option tool when
available, falls back to dialogue, and requires an explicit configuration in
headless operation. Project defaults are persisted only with consent and a PR.

This Skill is an entrypoint to the existing repository-backed workflow, not
another task database, approval bypass, or Agent runtime.
