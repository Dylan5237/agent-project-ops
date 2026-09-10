# 调研报告 / Research report — Bootstrap and agent binding

- **Date retrieved:** 2026-09-10
- **Repo:** methodology only (`agent-project-ops`). Zero business/product coupling.
- **Companion design (not this file):** [docs/rfcs/0001-bootstrap-and-binding.md](../rfcs/0001-bootstrap-and-binding.md)
- **Method:** Official vendor docs and git/GitHub/GitLab manuals first. GitHub examples cited as *patterns*, not as capability claims. If a page does not state a behavior, this report marks it **uncertain** — it does not invent auto-load.

This document is **findings**. The RFC is **what to build**. Do not treat this file as playbook steps.

---

## 中文摘要

- **没有“一个文件绑死所有 Agent”。** 跨工具最接近的总是 `AGENTS.md`（[agents.md](https://agents.md/)）。Claude Code **官方写明读 `CLAUDE.md`、不读 `AGENTS.md`**，要用 `@AGENTS.md` 导入或符号链接（[Claude memory](https://code.claude.com/docs/en/memory)）。
- **本方法论仓库根目录的 `skills/` 不会被 Cursor/Copilot 自动发现。** 自动发现目录是 `.agents/skills/`、`.cursor/skills/`、`.claude/skills/`、`.github/skills/` 等（见各厂商文档）。只在聊天里说 “去读 Dylan5237/agent-project-ops” 对**后来的** Agent 是希望，不是绑定。
- **Cursor Cloud Agent 拿不到未同步的本机用户 skills。** 只有仓库内 project skills（以及可选同步的 `~/.cursor/skills/`）会进云端/SSH/self-hosted（[Cursor Skills](https://cursor.com/docs/skills)）。绑定文件必须进**业务仓库**。
- **脚手架业界模式：** `gh repo create --private --source=. --remote=origin --push`（[gh repo create](https://cli.github.com/manual/gh_repo_create)）适合作为零依赖创建路径；Copier 适合以后“模板可更新”；Cookiecutter 偏一次性渲染；`npx create-*` 是应用框架，不适合方法论身份。
- **双远端 SoT：** GitLab 自己说镜像下游不要直接 push（[push mirror](https://docs.gitlab.com/user/project/repository/mirror/push/)、[pull mirror](https://docs.gitlab.com/user/project/repository/mirror/pull/)）。GitHub **没有**原生“推到 GitLab”的镜像设置；官方复制手段是 `git clone --mirror` / `git push --mirror`（[Duplicating a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/duplicating-a-repository)），`--mirror` 会删远端多余 refs，危险。
- **GitLab pull mirror 是 Premium**（13.9 起）。默认分歧分支停止更新；“Overwrite diverged branches”会丢掉镜像独有提交。
- **文档 ≠ 强制。** 客户端 `pre-push` 可 `--no-verify` 跳过（[githooks](https://git-scm.com/docs/githooks)）。真牙在 GitHub 保护规则/rulesets、GitLab protected branches、CODEOWNERS。管理员旁路与计划额度仍在。
- **Skills 分发：** Agent Skills 规范是渐进加载（[agentskills.io](https://agentskills.io/specification)）。子模块能钉 SHA 但 Agent 容易忘了 init；subtree 把历史混进业务库。MVP 更稳的是**钉 SHA 的快照 + 自动发现路径上的薄包装**。
- **Worktree：** 官方 `git worktree` 共享同一 `.git`（[git-worktree](https://git-scm.com/docs/git-worktree)）。`.worktrees/` 必须 gitignore。脏的主 checkout 做同步是反模式，git **不能**从协议上禁止。
- **安全：** `gh` 用已有登录；投影 URL 不得内嵌 token。方法论仓库禁止写死密钥。
- **不能保证：** 不守规矩的模型、`--no-verify`、有 bypass 的管理员、把 GitLab 当第二套真相。绑定提高**合作型** Agent 的命中率，不是安全飞地。

---

## 1. Executive summary

Coding agents do **not** share one auto-load contract. A portable always-on file (`AGENTS.md`) is widely adopted, but several high-use tools need **additional** files (`CLAUDE.md`, `.cursor/rules/*.mdc`, `.github/copilot-instructions.md`, skill directories). Skills are discovered only from **named directories**, not from an arbitrary `skills/` folder at a methodology clone.

Bootstrap CLIs in the wild split into: (a) `gh repo create` from a local tree, (b) Cookiecutter one-shot templates, (c) Copier generate-and-update, (d) `npx create-*` app frameworks, (e) harness scripts that emit `AGENTS.md` adapters. For this methodology, (a)+(e) fit identity; (c) is the best *later* update story; (d) is a product.

Multi-remote “write once, project elsewhere” is an industry mirror pattern. Hosts document **do not push to the downstream**. GitHub is not a native push-mirror server. Dual remotes on a laptop are the Agent-visible form; git submodule/subtree solve a *different* problem (nesting another project tree).

Enforcement that survives a random future Agent is **server-side**. Client hooks and markdown are prompt- or laptop-local. Plans, admin bypass, and `--no-verify` remain.

Implication: a one-sentence init must **write a binding set into the new business repo** (auto-load paths + pinned methodology snapshot) and treat GitHub `origin` as write authority, with an optional named `projection` remote that is never a second SoT.

---

## 2. Research questions

| # | Question | Why it matters |
| --- | --- | --- |
| Q1 | Which files do major coding agents **actually auto-load** vs require config or a chat instruction? | Chat-URL adopt does not bind the next Agent. |
| Q2 | How do other “agent ops / methodology / harness” repos bootstrap a new git project? | Avoid inventing a product CLI if a thin script + `gh` is enough. |
| Q3 | What are industry patterns for authority vs projection (GitHub + GitLab/other)? | Stop dual SoT, diverged `main`, projection-ahead. |
| Q4 | What can make a non-compliant Agent **fail closed** vs merely be told no? | Hooks vs branch protection vs CODEOWNERS vs CI. |
| Q5 | How should methodology skills reach a business repo over time without coupling this repo to a product? | Vendoring vs submodule vs URL vs MCP. |
| Q6 | What does `git worktree` actually provide, and what wrappers exist? | Dirty primary checkout / parallel Agents. |
| Q7 | How is private GitHub create and GitLab auth supposed to work without secrets in the methodology tree? | PATs in URLs, Actions secrets, `gh` login. |

---

## 3. Findings by topic

### 3.1 Binding auto-load (Q1)

#### 3.1.1 `AGENTS.md` as a convention

[AGENTS.md](https://agents.md/) is a **plain Markdown** file with **no required fields**. The site states it is stewarded by the Agentic AI Foundation under the Linux Foundation, and lists many consumers (Cursor, Codex, Copilot, Gemini CLI, Aider, Windsurf, Amp, Factory, Jules, goose, opencode, Zed, Warp, RooCode, and others). Nested files: *“The closest AGENTS.md to the edited file wins; explicit user chat prompts override everything.”*

**Uncertain:** Whether every logo on that page auto-loads root `AGENTS.md` with **zero** config. Official per-tool docs (below) are the capability claims. The agents.md FAQ itself tells Aider and Gemini CLI to **configure** the filename.

#### 3.1.2 Cursor

Official: [Rules](https://cursor.com/docs/rules), [Agent Skills](https://cursor.com/docs/skills).

| Mechanism | Documented load behavior |
| --- | --- |
| Project rules `.cursor/rules/*.mdc` | Version-controlled. Need `.mdc` + frontmatter. `alwaysApply: true` → every Agent chat. Plain `.md` in that folder is **ignored**. |
| `AGENTS.md` | First-class rule type. Root and nested; nested combine with parent, more specific wins. |
| User Rules | Agent (Chat) only. **Not** Inline Edit (Cmd/K). Not in the git repo. |
| Team Rules | Team/Enterprise dashboard. Can be **enforced** (user cannot disable). Precedence: Team → Project → User when guidance conflicts. Still prompt-level, not a git server. |
| Remote Rule (GitHub) | Manual import in Customize; copies `.mdc` into `.cursor/rules/imported/`. |

Cursor **does not** document a global `~/.cursor/AGENTS.md` on the Rules page (cross-project prefs are User/Team Rules).

Skills auto-discovery ([Cursor Skills](https://cursor.com/docs/skills)):

| Location | Scope |
| --- | --- |
| `.agents/skills/` | Project |
| `.cursor/skills/` | Project |
| `~/.agents/skills/` | User, **local machine** |
| `~/.cursor/skills/` | User, **local machine** |
| `.claude/skills/`, `.codex/skills/` (+ home dirs) | Compatibility |

**Cloud / remote:** Cursor documents that it does **not** copy `~/.agents/skills/` or unsynced local skills to Cloud Agents, Agents Window remote SSH, or self-hosted workers. Only `~/.cursor/skills/` can be synced (user-private). Teammates and Cloud Agents share **project skills in the repository**.

Skill `name` in YAML must match the parent folder. Body loads when relevant or via `/skill-name`. Rules: keep under 500 lines; prefer `@file` references.

#### 3.1.3 Claude Code

Official: [How Claude remembers your project](https://code.claude.com/docs/en/memory), [Skills](https://code.claude.com/docs/en/skills).

Verbatim: **“Claude Code reads `CLAUDE.md`, not `AGENTS.md`.”** Bridge: `@AGENTS.md` import in `CLAUDE.md`, or `ln -s AGENTS.md CLAUDE.md` (Windows: import, because symlink needs Admin/Developer Mode).

Always-on locations include `./CLAUDE.md` or `./.claude/CLAUDE.md`, `~/.claude/CLAUDE.md`, `CLAUDE.local.md` (gitignore), and managed policy paths. CLAUDE.md is **context, not a sandbox**. To block a tool call regardless of the model, the same memory page points at **hooks** (e.g. PreToolUse). Size guidance: keep CLAUDE.md under ~200 lines.

Skills: `.claude/skills/<name>/SKILL.md`. Progressive: name+description at start; body on invoke. Official Claude skills/memory pages fetched 2026-09-10 **do not** promise `.agents/skills/`. Treat Claude auto-discovery of `.agents/skills/` as **uncertain**.

`/init` can ingest Cursor (`.cursor/rules/` or `.cursorrules`) and Copilot (`.github/copilot-instructions.md`). With `CLAUDE_CODE_NEW_INIT=1`, `/init` also reads `AGENTS.md` and several other vendors’ rule files. `/import` (v2.1.213+) can copy `AGENTS.md` into `CLAUDE.md` once — a human migration, not a runtime auto-load of `AGENTS.md`.

#### 3.1.4 GitHub Copilot

Official: [Adding repository custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions), [About agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills), [Adding agent skills](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills).

| File | Documented role |
| --- | --- |
| `.github/copilot-instructions.md` | Repository-wide instructions |
| `.github/instructions/*.instructions.md` | Path-specific; `applyTo` globs. On github.com: **cloud agent** and **code review** (not claimed for every IDE panel) |
| `AGENTS.md` anywhere | “Agent instructions”; nearest file wins. Alternatives: root `CLAUDE.md` or `GEMINI.md` |
| Skills | `.github/skills/`, `.claude/skills/`, `.agents/skills/` in-repo; `~/.copilot/skills` or `~/.agents/skills` personal |

Code review reads instructions/skills from the **head** branch, not the base.

VS Code Copilot customization ([Create and manage agent customizations](https://code.visualstudio.com/docs/copilot/copilot-customization)): always-on instructions include `copilot-instructions.md`, `AGENTS.md`, `CLAUDE.md`. Opening a monorepo **subfolder** does not walk up to `.git` unless `chat.useCustomizationsInParentRepositories` is enabled (default **off**). **Uncertain** for other IDEs.

#### 3.1.5 OpenAI Codex

Official: [Custom instructions with AGENTS.md](https://developers.openai.com/codex/guides/agents-md).

Codex **reads `AGENTS.md` before doing any work**. Discovery: global `~/.codex/AGENTS.override.md` else `~/.codex/AGENTS.md`; then walk from project root to cwd, at most one file per directory (`AGENTS.override.md` then `AGENTS.md` then `project_doc_fallback_filenames`). Concatenate root→leaf. Combined size capped by `project_doc_max_bytes` (**32 KiB default**). Empty files skipped. This is a **truncation** risk if a binding file dumps entire playbooks.

#### 3.1.6 Aider

Official: [YAML config](https://aider.chat/docs/config/aider_conf.html); FAQ on [agents.md](https://agents.md/).

Aider looks for `.aider.conf.yml` in cwd, git root, then home. The documented way to attach files is `read: [AGENTS.md, …]`. `CONVENTIONS.md` is an **example filename**, not a magic auto-load. **Do not claim** Aider always reads `AGENTS.md` with no config; the official config path is explicit `read:`.

#### 3.1.7 Continue

Official: [Rules deep dive](https://docs.continue.dev/customize/deep-dives/rules).

Project rules: `.continue/rules/*.md` with optional YAML (`alwaysApply`, `globs`, `description`). This is the documented primary. **`AGENTS.md` is not** the documented Continue auto-load. Binding Continue requires a rule file that points at `AGENTS.md`, or **uncertain** native AGENTS.md support.

#### 3.1.8 Gemini CLI

[agents.md FAQ](https://agents.md/): configure `.gemini/settings.json` `{ "context": { "fileName": "AGENTS.md" } }`. That is **config**, not claimed zero-config auto-load.

#### 3.1.9 Agent Skills standard

[Agent Skills specification](https://agentskills.io/specification): a skill is a directory with `SKILL.md` (YAML `name` + `description` required). Progressive disclosure: metadata ~always, body on activate, `scripts/` `references/` `assets/` on demand. Recommended SKILL.md under 500 lines. `name` must match parent directory (lowercase, hyphens).

#### 3.1.10 Honest matrix (root files in a **business** repo)

| File | Cursor | Claude Code | Copilot | Codex | Aider | Continue |
| --- | --- | --- | --- | --- | --- | --- |
| `AGENTS.md` | Auto ([Rules](https://cursor.com/docs/rules)) | No unless imported ([memory](https://code.claude.com/docs/en/memory)) | Auto as agent instructions ([custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)) | Auto ([Codex](https://developers.openai.com/codex/guides/agents-md)) | If `read:` ([Aider](https://aider.chat/docs/config/aider_conf.html)) | Not primary ([Continue rules](https://docs.continue.dev/customize/deep-dives/rules)) |
| `CLAUDE.md` `@AGENTS.md` | Not Claude’s file | Auto | Optional alternative | No | No | No |
| `.cursor/rules/*.mdc` alwaysApply | Auto | `/init` may copy; not native | No | No | No | No |
| `.agents/skills/` | Auto | **Uncertain** | Auto | Cursor lists `.codex/skills/` compatibility; Codex-native skill dirs **not verified here** | No | No |
| `.claude/skills/` | Compatibility | Auto | Auto | **Uncertain** | No | No |
| `.github/copilot-instructions.md` | No | `/init` may read | Auto many surfaces | No | No | No |
| `.github/skills/` | Not on Cursor’s table | **Uncertain** | Auto | **Uncertain** | No | No |
| Chat “load methodology URL” | Hope | Hope | Hope | Hope | Hope | Hope |

**Implication:** bootstrap must emit a **set**, keep always-on files short (Codex 32 KiB combined; Claude ~200 lines; Cursor &lt;500 lines per rule), and put skills on auto-discovery paths **inside the business repo**.

This methodology’s `skills/*/SKILL.md` at **methodology-repo root** is an entrypoint **if an Agent is pointed at this clone**. It is **not** in any vendor auto-discovery table above.

---

### 3.2 Bootstrap patterns (Q2)

| Pattern | Primary source | What it does | Fit for a methodology repo |
| --- | --- | --- | --- |
| Chat “read this URL” | Current `README.md` adopt path | Relies on the Agent fetching another git host | Insufficient for later Agents in the business folder |
| `gh repo create` | [gh repo create](https://cli.github.com/manual/gh_repo_create) | `--private` / `--public` / `--internal`; `--source=.` `--remote=` `--push`; `--clone`; `--template` | **Best MVP create:** uses existing `gh` auth, no PAT in files. `--template` snapshots whatever is in a GitHub template repo (stale-copy risk). |
| Cookiecutter | [Cookiecutter docs](https://cookiecutter.readthedocs.io/en/stable/README.html) | Render from git/local template; `cookiecutter.json` prompts; pre/post hooks | One-shot. Official README does not present a first-class “update generated project from new template version” loop like Copier. |
| Copier | [Generating](https://github.com/copier-org/copier/blob/master/docs/generating.md), [Updating](https://copier.readthedocs.io/en/stable/updating/) | `copier copy`, `--vcs-ref`, answers file; `copier update` replays template vs last answers | **Best stretch for flowing updates.** Adds a Python/uv toolchain. Never hand-edit `.copier-answers.yml` (documented). |
| `npx create-*` | Ecosystem (e.g. app starters) | Installs an **application** skeleton | Product coupling; reject as the methodology vehicle |
| Harness bootstrap scripts | e.g. [code-with-vanhai/agent-bootstrap-template](https://github.com/code-with-vanhai/agent-bootstrap-template) | Script emits adapter files (`AGENTS.md`, `.agents/skills/`, harness flags) | Same *shape* as a methodology bootstrap script. Cite as pattern; do not vendor that repo. |
| Copier coding harness | [agentic-tend/copier-coding-harness](https://github.com/agentic-tend/copier-coding-harness) | Copier → `AGENTS.md` + durable contracts; layered answers files | Pattern for “harness layered on a product template” without mixing answers files |
| Explicit session bootstrap | [boshu2/agentops AGENTS.md](https://github.com/boshu2/agentops/blob/main/AGENTS.md) | Documents **hookless**: `ao session bootstrap` must be run; nothing auto-injects | Even a CLI does not bind a *foreign* Agent. Files in the target repo still matter. |
| Copilot onboard prompt | [Customize Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-copilot-overview) | Cloud agent writes `.github/copilot-instructions.md` | Complementary; a methodology bootstrap should already have written that file |

**CLI identity for this repo:** a tiny bash script + skill, flags, `--dry-run`, no npm package. Closest cousins: `gh repo create` wrappers and harness `bootstrap-*.sh` scripts — not application `create-*`.

---

### 3.3 Multi-remote source of truth (Q3)

Keep **two problems** separate:

1. **Product remotes:** GitHub authority vs a GitLab (or other) **projection**.
2. **Methodology consumption:** how a business repo *reads* this methodology (copy / submodule / URL). That is **not** a second product remote.

#### 3.3.1 Host mirroring (product remotes)

**GitLab push mirror** (GitLab → downstream): [Push mirroring](https://docs.gitlab.com/user/project/repository/mirror/push/). Quote: *“To prevent the mirror from diverging from the upstream repository, don’t push commits directly to the downstream mirror. Push commits to the upstream repository instead.”* If **this** methodology’s write authority is GitHub, GitLab-as-push-source is the **wrong direction**.

**GitLab pull mirror** (GitLab copies **from** an upstream such as GitHub): [Pull from a remote repository](https://docs.gitlab.com/user/project/repository/mirror/pull/). Same “don’t push to the mirror.” History: **moved to GitLab Premium in 13.9**. Default: diverged branches **stop updating** (fail-closed-ish). “Overwrite diverged branches” **loses unique commits on the mirror**. “Trigger pipelines for mirror updates” is the documented “CI on the GitLab copy” pattern; GitLab also documents credential risk (pipelines run as the mirror user). Pull is scheduled (docs: ~30 minutes after a previous pull, with capacity limits).

**GitHub** has **no** settings page equivalent to GitLab’s “Mirroring repositories” for push-to-GitLab. Official duplicate/maintain-mirror: [Duplicating a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/duplicating-a-repository) — `git clone --bare` / `--mirror` then `git push --mirror`. `--mirror` makes the destination match the local ref set (including **deletes**). GitHub’s [push policy](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/managing-the-push-policy-for-your-repository) (public preview when fetched) can **block** `git push --mirror` as potentially destructive.

Community GitHub Actions that “mirror all branches” are **not** official GitHub product. If a business repo uses one, constrain to fast-forward of the **default branch only**; credentials in Actions secrets — never in this methodology tree.

**Laptop dual remotes** (`origin` + `projection`) are the form Agents see. Topic push belongs on authority only. Projection update = FF after authority lands, or disposer-authorized align (methodology playbook, not a git feature).

#### 3.3.2 Submodule vs subtree (not projection)

[gitsubmodules](https://git-scm.com/docs/gitsubmodules): a submodule is a **nested repository** with its own history, pinned to a commit. Clone does **not** check out submodules by default (`--recurse-submodules` / `submodule update --init`).

[git-subtree](https://github.com/git/git/blob/HEAD/contrib/subtree/git-subtree.adoc): copies another project **into a subdirectory** of *this* history. No `.gitmodules`. Easy for Agents to “fix” the nested copy in the business repo.

Neither mechanism **mirrors `main` to another host**. Using them as a substitute for projection is a category error.

---

### 3.4 Enforcement vs documentation (Q4)

Layers, weakest to strongest:

| Layer | Primary source | Can do | Cannot do |
| --- | --- | --- | --- |
| Markdown / skills / rules | Cursor, Claude, Copilot, Codex docs above | Raise odds a **cooperating** Agent sees the rule | Stop a model that ignores context |
| Client `pre-push` | [githooks pre-push](https://git-scm.com/docs/githooks) | Receives remote name + URL; stdin is local/remote ref+SHA; non-zero exit aborts the push | `git push --no-verify` skips client hooks (git-push behavior; standard). Not installed until `core.hooksPath` or `.git/hooks` is set. Not on every GUI. |
| Lefthook | [lefthook.dev](https://lefthook.dev/) | `lefthook.yml` + `lefthook install` writes `.git/hooks` that call lefthook | Same `--no-verify`. Extra toolchain. |
| Husky | [typicode/husky](https://github.com/typicode/husky) | `core.hooksPath`; npm `prepare` | Same bypass; typically Node — poor methodology dependency |
| GitHub protected branches | [About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) | Require PRs/reviews, status checks, block force/delete (defaults), optional “do not allow bypassing” for admins | Feature set and who can bypass depend on plan and settings. Only one classic protection rule applies at a time (docs contrast with rulesets). |
| GitHub rulesets | [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) | Multiple rulesets layer (most restrictive wins); org-level on Team/Enterprise; quotas (docs: up to 75 per repo / 75 org) | Still org-plan dependent. Not a substitute for Principle 3 (merge ≠ PASS). |
| CODEOWNERS | [About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) | Review requests; optional **required** owner review via protection. Protect CODEOWNERS itself | Owners need write access. Invalid users skipped. |
| Required status checks | Same protection/ruleset docs | Block merge until a check is green | Need a check to exist; green merge is still not Phase PASS |
| GitLab protected branches | [Protected branches](https://docs.gitlab.com/user/project/repository/branches/protected/) | Control who can push/merge; force push **default no**; delete default no | If Agents are in “Allowed to push”, they can still push. Force-push toggle can be turned on. Multiple matching rules: **most permissive** force-push wins ([protection rules](https://docs.gitlab.com/user/project/repository/branches/protection_rules/)) |
| Claude / Cursor hooks | Claude memory page; Cursor hooks (product) | Deterministic deny of a tool | Tool-specific; not portable across all Agents |

**GitHub private repos:** some protection/ruleset features historically require paid plans. Exact current matrix is **plan-dependent**; bootstrap must treat API rejection as a recorded gap, not as “main is protected.”

---

### 3.5 Skill distribution (Q5)

| Mechanism | Updates | Footguns | Evidence |
| --- | --- | --- | --- |
| Chat URL to methodology `main` | Always latest *if* fetched | Skipped; private clone auth; silent process drift | Not an auto-load path (Q1) |
| User-level `~/.cursor/skills/` only | Per machine | Cloud Agents / teammates miss unless sync; sync is **user-private** ([Cursor Skills](https://cursor.com/docs/skills)) | Official Cloud limitation |
| Vendor snapshot in business repo + PIN SHA | Explicit refresh | Stale if never bumped | Pattern from Copier pins / git SHAs; not a vendor magic |
| Thin wrappers in `.agents/skills/` and `.claude/skills/` | Same as snapshot | Wrapper `description:` can drift | Matches auto-discovery tables (Q1) |
| `git submodule` of methodology | Honest SHA | Uninitialized submodule ([gitsubmodules](https://git-scm.com/docs/gitsubmodules)) | Official git |
| `git subtree` | Mixed history | Agents edit methodology inside the product tree | [git-subtree](https://github.com/git/git/blob/HEAD/contrib/subtree/git-subtree.adoc) |
| Cursor Remote Rule import | Cursor-only copy | Not Copilot/Claude; can stale | [Cursor Rules](https://cursor.com/docs/rules) |
| Copier `update` | Template evolution | Conflict markers; extra toolchain | [Copier updating](https://copier.readthedocs.io/en/stable/updating/) |
| MCP “is the methodology” | Live | Second control plane; auth; product-shaped | Out of methodology identity (no official MCP-as-SoT for this repo) |

Agent Skills ([spec](https://agentskills.io/specification)) are designed for **progressive** load. Dumping all playbooks into always-on `AGENTS.md` fights Codex’s 32 KiB cap and Claude’s size guidance.

---

### 3.6 Worktree UX (Q6)

Official: [git-worktree](https://git-scm.com/docs/git-worktree). Additional working trees share one repository (one `.git`). The primary checkout can stay on the default branch while tasks use other paths.

This methodology already specifies `{repo}/.worktrees/{issue-or-phase}-{owner}-{slug}` and `scripts/new-worktree.sh`. Git does **not** gitignore that path for you; committing `.worktrees/` would nest checkouts (anti-pattern). Git also **cannot** forbid a dirty primary tree — that is process.

Other harnesses sometimes put worktrees under vendor dirs (e.g. `.claude/worktrees/` in third-party project notes). That is **their** convention, not `git worktree`’s. Treat extra random clones as out-of-policy unless Command Center records an exception.

Parallel isolation is exactly what worktrees are for; wrappers (this repo’s script, or third-party `wt` tools) are UX, not new git semantics.

---

### 3.7 Security (Q7)

| Surface | Documented / implied rule | Methodology implication |
| --- | --- | --- |
| `gh repo create --private` | [gh repo create](https://cli.github.com/manual/gh_repo_create) uses CLI auth | Do **not** pass a PAT as a flag or write it to disk. |
| HTTPS remotes with `user:token@` | git remote URLs can embed credentials; they leak via `git remote -v`, logs, PIN files | Reject such URLs in bootstrap. Use SSH or credential helper. |
| GitLab pull-mirror tokens | [Pull mirror](https://docs.gitlab.com/user/project/repository/mirror/pull/) authentication methods live in GitLab settings; SSO session caveats documented | Tokens stay on the **host**, not in `AGENTS.md`. |
| GitHub Actions | Secrets are repository secrets, not files | Do not ship a required workflow in the methodology that needs a GitLab SSH key (that forces product CI). |
| `CLAUDE.local.md` | [Claude memory](https://code.claude.com/docs/en/memory): gitignore personal overlays | Templates should gitignore local overlays. |
| Private methodology clone | If the methodology were private, Cloud Agents need credentials to *fetch* it | Snapshot-in-repo means day-to-day work need not fetch. |

---

## 4. Implications for `agent-project-ops`

These are **conclusions from evidence**, not a second architecture spec. Design lives in RFC 0001.

1. **Adopt-by-URL is not binding.** Root `skills/` in this methodology clone is invisible to Cursor/Copilot auto-discovery. A later Agent in a business folder will not load it unless files exist **there**.
2. **Write a binding set, not one file.** Minimum portable core: `AGENTS.md`. Add `CLAUDE.md` import, Cursor `alwaysApply` rule, Copilot instructions, `.aider.conf.yml` `read:`, Continue rule — each justified by a primary doc above.
3. **Put skills on vendor discovery paths in the business repo.** `.agents/skills/` (Cursor + Copilot) and `.claude/skills/` (Claude; Cursor compatibility). `.github/skills/` is Copilot-documented; Cursor’s official skills table does **not** list it — optional extra, not the only copy.
4. **Keep always-on text short.** Point at a pinned snapshot. Codex truncates combined AGENTS.md (~32 KiB). Claude asks for ~200-line CLAUDE.md.
5. **Pin the methodology SHA** in the business repo so “floating HEAD of the methodology” is not silent process change (chat ≠ state).
6. **Create GitHub with `gh`, not baked tokens.** Default **private**.
7. **Projection is optional and must be named and classified.** GitLab pull-mirror (Premium) is the host-native “GitHub authority, GitLab CI copy” if available; otherwise FF-only of default branch. Never `git push --mirror` as the happy path. Never GitLab-as-write-authority in this methodology.
8. **Client hooks are a seatbelt, not a lock.** Allow the **first** create of `origin` default branch (empty remote) so `gh repo create --push` works; deny later direct `main` updates. Server protection is the lock.
9. **Worktrees:** create `.worktrees/` and gitignore it at bootstrap. Copy `new-worktree.sh` via snapshot so Agents need no sibling clone.
10. **Do not become an app framework.** Cookiecutter/Copier/`npx` are research options; identity stays documentation + tiny scripts.

---

## 5. What we cannot guarantee

Stated so the disposer does not buy a false lock:

| Residual | Why |
| --- | --- |
| Model ignores `AGENTS.md` / skills | All of the above are prompt/context, except hooks and servers |
| `git push --no-verify` | [githooks](https://git-scm.com/docs/githooks) are client-side |
| Admin / Maintainer bypass | GitHub “do not allow bypassing” is optional; GitLab “Allowed to push” can include Agents |
| Plan / API cannot enable protection | Private-repo feature matrix is plan-dependent |
| Codex truncates long AGENTS.md | 32 KiB default |
| Continue/Aider/Gemini without extra files | Not zero-config in official docs |
| Claude misses `.agents/skills/` | **Uncertain** in official Claude docs |
| VS Code opened on a subfolder | Parent `AGENTS.md` not discovered unless a VS Code setting is on |
| Uninitialized submodule | git default |
| Pull-mirror overwrite | GitLab option destroys unique projection commits |
| Human redefines SoT in chat only | Chat ≠ state if they never write Command Center |
| Malicious Agent | Out of scope for markdown methodology |

Binding + server rules target **accidental** multi-remote explosion (diverged default branch, dual SoT, silent force, dirty primary used as SoT, projection ahead of authority). They are not a secure enclave.

---

## 6. Source list

Fetched or checked **2026-09-10**. Claims in §§3–5 map to these URLs. Third-party blogs were **not** used as capability evidence.

### Binding / skills

| URL | Used for |
| --- | --- |
| https://agents.md/ | AGENTS.md convention, no required fields, nested closest-wins, Aider/Gemini FAQ config |
| https://cursor.com/docs/rules | Cursor rule types, `.mdc` vs `.md`, `alwaysApply`, nested AGENTS.md, Team/User rules, Remote Rule import, Cmd/K |
| https://cursor.com/docs/skills | Skill directories, Cloud Agent / SSH / self-hosted limitation, progressive load, `name` match |
| https://agentskills.io/specification | Skill layout, frontmatter, progressive disclosure |
| https://code.claude.com/docs/en/memory | CLAUDE.md vs AGENTS.md, `@AGENTS.md`, hooks vs context, `/init`, size, load order |
| https://code.claude.com/docs/en/skills | `.claude/skills/` |
| https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions | copilot-instructions, path instructions, AGENTS.md, head-branch review |
| https://docs.github.com/en/copilot/concepts/agents/about-agent-skills | Copilot skill locations |
| https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills | `.github/skills`, `.claude/skills`, `.agents/skills` |
| https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-copilot-overview | Copilot onboard to copilot-instructions.md |
| https://developers.openai.com/codex/guides/agents-md | Codex AGENTS.md discovery, 32 KiB, override files |
| https://aider.chat/docs/config/aider_conf.html | `.aider.conf.yml` `read:` |
| https://docs.continue.dev/customize/deep-dives/rules | `.continue/rules` |
| https://code.visualstudio.com/docs/copilot/copilot-customization | VS Code always-on files; parent-repo setting default off |

### Bootstrap / templates

| URL | Used for |
| --- | --- |
| https://cli.github.com/manual/gh_repo_create | `gh repo create` flags including `--private --source --push` |
| https://cookiecutter.readthedocs.io/en/stable/README.html | Cookiecutter one-shot generate |
| https://github.com/copier-org/copier/blob/master/docs/generating.md | `copier copy`, `--vcs-ref` |
| https://copier.readthedocs.io/en/stable/updating/ | `copier update`, answers file, conflicts |
| https://github.com/code-with-vanhai/agent-bootstrap-template | Harness bootstrap-script **pattern** |
| https://github.com/agentic-tend/copier-coding-harness | Copier harness **pattern** |
| https://github.com/boshu2/agentops/blob/main/AGENTS.md | Explicit/hookless session bootstrap **pattern** |

### Remotes / git

| URL | Used for |
| --- | --- |
| https://docs.gitlab.com/user/project/repository/mirror/push/ | Push mirror; do not push to downstream |
| https://docs.gitlab.com/user/project/repository/mirror/pull/ | Pull mirror; Premium 13.9; overwrite; pipelines |
| https://docs.github.com/en/repositories/creating-and-managing-repositories/duplicating-a-repository | `clone --mirror` / `push --mirror` |
| https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/managing-the-push-policy-for-your-repository | Push policy can block `--mirror` |
| https://git-scm.com/docs/gitsubmodules | Submodule pin + init footgun |
| https://github.com/git/git/blob/HEAD/contrib/subtree/git-subtree.adoc | Subtree copies history into parent |
| https://git-scm.com/docs/git-worktree | Shared `.git`, extra checkouts |
| https://git-scm.com/docs/githooks | `pre-push` stdin/args |

### Enforcement / security hosts

| URL | Used for |
| --- | --- |
| https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches | PR required, force/delete, admin bypass option |
| https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets | Rulesets layering, quotas, vs classic protection |
| https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners | CODEOWNERS + required reviews |
| https://docs.gitlab.com/user/project/repository/branches/protected/ | GitLab protected branches, force-push toggle |
| https://docs.gitlab.com/user/project/repository/branches/protection_rules/ | Most-permissive force-push when rules overlap |
| https://lefthook.dev/ | Lefthook install model |
| https://github.com/typicode/husky | Husky / `core.hooksPath` |

---

## 7. Document control

- **Uncertainties left explicit:** Claude/Codex auto-discovery of `.agents/skills/` and `.github/skills/`; Aider/Continue/Gemini zero-config AGENTS.md; GitHub protection feature matrix on free private repos; marketplace Actions behavior (not official).
- **Not used as evidence:** SEO blogs claiming “Claude falls back to AGENTS.md” (contradicted by Anthropic).
- **Next:** RFC 0001 phased plan (MVP stubs already on this branch). This research file should be updated when vendor docs change, with a new date or changelog line.
