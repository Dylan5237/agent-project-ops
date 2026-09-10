# Methodology audit — agent-project-ops (2026-09-10)

> **中文摘要**：方法论的想法扎实 —— `PRINCIPLES.md` 十条每一条都能对上一个真实故障模式，Principle 10（至多一个可写权威）几乎是为「本地 + GitHub + GitLab」的多仓库困境写的，§G 的清理红线（Never delete 表）是大多数方法论只会讲「怎么建」而不会讲「怎么删」的地方。问题出在两处：**(1) 执行层有三个实机可复现的洞** —— hook 对未登记远端基本放行、新克隆不继承 `core.hooksPath` 导致 hook 完全不生效、projection 首次播种不做 authority 校验；**(2) 仓库自身没有按方法论运行** —— `main` 未受保护、0 个真实 Issue、2 条无 PR 的孤儿分支、PR #3 是 stacked。
>
> 本文件只做记录与提议，不改任何实现（Principle 9）。**Agent proposes / control plane disposes** —— 这里没有任何 `PHASE ACCEPT`、没有改冻结合同、没有授权删分支。

**Audit type:** read-only review + local reproduction. Files unchanged.
**Findings:** 3 × P0 · 5 × P1 · 10 × P2.

---

## 0. Baselines

Everything below was measured on 2026-09-10.

| Ref | Commit | Role |
| --- | --- | --- |
| `main` | `f4dcf8a8` | Default branch (22 blobs) |
| `cursor/bootstrap-and-binding-6bec` | `4d8ba991` | PR #3 head (42 blobs) |
| `cursor/git-authority-projection-3c80` | `1cb1c997` | PR #2 head |
| `cursor/pre-push-hook-initial-origin-a174` | `a2e1afd3` | **No PR** |
| `cursor/backfill-fast-forward-failure-1165` | `511e1215` | **No PR** |

> **Read this before the findings.** `scripts/bootstrap-project.sh`, `scripts/hooks/pre-push-authority.sh`, and the whole `templates/` directory **do not exist on `main`**. They exist only on the PR #3 branch. All hook and binding findings below therefore apply to the **PR #3 tree**, i.e. they are findings *before merge* — which is the cheapest possible time to fix them. Findings P1-3 and P1-4 apply to `main` as well.

### 0.1 Repository state vs. its own rules

| Item | Observed | Required by this methodology |
| --- | --- | --- |
| Default-branch protection | `protected: false` | `playbooks/start-project.md` §3: **Protect `main`**, require PRs |
| Real issues | **0** (the 3 entries from `/issues` are all PRs) | Command Center + Phase issues are the only index |
| Labels | none (`status:*` / `type:*` / `pr:*` absent) | `playbooks/start-project.md` §2 applies `templates/labels.md` |
| Pull requests | #1 merged · #2 open (`mergeable: clean`) · #3 open (`mergeable: unknown`) | — |
| PR structure | PR #3's first commit **is** PR #2's head (`1cb1c997`) → stacked | Principle 6: one Phase, one core problem |
| Branches | 5, **all** `protected: false` | — |
| Orphan branches | 2 branches with **no PR**, each carrying one commit not on `main` | §G: disposer authorization required to delete Agent-private `cursor/*` |
| Self-binding files | no `AGENTS.md`, no `.cursor/rules/`, no `.agents/skills/` | RFC §9 open question #7 (asked, unresolved) |
| CI | none | RFC §8.1: *"Dry-run (must pass in methodology CI **once wired**)"* |

---

## 1. Scope and method

**Read:** the complete file trees of `main` (22 blobs) and `cursor/bootstrap-and-binding-6bec` (42 blobs) — all playbooks, skills, scripts, templates, RFC 0001, and the bootstrap-and-binding research report; plus PR #2/#3 metadata and diffs, all 5 branches, and the issue set.

**Reproduced locally (not inferred):**

1. **Hook behaviour matrix.** Three local bare repos stood in for `origin`, `projection`, and an unregistered `gitlab`. The repository's unmodified `scripts/hooks/pre-push-authority.sh` was installed at `.githooks/pre-push` with `core.hooksPath=.githooks`, then nine push scenarios were run. Raw output in Appendix A.1.
2. **Clone inheritance.** Source repo configured with `core.hooksPath` → `git clone` → inspect the clone's local config → push `main` from inside the clone. Appendix A.2.
3. **Credential guard.** Both `url_has_secrets()` (bootstrap) and the hook's inline check were run against the same 8-URL table. Appendix A.3.
4. **RFC §8.2 acceptance run.** `scripts/bootstrap-project.sh --name … --disposer @Dylan5237 --no-projection --skip-github --yes`, executed for real, then every §8.2 checkbox was verified against the produced tree. Appendix A.4. Two findings (P1-5, P2-10) came out of this run only.

**Not audited (stated so nobody has to guess):**

- Whether GitHub's protection API actually accepts the proposed payload on a **free private** repo — plan-dependent, and testing it would require creating a repo. RFC §9 open question #2 remains open.
- Cursor Cloud Agent behaviour — no cloud run was performed.
- The `v1`/stretch items in RFC §7.
- `gh repo create` / projection remote creation paths — no repo was created.

---

## 2. What is working — do not regress

Recorded first because most of this document is criticism.

