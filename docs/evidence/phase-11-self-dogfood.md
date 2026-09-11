# Phase #11 evidence — self-bind methodology repo and prove fresh-agent takeover

Command Center: #10  
Phase: #11  
Implementation PR: #12  
Implementation merge SHA: `b72388677cce276837cd18c5128dff7bb5f691e3`

## Evidence map

| Frozen acceptance test | Proof | Location |
| --- | --- | --- |
| 1. Protection B/A verified and disposer `FREEZE ACK` exists before implementation | Owner `gh` branch-protection response showed PR-required, `enforce_admins=true`, force-push disabled, deletion disabled. Disposer posted `FREEZE ACK`; follow-up comment records the jq helper false-negative and preserves the raw API result as authority. | Phase #11 comments; Command Center #10 protection section |
| 2. One dedicated implementation branch/PR; no direct `main` push | Implementation used `feat/11-self-dogfood-binding` → PR #12. GitHub `main` protection was already capability B. PR #12 merged via PR as squash `b7238867…`. | PR #12 |
| 3. CI verifies root self-binding, no recursive snapshot, local methodology + Command Center pointer | `self-dogfood-contract` run `34574745240` passed. Log includes `PASS: self-binding adapters and hook entrypoint exist`, `PASS: self-binding contains no recursive methodology snapshot`, and `PASS: AGENTS.md contains takeover-critical control-plane facts`. | GitHub Actions run 34574745240, job 103184533878 |
| 4. Fresh clone does not inherit `core.hooksPath`; installer restores `.githooks` | Same CI run performs an actual local fresh clone of the checked-out merge candidate and passes `PASS: fresh clone detects missing local hook config and installer restores it`. | GitHub Actions run 34574745240, job 103184533878 |
| 5. Fresh Agent can recover authority, projection, Command Center, current Phase discovery, direct-main rule, and disposer separation from durable state | `AGENTS.md` points to Command Center #10, declares `origin` sole authority and projection `(none)`, forbids direct `main`, requires current Phase discovery from the Command Center index, and forbids Agent self-Accept. CI passes `PASS: fresh clone exposes takeover-critical durable state`. | `AGENTS.md`; GitHub Actions run 34574745240 |
| 6. Evidence separated from implementation; Agent posts `EVIDENCE READY` only after replayable proof exists | This evidence branch/PR contains proof documentation only and was created after implementation CI passed and PR #12 merged. | `evidence/11-self-dogfood` / evidence PR |
| 7. Disposer gives `PHASE ACCEPT` or `PHASE RETURN`; merge alone is not PASS | **Pending disposer decision by design.** This document and the subsequent `EVIDENCE READY` comment provide the decision input; they do not self-Accept. | Phase #11 |

## Replay notes

The critical replayable command is the repository-owned contract:

```bash
bash tests/self-dogfood-binding.sh
```

Expected terminal markers:

```text
PASS: self-binding adapters and hook entrypoint exist
PASS: self-binding contains no recursive methodology snapshot
PASS: AGENTS.md contains takeover-critical control-plane facts
PASS: supported adapters converge on one binding
PASS: self remote registry is explicit
PASS: hook entrypoint and installer parse
PASS: fresh clone detects missing local hook config and installer restores it
PASS: fresh clone exposes takeover-critical durable state
self-dogfood-binding: all contract checks passed
```

The GitHub Actions run used a fresh `actions/checkout@v4` workspace, then the test created a second fresh clone to verify that tracked hook files arrive but repository-local `core.hooksPath` does not, and that `scripts/install-hooks.sh` restores it.

## Boundaries / residual guarantees

This evidence does **not** claim capability A. Agent and disposer operations currently share the same GitHub identity, so GitHub cannot enforce a human-vs-Agent identity boundary. Capability B is the intentionally frozen requirement for this Phase.

The client hook remains bypassable. Server-side branch protection is the actual default-branch gate.

## Agent conclusion

Frozen acceptance tests 1–6 have replayable proof. Test 7 is the disposer decision itself and remains pending. The Agent may therefore propose `EVIDENCE READY`, but may not post `PHASE ACCEPT`.
