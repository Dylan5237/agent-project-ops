# ADR 0003 — Share-export ≠ full-tree projection (colleague GitLab)

- **Status:** Accepted
- **Date:** 2026-09-20
- **Deciders:** disposer `@Dylan5237` `FREEZE ACK` on Phase [#32](https://github.com/Dylan5237/agent-project-ops/issues/32) (2026-09-20); Command Center [#10](https://github.com/Dylan5237/agent-project-ops/issues/10) §1
- **Implements:** Phase [#32](https://github.com/Dylan5237/agent-project-ops/issues/32)
- **Identity:** Methodology remote-classification only. No business SOP.

---

## Context

Principle 10 allows **at most one write authority**. An optional second git remote may be a **projection**: the same commit history, fast-forwarded from GitHub `origin`.

That projection model was easy to misread as “put GitLab next to GitHub and `git push --mirror`.” For **colleague share**, a full-tree mirror publishes `agent-project-ops` bindings (hooks, Agent entry files, pinned playbooks, Issue/PR templates, CODEOWNERS). Colleagues who should see product files would also receive the ops control plane.

Phase #32 freeze (2026-09-20):

- GitHub `origin` remains the sole write authority and keeps the **full** ops tree.
- Colleague GitLab is a **business-only export surface**, not a projection and not a second SoT.
- Full-tree git mirror/projection to colleague GitLab is **rejected** for this use case.

## Decision

Split two operations that share a host family but not a git contract:

| Mode | What it is | What it is not | Typical host |
| --- | --- | --- | --- |
| **Projection** | Optional **same-history** mirror: fetch + fast-forward (or disposer-authorized align) of the authority tip, **including** ops bindings | A feature host, a control plane, or a place to rewrite history | An internal git host the Command Center **names as projection** |
| **Share-export** | A **filtered business tree** published for colleagues: denylist paths stripped (or the push is refused) | A `git push --mirror` / FF projection of GitHub history | **Colleague GitLab** (this freeze) |

Rules:

1. **GitHub `origin`** = only write authority; Issues/PRs; full `agent-project-ops` binding stays there.
2. **Colleague GitLab** = share-export only. Do not register it as `projection`. Do not `git push` the bound working tree there. Do not describe it as a full-tree projection.
3. **Projection** remains valid only when Command Center classifies a remote as a same-history FF mirror. That is a different use case from colleague share.
4. **No reflux:** colleagues do not open feature branches on GitLab to land back on GitHub. Forks and PRs stay on GitHub.
5. The denylist below is a **minimum**. Implementations may add paths. Shrinking it requires a new disposer ACK (Architecture Exception if a freeze already cited this list).

### Denylist (minimum)

These paths must not appear in a colleague share-export (directory prefixes include the directory itself and every descendant):

| Path | Why |
| --- | --- |
| `.agent-project-ops/` | Pinned methodology snapshot, PIN, remotes registry, vendored playbooks/scripts |
| `.agents/` | Project skill wrappers |
| `.claude/` | Claude skill wrappers |
| `.cursor/` | Cursor rules / Agent config |
| `.continue/` | Continue rules |
| `.githooks/` | Tracked Agent hook install path (`core.hooksPath=.githooks`) |
| `.github/ISSUE_TEMPLATE/` | agent-project-ops Command Center / Phase / Exception templates |
| `.github/PULL_REQUEST_TEMPLATE/` | agent-project-ops implementation / evidence PR templates |
| `.github/CODEOWNERS` | Disposer CODEOWNERS binding |
| `.github/copilot-instructions.md` | Bootstrap Copilot adapter (Agent entry) |
| `AGENTS.md` (repository root) | Canonical Agent binding entrypoint |
| `CLAUDE.md` (repository root) | Bootstrap Claude adapter → `AGENTS.md` |
| `.aider.conf.yml` (repository root) | Bootstrap Aider adapter (Agent entry) |

**`.github/workflows/` (business CI):** keep by default. Bootstrap does not install methodology CI into a business repo. If a repo has **pure business** GitHub Actions, leave them in the export. If a workflow exists only to enforce agent-project-ops, add that file to an extra denylist rather than deleting all workflows.

To strip every `.github/` path, pass `--strip-all-github` on the helper (documented exception, not the default).

Root **bootstrap-equivalent Agent entry files** are the files bootstrap writes at repo root for Agents (`AGENTS.md`, `CLAUDE.md`, `.aider.conf.yml`). Other root Agent instruction files must not be added to a share-export without an ACK that they are business docs rather than bindings.

### How to publish (fail closed)

Use [`scripts/share-export.sh`](../../scripts/share-export.sh) (copied into a bootstrapped project as `.agent-project-ops/scripts/share-export.sh`):

- Build a filtered tree from an authority ref.
- **Refuse** to push if any denylist path is still present.
- **Refuse** to `git push` the bound working clone to a share-export URL (that would leak ops).
- Never `--force`. Subsequent exports commit onto the existing GitLab branch when it already exists (new snapshot commit, not a rewrite of GitHub history).

Classifying a colleague GitLab URL as `projection` in `.agent-project-ops/remotes` is a contract error: the projection hook would then allow a full-tree FF push.

Share-export destinations are **not** day-to-day git remotes on the business clone. If a share-export remote name is recorded in the registry, the client hook **denies every push** from the bound working tree to that name and points at the helper.

## Consequences

- Playbooks/skills must not tell Agents to full-mirror ops into colleague GitLab.
- Bootstrap `--projection-url` is not the colleague-share path. Examples that used GitLab as “the projection host” are superseded for that use case.
- Merge of the implementation PR is **not** Phase PASS ([PRINCIPLES.md](../../PRINCIPLES.md) §3).

## Non-goals

- Fleet REGISTRY dual-write model (ADR 0002) unchanged
- GitLab Issues as a control plane
- Hard CI “gate → Command Center §1” robots
- Scrubbing or re-exporting any named business product repository in this ADR (Phase #32 implementation in this methodology repo only, after the 2026-09-20 scope cut)

## See also

- [playbooks/share-export.md](../../playbooks/share-export.md)
- [playbooks/git-authority-and-projection.md](../../playbooks/git-authority-and-projection.md)
- [skills/share-export/SKILL.md](../../skills/share-export/SKILL.md)