1. **Principle 10 names the real problem.** Multi-remote chaos is usually answered with "keep them in sync", which cannot converge. "Exactly one write authority; everything else is read-or-fast-forward" collapses an unbounded reconciliation problem into a one-directional projection that is actually checkable.
2. **Three enforcement layers, each honest about not being a lock.** Server protection > client hook > documentation, and the hook's own header says `Bypassable with --no-verify (not a server)`. Most methodologies quietly present `pre-commit` as a security boundary. This one does not.
3. **Evidence grading in the research doc.** Candidate mechanisms are marked official vs. uncertain, and the document ends with an explicit *"Uncertainties left explicit"* list — including whether Claude/Codex really auto-discover `.agents/skills/` and the GitHub protection feature matrix on free private repos. The temptation to state uncertain things confidently was resisted.
4. **§G cleanup red lines.** Splitting deletions into *never*, *low-risk stale*, and *high-risk / separate decision*, and explaining why closing a PR is not deleting the evidence trail. Deletion policy is much harder to write correctly than creation policy.
5. **The hook works inside linked worktrees.** `.githooks` is a repo-relative path and `core.hooksPath` lives in the shared `.git/config`, so worktrees inherit it automatically. Verified. A lot of designs get this wrong.
6. **Thin wrappers + full-text snapshot.** `.agents/skills/*/SKILL.md` carries only frontmatter plus a link into `.agent-project-ops/skills/`. Auto-discovery path satisfied, no duplicated body to drift. Verified in the §8.2 run — the generated wrapper preserves the full `description:` block correctly.

---

## 3. Findings summary

| ID | Sev | Finding | Surface |
| --- | --- | --- | --- |
| P0-1 | P0 | Remote classification is a reverse whitelist — unregistered remotes are treated as `origin` and released | `scripts/hooks/pre-push-authority.sh` :29–32, :57–66 |
| P0-2 | P0 | `core.hooksPath` is not inherited by a clone; the hook silently does nothing and no playbook says to install it | clone path; `templates/AGENTS.md` |
| P0-3 | P0 | Projection's first seed skips the ancestor check entirely | `scripts/hooks/pre-push-authority.sh` :45–54 |
| P1-1 | P1 | Two divergent implementations of the credential guard; both miss query-string tokens | `bootstrap-project.sh` :68–76 · `pre-push-authority.sh` :20–24 |
| P1-2 | P1 | Branch protection payload contradicts the threat model — CODEOWNERS is not enforced, self-merge is allowed | `bootstrap-project.sh` :347–359 vs RFC §6 |
| P1-3 | P1 | The repository does not follow its own methodology (dogfood gap) | whole repo |
| P1-4 | P1 | A real logic bug in PR #2 §D has a written fix sitting on a PR-less branch that can never merge | `playbooks/git-authority-and-projection.md` :70 |
| P1-5 | P1 | `PIN` is committed as `sha=unknown` with no warning and no fail-closed when the methodology root is not a git checkout | `bootstrap-project.sh` :168–174, :245–251 |
| P2-1…P2-10 | P2 | See §6 | — |

---

## 4. P0 findings

### P0-1 — The remote classification is a reverse whitelist

`scripts/hooks/pre-push-authority.sh` :29–32:

```bash
is_projection=0
if [[ "${remote_name}" == "projection" ]]; then
  is_projection=1
fi
```

The question asked is *"is it called `projection`?"* — and anything that is not is treated as `origin`. The `origin / other` branch then only blocks **updates to an already-existing** default branch (:57–66), because the comment above it deliberately allows the first publish so `gh repo create --push` works.

Net effect: **any remote you did not name `projection` accepts a first push of anything.**

This directly contradicts `templates/AGENTS.md` :31:

```
- Unknown remotes → stop until the Command Center names them.
```

**Reproduced** (Appendix A.1, cases 1–3): pushing `feat/1-test` to a remote named `gitlab` **succeeded**; the first push of `main` to `gitlab` **succeeded**; only the second push of `main` was blocked.

Consequence, concretely: an Agent runs `git remote add gitlab <url>` then `git push -u gitlab HEAD`, and the first feature branch lands on the projection — which is precisely the action Principle 10 and `git-authority-and-projection.md` §A.3 (`Topic branches push **only** to authority origin`) exist to prevent. By the time the hook objects, the branch is already there.

**Proposed patch** — replace :29–32 with deny-by-default registration. The registry must live **in the repository** (`.git/config` does not travel with a clone; see P0-2):

```bash
# Remote classification is deny-by-default. A remote that is not registered
# here is not "probably origin" — it is unknown, and unknown means stop
# (templates/AGENTS.md, "Remotes"). The registry lives in the repository so it
# travels with clone; .git/config would not.
root="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
registry="${root}/.agent-project-ops/remotes"

authority="origin"
projection_remotes="projection"
if [[ -f "${registry}" ]]; then
  authority="$(sed -n 's/^authority=//p' "${registry}" | head -1)"
  projection_remotes="$(sed -n 's/^projection=//p' "${registry}" | head -1)"
fi
[[ -n "${authority}" ]] || authority="origin"
[[ -n "${projection_remotes}" ]] || projection_remotes="projection"

is_authority=0
is_projection=0
if [[ "${remote_name}" == "${authority}" ]]; then
  is_authority=1
fi
IFS=',' read -r -a _projection_list <<< "${projection_remotes}"
for _p in "${_projection_list[@]}"; do
  if [[ -n "${_p}" && "${remote_name}" == "${_p}" ]]; then
    is_projection=1
  fi
done

if [[ "${is_authority}" -eq 0 && "${is_projection}" -eq 0 ]]; then
  deny "remote '${remote_name}' is not registered (authority='${authority}', projection='${projection_remotes}'). Register it on the Command Center and write .agent-project-ops/remotes, or remove the remote. Fail closed."
fi
```

and have `bootstrap-project.sh` write the registry next to the PIN (and add it to the committed set):

```bash
{
  echo "authority=origin"
  echo "projection=${projection_remote_names:-(none)}"
} > .agent-project-ops/remotes
```

This upgrades remote classification from a **silent naming convention** into a **committed, reviewable, clone-portable registry** — which also supplies the half of §A.2 ("Unknown → `status:blocked` until the disposer names them") that the automation layer was missing.

Note: this patch introduces `authority`, which the P0-3 patch below also uses. Apply them together.

### P0-2 — The hook does nothing in a fresh clone, and no step tells you to install it

`core.hooksPath` is **repository-local configuration** stored in `.git/config`; `git clone` does not carry it. The file `.githooks/pre-push` *is* version-controlled (it is not in `.gitignore`), so it arrives — and then sits there inert.

