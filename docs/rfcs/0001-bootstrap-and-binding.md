# RFC 0001 — Bootstrap and agent binding

- **Status:** Proposed
- **Date:** 2026-09-10
- **Depends on:** [PR #2](https://github.com/Dylan5237/agent-project-ops/pull/2) (Principle 10, authority vs projection). This RFC is stacked on that work; do not duplicate or weaken it.
- **Identity:** Methodology only. Zero business/product coupling.

---

## 1. Problem

Today this repository **prevents multi-remote chaos if Agents read and obey**. It does **not** one-shot scaffold a new project.

Current adopt path ([README.md](../../README.md), [playbooks/start-project.md](../../playbooks/start-project.md)):

1. A **business** git repository already exists.
2. A human tells an Agent to load this methodology by URL.
3. The Agent (hopefully) reads `PRINCIPLES.md` and `skills/*/SKILL.md`.
4. Command Center is opened; remotes are recorded; worktrees are used thereafter.

That path fails the user’s end-state:

| End-state | Gap today |
| --- | --- |
| Human tells a **local AI**: “Initialize this project using Dylan5237/agent-project-ops.” | No bootstrap skill or script. `start-project` assumes the repo exists. NON-GOALS historically forbade a full bootstrap CLI. |
| AI creates a local folder, wires skills, writes `AGENTS.md` (or equivalent), creates `.worktrees/`, creates a **GitHub private** repo, optionally adds a **projection** remote | No generators. Methodology skills live at repo-root `skills/`, which **is not** an auto-discovery path for Cursor/Copilot/Claude. |
| Forever after, any AI using that folder follows the methodology so diverged `main`, dual SoT, silent force, dirty primary checkout, and projection-ahead-of-authority do not recur | Binding is chat-hope. Later Agents in the business folder are not guaranteed to load this repo. |

PR #2 documents **what to do** when a second remote exists. This RFC documents **how a new repo gets born already bound**, and which files actually get auto-loaded versus which are still hope.

---

## 2. Goals

1. **One sentence → scaffold.** A local Agent that can reach this methodology (clone, URL, or already-loaded skill) can initialize a **generic** project folder that is a git repo with GitHub `origin` as write authority.
2. **Binding in the business repo**, not in chat. Always-on instruction files and auto-discovered skills live **inside** the new project so later Agents, including Cloud Agents that do not receive `~/.cursor/skills/`, still see the methodology.
3. **Projection is optional and fail-closed.** Ask whether to add a GitLab (or other) projection remote. If yes, name it `projection`, never as a second SoT. Follow PR #2 / Principle 10 forever after.
4. **Harden against Fuxi-class failure modes** with a stack: documentation + auto-load binding + client hooks (bypassable) + server-side GitHub/GitLab rules (not bypassable by `--no-verify`).
5. **Keep methodology identity.** Principles win over convenience. Chat ≠ state. Merge ≠ PASS. One write authority. Projection fail-closed. No product names, internal hosts, or release IDs in this repo.

---

## 3. Non-goals

- **Not a product or app framework.** No runtime, no domain SOP, no `package.json` app stack, no deploy pipeline as part of methodology.
- **Not a guarantee against malicious or non-compliant Agents.** Binding raises the chance that a random future Agent loads the rules. It cannot make a model that ignores context, uses `--no-verify`, or has admin bypass, obey.
- **Not GitLab-as-authority.** GitHub remains the Issues/PR control plane (Principle 10). Other hosts are projection or out of scope.
- **Not MCP-as-SoT.** An MCP server that “is the methodology” would be a second control plane and a product. Out of scope.
- **Not rewriting history on protected `main` from bootstrap.** Bootstrap creates a clean repo; it does not force-align diverged remotes (that remains the projection playbook, disposer-authorized).
- **Not auto-creating a GitLab project** in MVP. Optional projection is “add this git URL as remote `projection`.” Creating the empty GitLab project is the human’s hosting step unless a later phase adds a documented, secret-free `glab` path.
- **Not replacing `start-project`.** Bootstrap **creates and binds** the repo. Command Center, labels, Freeze, and first Phase remain [playbooks/start-project.md](../../playbooks/start-project.md).

---

## 4. Research findings

Sources below were fetched or verified 2026-09-10. Where behavior is vendor-specific or version-dependent, this RFC says **uncertain** instead of inventing a capability.

### 4.1 Coding-agent binding — what actually auto-loads

**Summary:** There is no single file every agent auto-loads. The portable always-on file is `AGENTS.md`. Claude Code’s documented native file is `CLAUDE.md`, not `AGENTS.md`. Skills auto-load only from **specific directories**, not from an arbitrary `skills/` folder. This methodology’s current `skills/` layout is an Agent entrypoint **if something points at it**; it is **not** Cursor/Copilot auto-discovery.

#### AGENTS.md (cross-tool convention)

- Spec/home: [https://agents.md/](https://agents.md/) — plain Markdown, no required fields. Stewarded by the Agentic AI Foundation (Linux Foundation). Listed consumers include Cursor, Codex, Copilot, Gemini CLI, Aider (with config), Windsurf, Amp, Factory, Jules, goose, opencode, Zed, Warp, RooCode, and others.
- Nested files: closest `AGENTS.md` to the edited file wins; user chat overrides. Cursor documents nested `AGENTS.md` with parent+child combine, child more specific ([Cursor Rules](https://cursor.com/docs/rules)).
- Aider: official site says configure `.aider.conf.yml` with `read: AGENTS.md` ([agents.md FAQ](https://agents.md/); [Aider YAML config](https://aider.chat/docs/config/aider_conf.html)). Native auto-read of `AGENTS.md` without that key is **not** what Aider’s config docs guarantee.
- Gemini CLI: `.gemini/settings.json` `"context": { "fileName": "AGENTS.md" }` ([agents.md FAQ](https://agents.md/)).

#### Cursor — rules vs skills vs AGENTS.md

Official: [Rules](https://cursor.com/docs/rules), [Agent Skills](https://cursor.com/docs/skills).

| Mechanism | Auto-loaded? | Notes |
| --- | --- | --- |
| `AGENTS.md` at project root (and nested) | Yes (Cursor lists it as a first-class rule type) | Plain markdown; no frontmatter. Cursor does **not** document `~/.cursor/AGENTS.md`. Cross-project prefs are User Rules / Team Rules. |
| `.cursor/rules/*.mdc` | Conditional | Requires `.mdc` + frontmatter. `alwaysApply: true` → every Agent chat. Plain `.md` in that folder is **ignored**. |
| User Rules | Yes, Agent chat only | Not applied to Inline Edit (Cmd/K). Not in the repo → **Cloud Agents / other people do not get them.** |
| Team Rules | Yes, if enabled | Dashboard; can be **enforced**. Precedence documented as Team → Project → User when guidance conflicts. Still prompt-level, not a git server. |
| Legacy `.cursorrules` | Compatibility / de-emphasized | Current Rules doc does not present it as the way to author new rules. Do not emit it from bootstrap. |
| Remote Rule (GitHub) import | Manual in Customize | Copies `.mdc` into `.cursor/rules/imported/`. Cursor-only; not a substitute for files in git. |

Skills (Cursor), official discovery paths:

| Location | Scope |
| --- | --- |
| `.agents/skills/` | Project |
| `.cursor/skills/` | Project |
| `~/.agents/skills/` | User, **local machine** |
| `~/.cursor/skills/` | User, **local machine** |
| `.claude/skills/`, `.codex/skills/` and home equivalents | Compatibility |

**Critical Cloud Agent fact (Cursor docs):** Cursor does **not** copy `~/.agents/skills/` or unsynced local skills to Cloud Agents, Agents Window remote SSH, or self-hosted workers. Only `~/.cursor/skills/` can be synced (user-private), and project skills in the **repo** are what teammates and Cloud Agents share. **Bootstrap must put skills in the business repository.**

Skill body loads when the agent decides it is relevant (description matching) or via `/skill-name`. Frontmatter `name` must match the parent folder ([Agent Skills spec](https://agentskills.io/specification)).

This methodology’s `skills/foo/SKILL.md` at **methodology repo root** is **not** in the table above. An Agent working in a business repo will not auto-discover it unless bootstrap copies/wraps it into `.agents/skills/` (and/or `.cursor/skills/`).

#### Claude Code

Official: [How Claude remembers your project](https://code.claude.com/docs/en/memory), [Skills](https://code.claude.com/docs/en/skills).

- Native always-on: `CLAUDE.md` or `.claude/CLAUDE.md`. Also `~/.claude/CLAUDE.md`, `CLAUDE.local.md` (gitignored), managed policy paths.
- **Claude Code reads `CLAUDE.md`, not `AGENTS.md`.** Documented bridge: first line `@AGENTS.md` import, or `ln -s AGENTS.md CLAUDE.md` (Windows: prefer import). Claims that Claude “falls back to AGENTS.md” are **not** in the official memory doc (as of the fetched page).
- Skills: `.claude/skills/<name>/SKILL.md`. Progressive load: name+description at start; body on invoke. Official Claude docs emphasize `.claude/skills/`; they do **not** (on the fetched skills/memory pages) promise `.agents/skills/`. Treat Claude auto-discovery of `.agents/skills/` as **uncertain**; MVP also writes `.claude/skills/` wrappers **or** relies on `CLAUDE.md` instructing Claude to read `.agents/skills/` / `.agent-project-ops/skills/`.
- Enforcement that is not prompt-hope: **hooks** (PreToolUse, etc.). Claude’s own docs: CLAUDE.md is context, not a hard sandbox; hooks block actions the model cannot talk its way around.
- `/init` can ingest Cursor/Copilot files; `CLAUDE_CODE_NEW_INIT=1` also reads `AGENTS.md`. Useful for humans, not a bootstrap substitute.

#### GitHub Copilot

Official: [Adding repository custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions), [About agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills), [Adding agent skills](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills).

| File | Role |
| --- | --- |
| `.github/copilot-instructions.md` | Repository-wide instructions; widely used on GitHub.com Copilot surfaces |
| `.github/instructions/*.instructions.md` | Path-specific; `applyTo` globs. On github.com, documented for **cloud agent** and **code review** (not every IDE panel) |
| `AGENTS.md` anywhere | “Agent instructions”; nearest file wins. Also `CLAUDE.md` / `GEMINI.md` at root as alternatives |
| Skills | `.github/skills/`, `.claude/skills/`, `.agents/skills/` in-repo; `~/.copilot/skills` or `~/.agents/skills` personal |

Copilot code review reads instructions/skills from the **head branch**, not the base. Binding changes can be tested in the same PR.

#### Continue

Official: [Rules](https://docs.continue.dev/customize/deep-dives/rules). Project rules: `.continue/rules/*.md` (YAML frontmatter, `alwaysApply`, `globs`). Not `AGENTS.md` as the documented primary. MVP: optional `.continue/rules/agent-project-ops.md` that says “obey root `AGENTS.md`.” Stretch, not required for Cursor-first bootstrap.

#### Aider

Official config: [YAML config](https://aider.chat/docs/config/aider_conf.html). Conventions are ordinary files listed under `read:`. Filename `CONVENTIONS.md` is an example, not a magic auto-load. MVP may write `.aider.conf.yml` with `read: [AGENTS.md]` — small, generic, no secrets.

#### Honest auto-load matrix (business repo after bootstrap)

| File we write | Cursor Agent | Claude Code | Copilot (GitHub + VS Code agent) | Aider | Continue |
| --- | --- | --- | --- | --- | --- |
| `AGENTS.md` | Auto | No (unless imported) | Auto (agent instructions) | If configured | Not primary |
| `CLAUDE.md` `@AGENTS.md` | Ignored as Claude-specific | Auto | Optional root alternative | No | No |
| `.cursor/rules/*.mdc` `alwaysApply: true` | Auto | `/init` may copy ideas; not native | No | No | No |
| `.agents/skills/*/SKILL.md` | Auto discover | **Uncertain** | Auto discover | No | No |
| `.claude/skills/*/SKILL.md` | Compatibility discover | Auto discover | Auto discover | No | No |
| `.github/copilot-instructions.md` | No | `/init` may read | Auto on many surfaces | No | No |
| `.github/skills/` | Not in Cursor’s official table | Uncertain | Auto discover | No | No |
| Chat “please load Dylan5237/agent-project-ops” | Hope | Hope | Hope | Hope | Hope |

**Design implication:** bootstrap writes a **binding set**, not one file. The always-on files must be short (context budget: Cursor suggests rules &lt; 500 lines; Claude suggests CLAUDE.md &lt; ~200 lines) and **point** at playbooks/skills rather than paste them.

### 4.2 How other methodology / harness repos bootstrap

Patterns observed (GitHub + official CLIs):

| Pattern | What it is | Fit here |
| --- | --- | --- |
| Chat adopt | “Read this URL” (current agent-project-ops) | Insufficient for end-state |
| `gh repo create` | Official: [gh repo create](https://cli.github.com/manual/gh_repo_create) — `--private --source=. --remote=origin --push` | **MVP create path.** Uses existing `gh` auth; no tokens in files |
| GitHub template repo | `--template` on `gh repo create` | Tempting, but a GitHub template would snapshot methodology into every product. Coupling + stale copies. Prefer generate-from-clone. |
| Cookiecutter | One-shot render; weak update story | Stretch alternative |
| Copier | [copier copy](https://github.com/copier-org/copier/blob/master/docs/generating.md) + `copier update` + answers file + `--vcs-ref` pin | **Best stretch** for “methodology updates flowing” without making this repo a product. Not MVP (adds a Python tool dependency). |
| `npx create-*` | App frameworks (Next, etc.) | Product coupling; reject as the methodology vehicle |
| agent-bootstrap-template ([code-with-vanhai/agent-bootstrap-template](https://github.com/code-with-vanhai/agent-bootstrap-template)) | Script generates skeleton; harness-specific adapters; `AGENTS.md` for Codex; `.agents/skills/` for full feature set | Same *shape* as this RFC (script + adapters). Do not vendor that project; cite the pattern. |
| copier-coding-harness ([agentic-tend/copier-coding-harness](https://github.com/agentic-tend/copier-coding-harness)) | Copier → `AGENTS.md` + durable `decisions/` | Layered template + answers file; useful for v1 update path |
| boshu2/agentops | `ao session bootstrap` **explicit** (hookless: nothing auto-injects) | Reminder: even a CLI does not bind a foreign Agent. Files in the repo still matter. |
| GitHub Copilot “onboard” prompt | Cloud agent writes `.github/copilot-instructions.md` | Complementary; our bootstrap should already have written that file |

**CLI pattern we adopt:** a **tiny bash script in this repo**, invoked by a skill, flags + prompts, `--dry-run`, no npm package, no `npx`. Closest cousins: `gh repo create` wrappers and harness `bootstrap-request.sh` scripts — not `create-next-app`.

### 4.3 Multi-remote source of truth

Keep two problems separate:

1. **Product remotes:** GitHub authority vs GitLab (or other) **projection** — PR #2 / Principle 10.
2. **Methodology consumption:** how the business repo *reads* agent-project-ops — submodule / subtree / vendor copy / URL. **Not** a second product remote.

#### Product remotes (authority / projection)

- GitLab **push** mirror (GitLab → downstream): [Push mirroring](https://docs.gitlab.com/user/project/repository/mirror/push/). GitLab’s own words: *“To prevent the mirror from diverging from the upstream repository, don’t push commits directly to the downstream mirror.”* That matches Principle 10 **if GitLab were upstream**. In this methodology GitHub is upstream, so GitLab push-mirror is the **wrong direction** unless someone inverted SoT (forbidden).
- GitLab **pull** mirror (GitLab copies from GitHub): [Pull from a remote repository](https://docs.gitlab.com/user/project/repository/mirror/pull/). Same “don’t push to the mirror” rule. **Premium** (moved to Premium in 13.9). Default: diverged branches stop updating (fail-closed-ish). “Overwrite diverged branches” **destroys unique projection commits** — that is a disposer-level choice, not an Agent default. “Trigger pipelines for mirror updates” is the legitimate “GitLab as CI remote” pattern; it is also a credential/security surface (pipelines run as the mirror user).
- GitHub **has no native push-mirror setting** to GitLab. Official duplicate/mirror is manual `git clone --mirror` / `git push --mirror` ([Duplicating a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/duplicating-a-repository)). `git push --mirror` is destructive (deletes refs that don’t exist locally). GitHub’s push policy preview even **blocks** `git push --mirror` when enabled ([Managing the push policy](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/managing-the-push-policy-for-your-repository)).
- Community GitHub Actions (e.g. marketplace “Mirroring Repository”) can push all branches to GitLab. **Dangerous for this methodology** if they mirror topic branches or force non-FF. If used, constrain to **fast-forward of the default branch only**, credentials in Actions secrets (never in this methodology repo).
- Dual remotes on a laptop (`origin` + `projection`) are the Agent-visible form. Topic push: `git push -u origin HEAD` only (PR #2). Projection update: FF default branch after authority lands, or disposer-authorized align.

**Do not use** git submodule or subtree as a substitute for projection. Those nest **another repository’s tree** into the product tree; they do not mirror `main`.

#### Methodology consumption (not a product SoT)

| Mechanism | Updates | Agent footguns | Recommendation |
| --- | --- | --- | --- |
| Chat URL “read github.com/Dylan5237/agent-project-ops” | Always latest if fetched | Often skipped; Cloud Agent may lack net/auth | Insufficient alone |
| Vendor snapshot `.agent-project-ops/` + PIN (URL@SHA) | Explicit refresh script | Stale if never synced | **MVP** |
| Thin wrappers in `.agents/skills/` pointing at the snapshot | Same | Wrappers can drift from descriptions | **MVP** |
| `git submodule` of methodology | SHA pin is honest | Uninitialized submodule; extra clone step; Windows/CI pain ([gitsubmodules](https://git-scm.com/docs/gitsubmodules)) | v1 optional |
| `git subtree` | History mixed into product | Noisy product log; easy to “fix methodology” inside the business repo (Principle 7 inversion) | Avoid |
| Cursor Remote Rule import | Cursor-only copy into `.cursor/rules/imported/` | Not Copilot/Claude; can stale | Optional extra, not SoT |
| MCP | Live | Product; auth; second control plane | Non-goal |

### 4.4 Enforcement vs documentation

Layers, from hope to teeth:

| Layer | What it can do | What it cannot |
| --- | --- | --- |
| `AGENTS.md` / rules / skills | Raise compliance of **cooperating** Agents | Stop a model that ignores context |
| Client `pre-push` hook (`core.hooksPath`) | Block **updates** to `origin` default branch; block topic pushes to `projection`; require FF on projection. **Exception:** first create of the default branch (remote SHA all-zero) so bootstrap/`gh repo create --push` can publish | `--no-verify`; not installed until clone/bootstrap; not on every GUI |
| lefthook / husky | Team-shareable client hooks ([husky](https://github.com/typicode/husky), lefthook) | Same bypass; husky implies Node — **avoid as a methodology dependency** |
| GitHub **branch protection** / **rulesets** | Require PR, block force-push, block deletions, require reviews, optional CODEOWNERS, optional status checks ([protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches), [rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)) | Admins may bypass unless “do not allow bypassing” is on. Feature availability depends on plan (private repos / rulesets quotas). |
| CODEOWNERS + required owner review | Binding files (`AGENTS.md`, `.agents/skills/`, PIN) cannot change without the disposer ([CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)) | Must protect CODEOWNERS itself. Users/teams need write access. |
| Required status checks | Merge ≠ green CI; can encode “projection FF job passed” | Needs a check to exist; merge still ≠ Phase PASS (Principle 3) |
| Projection host protection | GitLab protected `main`, no force, no direct push for Agent identities | If Agents have Maintainer + force, paper wall |
| Claude hooks / Cursor hooks | Deterministic deny of `git push` to wrong remote | Tool-specific; not portable |

**Fail-closed default for bootstrap:** enable GitHub PR-required + no force on default branch **best-effort**. If the API rejects (plan/permission), write `BLOCKED:` on Command Center with the gap — do not pretend protection exists.

### 4.5 Skill distribution and updates

Agent Skills standard: [https://agentskills.io/specification](https://agentskills.io/specification). Progressive disclosure: metadata always, body on activate, `scripts/` `references/` `assets/` on demand.

**Do not** keep the only copy of skills in `~/.cursor/skills/` (Cloud Agents / other people miss them).

**Do not** teach later Agents to “fetch from URL and trust HEAD” as the only copy: network, auth, and silent methodology drift.

MVP: **pinned vendor snapshot** in the business repo:

```
.agent-project-ops/          # PRINCIPLES, playbooks, skills, scripts (generic)
.agent-project-ops/PIN       # url + sha + date
.agents/skills/<name>/       # thin SKILL.md wrappers (auto-discover)
.claude/skills/<name>/       # same wrappers (Claude)
```

Refresh is an explicit command (`scripts/sync-methodology.sh` in v1) that updates the snapshot to a **named ref** and records the new SHA on Command Center. That is how updates “flow” without the methodology repo depending on any business repo (Principle 7).

Submodule is an alternative pin with poorer Agent UX. Copier `update` is the stretch path if this repo becomes a Copier template — still generic, still no business coupling.

### 4.6 Worktree UX

Official: [git-worktree](https://git-scm.com/docs/git-worktree). Additional checkouts share the same `.git`; default branch can stay clean.

This repo already specifies:

- Path: `{repo}/.worktrees/{issue-or-phase}-{owner}-{slug}`
- Helper: [scripts/new-worktree.sh](../../scripts/new-worktree.sh)
- PR #2: create from **current authority tip**; primary checkout stays clean for sync

Bootstrap must:

1. Create `.worktrees/` as an empty directory.
2. Gitignore `.worktrees/` (never commit nested checkouts).
3. Copy or symlink `new-worktree.sh` into the business repo (via snapshot) so Agents do not depend on a sibling clone of the methodology.

Other ecosystems (Claude/Antigravity worktrees under `.claude/worktrees/`) are **out of convention**. If an Agent creates those, treat as extra clones (worktree playbook anti-pattern) unless Command Center records an exception.

### 4.7 Security

| Surface | Rule |
| --- | --- |
| `gh repo create --private` | Uses already-logged-in GitHub CLI. Bootstrap **must not** accept a PAT as a flag or write it to disk. |
| Projection URL | Git URL only (`git@host:group/repo.git` or `https://host/group/repo.git`). **Reject** URLs that embed `user:token@` or query tokens. Credentials stay in the user’s git credential helper / SSH agent. |
| GitLab tokens | If a human configures a pull-mirror, tokens live in GitLab’s mirror settings, not in methodology files, not in `AGENTS.md`. |
| GitHub Actions mirror | `secrets.*` only. This methodology does **not** ship a required workflow that needs GitLab SSH keys (that would force a product CI). v1 may document an **optional** FF-only workflow the business repo can add. |
| Private methodology | If agent-project-ops is public, snapshot is easy. If it were private, Cloud Agents need credentials to refresh — pin the snapshot in-repo so day-to-day work does not fetch. |
| `.env` / `CLAUDE.local.md` | Gitignore local overlays. Never bake secrets into templates. |

---

## 5. Target architecture

### 5.1 One-sentence path

```text
Human → local Agent: “Initialize this project using Dylan5237/agent-project-ops.”
        → Agent loads skills/bootstrap-project (from a clone, URL, or this repo)
        → scripts/bootstrap-project.sh (or equivalent Agent steps)
        → folder + git + binding files + skill wrappers + .worktrees/
        → gh repo create --private --source=. --remote=origin
        → prompt: add projection remote? if yes, git remote add projection <url>
        → first commit + push origin + best-effort protect default branch
        → playbooks/start-project.md (Command Center, labels, first Phase — no implement yet)
```

After that, **the business folder is the workspace**. Later Agents should not need the original chat.

### 5.2 Two layers in the business repo

```text
business-repo/
  AGENTS.md                          # always-on, portable
  CLAUDE.md                          # @AGENTS.md
  .aider.conf.yml                    # read: AGENTS.md (optional, tiny)
  .cursor/rules/agent-project-ops.mdc  # alwaysApply: true
  .github/copilot-instructions.md
  .github/CODEOWNERS                 # disposer owns binding paths
  .github/ISSUE_TEMPLATE/…           # copied templates
  .agents/skills/*/SKILL.md          # thin wrappers → snapshot
  .claude/skills/*/SKILL.md          # same
  .agent-project-ops/                # pinned snapshot of methodology
    PIN
    PRINCIPLES.md
    playbooks/
    skills/                          # full skill bodies (relative links still work inside snapshot)
    scripts/new-worktree.sh
  .githooks/pre-push                 # optional; installed by bootstrap
  .worktrees/                        # gitignored
  .gitignore
```

`origin` = GitHub private repo (authority). Optional `projection` = mirror/FF only.

### 5.3 Binding content (always-on, short)

Always-on files state, in order:

1. Load snapshot `PRINCIPLES.md` (version + PIN SHA). Invariants beat convenience.
2. Chat ≠ state; Agent proposes / disposer disposes; merge ≠ PASS.
3. Remotes: `origin` is write authority; extra remotes are projection; classify or stop.
4. Worktrees: `.worktrees/…`; primary checkout stays clean.
5. Discover skills under `.agents/skills/` (and `.claude/skills/`).
6. If PIN SHA ≠ snapshot content, fail closed and refresh or stop.
7. Do not copy business SOP back into Dylan5237/agent-project-ops.

Full procedures stay in snapshot playbooks (progressive disclosure).

### 5.4 Bootstrap vs start-project vs projection playbook

| Phase | Owner doc |
| --- | --- |
| Create folder, git, GitHub, binding, optional projection remote | This RFC + `skills/bootstrap-project` + `playbooks/bootstrap-project.md` |
| Command Center, labels, protect `main`, first Phase, Freeze-before-code | `playbooks/start-project.md` |
| Day-to-day topic branches / worktrees | `git-worktree` + `git-branch-and-remote` |
| Any non-origin push, divergence, cleanup | `playbooks/git-authority-and-projection.md` (PR #2) |

### 5.5 Ongoing hygiene (forever after)

Every Agent session in the folder:

1. Read `AGENTS.md` / rules (auto) → PRINCIPLES in snapshot.
2. `git remote -v` → origin-only **or** classify projection.
3. `git status` on primary checkout: if dirty with unrelated work, stop or park into a worktree.
4. Fetch `origin`. Base worktrees on **authority tip**.
5. Push topics to `origin` only.
6. If Command Center requires projection: after authority default advances, FF projection or **fail closed** (do not ship).
7. Projection ahead of authority → Blocked (PR #2 §D). Never silent force.

v1 adds `scripts/hygiene-remotes.sh` (read-only three-surface table). Stretch: required CI check that projection SHA is ancestor-or-equal of origin default.

### 5.6 Methodology updates

- Business repo records `PIN` (url, sha, fetched-at).
- Humans/Agents **propose** a pin bump via PR (CODEOWNERS).
- Do not float `main` of the methodology without recording SHA (silent process change = chat-like drift).

---

## 6. Threat model — Fuxi-class modes

Named after the failure cluster this methodology exists to stop. Controls assume a **typical** Agent with write access, not a hostile admin.

| Failure | Why it happens | Prevent (hope) | Prevent (teeth) | Residual |
| --- | --- | --- | --- | --- |
| **Diverged `main`** | Agent pushes to both remotes; force; Cloud sandbox treated as SoT | AGENTS.md + Principle 10 + projection playbook | GitHub: block direct/force push to default. Projection host: protect default; prefer pull-mirror from GitHub so GitLab never receives unique Agent pushes. Client hook: deny `push origin main` and non-FF projection | Admin bypass; `--no-verify`; host misconfig |
| **Dual SoT** | “GitLab is production now”; Issues on one host, git on another | Command Center names one authority; skill descriptions mention mirror/projection so the *right* skill loads | Unknown remotes → `blocked` until disposer names them. No Issues workflow on projection in this methodology | Human redefines SoT in chat and never writes Command Center |
| **Silent force** | Agent `--force` to “fix” FF | Playbook: force default only with disposer SHAs on the Issue | GitHub/GitLab: force disabled on default. Hook: reject non-FF to projection | Disposer-authorized force still dangerous if SHAs are wrong |
| **Dirty primary checkout** | Feature work on the clone that also syncs remotes | Worktree playbook; AGENTS.md “primary is sync-only” | Social/process; git cannot forbid a dirty tree. Hygiene script can **refuse to project** if primary is dirty | Agents that ignore the rule |
| **Projection ahead of authority** | Unique commits landed only on GitLab | PR #2 §D: Blocked; backfill or written abandon **before** projecting | Pull-mirror without overwrite **stops** updating (GitLab default). Hook/CI: detect unique projection commits and fail | “Overwrite diverged branches” or `push --mirror` used as a blunt hammer |
| **Later Agent never sees methodology** | Skills only in chat or `~/.cursor/skills` | — | Files in **repo** on auto-load paths; Cloud Agents see project skills | Agent with AGENTS.md disabled; Continue-only user if we skip `.continue/rules`; Aider without `read:` |
| **Methodology/business coupling** | Product nouns leak into this repo; or business “fixes” snapshot and PRs them upstream as SOP | Principle 7; PIN says snapshot is a copy | Review; CODEOWNERS on this methodology repo | Copy-paste in a hurry |
| **Secrets in tree** | PAT in remote URL, token in AGENTS.md | Templates refuse embedded credentials | git-secrets / push rulesets on `*.pem` etc. are business choices | Humans pasting tokens in Issues |

**Cannot be guaranteed:** a malicious Agent, an Agent instructed to ignore AGENTS.md, `git push --no-verify`, a disposer who force-aligns without reclaim, or a GitLab Maintainer pushing features to the mirror. Binding + server rules make the **accidental** path fail closed. They do not create a secure enclave.

---

## 7. Phased plan

### 7.1 MVP (this PR + immediate follow-through)

**Ships in this change (design + stubs):**

- This RFC.
- `skills/bootstrap-project/SKILL.md` — Agent entrypoint for the one-sentence init.
- `playbooks/bootstrap-project.md` — step list, generic.
- `scripts/bootstrap-project.sh` — flags, prompts, dry-run, `gh repo create`, binding generation, `.gitignore` for `.worktrees/`, optional `projection` remote, **no secrets**.
- Templates: `templates/AGENTS.md`, `templates/CLAUDE.md`, Cursor rule, Copilot instructions, gitignore fragment, CODEOWNERS skeleton, optional hook.
- README “Bootstrap (proposed)” pointing here.
- Pointers from `start-project` and the project-ops skill (do not fork PR #2’s projection rules).

**MVP behavior (script):**

- Safe to run `--dry-run`.
- Real run requires `git` + `gh auth` for GitHub create; can `--skip-github` for local-only.
- Copies a snapshot of this methodology into `.agent-project-ops/` and writes wrappers.
- Does **not** require Node, Copier, or GitLab tokens.
- Best-effort branch protection; on failure, record the gap (fail closed, don’t fake it).
- Does **not** Freeze or implement product code.

**Done for MVP** when a disposer can follow the skill + script on an empty directory and get a private GitHub repo whose clone contains binding files (even if protection API is skipped).

### 7.2 v1 (implement without redesign)

- `scripts/sync-methodology.sh` — refresh snapshot to a specified git ref; rewrite PIN; open a `docs/` PR on the **business** repo.
- `scripts/hygiene-remotes.sh` — read-only three-surface table (PR #2 §F).
- Install `.githooks` via `git config core.hooksPath .githooks` in bootstrap.
- `gh` labels from `templates/labels.md`; open Command Center issue from template (fill disposer, PIN, remotes).
- Document optional GitLab **pull-mirror** (Premium) vs optional FF-only GitHub Action vs Agent-run `git push projection <default-branch>` after merge.
- CODEOWNERS filled with the real disposer handle; enable required reviews if the plan allows.
- Thin `.continue/rules/` + `.aider.conf.yml` as generated optionals.
- Tests: `scripts/bootstrap-project.sh --dry-run` in CI of **this** methodology repo (no network create).

### 7.3 Stretch

- Copier (or equivalent) template with `copier update` for binding files, answers file separate from any product template.
- Required status check: projection default is FF of authority (needs a runner + stored projection credentials — **business** secret, not methodology).
- Cursor Team Rule that says “if the repo has `.agent-project-ops/PIN`, obey it” — org-wide, still not a git server.
- Claude `PreToolUse` hook denying `git push` to remotes named `projection` except allowlisted refs.
- `glab` project create — only if it can work with existing auth like `gh`, still no tokens in tree.
- GitHub template repository **generated from** these templates — evaluate stale-copy risk before enabling.

No phase turns this repository into an application framework.

---

## 8. Success metrics / acceptance tests (bootstrap)

Run in a throwaway directory. No business names.

### 8.1 Dry-run (must pass in methodology CI once wired)

```bash
scripts/bootstrap-project.sh --dry-run \
  --name sample-ops-project \
  --dir /tmp/sample-ops-project \
  --disposer @example \
  --skip-github
```

Expect: printed plan includes git init, binding files, `.worktrees/` gitignore, snapshot, no token values.

### 8.2 Local scaffold (`--skip-github`)

After a real local run:

- [ ] Directory exists and is a git repo.
- [ ] `AGENTS.md`, `CLAUDE.md` (contains `@AGENTS.md`), `.cursor/rules/agent-project-ops.mdc` (`alwaysApply: true`), `.github/copilot-instructions.md` exist.
- [ ] `.gitignore` contains `.worktrees/`.
- [ ] `.worktrees/` exists as a directory.
- [ ] `.agent-project-ops/PIN` contains a URL and a SHA (or `local:` + SHA of the source clone).
- [ ] `.agent-project-ops/PRINCIPLES.md` and `skills/` exist (snapshot).
- [ ] `.agents/skills/github-multi-agent-project-ops/SKILL.md` (and other wrappers) exist with matching `name:` frontmatter.
- [ ] `.claude/skills/` wrappers exist.
- [ ] No file contains `ghp_`, `glpat-`, or `user:token@`.
- [ ] `git remote -v` is empty **or** only remotes the test asked for.

### 8.3 GitHub private (`gh` available, opt-in)

- [ ] `gh repo view` shows **private**.
- [ ] `origin` URL is GitHub; default branch has the binding commit.
- [ ] Issues enabled (Command Center needs them).
- [ ] Protection: either PR-required + no force on default, **or** Command Center/Issue comment `BLOCKED:` explaining API/plan failure.

### 8.4 Optional projection

- [ ] Script asked, or `--projection-url` was passed.
- [ ] `git remote -v` shows `projection` **and** `origin`.
- [ ] AGENTS.md / Command Center text says projection is mirror/FF only.
- [ ] A topic branch push instruction in AGENTS.md is `origin`, not `projection`.
- [ ] Projection URL has no embedded password.

### 8.5 Binding smoke (manual / Agent)

- [ ] In Cursor, Customize → Rules shows the project rule and `AGENTS.md`.
- [ ] Customize → Skills lists the wrapped project-ops skills (project-level).
- [ ] A new Agent in the folder, given only “add a healthcheck,” **mentions** Freeze/Command Center or fails closed — it does not invent a second remote.

### 8.6 Forever-after negatives (process tests)

These are playbook tests, not necessarily scripted in MVP:

- [ ] `git push origin main` as a normal Agent identity is rejected by GitHub (once protection exists).
- [ ] `git push projection feat/1-x` is refused by hook and/or by policy; Agent stops.
- [ ] Dirty primary checkout → Agent creates a worktree instead of committing on `main`.
- [ ] Projection SHA ahead of origin default → `status:blocked`, no overwrite.

---

## 9. Open questions for the human disposer

1. **Pin policy:** Snapshot SHA of methodology `main` at bootstrap time, or require a tagged release (`v0.1.1` …) before bootstrap is “supported”?
2. **GitHub protection on free private personal repos:** Accept best-effort + BLOCKED comment, or require GitHub Team/Pro before calling bootstrap complete?
3. **Projection create:** Keep “human creates empty GitLab project, Agent only adds remote,” or authorize a later `glab` path?
4. **Preferred projection mechanism** when GitLab Premium pull-mirror is unavailable: Agent FF push after merge, or optional GitHub Action (secret lives in the **business** repo)?
5. **Wrapper duplication:** Keep both `.agents/skills/` and `.claude/skills/` (recommended) or Claude-only via `CLAUDE.md` pointers?
6. **Copier in v1** vs stay bash-only? Copier improves updates; bash keeps zero extra toolchain.
7. **Should this methodology repo itself grow `.agents/skills/` symlinks** so Agents *inside agent-project-ops* auto-discover skills? (Today they must be told to read `skills/`.)
8. **NON-GOALS wording:** Confirm the README change that optional bootstrap is allowed, still not a product/framework.
9. **PR #2 merge order:** Merge authority/projection docs first, then this RFC — or merge this stacked PR which already contains #2’s commits?

---

## 10. Alignment with PR #2

PR #2 adds Principle 10, `playbooks/git-authority-and-projection.md`, and `skills/git-authority-and-projection`. This RFC **does not** redefine those rules.

Bootstrap only:

- Default: origin-only (same as start-project).
- If the user wants a second remote: name it `projection`, record it on Command Center, and load the PR #2 skill **before any non-origin push**.

If PR #2 and this PR are both open: this branch is **stacked** on `cursor/git-authority-projection-3c80`. Prefer merging #2 first; this PR then rebases to a small delta. Do not land conflicting “origin only forever” text.

---

## 11. Document history

- 2026-09-10 — Proposed. Research citations in §4. Stubs land in the same change.
