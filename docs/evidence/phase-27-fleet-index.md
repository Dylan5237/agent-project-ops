# Phase #27 evidence — Fleet index SoT + CC §1 / REGISTRY auto-ops

Command Center: [#10](https://github.com/Dylan5237/agent-project-ops/issues/10)  
Phase: [#27](https://github.com/Dylan5237/agent-project-ops/issues/27) (`freeze:acked`, `status:verification`)  
Implementation PR: [#28](https://github.com/Dylan5237/agent-project-ops/pull/28) (`pr:implementation`)  
ADR decision: [#26](https://github.com/Dylan5237/agent-project-ops/issues/26) `DISPOSER ACK` — Option 3  
Ops covered: [#24](https://github.com/Dylan5237/agent-project-ops/issues/24), [#25](https://github.com/Dylan5237/agent-project-ops/issues/25)

This document is **evidence only**. It does not change product/docs under test. Merge of this evidence PR is **not** Phase PASS. The Agent does **not** issue `PHASE ACCEPT`.

## Overall verdict

**PASS** (in-repo frozen gates). Residual noted below is environmental, not a product defect.

Independent verifier: Cursor Cloud Agent (this evidence branch). Disposer remains `@Dylan5237`.

## SHAs under test

| Object | SHA |
| --- | --- |
| Implementation HEAD (`cursor/phase-27-fleet-index-b305`) | `29e72bdabaf1f5e3785f1d767575b2ca8cc843c3` |
| Single impl commit message | `feat(#27): fleet REGISTRY SoT + CC §1 / bootstrap auto-ops` |
| Merge-base / `origin/main` at verification | `82c99296342364739fcacfe8f46f602d2535f8f0` |
| GitHub PR #28 merge-commit preview (not landed) | `ba1e5679b828063d4bce873e7e9c62166cb4b38f` |
| Evidence branch base | `82c99296342364739fcacfe8f46f602d2535f8f0` (`main`) |

Reviewed: `gh pr view 28` JSON (head, files, commits) plus checkout of the impl SHA and `git diff origin/main...29e72bd` (20 files, +249 / −20). No other commits on the impl branch.

## Evidence map (frozen #27 gates)

| # | Frozen acceptance test | Result | Proof |
| --- | --- | --- | --- |
| 1 | ADR under `docs/` stating Option 3 (SoT, mirror, upsert key, migration) | **PASS** | `docs/adr/0002-canonical-fleet-index.md` at `29e72bd`: **Option 3 — git source of truth + box mirror.** SoT `fleet/REGISTRY.md`; mirror `/home/box/agent-data/fleet-morning-digest/REGISTRY.md`; upsert key `owner/repo`; **Migration** section seeds from 2026-09-20 box REGISTRY, then git-first. Rejects Issue-as-SoT. |
| 2 | `fleet/REGISTRY.md` present; row set vs PR claim (8 projects); no silent drops; upsert key documented | **PASS** vs PR claim; **residual BLOCKED** vs live box file | See Gate 2. |
| 3 | Bootstrap skill + playbook: mandatory Register to Fleet REGISTRY; fail closed if skipped; disposer phrase 「已纳入舰队晨报扫描」 | **PASS** | See Gate 3 (fail-closed wording cited). |
| 4 | `skills/github-multi-agent-project-ops`: CC §1 mandatory Agent duty; checklist 「CC §1 updated」; fail closed if cannot update CC | **PASS** | See Gate 4. |
| 5 | Duty mirrored in phase-lifecycle and/or staff-and-dispatch (and related if claimed) | **PASS** | See Gate 5. |
| 6 | No scope creep into #15 README showcase or #14 audit debt | **PASS** | Diff does not touch `README.md` / `README.zh-CN.md` / showcase assets. ADR Non-goals name #15 and #14. `fleet/REGISTRY.md` column “#15” is **agent-team-workbench’s Command Center**, not this repo’s issue #15. |
| 7 | PRINCIPLES/AGENTS claim inflation check (still v0.1.x; no overclaim) | **PASS** | `PRINCIPLES.md` still **v0.1.1** (one clarifying sentence under Chat ≠ State; no new numbered invariant, no changelog bump). `AGENTS.md` adds two pointer lines (CC §1 duty + fleet SoT). `README*` unchanged; badge remains v0.1. |
| 8 | Run relevant repo tests; record results + SHAs | **PASS** (CI + local contracts that can run here) | See Tests. |

Phase #27 also lists: evidence pack itself; CC #10 §1 on label moves; independent verification before disposer Accept. Those are process gates — see Process notes.

## Gate 1 — ADR Option 3

File exists: `docs/adr/0002-canonical-fleet-index.md` (added on `29e72bd`). Indexed from `docs/adr/README.md`.

Facts from the ADR at that SHA:

- Decision heading: **Option 3 — git source of truth + box mirror.**
- SoT: `fleet/REGISTRY.md` in `Dylan5237/agent-project-ops`
- Mirror: `/home/box/agent-data/fleet-morning-digest/REGISTRY.md`
- Upsert key: `owner/repo` (idempotent; one row per repository)
- Migration: seed from 2026-09-20 box REGISTRY (same columns/rows; no silent drops); after land, box becomes a mirror; subsequent upserts go to git first
- Rejected for SoT: long-lived Issue-as-index
- Box path is **not** a second write authority (Principle 10)

Matches disposer comment on #26 (`DISPOSER ACK — Option 3`, 2026-09-20).

## Gate 2 — `fleet/REGISTRY.md` row set

File present on impl SHA. Header documents SoT, mirror path, and **Upsert key: `owner/repo`**.

Data rows parsed from `fleet/REGISTRY.md` at `29e72bd` (8 rows, 8 unique `owner/repo`, 0 duplicates):

| 项目 | Repo (`owner/repo`) | Command Center |
| --- | --- | --- |
| 天宫组件协同 | Dylan5237/tiangong-component-collab | #2 |
| 伏羲平台 | Dylan5237/prototype-manager | #11 |
| Arckeep / kcc | Dylan5237/kcc-workbench | #2 |
| safe-delete-cli | Dylan5237/safe-delete-cli | #1 |
| agent-project-ops | Dylan5237/agent-project-ops | #10 |
| agent-team-workbench | Dylan5237/agent-team-workbench | #15 |
| req-to-page | Dylan5237/req-to-page | #6 |
| architecture-expert | Dylan5237/architecture-expert | （待确认 CC；门禁常看 #12） |

PR #28 body claimed exactly these eight names. **Match: 8/8 vs PR claim. No duplicate upsert keys.**

**Residual BLOCKED (independent vs-box replay):** this verifier VM has no `/home/box` (`ls: cannot access '/home/box': No such file or directory`). Issues #26/#27 and PR #28 do **not** attach a dated dump of the 2026-09-20 box file. Therefore “no silent drops vs box REGISTRY” cannot be replayed here. It is an implementer attestation. Disposer (or a box-side Agent) should compare the live box file to the table above before `PHASE ACCEPT`. This residual is **not** a silent drop; it is a missing independent snapshot.

Columns on the git file: `项目 | Repo | Command Center | 备注` — claimed “same table columns as the box file”; same residual applies.

## Gate 3 — Bootstrap fail-closed + confirm phrase

Mandatory step and disposer phrase are present:

`skills/bootstrap-project/SKILL.md` required path item 9 (impl SHA):

> **Register to Fleet REGISTRY** (mandatory; fail closed if skipped). After Command Center exists, upsert one row in `Dylan5237/agent-project-ops` `fleet/REGISTRY.md` keyed by `owner/repo` … Confirm to the disposer: **「已纳入舰队晨报扫描」**. Bootstrap is not done without this step.

Fail-closed bullet in the same skill:

> Fleet REGISTRY row skipped, duplicated, or left only in chat → stop; do not claim bootstrap done. Mirror unwritable → still land the git row and report `BLOCKED:` on GitHub for the mirror gap.

`playbooks/bootstrap-project.md`: After-bootstrap step 5 is Register to Fleet REGISTRY with the same phrase; **Done when** includes a required checkbox for the git row + mirror confirm or GitHub `BLOCKED:` + 「已纳入舰队晨报扫描」. Skipping step 5 is fail closed. Anti-pattern: treating bootstrap as done because the business repo exists while absent from `fleet/REGISTRY.md`.

Also on `playbooks/start-project.md` (step 6 + Done-when checkbox) and `fleet/README.md`.

**Adversarial — can bootstrap be marked done without fleet register?**  
Under the **skill/playbook contract: no.** Claiming done while the row is skipped/duplicated/chat-only must stop.  

`scripts/bootstrap-project.sh` can still exit 0 after local/GitHub **scaffold** (`local scaffold complete` / `done. Next: open Command Center…`) without writing `fleet/REGISTRY.md`. That script never upserts the methodology fleet file (a later PR on this repo, after Command Center exists). Frozen #27 asked for skill/playbook/checklist fail-closed, not a shell abort. Residual, not FAIL: mechanical script success ≠ playbook-done.

## Gate 4 — CC §1 mandatory Agent duty

`skills/github-multi-agent-project-ops/SKILL.md` at `29e72bd`:

> Keeping Command Center **section 1** current is **Agent work on every gate flip**, not a user habit.

Required checkbox:

> - [ ] **CC §1 updated**

Fail closed if CC cannot be updated:

> If the Agent **cannot** update Command Center (auth, permissions, read-only `gh`, API failure): fail closed. Comment `BLOCKED:` with the gap on the Phase (or a new Command Center draft) and set `status:blocked`. Do **not** leave the new state only in chat.

Also:

> Gate flipped but CC §1 not updated → incomplete; treat as blocked until GitHub reflects it.  
> Cannot edit Command Center → `BLOCKED:` on GitHub, not chat-only.  
> Do not: Ask the human to “remember to update CC §1” as the primary path.

Templates: `templates/ISSUE_TEMPLATE/phase.md` and `templates/PULL_REQUEST_TEMPLATE/implementation.md` include **CC §1 updated**. Command Center template section 1 states Agent duty, not user habit.

## Gate 5 — Duty mirrored in playbooks

Present on impl SHA:

- `playbooks/phase-lifecycle.md` — intro: mandatory Agent duty; every step has `[ ] **CC §1 updated**`; fail closed to GitHub `BLOCKED:` if CC cannot be updated
- `playbooks/staff-and-dispatch.md` — project-ops Agent “Mandatory duty”; dispatch/recall/Done-when checkboxes; anti-pattern “Treating CC §1 refresh as the human’s habit”
- Related (claimed by PR #28 and in-scope for gate flips): `playbooks/issues-and-prs.md`, `playbooks/blocked-and-exceptions.md`, `playbooks/verification-and-evidence.md`, `skills/issues-prs-and-evidence/SKILL.md`

Nit (not FAIL): `playbooks/verification-and-evidence.md` **Done when** repeats the same `CC §1 updated` checkbox twice (duplicate lines).

## Gate 6 — Scope

`git diff --name-only origin/main...29e72bd` is the 20-file set listed on PR #28. No `README.md`, no showcase SVGs, no `docs/research/2026-09-10-methodology-audit.md` edits, no attempt to close #14/#15. ADR Non-goals name those issues.

## Gate 7 — Claim inflation

- PRINCIPLES version line still `v0.1.1`. Changelog still ends at v0.1.1 (Principle 10). Added sentence is a pointer to the skill duty, not a new invariant number or a “v0.2 / guaranteed fleet scan” claim.
- AGENTS.md still discovers current Phase from Command Center; adds fleet SoT pointer + CC §1 duty.
- No README claim change on this PR.

## Tests (Gate 8)

Verifier cwd at impl SHA `29e72bdabaf1f5e3785f1d767575b2ca8cc843c3`, 2026-09-20T02:41:44Z UTC.

| Command | Result |
| --- | --- |
| `bash tests/self-dogfood-binding.sh` | **PASS** (exit 0) — all eight contract markers including fresh-clone takeover |
| `bash tests/url-guard.sh` | **PASS** (exit 0) |
| `bash tests/hook-behavior.sh` | **PASS** (13 passed, 0 failed) |
| `bash tests/bootstrap-local.sh` | **FAIL locally (exit 1)** — `bootstrap: error: methodology URL is unsafe` because this Cloud Agent `git remote get-url origin` is `https://x-access-token:<redacted>@github.com/…` and `url_has_secrets` rejects credential-bearing HTTPS. **Not attributed to Phase #27.** Same SHA on GitHub Actions `bootstrap-contract` **PASS**. |

GitHub Actions on `29e72bd`:

| Workflow | Run | Conclusion |
| --- | --- | --- |
| `self-dogfood-contract` | [35484548413](https://github.com/Dylan5237/agent-project-ops/actions/runs/35484548413) | success |
| `bootstrap-contract` | [35484548579](https://github.com/Dylan5237/agent-project-ops/actions/runs/35484548579) | success (includes `tests/bootstrap-local.sh`) |
| Cursor Bugbot | pending at verification time | not a frozen #27 gate |

## Adversarial checks

### Bootstrap done without fleet register?

**No** under skill/playbook. Fail-closed wording (cite):

`skills/bootstrap-project/SKILL.md`:

> Fleet REGISTRY row skipped, duplicated, or left only in chat → stop; do not claim bootstrap done.

`playbooks/bootstrap-project.md`:

> Skipping step 5 is fail closed. The bootstrap checklist cannot be marked done without the Fleet REGISTRY row (git SoT) and an explicit mirror confirm or GitHub `BLOCKED:` for the mirror gap.

Shell scaffold can still complete; that is not the playbook Done-when.

### Is Issue-as-SoT sneaking back?

**No.** ADR 0002 rejects long-lived Issue-as-index for the **fleet** SoT. Command Center issues remain the per-project control plane (already required). Fleet SoT is the git file; CC §1 is what the digest **reads** for registered rows, not a substitute registry. Forbidden on #27: “Making the long-lived Issue the SoT” — not done.

### Box-mirror sync / Grok Bot skill-copy deferred?

**Recorded, not silent.**

- ADR Consequences: “Digest-bot skill copies on the box are **out of scope** for Phase #27 (follow-up after merge; do not treat box skill text as SoT).”
- PR #28: box path not writable from the Cloud Agent; after merge, box ops must sync mirror to git SoT; Grok Bot skill-copy listed as NON-GOAL / deferred.
- Phase #27 Deferred: “Syncing Grok Bot box copies of skills outside this repo (follow-up after merge; note in evidence)” — this paragraph is that note.
- CC #10 §1 Open gates at verification time included `⏳ box mirror sync after merge · ⏳ Grok Bot skill-copy sync`.
- `#25` mentioned `grok-bot-project-ops`; that skill is **not in this repository** (glob `*grok*` = 0 files). Staffing copy landed in `playbooks/staff-and-dispatch.md` instead. Acceptable under Phase #27 deferred skill-copy.

## Process notes (not product FAIL)

- Freeze ACK exists on Phase #27 body + `freeze:acked`; #26 Option 3 ACK exists.
- Implementation used one branch/PR (`cursor/phase-27-fleet-index-b305` → #28). No direct `main` push observed.
- CC #10 §1 was updated to **VERIFICATION** by apo项目经理 after the impl Agent recorded `BLOCKED:` (read-only `gh`) on PR #28. Observed §1 at verification: current phase #27, status **VERIFICATION**, Next Action = independent verification. That satisfies the “CC §1 on label move” gate for the impl→verification flip.
- This verifier also cannot edit Issue bodies (`gh` read-only). After this evidence lands, CC §1 Next Action should become **disposer review of evidence / `PHASE ACCEPT` or `PHASE RETURN`**. Proposed text is below; gap recorded as `BLOCKED:` for §1 rewrite by this Agent, not chat-only.
- This verifier cannot comment on Issue #27 via `gh` (read-only). Verdict is on this evidence PR and a comment on PR #28. Copy-paste for #27 is below.

### Proposed CC #10 §1 after this evidence

| Field | Value |
| --- | --- |
| **Current phase** | #27 Fleet index SoT + CC§1 / REGISTRY auto-ops |
| **Status word** | **VERIFICATION** (`EVIDENCE READY`; awaiting disposer) |
| **Impl PR** | #28 `29e72bdabaf1f5e3785f1d767575b2ca8cc843c3` |
| **Evidence** | this file / evidence PR |
| **Last closed phase** | #11 self-dogfood — **PHASE ACCEPT — PASS** (2026-09-11) |
| **Open gates** | ▶ Disposer `PHASE ACCEPT` or `PHASE RETURN` · ⏳ box mirror sync after merge · ⏳ Grok Bot skill-copy sync · ⏳ optional box-file spot-check of 8 rows · ⏳ #15/#14 |
| **Single Next Action** | Disposer reviews this evidence and records `PHASE ACCEPT` or `PHASE RETURN` on #27. Merge ≠ PASS. |

## Agent conclusion

Frozen in-repo gates 1, 3–8 **PASS**. Gate 2 **PASS** against the PR-claimed 8 unique `owner/repo` rows; independent vs-box file comparison remains a disposer spot-check. Deferred box-mirror and Grok Bot skill-copy gaps are explicit.

The Agent proposes **`EVIDENCE READY`**. The Agent does **not** comment `PHASE ACCEPT`. Merge of #28 or of this evidence PR is not Phase PASS.