**Reproduced** (Appendix A.2): source repo had `core.hooksPath=.githooks`; after `git clone`, `git config --get core.hooksPath` exits 1 (unset); pushing `main` from inside the clone succeeded with the hook never firing.

This is arguably a **documentation gap** rather than a design error — RFC :203 already lists `not installed until clone/bootstrap` as a known limitation. But nothing in the repository covers the *"someone else cloned the business repo"* case:

- `playbooks/bootstrap-project.md` :51 asks only the **person running bootstrap** to verify `core.hooksPath`.
- No playbook covers a second engineer, or an Agent, cloning afterwards.
- `templates/AGENTS.md` — the one file every Agent is guaranteed to read — says nothing about self-checking hook installation.

An Agent is exactly the actor most likely to `git clone` and then `git push origin main`.

**Proposed fix — three small additions.**

1. New idempotent `scripts/install-hooks.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
[[ -f "${root}/.githooks/pre-push" ]] || { echo "no .githooks/pre-push in this repo" >&2; exit 1; }
chmod +x "${root}/.githooks/pre-push"
git config core.hooksPath .githooks
echo "hooks installed: core.hooksPath=$(git config --get core.hooksPath)"
```

2. In `templates/AGENTS.md`, immediately before `## Remotes`:

```markdown
## Before your first push

Run `git config --get core.hooksPath` and confirm it prints `.githooks`.
`git clone` does **not** carry this setting. If it is empty:

    bash .agent-project-ops/scripts/install-hooks.sh

A missing hook is not permission to push `main`.
```

3. Add to the `## Done when` list in `playbooks/start-project.md`:

```markdown
- [ ] `git config --get core.hooksPath` prints `.githooks` (run `install-hooks.sh` if not).
```

Even with all three, the hook remains a seatbelt, not a lock. The real fix stays server-side — a GitHub ruleset with *"Do not allow bypassing the above settings"*, and force-push disabled for Agent identities on the projection host. The documentation already says this; the point is to make the business repo actually do it.

### P0-3 — Projection's first seed bypasses the fast-forward check

`scripts/hooks/pre-push-authority.sh` :45–54:

```bash
if [[ "${is_projection}" -eq 1 ]]; then
  if [[ "${remote_ref}" != "refs/heads/${default_branch}" ]]; then
    deny "projection accepts only ${default_branch} (got ${remote_ref}). Topic branches push to origin."
  fi
  if [[ "${remote_sha}" != "${zero}" ]]; then
    if ! git merge-base --is-ancestor "${remote_sha}" "${local_sha}" 2>/dev/null; then
      deny "non-fast-forward to projection ${default_branch} is forbidden (projection ahead or diverged). Fail closed."
    fi
  fi
  continue
fi
```

`remote_sha == zero` means *"the target ref does not exist yet."* That escape hatch is legitimate for `origin` (a first publish is necessarily a new branch). It is applied to `projection` **as well**, so the ancestor check is skipped entirely on projection's first `main`.

**Reproduced** (Appendix A.1, case 4): the first `git push projection HEAD:refs/heads/main` **succeeded**, with no comparison against the authority tip. For contrast, cases 7 and 9 show topic pushes to projection and deletion of projection's `main` are both correctly blocked — so this is one isolated path, not a general failure.

Why this is P0: the entire multi-remote story rests on *"what is on projection came from authority"*. Allowing an unverified first seed leaves a door at the very start of the projection chain. One mistaken `git push projection main` from a stale checkout plants history on projection that authority never had; every subsequent "projection is behind authority" judgement is then wrong, and §D's remediation flow assumes you only notice divergence *after* it exists.

**Proposed patch** — reconstruct the projection branch so the seed must equal the authority tip:

```bash
  if [[ "${is_projection}" -eq 1 ]]; then
    if [[ "${remote_ref}" != "refs/heads/${default_branch}" ]]; then
      deny "projection accepts only ${default_branch} (got ${remote_ref}). Topic branches push to origin."
    fi

    if [[ "${remote_sha}" == "${zero}" ]]; then
      # First seed must equal the authority tip. Without this, a stale checkout
      # can plant history on projection that authority never had.
      auth_url="$(git remote get-url "${authority}" 2>/dev/null || echo "")"
      if [[ -z "${auth_url}" ]]; then
        deny "cannot read '${authority}' to verify the projection seed. Fail closed (Principle 5)."
      fi
      auth_tip="$(git ls-remote "${auth_url}" "refs/heads/${default_branch}" 2>/dev/null | cut -f1)"
      if [[ -z "${auth_tip}" ]]; then
        deny "${authority} has no ${default_branch} yet; nothing may be seeded to projection."
      fi
      if [[ "${auth_tip}" != "${local_sha}" ]]; then
        deny "projection first seed must equal the ${authority} tip (${auth_tip:0:8}); got ${local_sha:0:8}. Fetch ${authority} and retry."
      fi
      continue
    fi

    if ! git merge-base --is-ancestor "${remote_sha}" "${local_sha}" 2>/dev/null; then
      deny "non-fast-forward to projection ${default_branch} is forbidden (projection ahead or diverged). Fail closed."
    fi
    continue
  fi
```

The tip is read with `git ls-remote` rather than the local `origin/main`, so the check validates the remote's actual state instead of a possibly-stale local cache.

---

## 5. P1 findings

### P1-1 — Two credential guards, divergent behaviour, both missing query tokens

The rule *"a remote URL must not embed credentials"* is implemented twice, with different patterns:

- `scripts/bootstrap-project.sh` :68–76 `url_has_secrets()` — `*"://"*:*@*` plus the prefixes `ghp_`, `glpat-`, `github_pat_`
- `scripts/hooks/pre-push-authority.sh` :20–24, inline — `*":@"*` and `*"://"*:*@*` only, **no token-prefix check**

**Reproduced** (Appendix A.3):

