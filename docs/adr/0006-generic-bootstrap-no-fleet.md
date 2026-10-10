# ADR 0006 — Generic APO bootstrap does not register an owner's personal Fleet

Status: **proposed; pending disposer acceptance**

## Decision proposal

For newly bootstrapped generic APO projects, the required project state remains its own GitHub Issues, PRs, Command Center, PIN and repository history. Registering with `Dylan5237/agent-project-ops/fleet/REGISTRY.md`, syncing a particular box path, or declaring inclusion in a morning digest is **not** a generic bootstrap or adoption requirement.

The old Fleet requirement came from [Phase #27](https://github.com/Dylan5237/agent-project-ops/issues/27). This proposal supersedes it **for new generic-methodology snapshots after acceptance**, not retroactively. Project-level Command Center hygiene is retained. Historical fleet registry, ADR 0002 and existing monitoring consumers are not deleted.

## Compatibility and migration

- Existing repositories with pinned pre-change APO snapshots retain their original rules until the disposer explicitly approves a version update; do not silently replace their Skills.
- A Fleet/morning-digest service may continue running outside APO, reading its own index. It cannot require unrelated new adopters to grant write access or publish their private repository names.
- Existing pending Fleet-registration PRs and mirror jobs need independent review; do not merge/close or alter those resources as part of this project-level change.
- After methodology acceptance, explicitly pin the new SHA in a chosen test project, compare generated rules, and verify the external adoption flow without owner Fleet credentials.

## Evidence expected

Run the bootstrap contract and inspect generated pinned Skills, Playbooks and the Command Center template for required Fleet-registration steps. Verify existing Git authority, hook, CC updates and Accept gates remain effective.

Historical reference: #24–#27. Implementation proposal: #64, PR #82.
