# Phase #36 evidence — Free-private capability C is expected (record and continue)

Command Center: [#10](https://github.com/Dylan5237/agent-project-ops/issues/10)  
Phase: [#36](https://github.com/Dylan5237/agent-project-ops/issues/36) (`freeze:acked`, `status:verification`)  
Implementation PR: [#38](https://github.com/Dylan5237/agent-project-ops/pull/38) (`pr:implementation`)  
Evidence PR: [#39](https://github.com/Dylan5237/agent-project-ops/pull/39) (`pr:evidence` requested)  
Freeze: 2026-09-22 on #36 — C is expected on GitHub Free private; record on CC and continue; not a hard bootstrap stop; never claim B/A when only C.

This document is **evidence only**. It does not change product/docs under test. Merge of this evidence PR is **not** Phase PASS. The Agent does **not** issue `PHASE ACCEPT`.

Independent verifier: Cursor Cloud Agent (this evidence branch). Disposer remains `@Dylan5237`.

## Overall verdict

**PASS** (frozen in-repo gates 1–5).

Residuals below are historical-RFC wording or verifier-environment limits, not frozen-gate failures.

Merge of PR #38 ≠ Phase PASS.

## SHAs under test

| Object | SHA |
| --- | --- |
| Implementation HEAD (`cursor/phase-36-free-private-c-55b8`) | `b040e32225f81c15264332f559f993460199817e` |
| Single impl commit message | `feat(#36): treat Free-private capability C as expected, not a hard stop` |
| Merge-base with `origin/main` at impl time | `074cb489c9e52162e35cc32e25a8e56910fb3bbe` |
| `origin/main` at this verification | `091c302c2501d07d36166fe5dbea0624bf0cc294` |
| Evidence branch base | `091c302c2501d07d36166fe5dbea0624bf0cc294` (`main`) |
| Evidence commit (this file, first revision) | `a66893b63707f7cc605071dec3296159bada0bdc` |

Reviewed: `gh pr view 38` JSON (head `b040e32`, 13 files, +136 / −36, label `pr:implementation`, not draft) plus checkout of the impl SHA and `git diff 074cb48...b040e32`. One commit on the impl branch. `origin/main` has since landed PR #37 (fleet PM note); that commit is **not** in the impl diff.

GitHub PR #38 merge-commit preview (not landed): `5800aea5b04d52d90f2c57f89b97e3601d043369`.

## Evidence map (frozen #36 gates)

| # | Frozen acceptance test | Result | Proof |
| --- | --- | --- | --- |
| 1 | ADR 0004 exists and matches freeze | **PASS** | See Gate 1 |
| 2 | Playbook / skill / start-project / CC template no longer say C ⇒ stop all work / do not start feature work | **PASS** | See Gate 2 |
| 3 | `bootstrap-project.sh`: C is a warning; scaffold does not `exit 2` after repo create for C | **PASS** | See Gate 3 |
| 4 | `tests/bootstrap-local.sh` contract assertions pass; relevant tests run | **PASS** | See Gate 4 |
| 5 | Scope: no unrelated fleet / share-export / zentao work | **PASS** | See Gate 5 |

Phase #36 also lists independent verify + disposer `PHASE ACCEPT`. Those are process gates — see Process notes. The Agent proposes `EVIDENCE READY` only.

## Gate 1 — ADR 0004 matches freeze

File exists on impl SHA: `docs/adr/0004-free-private-capability-c.md`. Indexed from `docs/adr/README.md` as Accepted (disposer FREEZE ACK #36, 2026-09-22).

Facts from the ADR at `b040e32` vs freeze on #36:

| Freeze (Phase #36 body, 2026-09-22) | ADR 0004 match |
| --- | --- |
| Attempt to enable protection; report A/B/C honestly | Decision §1–2: attempt; report observed letter; never claim B/A when only C |
| Stop treating C as bootstrap failure / “do not start feature work” | Decision §3: C is not a hard bootstrap stop; warn, record, continue; do not abort scaffold as init failed |
| Free private → expected C; record on CC; proceed with hooks + PR discipline | Decision §4: GitHub Free private → expected C; disposer need not buy Pro to finish init |
| Never claim B/A when only C | Decision §2 + Consequences: wording cannot upgrade capability |
| Pro or public when a real server gate is required | Decision §5: upgrade path, not an init prerequisite |
| Fail closed stays for false claims | Decision §6: fail closed for false claims / missing Freeze / unknown remotes / skipped Fleet REGISTRY — not for recording an honest C |

A/B/C letter meanings are unchanged (A = independent review gate; B = PR-only; C = requested protection could not be enabled or verified). The **posture** of C changes from hard stop to record + continue.

ADR Consequences also state: script exit after a created repo is **success with a warning** when capability is C, not `exit 2`. That is Gate 3.

## Gate 2 — Instructional surfaces no longer say C ⇒ stop

Checked on impl SHA `b040e32` (Agent-facing surfaces named by the freeze + the aftercare/Getting Started/README pair that Agents actually load).

| Surface | C ⇒ stop / “do not start feature work” remaining? | Record + continue + honesty present? |
| --- | --- | --- |
| `playbooks/bootstrap-project.md` | No. After-create C **warns, reports C, and completes**. Anti-pattern: treating Free-private C as failure / “do not start feature work.” | Yes. Links ADR 0004. Done-when: C is expected on Free private and is not a failed init. |
| `skills/bootstrap-project/SKILL.md` | No. “Do not treat C as init failure or ‘do not start feature work.’” Fail-closed list no longer includes protection C. | Yes. Free-private C is **expected**; record C and continue. Protection honesty vs Fail closed are split. |
| `playbooks/start-project.md` | No. “Do not treat C as a stop-all-work gate.” Anti-pattern names the old reading. | Yes. Record C and continue; never claim B/A. |
| `templates/ISSUE_TEMPLATE/command-center.md` | No. Old “C → **BLOCKED**” line is gone. | Yes. Free private C is **expected**. Record C and continue. Do not treat C as init failure. |
| `docs/GETTING_STARTED.md` | No. Old “**No — BLOCKED**” and “If protection is **C**, stop.” are gone. | Yes. “**Yes — record C and continue**”; `--private` is valid. |
| `docs/GETTING_STARTED.zh-CN.md` | No. Old “**不可以，BLOCKED**” and “如果结果是 **C**，就应该停止” are gone. | Yes. Parallel to EN. |
| `README.md` / `README.zh-CN.md` | No. Old “C / BLOCKED” and “BLOCKED / fail closed” are gone. | Yes. “record + continue”; never claim B/A. |
| `docs/rfcs/0001-bootstrap-and-binding-hardening-contract.md` §7 | Label changed from `unprotected/BLOCKED` to `unprotected/unverifiable`. | Yes. Operational policy points at Phase #36 / ADR 0004. |

**Adversarial leftover-string scan** (exact old hard-stop sentences; `rg -F` on impl SHA). Hits only as **negative assertions** inside `tests/bootstrap-local.sh` (the contract that forbids them):

- `report capability C / BLOCKED`
- `Record capability C on Command Center before feature work`
- `capability C is explicitly Blocked`
- `No — BLOCKED`
- `If protection is **C**, stop.`
- `bootstrap returns a blocked result after repository creation`
- `不可以，BLOCKED`
- `C / BLOCKED`
- `BLOCKED / fail closed`
- `unprotected/BLOCKED`

Those strings are **absent** from playbook / skill / start-project / CC template / Getting Started / README on `b040e32`. Remaining `BLOCKED:` uses are unrelated fail-closed gaps (Fleet mirror, unknown remotes, cannot-edit-CC) — not protection C.

**Residual (not FAIL):** `docs/rfcs/0001-bootstrap-and-binding.md` is historical. It still says “write `BLOCKED:` on Command Center with the gap” (honesty, not “stop all work”) and still lists the open question “require GitHub Team/Pro before calling bootstrap complete?”. It has an ADR **0003** supersede banner, not an ADR 0004 banner. ADR 0004 explicitly supersedes the operational reading of RFC 0001 §7 that “C = BLOCKED means stop all work.” Agents are bound to PRINCIPLES + playbooks/skills + ADR 0004, not the 2026-09-10 RFC body. The **hardening contract** (the file Agents are pointed at for §7 letters) **was** updated in this PR.

## Gate 3 — Script: C is warning; no `exit 2` after repo create

`scripts/bootstrap-project.sh` at `b040e32` vs merge-base `074cb48`:

| Before (hard stop) | After (Phase #36) |
| --- | --- |
| `protection_label='unprotected/BLOCKED'` | `protection_label='unprotected/unverifiable'` |
| On C: `err "BLOCKED: … Record capability C on Command Center before feature work."` then `exit 2` | On C: `warn` (stderr `bootstrap: warning:`). Private visibility adds expected-C + “GitHub Pro is not required to finish init.” Public C still warns record+continue, never claim B/A. **No `exit`.** |
| Unmet `--require-codeowner-review` A: `err` + `exit 2` | `warn` only; record actual letter; never claim A |
| `usage` / dry-run plan: verify protection | Help + dry-run: C on Free private is expected; do not abort |

`rg -n 'exit 2' scripts/bootstrap-project.sh` at `b040e32`: **no matches**. The only exits after a created GitHub repo are implicit success (`set -e`; last command is `log "done. …"`). `--skip-github` still `exit 0`. `die` remains `exit 1` for pre-create failures (empty dest, missing `gh`, unsafe URL) — those are not C-after-create.

Dry-run replay at impl SHA (cwd methodology checkout, 2026-09-22 UTC):

```text
bootstrap: plan: gh repo create --private; push initial authority main; report protection capability A/B/C (C on Free private is expected; do not abort)
```

`bash -n scripts/bootstrap-project.sh` → exit 0.

Honesty is kept: default `protection_level='C'` until the protection API **and** observed fields verify A or B; wording cannot upgrade C.

## Gate 4 — Tests

Verifier cwd at impl SHA `b040e32225f81c15264332f559f993460199817e`, 2026-09-22 UTC (Cloud Agent workspace).

| Command | Result |
| --- | --- |
| `bash -n scripts/bootstrap-project.sh` | **PASS** (exit 0) |
| `bash tests/bootstrap-local.sh` | **PASS** (exit 0) — includes new C wording contract |
| `bash tests/self-dogfood-binding.sh` | **PASS** (exit 0) — supporting; path-filtered CI did not run on #38 |
| `bash tests/hook-behavior.sh` | **PASS** — **15 passed, 0 failed** — supporting |
| `bash tests/url-guard.sh` | **PASS** (exit 0) — supporting |
| `bash scripts/bootstrap-project.sh --dry-run … --yes` | **PASS** (exit 0); plan line says do not abort on C |

`tests/bootstrap-local.sh` terminal markers:

```text
PASS: methodology shell scripts are pinned to LF
PASS: wrapper rendering does not execute Markdown/backticks
PASS: binding/scaffold files exist
PASS: generated executable shell surfaces are pinned to LF
PASS: PIN carries the real methodology SHA
PASS: remote registry is explicit and clone-portable
PASS: share-export helper is vendored into the snapshot
PASS: bootstrap checkout has core.hooksPath=.githooks
PASS: gitignore and disposer substitution are correct
PASS: project skill wrappers are discoverable and rendered literally
PASS: fresh-clone hook installation path works
PASS: placeholder disposer fails closed
PASS: unsafe projection URL fails closed
PASS: non-git methodology source fails closed instead of sha=unknown
PASS: capability C is expected on Free private: record + continue, never claim B/A
bootstrap-local: all contract checks passed
```

The new contract (lines 121–154) asserts: old hard-stop sentences gone from playbook/skill/script/start-project/Getting Started; skill has Free-private + “record C on Command Center and continue”; script has “Record C on Command Center and continue” and “Do not claim B or A”; the C-handling block does not contain `exit 2` in the next 12 lines.

GitHub Actions on the same SHA `b040e32225f81c15264332f559f993460199817e`:

| Workflow | Run | Conclusion |
| --- | --- | --- |
| `bootstrap-contract` (syntax + dry-run + `tests/bootstrap-local.sh`) | [35681361395](https://github.com/Dylan5237/agent-project-ops/actions/runs/35681361395) | **success** |
| `self-dogfood-contract` | not triggered (path filter; `AGENTS.md` / hooks unchanged) | local replay PASS |
| `enforcement-contract` | not triggered (path filter; hooks / share-export unchanged) | local hook-behavior + url-guard PASS |
| Cursor Bugbot on PR #38 | skipping (usage limit) | **not a frozen #36 gate** |

No live `gh repo create --private` smoke was required by the freeze. This verifier did not create a GitHub repository.

## Gate 5 — Scope (no fleet / share-export / zentao)

`git diff --name-only 074cb48...b040e32` is exactly the 13-file set on PR #38:

```text
README.md
README.zh-CN.md
docs/GETTING_STARTED.md
docs/GETTING_STARTED.zh-CN.md
docs/adr/0004-free-private-capability-c.md
docs/adr/README.md
docs/rfcs/0001-bootstrap-and-binding-hardening-contract.md
playbooks/bootstrap-project.md
playbooks/start-project.md
scripts/bootstrap-project.sh
skills/bootstrap-project/SKILL.md
templates/ISSUE_TEMPLATE/command-center.md
tests/bootstrap-local.sh
```

None of:

- `fleet/REGISTRY.md` / `fleet/README.md`
- `scripts/share-export.sh` / `scripts/lib/share-export-denylist.sh` / `playbooks/share-export.md`
- `Dylan5237/zentao-mcp` (no files, no submodule)
- `CLAUDE.md` / root `AGENTS.md` / `PRINCIPLES.md`

README / Getting Started edits are C-posture only (remove BLOCKED / stop; add record + continue + honesty). That is Phase #36 documentation, not fleet/share-export/zentao work.

`origin/main` later merged PR #37 (`091c302`, fleet PM note). That is **outside** this impl PR.

## Adversarial checks

### Can an Agent still follow a remaining “C ⇒ stop all work” happy path?

Under **current playbooks / skill / start-project / CC template / Getting Started / README: no.** The script no longer `exit 2` after a created repo when C is observed.

### Can wording still upgrade C to B/A?

No instructional surface on the impl SHA does that. Script default remains C until verified A/B. Warnings say “Do not claim B or A.”

### Does continue-on-C weaken fail-closed for false claims / Fleet / unknown remotes?

No. Skill Fail-closed list still stops on missing SHA, unauthenticated `gh`, unknown remotes, GitLab-as-projection, skipped Fleet REGISTRY. ADR 0004 Decision §6 states that split.

### Did implementation mix evidence dumps?

PR #38 contains tests that **are** methodology contract code (`tests/bootstrap-local.sh`). It does not contain `docs/evidence/phase-36-*`. This evidence branch contains only this file versus `main`.

## Process notes (not product FAIL)

- Freeze ACK exists on Phase #36 (`freeze:acked`, body dated 2026-09-22). Implementation started after that ACK.
- Implementation used one branch/PR (`cursor/phase-36-free-private-c-55b8` → #38). No direct `main` push observed.
- CC #10 §1 at verification time: current phase **#36**, status **VERIFICATION**, Impl PR **#38**, Next Action = independent verification. That satisfies the impl→verification flip (updated by apo项目经理).
- This verifier’s `gh` is **read-only for Issues** (`gh api user` / `gh issue comment 36` → 403 `addComment`). It cannot edit Issue bodies or comment on #36. `EVIDENCE READY` was posted on PR #38. Copy-paste for #36 is below.
- Evidence-branch push: live `.githooks/pre-push` was not executable in this checkout (installer `chmod +x` was discarded so this PR would stay evidence-only). The same topic-branch update replayed through `bash scripts/hooks/pre-push-authority.sh origin https://github.com/Dylan5237/agent-project-ops.git` **allowed** (`exit 0`). Push used a normal `git push -u` (no `--force`).
- After this evidence lands, CC §1 Next Action should become **disposer review of evidence / `PHASE ACCEPT` or `PHASE RETURN`**. Proposed text is below; gap recorded as `BLOCKED:` for §1 rewrite **by this Agent**, not chat-only.

### Proposed CC #10 §1 after this evidence

| Field | Value |
| --- | --- |
| **Current phase** | #36 Free-private capability C expected |
| **Status word** | **VERIFICATION** (`EVIDENCE READY`; awaiting disposer) |
| **Impl PR** | #38 `b040e32225f81c15264332f559f993460199817e` |
| **Evidence** | this file / evidence PR |
| **Last closed** | #32 share-export · #27 fleet REGISTRY — PASS |
| **Open gates** | ▶ Disposer `PHASE ACCEPT` or `PHASE RETURN` · ⏳ merge (merge ≠ PASS) |
| **Single Next Action** | Disposer reviews this evidence and records `PHASE ACCEPT` or `PHASE RETURN` on #36. Merge ≠ PASS. |

## Paste block for Phase #36 (gh issue comment is read-only here)

```
## EVIDENCE READY (independent verifier) — not PHASE ACCEPT

Overall: **PASS** (frozen in-repo gates 1–5).

- Impl PR: #38 HEAD `b040e32225f81c15264332f559f993460199817e`
- Evidence: `docs/evidence/phase-36-independent-verify.md` (this evidence PR)
- Gates 1–5: PASS. Residual: RFC 0001 historical body still has BLOCKED/Pro open-question wording; ADR 0004 + hardening contract supersede the “C = stop” reading. This Agent cannot edit CC #10 §1 (`BLOCKED:` for §1 rewrite by project-ops / disposer).
- Tests: local `tests/bootstrap-local.sh` PASS (C wording contract); `bash -n` / self-dogfood / hook-behavior 15/0 / url-guard PASS. Actions run 35681361395 (`bootstrap-contract`) success on the same SHA.

Merge ≠ PASS. Disposer `@Dylan5237` records `PHASE ACCEPT` or `PHASE RETURN`.
```

## Agent conclusion

Frozen in-repo gates **1–5 PASS**. Fleet / share-export / zentao were correctly absent. A/B/C honesty is kept; C posture is record + continue.

The Agent proposes **`EVIDENCE READY`**. The Agent does **not** comment `PHASE ACCEPT`. Merge of #38 or of this evidence PR is not Phase PASS.