| URL | bootstrap | hook |
| --- | --- | --- |
| `https://user:pass@github.com/o/r.git` | REJECT | REJECT |
| `https://ghp_AAA111@github.com/o/r.git` | REJECT | **PASS** ← inconsistent |
| `https://gitlab.corp/x.git?access_token=abc123` | **PASS** | **PASS** ← both miss |
| `https://gitlab.corp/x.git?private_token=xyz` | **PASS** | **PASS** ← both miss |
| `https://gitlab.corp/x.git?token=xyz` | **PASS** | **PASS** ← both miss |
| `ssh://git@github.com/o/r.git` | PASS | PASS |
| `git@github.com:o/r.git` | PASS | PASS |

The query-string form is a real GitLab and self-hosted idiom (`git clone https://host/repo.git?private_token=…`) — and an internal GitLab is exactly the projection case this methodology's own documentation uses as its example. If someone passes it to `--projection-url`, the script accepts it and then writes the token-bearing URL into `.agent-project-ops/PIN` and `AGENTS.md`, i.e. **commits it**.

**Proposed fix** — one shared library, sourced by both:

```bash
#!/usr/bin/env bash
# scripts/lib/url-guard.sh — single source of truth
url_has_secrets() {
  local u="$1"
  # 1) known token prefixes
  case "${u}" in
    *"ghp_"*|*"gho_"*|*"ghu_"*|*"ghs_"*|*"ghr_"*|*"github_pat_"*|\
    *"glpat-"*|*"gldt-"*|*"glrt-"*|*"glcbt-"*) return 0 ;;
  esac
  # 2) scheme://user:pass@host
  case "${u}" in
    *"://"*:*@*) return 0 ;;
  esac
  # 3) any query string — a legitimate git remote never needs one
  case "${u}" in
    *"?"*) return 0 ;;
  esac
  return 1
}
```

Rule 3 is deliberately broad: no valid git remote needs a query string, and the narrow `access_token=`/`private_token=` enumeration will always be one step behind. Note that `https://user:pass@…` and `ssh://git@…`/`git@…:…` must keep passing — rule 1's `*"://"*:*@*` and rule 3's `*"?"*` are chosen so SSH forms are unaffected.

### P1-2 — Branch protection contradicts the threat model

RFC §6 promises, in the threat-model table at :206:

> CODEOWNERS + required owner review | Binding files (`AGENTS.md`, `.agents/skills/`, PIN) cannot change without the disposer

But `scripts/bootstrap-project.sh` :347–359 actually PUTs:

```json
{
  "required_status_checks": null,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "enforce_admins": true,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
```

Two problems:

- **`require_code_owner_reviews` is absent**, so `.github/CODEOWNERS` produces a *review request*, not a *merge gate*. The RFC's guarantee — binding files cannot change without the disposer — does not hold.
- **`required_approving_review_count: 0`**, so any identity with write access (including the Agent itself) can open a PR and immediately merge it. This blocks direct pushes; it does not block self-merge.

`enforce_admins: true` and `allow_force_pushes: false` are correct and should stay.

**Proposed payload:**

```json
"required_pull_request_reviews": {
  "required_approving_review_count": 1,
  "require_code_owner_reviews": true,
  "dismiss_stale_reviews": true
}
```

**Realistic constraint.** On free personal private repos the whole `required_pull_request_reviews` object may be rejected outright — this is RFC §9 open question #2. So the script should distinguish three outcomes and report them as three different things, rather than letting all three be called "protected":

| Outcome | Report as |
| --- | --- |
| Accepted with code-owner requirement | `protected (code-owner enforced)` |
| Accepted but only with `count: 0` | `protected (PR-only, no review gate)` — and say on the Command Center that this stops accidental pushes, not self-review |
| API rejects | `BLOCKED` (the script already does this correctly) |

The gap between the RFC sentence and the payload is itself a small demonstration of why Principle 2 exists.

### P1-3 — The repository does not follow its own methodology

| Own invariant | What the repository does |
| --- | --- |
| §2 **Chat ≠ state** — state lives on Issue/PR/git objects | **0 issues.** The methodology's entire evolution (RFC 0001, the research report, Principle 10) exists only in PR descriptions and Cursor conversations. No Command Center, no Phase issue, no Freeze record. |
| §4 **Contract Freeze before implementation** | PR #3 arrives as 4 commits / +1921 lines containing an RFC *and* its implementation, with no prior freeze record. |
| §6 **One phase, one core problem** | PR #3 simultaneously writes an RFC, implements the bootstrap script, adds a research report, and edits the hook — four things. |
| `start-project` §3 **Protect `main`** | `protected: false`. Most pointedly: the methodology whose subject is *"an Agent must not push `main` directly"* has an unprotected `main`. |
| §G cleanup red lines | Two PR-less `cursor/*` branches are parked, one of them holding the only copy of a necessary fix. |
| RFC §9 open question #7 | Unresolved: this repo has no `AGENTS.md`, no `.cursor/rules/`, no `.agents/skills/`, so an Agent working *inside* the methodology is bound by nothing. |
| RFC §8.1 "dry-run must pass in methodology CI once wired" | No CI. |

**Interpretation.** This is a sequencing artefact, not negligence: the methodology was extracted from real Agent-driven work on other repos and has not yet been turned on itself. The recommendation is simply to schedule that step — and it happens to be the single most persuasive artefact the project could produce. A repository governed by its own rules is worth more than any paragraph in RFC 0001.

### P1-4 — A real logic bug in PR #2 has a written fix that can never merge

`cursor/backfill-fast-forward-failure-1165` has no pull request and carries exactly one commit not on `main`:

```
commit 511e1215  Fix backfill path to align projection after reclaim.
--- a/playbooks/git-authority-and-projection.md
+++ b/playbooks/git-authority-and-projection.md
@@ -67,7 +67,7 @@
-   - **Backfill:** recreate the unique work as a PR **on authority**
-     (cherry-pick or equivalent onto the authority tip). Merge on GitHub.
-     Then fast-forward projection.
+   - **Backfill:** recreate the unique work as a PR **on authority**
+     (cherry-pick or equivalent onto the authority tip). Merge on GitHub.
+     Then align projection to authority (see §E). Recreated commits have
+     new SHAs, so projection is not an ancestor of the new authority tip and
+     fast-forward will usually fail.
```

