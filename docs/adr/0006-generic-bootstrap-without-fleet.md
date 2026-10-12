# ADR 0006 — Generic bootstrap does not register to the author's Fleet

- **Status:** Proposed; Phase #64 pending disposer Accept
- **Date:** 2026-10-10
- **Related:** [#56](https://github.com/Dylan5237/agent-project-ops/issues/56), [#57](https://github.com/Dylan5237/agent-project-ops/issues/57), [#64](https://github.com/Dylan5237/agent-project-ops/issues/64)
- **Supersedes for generic projects:** mandatory registration in [ADR 0002](./0002-canonical-fleet-index.md), without rewriting that historical decision

## Context

ADR 0002 added a Git index and a box mirror for one author's Fleet Morning Digest. Active bootstrap/adoption guidance then required **every** user project to upsert `Dylan5237/agent-project-ops/fleet/REGISTRY.md` and sync `/home/box/agent-data/fleet-morning-digest/REGISTRY.md`. An external user cannot satisfy that contract without writing to a stranger's repository and disclosing project existence.

## Proposed decision

Generic project bootstrap/adoption succeeds based on **its own** GitHub `origin`, durable binding, Command Center, protection report, Phase workflow and legitimate human decisions. It never requires registration into somebody else's Fleet or a private box.

Command Center section 1 remains an Agent duty for recoverable project-local state, independent of any optional external status reader.

## Compatibility

- Existing project PIN snapshots retain the rules of their pinned SHA. No automatic upgrade or weakening.
- The historical Fleet registry, ADR, evidence, and open Fleet PRs remain intact for existing external consumers, which require separate authorized migration.
- Project owners approving an explicit version upgrade should compare active Skills/Playbooks, revalidate the new pinned SHA through CI, and review policy changes before merging.
- No change to GitHub sole write authority, unknown-remote denial, hook limitations, evidence or human Freeze/Accept.

## Verification

`tests/no-fleet-contract.sh` validates that active generic contracts no longer contain mandatory personal Fleet steps. It does not access or alter any external digest service.
