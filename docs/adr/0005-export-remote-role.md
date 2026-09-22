# ADR 0005 — Export remote role (authority − strip list)

- **Status:** Proposed (implementation PR; disposer Accept on Phase [#46](https://github.com/Dylan5237/agent-project-ops/issues/46) is authoritative)
- **Date:** 2026-09-22
- **Deciders:** disposer `@Dylan5237` `FREEZE ACK` on Phase [#46](https://github.com/Dylan5237/agent-project-ops/issues/46) (2026-09-22); Command Center [#10](https://github.com/Dylan5237/agent-project-ops/issues/10) §1
- **Implements:** Phase [#46](https://github.com/Dylan5237/agent-project-ops/issues/46)
- **Identity:** Methodology remote-classification only. No business SOP. Does not change zentao-mcp or other business repos in this change.

---

## Context

Principle 10 allows **at most one write authority**. ADR [0003](./0003-share-export-vs-projection.md) split **projection** (same-history FF, full tree including ops) from **share-export** (filtered snapshot publish via `scripts/share-export.sh`).

That split still left a hole: a colleague GitLab **copy that should stay content-current with authority** could not be classified as a remote without looking like a second write authority or a full-tree projection. Business repos were forced through Architecture Exception to keep a stripped GitLab remote.

Phase #46 freeze (2026-09-22):

- Add a first-class third remote role **export**.
- Export is **not** a second write authority.
- Content identity: `export tree = authority main − strip list`.
- Content must not lag authority; strip commits may make the export tip legitimately ahead.
- Sync: after authority advances, on the **current export tip** replay strip (delete newly introduced strip-list paths), then fast-forward push. Reject → stop. **No force.**
- Export remotes are **not** on the auto-push whitelist. Each sync needs disposer explicit authorization (fail closed / no silent drift).
- Default strip list is methodology-owned. Business repos may **add** entries and must **not** remove methodology entries.

## Decision

Name three remote roles. Only one of them is a write authority.

| Role | Registry keys | What it is | What it is not |
| --- | --- | --- | --- |
| **Authority** | `authority=` | GitHub `origin`. Issues/PRs. Full ops tree. Sole write SoT. | A mirror, a colleague share, or a draft checkout |
| **Projection** | `projection=` / `projection_url=` | Optional **same-history** FF mirror of the authority tip, **including** ops | Colleague GitLab; a feature host; a second SoT |
| **Export** | `export=` / `export_url=` | Colleague-facing copy whose **tree** is `authority main − strip list`. History stays related enough to merge + strip + FF. Tip may be **ahead** because of strip (and merge) commits. | A second write authority; a projection; an invitation to `git push --mirror` the bound clone |

### Content identity

After a successful sync, every non-stripped path on the authority tip has the same blob on the export tip, and no strip-list path is present on the export tip.

The export SHA is **not** required to equal the authority SHA. Strip commits (and merge commits that replay authority onto the export tip) may make export ahead. Export content must not lag authority.

### Default strip list (methodology-owned)

Directory prefixes include the directory itself and every descendant:

```
.agent-project-ops/
.agents/
.githooks/
.github/
.claude/
.continue/
.cursor/
AGENTS.md
CLAUDE.md
.aider.conf.yml
```

Business Command Centers may **add** private entries (file `.agent-project-ops/export-strip-extra` or `--extra-strip` / `--extra-file` on the helper). Removing a methodology entry requires a new disposer ACK (Architecture Exception if a freeze already cited this list). Helpers have **no shrink API**.

This list is **stricter** than the ADR 0003 share-export denylist: export strips **all** of `.github/`, including business workflows. Share-export keeps `.github/workflows/` by default unless `--strip-all-github`.

### Sync protocol (fail closed, no force)

1. Disposer records an explicit sync authorization on the Issue (who, when, authority SHA, export URL without secrets).
2. Fetch authority and export.
3. Work from the **current export tip**. Do **not** reset to `origin/main` and drop prior strip commits (that is the non-FF failure mode already seen in practice).
4. Merge the current authority tip into that export tip.
5. Replay strip: delete strip-list paths the merge newly introduced (and any that remained).
6. Commit if the tree changed.
7. Verify content identity. If it does not hold → stop; do not push.
8. Fast-forward push only. If the remote rejects, or the update would not be an ancestor FF → **stop**. Never `--force` / `--force-with-lease`.

First seed (empty export branch): checkout the authority tip, strip, commit, push. That keeps history related so later sync can merge.

### Defense: not on the auto-push whitelist

A classified `export=` remote may exist on a bound clone for **fetch**. The client hook **denies every `git push`** from that bound working tree to the export name. The error tells the Agent to use [`scripts/export-sync.sh`](../../scripts/export-sync.sh) only after disposer `--authorized`.

Silent / scheduled / hook-driven export updates are forbidden. No `--authorized` → no push.

### Relationship to ADR 0003 / `share-export.sh`

These are **related helpers**, not two write authorities.

| Surface | Contract | History | Typical use |
| --- | --- | --- | --- |
| **`export=` remote + `export-sync.sh`** | This ADR. Tree = authority − **#46 strip list**. Sync = merge + replay strip + FF. | Related to authority (seed from authority tip + strip commits). Export tip may be ahead. | Colleague GitLab copy that must stay content-current without EXCEPTION |
| **`share-export.sh`** | ADR 0003. Filtered **snapshot** publish. Default denylist **keeps** `.github/workflows/`. | New snapshot history (not GitHub SHAs). Subsequent publish commits onto the existing destination branch. | One-shot or snapshot republish when related-history sync is not the contract |

`share_export=` / `share_export_url=` remain valid registry aliases with the **same bound-clone push deny** as `export=`. New registries should write `export=` / `export_url=`. Do not register the same name as both `projection=` and `export=` / `share_export=`.

Do not `git push` the bound working tree to either destination. Do not invent a second Issues/PR host.

## Consequences

- Playbooks/skills classify colleague GitLab as **export** (or share-export snapshot), never as projection, never as a second SoT.
- Bootstrap writes `export=(none)` / `export_url=` alongside the existing projection and share-export keys.
- Merge of the implementation PR is **not** Phase PASS ([PRINCIPLES.md](../../PRINCIPLES.md) §3).

## Non-goals

- Changing zentao-mcp or other business repos in the methodology PR (they adopt later)
- Force-push semantics
- Removing methodology strip entries at business discretion
- Bidirectional sync / reflux from GitLab
- Automatic / unauthorized sync
- A second write authority

## See also

- [PRINCIPLES.md](../../PRINCIPLES.md) §10
- [playbooks/export-remote.md](../../playbooks/export-remote.md)
- [playbooks/share-export.md](../../playbooks/share-export.md)
- [playbooks/git-authority-and-projection.md](../../playbooks/git-authority-and-projection.md)
- [docs/adr/0003-share-export-vs-projection.md](./0003-share-export-vs-projection.md)
- [skills/export-remote/SKILL.md](../../skills/export-remote/SKILL.md)
- [scripts/export-sync.sh](../../scripts/export-sync.sh)