This is a hard logical point, not a wording preference: cherry-picking onto authority produces **new SHAs**, so projection's original commit cannot be an ancestor of the new authority tip, `--is-ancestor` is necessarily false, and §D's stated *"then fast-forward projection"* cannot succeed. Verified that PR #2's current head still carries the **uncorrected** text at line 70.

Three problems stacked:

1. PR #2's §D procedure is **wrong** — following it deadlocks at the last step.
2. The correct fix **already exists**, as a commit.
3. That commit's branch has **no PR**, so under this repository's own process it will neither merge nor be deleted (§G requires disposer authorization) — it will sit there until someone stumbles on it.

Related: `a2e1afd3` on `cursor/pre-push-hook-initial-origin-a174` ("Allow first publish of origin main in pre-push hook") and `eba8d0b7` on the PR #3 branch ("Allow the first origin main publish through the pre-push hook") are **two implementations of the same fix**. So of the two orphan branches, one holds something unique and necessary, the other is already covered elsewhere — which is exactly why "no PR" branches cannot be disposed of by a single blanket rule.

**Proposed actions** (disposer decisions, not Agent actions):

1. Cherry-pick `511e1215` into PR #2 (or #3) with a commit message explaining why §D must reclaim first and then merge-align.
2. Diff `a2e1afd3` against `eba8d0b7`; once semantically equivalent, route it through §G's *low-risk stale* path — **record disposer authorization, then delete**.
3. Record the disposition durably (a `docs/decisions/` entry, or this Issue). Otherwise the next audit has to reconstruct all of this reasoning from scratch — which is Principle 2 applied to the repository itself.

### P1-5 — `PIN` is committed as `sha=unknown`, with no warning and no fail-closed

`scripts/bootstrap-project.sh` :168–171 resolves the pin SHA with:

```bash
methodology_sha="unknown"
if git -C "${METHODOLOGY_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
  methodology_sha="$(git -C "${METHODOLOGY_ROOT}" rev-parse HEAD)"
fi
```

If the methodology root is not a git checkout, it silently falls back to the literal string `unknown` and proceeds to commit it (:245–251).

**Reproduced** in the §8.2 acceptance run — the generated `.agent-project-ops/PIN` was:

```
url=https://github.com/Dylan5237/agent-project-ops
sha=unknown
ref=HEAD
fetched_at=2026-09-10T10:39:04Z
```

Two things make this a finding rather than a test artefact:

1. **It is reachable in normal use.** Downloading the methodology as a ZIP ("Download ZIP" on GitHub), vendoring it, or fetching it through the GitHub API — all produce a non-git `METHODOLOGY_ROOT`. Any of those paths yields `sha=unknown`.
2. **It defeats the control the RFC names.** §5.6 states: *"Do not float `main` of the methodology without recording SHA (silent process change = chat-like drift)."* A committed `sha=unknown` is exactly that silent drift — and §8.2's own acceptance criterion explicitly permits a `local:` + SHA form, a branch the script does not implement at all.

The only trace is a `log "pin: … @ unknown"` line that scrolls past during bootstrap.

**Proposed fix** — prefer fail-closed, matching Principle 5:

```bash
methodology_sha=""
if git -C "${METHODOLOGY_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
  methodology_sha="$(git -C "${METHODOLOGY_ROOT}" rev-parse HEAD)"
fi
if [[ -z "${methodology_sha}" ]]; then
  if [[ -n "${allow_unknown_pin:-}" ]]; then
    methodology_sha="local:unknown"
    err "WARNING: methodology root is not a git checkout; PIN will say 'local:unknown'."
    err "Do not treat this PIN as a provenance record. Record the gap on the Command Center."
  else
    die "cannot determine the methodology SHA: ${METHODOLOGY_ROOT} is not a git checkout. Clone the methodology (do not download a ZIP), or pass --allow-unknown-pin to record 'local:unknown' explicitly."
  fi
fi
```

and have the skill's checklist require the Command Center to carry the PIN — so an `unknown` cannot pass unnoticed.

---

## 6. P2 findings

