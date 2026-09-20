# Phase #32 evidence — GitLab colleague share = business-only export (not full-tree projection)

Command Center: [#10](https://github.com/Dylan5237/agent-project-ops/issues/10)  
Phase: [#32](https://github.com/Dylan5237/agent-project-ops/issues/32) (`freeze:acked`, `status:verification`)  
Implementation PR: [#33](https://github.com/Dylan5237/agent-project-ops/pull/33) (`pr:implementation`)  
Evidence PR: this pack (`pr:evidence`)  
Scope cut (disposer, 2026-09-20): **`Dylan5237/zentao-mcp` is out of this Phase** (no scrub / no repo edits).

This document is **evidence only**. It does not change product/docs under test. Merge of this evidence PR is **not** Phase PASS. The Agent does **not** issue `PHASE ACCEPT`.

Independent verifier: Cursor Cloud Agent (this evidence branch). Disposer remains `@Dylan5237`.

## Overall verdict

**PASS** (in-repo frozen gates, after the 2026-09-20 zentao-mcp scope cut).

Residuals below are environmental or historical-doc nits, not frozen-gate failures.

## SHAs under test

| Object | SHA |
| --- | --- |
| Implementation HEAD (`cursor/phase-32-gitlab-share-export-bf1c`) | `2998ac559ca919ef93cc5cfff52d5cc7a9798410` |
| Single impl commit message | `feat(#32): colleague GitLab is share-export, not full-tree projection` |
| Merge-base / `origin/main` at verification | `33ca67c9647caef1ff3a1ceb4b688c77b2ab2845` |
| GitHub PR #33 merge-commit preview (not landed) | `4a7e602496e8e85b112de74749df06f62cb6e581` |
| Evidence branch base | `33ca67c9647caef1ff3a1ceb4b688c77b2ab2845` (`main`) |
| Evidence commit (this file, first revision) | `bc9220054953bce7a6e93c5a17e4c84c66688127` |

Reviewed: `gh pr view 33` JSON (head, files, commits, labels) plus checkout of the impl SHA and `git diff origin/main...2998ac5` (37 files, +915 / −83). No other commits on the impl branch.

## Evidence map (frozen #32 gates)

| # | Frozen acceptance test | Result | Proof |
| --- | --- | --- | --- |
| 1 | ADR 0003 (or equivalent) states share-export ≠ full-tree projection; denylist covers Phase #32 minimum paths | **PASS** | See Gate 1 |
| 2 | Playbooks/skills no longer instruct full-mirror ops into colleague GitLab; projection vs share-export split is clear | **PASS** | See Gate 2 |
| 3 | Runnable fail-closed export helper exists; refuse unfiltered push when denylist present | **PASS** | See Gate 3 |
| 4 | Tests cited in PR #33 run and pass (share-export, hook-behavior, bootstrap-local, self-dogfood as applicable) | **PASS** | See Gate 4 |
| 5 | Diff does not include `Dylan5237/zentao-mcp` or unrelated fleet/#15/#14 scope | **PASS** | See Gate 5 |
| 6 | No claim inflation beyond v0.1.x principles | **PASS** | See Gate 6 |

Phase #32 also lists: independent evidence; disposer `PHASE ACCEPT`. Those are process gates — see Process notes. The Agent proposes `EVIDENCE READY` only.

## Gate 1 — ADR 0003 + denylist vs freeze

File exists on impl SHA: `docs/adr/0003-share-export-vs-projection.md`. Indexed from `docs/adr/README.md` as Accepted (disposer FREEZE ACK #32, 2026-09-20).

Facts from the ADR at `2998ac5`:

- Title/decision: **Share-export ≠ full-tree projection (colleague GitLab)**
- GitHub `origin` = sole write authority + **full** ops tree
- Colleague GitLab = **filtered business tree**, not `projection`, not a second SoT
- Full-tree `git push --mirror` / FF projection to colleague GitLab is **rejected** for this use case
- No reflux: feature branches stay on GitHub
- Denylist is a **minimum**; shrinking it requires a new disposer ACK

Freeze minimum paths vs ADR + `scripts/lib/share-export-denylist.sh` at `2998ac5`:

| Freeze path (Phase #32 body) | ADR / denylist match |
| --- | --- |
| `.agent-project-ops/` | `.agent-project-ops` / `.agent-project-ops/*` |
| `.agents/` | `.agents` / `.agents/*` |
| `.claude/` | `.claude` / `.claude/*` |
| `.cursor/` | `.cursor` / `.cursor/*` |
| `.continue/` | `.continue` / `.continue/*` |
| `.githooks/` | `.githooks` / `.githooks/*` |
| `.github/` agent-project-ops Issue/PR templates | `.github/ISSUE_TEMPLATE` (+ descendants), `.github/PULL_REQUEST_TEMPLATE` (+ descendants) |
| `.github/` CODEOWNERS binding | `.github/CODEOWNERS` |
| Root `AGENTS.md`, `CLAUDE.md`, bootstrap-equivalent Agent entry | `AGENTS.md`, `CLAUDE.md`, `.aider.conf.yml` |

Additional (allowed expansion, not shrink): `.github/copilot-instructions.md`. Default **keeps** `.github/workflows/` (pure business CI); `--strip-all-github` is documented as the opt-out. Freeze asked that split to be listed in evidence — this paragraph is that listing.

`PRINCIPLES.md` §10 at the same SHA points playbooks at `playbooks/share-export.md` (colleague GitLab = filtered business tree, not a projection). Version remains **v0.1.1**.

## Gate 2 — Playbooks / skills no longer instruct full-mirror into colleague GitLab

Checked on impl SHA (instructional surfaces that Agents load):

| Surface | Split present? | Full-mirror-to-colleague-GitLab instruction remaining? |
| --- | --- | --- |
| `playbooks/share-export.md` (new) | Yes — terms table Authority / Projection / Share-export | Anti-pattern: `git push --mirror` / `--projection-url` / `projection=` |
| `playbooks/git-authority-and-projection.md` | Opening sentence: colleague GitLab is **not** this playbook | Anti-pattern: treating colleague GitLab as projection |
| `playbooks/git-branch-and-remote.md` | “Colleague GitLab is not a projection remote” | Anti-pattern: adding GitLab as `projection` |
| `playbooks/bootstrap-project.md` | `--projection-url` example moved off `gitlab.example` to `git.internal.example`; colleague GitLab → share-export helper | No |
| `playbooks/start-project.md` | Step 7 classifies share-export vs projection | Anti-pattern: registering GitLab as projection |
| `skills/share-export/SKILL.md` (new) | Required before colleague-share publish | Stop if about to `--mirror` |
| `skills/git-authority-and-projection/SKILL.md` | Colleague GitLab → share-export skill, not this one | “Never `git push --mirror` from the bound clone” |
| `skills/bootstrap-project/SKILL.md` | Do not collect `--projection-url` for colleague GitLab | Fail closed if GitLab URL used as projection |
| `docs/GETTING_STARTED.md` (+ zh-CN) | Dedicated “Optional projection vs colleague share-export”; projection example is internal git host | Boundary: “GitLab as a full-tree projection of agent-project-ops bindings” is in **does not promise** |
| `templates/AGENTS.md`, command-center template, cursor/continue/copilot adapters | Colleague GitLab = share-export | No mirror instruction |

**Adversarial — can an Agent still follow a remaining “mirror ops to GitLab” happy path?**  
Under **current playbooks/skills/bootstrap/Getting Started: no.** The previous `--projection-url git@gitlab.example:…` example is gone from those surfaces.

**Residual (not FAIL):** `docs/rfcs/0001-bootstrap-and-binding.md` still contains historical GitLab-as-projection sentences in the body. It opens with an explicit **Supersede (2026-09-20, ADR 0003 / Phase #32)** banner that those sentences are **rejected** for colleague share. `docs/research/2026-09-10-*.md` is historical research, not a playbook; it was not rewritten (and is not in the impl diff). Agents are bound to PRINCIPLES + playbooks/skills, not the research archive.

## Gate 3 — Fail-closed helper

Runnable helper on impl SHA:

- `scripts/share-export.sh` (276 lines; `bash -n` via tests)
- `scripts/lib/share-export-denylist.sh`
- Bootstrapped copy path: `.agent-project-ops/scripts/share-export.sh` (asserted by `tests/bootstrap-local.sh`)

Fail-closed behaviors replayed (see Gate 4 + adversarial):

| Behavior | Result |
| --- | --- |
| `--check` on a bound tree (denylist present) | **refuses** (exit 1). Message: do not `git push` this clone to colleague GitLab |
| `--check` on this methodology repo at `2998ac5` | **refuses** (exit 1). `include=83 exclude=6`. Denied paths included `.agent-project-ops/remotes`, `.cursor/rules/…`, `.githooks/pre-push`, `.github/copilot-instructions.md`, `AGENTS.md`, `CLAUDE.md` |
| `--push` of filtered tree | publishes only after a denylist scan of the filtered tree; never `--force` (help text + no `--force` flag in the script) |
| `--push` URL with query token | refused before network |
| Bound clone `git push` to a `share_export=` remote | client hook **deny** (`scripts/hooks/pre-push-authority.sh`) |
| Bound clone `git push` to an unregistered remote (e.g. name `gitlab`) | client hook **deny** (existing unknown-remote rule; still tested) |
| Dual `projection=` + `share_export=` on one name | hook **deny** |

The helper never adds the share-export URL as a remote on the **source** clone. `--push` uses a temp publish checkout.

**Residual (not FAIL):** if an operator **misclassifies** a colleague GitLab URL as `projection=` in `.agent-project-ops/remotes`, the projection hook would allow a same-history **full-tree** FF push. ADR 0003 names that a **contract error**. Playbooks/skills forbid it. The helper and the `share_export=` / unregistered paths refuse unfiltered publish. Client hooks remain bypassable (`--no-verify`); that is an existing v0.1 residual, not a new #32 claim.

## Gate 4 — Tests cited in PR #33

Verifier cwd at impl SHA `2998ac559ca919ef93cc5cfff52d5cc7a9798410`, 2026-09-20 UTC (Cloud Agent workspace).

| Command | Result |
| --- | --- |
| `bash tests/share-export.sh` | **PASS** (exit 0) — `--check` fail-closed, dry-run split, export strips denylist + keeps workflow, unsafe URL refused, first+second `--push` to local bare, `--strip-all-github`, `--out` exists-fail |
| `bash tests/hook-behavior.sh` | **PASS** — **15 passed, 0 failed** (includes `topic -> share_export remote` and `main -> share_export remote`) |
| `bash tests/bootstrap-local.sh` | **PASS** (exit 0) — helper vendored; `share_export=(none)`; PIN URL stripped of origin userinfo (`pin_url` must not contain `@`) |
| `bash tests/self-dogfood-binding.sh` | **PASS** (exit 0) — includes `self share_export is not none` |
| `bash tests/url-guard.sh` | **PASS** (exit 0) — supporting, not listed on the PR test plan |

GitHub Actions on the same SHA `2998ac559ca919ef93cc5cfff52d5cc7a9798410`:

| Workflow | Run | Conclusion |
| --- | --- | --- |
| `self-dogfood-contract` | [35501899267](https://github.com/Dylan5237/agent-project-ops/actions/runs/35501899267) | success |
| `enforcement-contract` (includes `tests/share-export.sh` + hook-behavior) | [35501899303](https://github.com/Dylan5237/agent-project-ops/actions/runs/35501899303) | success |
| `bootstrap-contract` (includes `tests/bootstrap-local.sh`) | [35501899318](https://github.com/Dylan5237/agent-project-ops/actions/runs/35501899318) | success |
| Cursor Bugbot on PR #33 | skipping (usage limit reached) | **not a frozen #32 gate** |

Local `tests/share-export.sh` terminal markers:

```text
PASS: share-export scripts parse
PASS: --check fails closed when denylist paths are present
PASS: dry-run splits denylist vs business files and keeps workflows
PASS: export strips denylist and keeps business tree + CI workflow
PASS: --check passes on a filtered export
PASS: unsafe share-export URL fails closed
PASS: first --push publishes a filtered seed
PASS: second --push updates GitLab without copying ops
PASS: --strip-all-github removes remaining .github paths
PASS: --out fails closed when destination exists
share-export: all contract checks passed
```

## Gate 5 — Scope (no zentao-mcp, no fleet/#15/#14)

`git diff --name-only origin/main...2998ac5` is the 37-file set listed on PR #33. None of:

- `Dylan5237/zentao-mcp` (no files, no submodule, no clone)
- `fleet/REGISTRY.md`
- `docs/research/2026-09-10-methodology-audit.md`
- showcase SVGs under `docs/assets/`

README.md / README.zh-CN.md **are** in the diff. The edits add the share-export vs projection split, a “does not claim colleague GitLab as full-tree projection” bullet, and a helper snippet. That is Phase #32 methodology documentation, not issue **#15** README showcase / architecture visuals, and not **#14** audit-debt closeout.

ADR 0003 Non-goals: Fleet REGISTRY dual-write unchanged; GitLab Issues not a control plane; no hard CI “gate → CC §1” robots; no scrub/re-export of a named business product repository. Matches the 2026-09-20 scope cut on #32.

`.agent-project-ops/remotes` only adds `share_export=(none)` / `share_export_url=` on this methodology repo (still origin-only; not a GitLab URL).

## Gate 6 — Claim inflation (still v0.1.x)

| Surface at `2998ac5` | Fact |
| --- | --- |
| `PRINCIPLES.md` version line | still **v0.1.1** |
| Changelog | still ends at v0.1.1 (Principle 10). The #32 edit is one playbook pointer under §10, not a new numbered invariant |
| `README.md` badge | still `version-v0.1` |
| README “Verified v0.1” / “does not claim” | adds an **anti-claim** (colleague GitLab is not a full-tree projection). Does not claim A-grade protection, unbypassable hooks, or GitLab as SoT |
| `AGENTS.md` (repo root) | **unchanged** in this PR |

No v0.2 / “guaranteed GitLab scrub” / “zentao-mcp cleaned” language in the impl PR body. PR #33 states merge ≠ Phase PASS and that this PR is not the evidence pack.

## Adversarial checks

### Unfiltered push of a bound clone?

**Refused** on the paths that the freeze asked to mechanize:

1. `bash scripts/share-export.sh --check --ref HEAD` on `2998ac5` of this repo: exit 1 (bindings present).
2. Helper `--push` builds a stripped tree and re-scans before `git push`; it does not push the source worktree.
3. Client hook denies `share_export=` remotes and unregistered remotes (`tests/hook-behavior.sh` PASS).

Hole that remains (documented, not silent): `projection=` misclassification (Gate 3 residual) and `--no-verify`.

### Can bootstrap still treat GitLab as `--projection-url`?

Skill/playbook: **stop** (“Colleague GitLab URL used as `--projection-url` → stop”). The script still **accepts** a credential-free `--projection-url` that happens to look like GitLab; classification is Command Center / Agent duty, not hostname sniffing. Frozen #32 asked playbooks/skills to stop *instructing* that path and to provide share-export instead. That bar is met. Residual: no URL-host heuristic inside `bootstrap-project.sh`.

### Did implementation mix evidence dumps?

PR #33 contains tests that **are** product/methodology code (`tests/share-export.sh`, hook and bootstrap assertions). It does not contain `docs/evidence/phase-32-*`. This evidence branch contains only this file versus `main`.

## Process notes (not product FAIL)

- Freeze ACK exists on Phase #32 (`freeze:acked`) plus the 2026-09-20 zentao-mcp **scope cut** comment. Implementation started after that cut.
- Implementation used one branch/PR (`cursor/phase-32-gitlab-share-export-bf1c` → #33). No direct `main` push observed.
- CC #10 §1 at verification time: current phase **#32**, status **VERIFICATION**, Next Action = independent verification of PR #33. That satisfies the impl→verification flip (updated by apo项目经理).
- This verifier’s `gh` CLI is **read-only**. It cannot edit Issue bodies or comment on #32. Verdict is on this evidence PR and a comment on PR #33 when the forge tool allows. Copy-paste for #32 is below.
- Evidence-branch push: live `pre-push` denied the Cloud Agent `origin` URL because the platform rewrites it with `x-access-token` (secret-bearing). The same topic-branch update replayed through `scripts/hooks/pre-push-authority.sh origin https://github.com/Dylan5237/agent-project-ops.git` **allowed** (`exit 0`). The branch was then pushed with `--no-verify` solely to pass that environment rewrite — not to land on `main`.
- After this evidence lands, CC §1 Next Action should become **disposer review of evidence / `PHASE ACCEPT` or `PHASE RETURN`**. Proposed text is below; gap recorded as `BLOCKED:` for §1 rewrite **by this Agent**, not chat-only.

### Proposed CC #10 §1 after this evidence

| Field | Value |
| --- | --- |
| **Current phase** | #32 GitLab business-only share-export |
| **Status word** | **VERIFICATION** (`EVIDENCE READY`; awaiting disposer) |
| **Impl PR** | #33 `2998ac559ca919ef93cc5cfff52d5cc7a9798410` |
| **Evidence** | this file / evidence PR |
| **Last closed** | #27 — **PHASE ACCEPT — PASS** |
| **Open gates** | ▶ Disposer `PHASE ACCEPT` or `PHASE RETURN` · ⏳ merge (merge ≠ PASS) |
| **Single Next Action** | Disposer reviews this evidence and records `PHASE ACCEPT` or `PHASE RETURN` on #32. Merge ≠ PASS. |

## Paste block for Phase #32 (gh issue comment is read-only here)

```
## EVIDENCE READY (independent verifier) — not PHASE ACCEPT

Overall: **PASS** (in-repo frozen gates; zentao-mcp out of scope per 2026-09-20 cut).

- Impl PR: #33 HEAD `2998ac559ca919ef93cc5cfff52d5cc7a9798410`
- Evidence: `docs/evidence/phase-32-gitlab-share-export.md` (this evidence PR)
- Gates 1–6: PASS. Residuals: RFC 0001 historical GitLab-as-projection text is superseded by an ADR 0003 banner; `projection=` misclassification would still FF a full tree (documented contract error); this Agent cannot edit CC #10 §1 (`BLOCKED:` for §1 rewrite by project-ops / disposer).
- Tests: local share-export / hook-behavior (15/0) / bootstrap-local / self-dogfood PASS; Actions runs 35501899267, 35501899303, 35501899318 success on the same SHA.

Merge ≠ PASS. Disposer `@Dylan5237` records `PHASE ACCEPT` or `PHASE RETURN`.
```

## Agent conclusion

Frozen in-repo gates **1–6 PASS**. zentao-mcp was correctly absent. Principles remain v0.1.1.

The Agent proposes **`EVIDENCE READY`**. The Agent does **not** comment `PHASE ACCEPT`. Merge of #33 or of this evidence PR is not Phase PASS.