| ID | Finding | Evidence | Suggested action |
| --- | --- | --- | --- |
| P2-1 | **Dead file** `templates/skill-wrapper/SKILL.md` | Repo-wide grep for `skill-wrapper`: **zero references**. `write_wrapper()` (:279–302) generates wrappers with an inline heredoc and never reads this template. The template's `{{SKILL_DESCRIPTION}}` placeholder is not handled by `subst()` either. | Delete it, or wire `write_wrapper()` to it (which needs frontmatter description extraction). Deleting is cheaper and removes a file that must otherwise be kept in sync. |
| P2-2 | **Dead file** `templates/agent-project-ops.PIN` | Also zero references. The script writes `PIN` itself by heredoc (:246–251), in a different shape than the template (the template carries explanatory comments for each field). | Prefer the opposite of P2-1 here: `cp` + `subst` the template, so the committed PIN explains its own fields. Verified the generated PIN is bare key=value with no comments. |
| P2-3 | **`.github/instructions/` is created and always empty** | `mkdir -p .github/instructions` at :229 and nothing ever writes into it — confirmed end-to-end in the §8.2 run (`entries=0`, `tracked=0`). Meanwhile the research doc :113 and RFC :119 both list `.github/instructions/*.instructions.md` as a **working** auto-load surface (path-specific, `applyTo` globs). | Since the docs argue it works, add `binding.instructions.md` with `applyTo: "**"` restating the short invariants — or stop creating the directory. Creating a directory that documents its own usefulness but is never filled is the kind of detail an Agent will notice and distrust. |
| P2-4 | **README is behind the implementation** | `README.md` still heads the bootstrap section *"Bootstrap **(proposed)**"* with a *"Stubs:"* table, while PR #3 carries a 377-line runnable script. The *"Who"* table also says *"New empty folder → bootstrap (proposed)"*. | On merge, drop the *proposed* / *Stubs* framing, document `--dry-run`-first usage and the failure paths. |
| P2-5 | **The README's headline adoption path is the anti-pattern its own research doc names** | README "60 秒接入 / 60-second adopt" step 1 tells the user to have the Agent *"Load `https://github.com/Dylan5237/agent-project-ops`"*. Research doc :15 says: *"只在聊天里说'去读 Dylan5237/agent-project-ops'对**后来的** Agent 是希望，不是绑定。"* | Keep the fast path, but label it explicitly as *"works for this Agent, in this session — creates no durable binding"* and point to bootstrap in the same step. Right now two different strengths are implied by one sentence. |
| P2-6 | **Left-over reasoning comment in a shipped script** | `bootstrap-project.sh` :320–322 contains a three-line internal debate (`# Keep an empty worktrees dir in tree via .gitkeep? … — fine.`). | Replace with one line, e.g. `# .worktrees/ is gitignored; git cannot track an ignored empty dir — intentional.` |
| P2-7 | **Research summary over-generalises what the body table carefully qualifies** | Research :15 lists auto-discovery dirs as a flat set (`\.agents/skills/`, `\.cursor/skills/`, `\.claude/skills/`, `\.github/skills/`), while the table at :154–157 grades these per vendor as **Auto / Uncertain / Not on Cursor's table**. The summary drops the document's most valuable layer. | Reword the summary to *"各厂商自动发现目录不同且部分未确认（见下表）"*. |
| P2-8 | **Two placeholder conventions** | `templates/AGENTS.md` uses `{{DISPOSER}}`; `templates/github/CODEOWNERS` uses `@DISPOSER`. The script therefore needs two substitution mechanisms (`subst()` at :253–264 plus a standalone `sed` at :270). Also, `--disposer` defaults to the literal `@DISPOSER` (:125) when omitted — GitHub silently skips invalid users, so the CODEOWNERS looks configured but is inert. | Unify on `{{DISPOSER}}` so `subst()` covers everything; and `die` instead of defaulting when `--disposer` is missing. |
| P2-9 | **`sanitize_public_git_url()` passes SSH URLs through unchanged** | :139–157: the `git@*:*` branch just `printf '%s\n' "${u}"`. If the methodology clone's origin is SSH (common), that SSH URL is written into the business repo's `AGENTS.md` and `PIN` — and Cursor Cloud Agents typically have no SSH key, so the recorded canonical URL is unfetchable for exactly the actor the RFC is trying to bind. | Normalise non-`github.com` SSH hosts to HTTPS too, or keep SSH only behind an explicit flag. |
| P2-10 | **CODEOWNERS comments self-reference after substitution** | `sed "s/@DISPOSER/${disposer}/g"` (:270) rewrites the whole file including comments. The §8.2 run produced: `# Replace @Dylan5237 with the GitHub handle passed to bootstrap (no org secrets here).` — an instruction telling the reader to replace the value that is already correct. | Restrict the `sed` to non-comment lines, or reword the comment. Confirmed by running the scaffold, not by reading the template. |

---

## 7. Proposed follow-ups (deliberately not in this PR)

Principle 9 forbids an evidence PR from carrying implementation changes, so these are **proposals**, to be filed as separate work.

### 7.1 A behaviour test for the hook — highest leverage

The hook is this methodology's enforcement layer and it has **no tests at all**. The matrix used for this audit is about 30 lines of bash and runs in under two seconds.

```bash
# tests/hook-behavior.sh — expected interception matrix
# <case> <remote> <ref> <kind> <expect ALLOW|DENY>
expect "topic -> unregistered remote"    gitlab      refs/heads/feat/1   new   DENY
expect "first main -> unregistered"      gitlab      refs/heads/main     new   DENY
expect "update main -> unregistered"     gitlab      refs/heads/main     upd   DENY
expect "topic -> projection"             projection  refs/heads/feat/1   new   DENY
expect "seed main -> projection (== tip)" projection refs/heads/main     seed  ALLOW
expect "seed main -> projection (!= tip)" projection refs/heads/main     seed2 DENY
expect "first main -> origin"            origin      refs/heads/main     new   ALLOW
expect "update main -> origin"           origin      refs/heads/main     upd   DENY
expect "topic -> origin"                 origin      refs/heads/feat/1   new   ALLOW
expect "delete main anywhere"            origin      refs/heads/main     del   DENY
```

**The first four rows are currently all wrong** (Appendix A.1), so the suite would arrive red — which is its value. This single addition also satisfies RFC §8.1 ("dry-run must pass in methodology CI once wired"), which is currently unmet: one `shellcheck` + this suite + `bootstrap-project.sh --dry-run` in a small workflow closes both gaps at once.

### 7.2 Split the stacked PR

PR #3's base is `main` but its branch contains PR #2's head commit `1cb1c997`. So:

- **Merging #2 with a merge commit → #3 behaves.** `1cb1c997` becomes an ancestor of `main` and #3's commit list collapses to its own 3.
- **Merging #2 with a squash → #3 breaks.** `main` gets a new SHA, `1cb1c997` remains "unique" on #3's branch, and PR #3 keeps claiming PR #2's 11 files as its own delta. The review view becomes unreadable.

GitHub has no native stacked-PR support. The cheapest mitigation is to **decide the merge method now** (merge commit) and state the dependency in PR #3's body. The cleaner route is to split into three independent PRs:

1. **A** — `docs/rfcs/0001-…` + `docs/research/…` (pure docs, zero risk, merges immediately)
2. **B** — `scripts/` + `templates/` (implementation, including the P0 patches)
3. **C** — the hook fix alone, together with §7.1's test suite

Each becomes independently reviewable and revertible, and each maps to one core problem (Principle 6).

### 7.3 Bind the methodology repo to itself

RFC §9 open question #7 asks this; the answer is straightforward. Add `AGENTS.md` (pointing at `PRINCIPLES.md` and `skills/`), `.cursor/rules/agent-project-ops.mdc` with `alwaysApply: true`, and `.agents/skills/` wrappers — so any Agent working inside this repo is constrained automatically instead of by instruction.

One detail that is easy to get wrong: **the methodology repo's own root `skills/` is not on any vendor's auto-discovery path** (the research doc :15 already notes this). So wrappers written *for this repo* must point at `../skills/` (same repo), **not** at `.agent-project-ops/skills/` (which is the business-repo layout that `bootstrap-project.sh` produces). Getting this backwards would produce wrappers that resolve to nothing.

### 7.4 Register remotes in the Command Center template

`templates/ISSUE_TEMPLATE/command-center.md` records the authority remote and default branch but gives the projection no **name list** field. The P0-1 patch depends on that registry, so the template needs the matching lines:

```markdown
- [ ] Remotes registered: authority=`origin`  projection=`(none | projection, gitlab-mirror)`
- [ ] `.agent-project-ops/remotes` matches the line above (the hook reads this file)
```

---

## 8. Suggested sequencing

| # | Action | Files | Why here |
| --- | --- | --- | --- |
| 1 | Recover the `511e1215` backfill fix into PR #2/#3 | `playbooks/git-authority-and-projection.md` | Costs one line, fixes a broken procedure, and the longer it waits the higher the chance §G cleanup deletes it by accident |
| 2 | Add `tests/hook-behavior.sh` + a CI workflow | 2 new files | Get the regression net in place **before** touching the hook, otherwise the P0 fixes cannot be verified |
| 3 | Fix P0-1 / P0-3, extract `scripts/lib/url-guard.sh` (P1-1) | `scripts/hooks/pre-push-authority.sh`, new lib | All hook defects in one PR, now covered by (2) |
| 4 | Fix P0-2 — `install-hooks.sh` + the two doc additions | `templates/AGENTS.md`, `playbooks/start-project.md`, new script | Purely additive, low risk, but must be designed together with P0-1's registry |
| 5 | Fix P1-2 — protection payload + three-outcome reporting | `bootstrap-project.sh`, RFC §6 | Touches the definition of "protected", so the RFC wording has to move with it |
| 6 | Split the stacked PRs (§7.2) | — | Do this after 1–5 have homes, so it does not have to be redone |
| 7 | Use itself: Command Center + labels + protect `main` + first Phase | repo settings + 1 Issue | The point at which the methodology has a self-consistent example |
| 8 | Clear the P2 list | see §6 | Low-risk tidying, batch it |

Step 1 is safe to do immediately and does not wait on anything else.

---

## Appendix A — reproduction and raw output

### A.1 Hook behaviour matrix

Three local bare repos as `origin` / `projection` / `gitlab`; the repository's **unmodified** `scripts/hooks/pre-push-authority.sh` installed at `.githooks/pre-push` with `core.hooksPath=.githooks`.

```
### 1) push feat/1-test -> gitlab (unregistered remote)
 * [new branch]      HEAD -> feat/1-test          EXPECT DENY  GOT ALLOW   <-- FAIL

### 2) first push main -> gitlab
 * [new branch]      HEAD -> main                 EXPECT DENY  GOT ALLOW   <-- FAIL

### 3) second push main -> gitlab (update existing)
agent-project-ops hook: direct push to main on gitlab is forbidden; open a PR on GitHub (authority)
error: failed to push some refs to '.../c.git'    EXPECT DENY  GOT DENY    OK

### 4) first push main -> projection
 * [new branch]      HEAD -> main                 EXPECT DENY  GOT ALLOW   <-- FAIL (P0-3)

### 5) first push main -> origin (bootstrap needs this)
 * [new branch]      HEAD -> main                 EXPECT ALLOW GOT ALLOW   OK

### 6) update existing main -> origin
error: failed to push some refs to '.../a.git'    EXPECT DENY  GOT DENY    OK

### 7) feat/2-x -> projection
error: failed to push some refs to '.../b.git'    EXPECT DENY  GOT DENY    OK

### 8) feat/2-x -> origin
 * [new branch]      HEAD -> feat/2-x             EXPECT ALLOW GOT ALLOW   OK

### 9) delete main on projection
error: failed to push some refs to '.../b.git'    EXPECT DENY  GOT DENY    OK
```

Cases 5–9 confirm the designed behaviour is intact; 1, 2 and 4 are the failures.

### A.2 Clone does not inherit `core.hooksPath`

```
$ git init src  &&  ... && git config core.hooksPath .githooks
$ git -C src config --get core.hooksPath
.githooks                              (source configured)

$ git clone src clone1
$ git -C clone1 config --get core.hooksPath
(no output, exit=1)                    <-- setting absent

$ git -C clone1 config --local --list | grep -i hook
remote.origin.url=...
                                       (grep matches only the test dir name; no hook config)

$ git -C clone1 push target HEAD:refs/heads/main
 * [new branch]      HEAD -> main       <-- hook never fired; push succeeded
```

### A.3 Credential guard matrix

```
URL                                                  bootstrap  hook
https://user:pass@github.com/o/r.git                 REJECT     REJECT
https://ghp_AAA111@github.com/o/r.git                REJECT     PASS     <-- inconsistent
https://github.com/o/r.git                           PASS       PASS
https://gitlab.corp/x.git?access_token=abc123        PASS       PASS     <-- both miss
https://gitlab.corp/x.git?private_token=xyz          PASS       PASS     <-- both miss
https://gitlab.corp/x.git?token=xyz                  PASS       PASS     <-- both miss
ssh://git@github.com/o/r.git                         PASS       PASS
git@github.com:o/r.git                               PASS       PASS
```

### A.4 RFC §8.2 acceptance run

Command:

```
scripts/bootstrap-project.sh \
  --name audit-sandbox --dir <tmp>/audit-sandbox \
  --disposer @Dylan5237 --no-projection --skip-github --yes
```

Result: exit 0; 59 tracked files; `core.hooksPath` = `.githooks`; wrappers generated under both `.agents/skills/` and `.claude/skills/` with frontmatter preserved.

Checked against §8.2:

| §8.2 criterion | Result |
| --- | --- |
| Directory exists and is a git repo | pass |
| `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/…mdc`, `.github/copilot-instructions.md` exist | pass |
| `.gitignore` contains `.worktrees/` | pass |
| `.worktrees/` exists as a directory | pass (untracked, as intended — see P2-6) |
| `.agent-project-ops/PIN` contains a URL and a SHA | **partial — `sha=unknown`** → P1-5 |
| `.agent-project-ops/PRINCIPLES.md` and `skills/` exist | pass |
| `.agents/skills/…` wrappers exist with matching `name:` frontmatter | pass |
| `.claude/skills/` wrappers exist | pass |
| No file contains `ghp_`, `glpat-`, or `user:token@` | pass |
| `git remote -v` empty or only requested remotes | pass (`--skip-github`) |

Additional observations not covered by §8.2:

```
.github/instructions : exists, entries=0, tracked=0     -> P2-3
.worktrees           : exists, entries=0, tracked=0     -> P2-6
.agent-project-ops/  : LICENSE PIN PRINCIPLES.md playbooks scripts skills templates
                       -> no `remotes` registry exists   -> P0-1 patch needs one
```

Generated `PIN` (verbatim):

```
url=https://github.com/Dylan5237/agent-project-ops
sha=unknown
ref=HEAD
fetched_at=2026-09-10T10:39:04Z
```

Generated CODEOWNERS comment (verbatim) — the substitution rewrote the instruction itself:

```
# Binding files — disposer reviews changes to process.
# Replace @Dylan5237 with the GitHub handle passed to bootstrap (no org secrets here).
```

### A.5 Repository state queries

```
# branches
cursor/backfill-fast-forward-failure-1165   511e1215  protected=False
cursor/bootstrap-and-binding-6bec            4d8ba991  protected=False
cursor/git-authority-projection-3c80         1cb1c997  protected=False
cursor/pre-push-hook-initial-origin-a174     a2e1afd3  protected=False
main                                         f4dcf8a8  protected=False

# pulls?state=all
#3  open  merged=False  base=main  head=cursor/bootstrap-and-binding-6bec     mergeable=None  state=None
#2  open  merged=False  base=main  head=cursor/git-authority-projection-3c80  mergeable=True  state=clean
#1  closed merged=True  base=main  head=cursor/methodology-repo-bootstrap-afd3

# issues?state=all  (after filtering entries carrying a `pull_request` field)
real issues: 0
```

PR #3 commit list — the first entry is PR #2's head, which is what makes it stacked:

```
1cb1c997  Document optional projection remotes with a single write authority.   <-- PR #2 head
8469106e  Propose bootstrap and agent-binding (RFC 0001).
eba8d0b7  Allow the first origin main publish through the pre-push hook.
4d8ba991  Add a standalone bootstrap-and-binding research report.
```

---

## Appendix B — file : line index

| Finding | Location | Point |
| --- | --- | --- |
| P0-1 | `scripts/hooks/pre-push-authority.sh` :29–32 | `is_projection` matches the literal name only |
| P0-1 | `scripts/hooks/pre-push-authority.sh` :57–66 | `origin / other` blocks only updates to an existing default branch |
| P0-1 | `templates/AGENTS.md` :31 | "Unknown remotes → stop until the Command Center names them" |
| P0-2 | `scripts/bootstrap-project.sh` :311–318 | Installs the hook and sets `core.hooksPath` — bootstrap-time only |
| P0-2 | `docs/rfcs/0001-bootstrap-and-binding.md` :203 | Self-declared limit: "not installed until clone/bootstrap" |
| P0-2 | `playbooks/bootstrap-project.md` :51 | Hook verification written from the bootstrap-runner's viewpoint only |
| P0-3 | `scripts/hooks/pre-push-authority.sh` :49–53 | Ancestor check wrapped in `remote_sha != zero` |
| P1-1 | `scripts/bootstrap-project.sh` :68–76 | `url_has_secrets()` |
| P1-1 | `scripts/hooks/pre-push-authority.sh` :20–24 | Second, weaker credential check |
| P1-2 | `scripts/bootstrap-project.sh` :347–359 | Protection payload: `count: 0`, no `require_code_owner_reviews` |
| P1-2 | `docs/rfcs/0001-bootstrap-and-binding.md` :206 | Threat model promises CODEOWNERS enforcement |
| P1-3 | `docs/rfcs/0001-bootstrap-and-binding.md` :484–497 | §9 open questions, incl. #7 (self-binding) |
| P1-4 | commit `511e1215` (branch with no PR) | The backfill fix; PR #2 :70 still has the old text |
| P1-5 | `scripts/bootstrap-project.sh` :168–174, :245–251 | `sha=unknown` fallback, committed silently |
| P2-1 | `scripts/bootstrap-project.sh` :279–302 | `write_wrapper()` uses a heredoc, never the template |
| P2-2 | `scripts/bootstrap-project.sh` :246–251 | PIN written by heredoc, never the template |
| P2-3 | `scripts/bootstrap-project.sh` :229 | Creates `.github/instructions/` and never fills it |
| P2-3 | `docs/research/2026-09-10-bootstrap-and-binding-research.md` :113 | Lists `.github/instructions/*.instructions.md` as a working surface |
| P2-4 | `README.md` bootstrap section | Still "proposed" / "Stubs" |
| P2-5 | `README.md` :17–21 vs research :15 | Chat-URL adopt vs "是希望，不是绑定" |
| P2-6 | `scripts/bootstrap-project.sh` :320–322 | Left-over internal reasoning comment |
| P2-7 | research :15 vs :154–157 | Summary over-generalises the graded table |
| P2-8 | `scripts/bootstrap-project.sh` :125, :253–264, :270 | Two placeholder conventions, two substitution paths |
| P2-9 | `scripts/bootstrap-project.sh` :139–157 | `sanitize_public_git_url()` SSH passthrough |
| P2-10 | `scripts/bootstrap-project.sh` :270 | `sed` rewrites CODEOWNERS comments too |
