<p align="right">
  <strong>English</strong> · <a href="./GETTING_STARTED.zh-CN.md">简体中文</a>
</p>

# Getting Started

This guide is the shortest path from **“I want AI Agents to work on a real project”** to a repository with durable project governance.

`agent-project-ops` is a methodology and control layer. It does not replace your application architecture, runtime, deployment stack, or product process.

---

## 1. Before you start

You need:

- Git
- Bash / Git Bash
- GitHub CLI (`gh`) if bootstrap should create or configure the GitHub repository
- a real git checkout of `agent-project-ops`
- a named human disposer, for example `@your-handle`

The disposer is the person allowed to make decisions such as:

- `FREEZE ACK`
- `PHASE ACCEPT`
- `PHASE RETURN`
- `EXCEPTION ACCEPT`

The Agent may prepare and propose these decisions, but it does not self-Accept.

---

## 2. Choose your protection posture first

The methodology reports what GitHub can actually enforce.

| Capability | Meaning | Can proceed? |
| --- | --- | --- |
| **A** | PR + independently enforceable reviewer / code-owner gate | Yes — strongest |
| **B** | PR required + admins enforced, but no independently guaranteed human identity | Yes — controlled use |
| **C** | required server protection is unavailable or cannot be verified | **Yes — record C and continue** (expected on GitHub Free private; never claim B/A) |

Important:

- client hooks can be bypassed with `--no-verify`;
- client hooks are therefore an early local guard, **not** the final security boundary;
- server-side GitHub protection is the real gate when it is available;
- GitHub Free private repositories do not provide the required protection here, so they correctly fall to **Capability C**. That is expected. Record C on Command Center and continue. Do not require GitHub Pro to finish init;
- GitHub Free public repositories can provide the PR-only protection used for Capability B. Use public (or Pro) when a real server-side gate is required — not as a condition of finishing init.

If the same GitHub account is used by both the human disposer and Agent automation, do **not** describe that setup as an independently enforced human-review boundary.

---

## 3. Bootstrap a new project

### Preferred: ask a compatible Agent

Use this instruction:

```text
Run the bootstrap-project skill from agent-project-ops and initialize this project.
```

A compatible Agent should read the methodology, inspect the environment, and invoke the bootstrap flow rather than improvising its own project rules.

### Direct CLI

From a real checkout of this methodology:

```bash
bash scripts/bootstrap-project.sh \
  --name my-project \
  --dir ../my-project \
  --github OWNER/my-project \
  --disposer @OWNER \
  --no-projection \
  --private \
  --yes
```

On GitHub Free, `--private` is valid and typically reports **Capability C**. That is expected: record C and continue. Use `--public` (or a paid plan) only when you need a real server-side B gate and public visibility is acceptable:

```bash
bash scripts/bootstrap-project.sh \
  --name my-project \
  --dir ../my-project \
  --github OWNER/my-project \
  --disposer @OWNER \
  --no-projection \
  --public \
  --yes
```

Before creating anything, you can inspect the intended plan:

```bash
bash scripts/bootstrap-project.sh \
  --name my-project \
  --dir ../my-project \
  --github OWNER/my-project \
  --disposer @OWNER \
  --no-projection \
  --dry-run
```

### Optional projection vs colleague share-export

A **projection** remote is a same-history fast-forward mirror of GitHub (full tree, including ops). Only add one when Command Center names that host as projection — **not** for colleague GitLab.

```bash
bash scripts/bootstrap-project.sh \
  --name my-project \
  --dir ../my-project \
  --github OWNER/my-project \
  --disposer @OWNER \
  --projection-url git@git.internal.example:group/my-project.git \
  --yes
```

That second remote never becomes a second source of truth.

**Colleague GitLab** is a [share-export](../playbooks/share-export.md): a filtered business tree. Do not pass its URL as `--projection-url`. After GitHub `origin` exists:

```bash
bash scripts/share-export.sh \
  --dir ../my-project \
  --ref origin/main \
  --push git@gitlab.example:group/my-project.git \
  --yes
```

Contract: [ADR 0003](./adr/0003-share-export-vs-projection.md). The helper refuses to publish if denylist paths (bindings, hooks, Agent entry files) would be included. Default **keeps** `.github/workflows/` so pure business CI can travel with the export; Issue/PR templates and CODEOWNERS are stripped.

<p align="center">
  <img src="./assets/quick-start.en.svg" alt="agent-project-ops quick start" width="100%" />
</p>

---

## 4. What bootstrap writes

Bootstrap creates a small durable control surface so later Agents can recover the project without the original chat.

```text
your-project/
├── AGENTS.md
├── CLAUDE.md
├── .agent-project-ops/
│   ├── PIN
│   ├── remotes
│   ├── PRINCIPLES.md
│   ├── playbooks/
│   └── scripts/
├── .agents/skills/
├── .githooks/pre-push
├── .github/
│   ├── CODEOWNERS
│   └── copilot-instructions.md
├── .cursor/rules/
├── .continue/rules/
└── ... your product code
```

Key files:

- `AGENTS.md` — canonical project instructions for Agents;
- `.agent-project-ops/PIN` — exact methodology repo/ref/SHA used by this project;
- `.agent-project-ops/remotes` — explicit authority/projection/share-export registry;
- `.githooks/pre-push` — local guard that fails closed on unregistered remotes and forbidden pushes;
- repo-specific adapter files — Claude, Cursor, Copilot, Continue, Aider, etc. converge toward the same durable rules.

The project pins a real methodology SHA. It does not silently float with methodology `main`.

<p align="center">
  <img src="./assets/repository-structure.en.svg" alt="Repository structure and control plane" width="100%" />
</p>

---

## 5. Verify bootstrap output

At minimum, check:

```bash
cat .agent-project-ops/PIN
cat .agent-project-ops/remotes
git remote -v
git config --get core.hooksPath
```

Expected local hook configuration:

```text
.githooks
```

Also confirm that bootstrap reports protection capability **A**, **B**, or **C** explicitly.

If protection is **C**, record **C** on Command Center and continue. Do not reinterpret it as B or A. On GitHub Free private, C is expected.

---

## 6. Fresh clone recovery

Git does **not** clone local `core.hooksPath` configuration.

A fresh clone contains the tracked hook files but does not automatically activate them.

Check:

```bash
git config --get core.hooksPath
```

If it is not `.githooks`, run:

```bash
bash .agent-project-ops/scripts/install-hooks.sh
```

Then verify again:

```bash
git config --get core.hooksPath
```

This behavior is intentional and tested. The methodology fails closed rather than pretending clone-local Git config is portable.

---

## 7. Authority, projection, and share-export

Default recommendation: **use only `origin`**.

When a second git host is a **same-history projection** (Command Center must name it as such):

```text
GitHub origin
   │
   │ sole write authority (full ops tree)
   ▼
accepted main
   │
   └────────────► internal git host / deployment projection
                  same commits, FF only
```

When the second host is **colleague GitLab**, it is **not** that diagram:

```text
GitHub origin  (SoT + ops)
   │
   │ scripts/share-export.sh (strip denylist)
   ▼
colleague GitLab  (business files only; not SoT; not the same SHAs)
```

Rules:

1. `origin` is the sole write authority;
2. unknown remotes are blocked until classified;
3. topic branches go to authority;
4. projection accepts only the authority-approved default branch state **and the same history**;
5. first projection seed must match the current authority tip;
6. non-fast-forward projection updates are rejected;
7. projection never becomes a second control plane;
8. colleague GitLab uses [share-export](../playbooks/share-export.md), never `git push --mirror` of the bound clone.

See [git-authority-and-projection](../playbooks/git-authority-and-projection.md) and [share-export](../playbooks/share-export.md).

---

## 8. Start the project control plane

Bootstrap creates the durable repository binding. The next step is to establish the project operating state.

Follow [start-project](../playbooks/start-project.md) to create:

- Command Center
- disposer record
- authority / projection / share-export record
- protection capability record
- project labels
- first Phase

The Command Center is the durable index for the project. Chat is not the project index.

---

## 9. Daily Phase workflow

The normal lifecycle is:

```text
1. Create Issue / Phase
2. Freeze the scope and acceptance tests
3. Disposer: FREEZE ACK
4. Create one worktree / branch for the task
5. Implement + test
6. Open PR + run CI
7. Before asking merge: comment exactly `bugbot run` on the PR; disposer waits for Bugbot (`Dylan5237/agent-project-ops` self-dogfood may skip)
8. Produce replayable evidence
9. Agent: EVIDENCE READY
10. Disposer: PHASE ACCEPT or PHASE RETURN
11. Close Phase
```

Rules that matter most:

- no implementation before Freeze when the Phase contract requires it;
- one task = one worktree / branch / PR;
- no routine direct push to `main`;
- Agent may autonomously implement, test, inspect CI, and prepare evidence;
- Agent pauses when a real product/architecture/disposer decision is required;
- PR merge does **not** equal `PHASE ACCEPT`;
- before asking the disposer to merge, comment exactly `bugbot run` on the PR and wait for Bugbot results; Bugbot pass ≠ `PHASE ACCEPT` (`Dylan5237/agent-project-ops` self-dogfood may skip the wake/wait; other repos follow the full gate);
- acceptance evidence must be replayable without the original chat.

See:

- [phase-lifecycle](../playbooks/phase-lifecycle.md)
- [git-worktree](../playbooks/git-worktree.md)
- [issues-and-prs](../playbooks/issues-and-prs.md)
- [verification-and-evidence](../playbooks/verification-and-evidence.md)

---

## 10. What a fresh Agent should recover

A fresh compatible Agent entering the repository should be able to determine, from durable state:

- who the disposer is;
- which remote is the authority;
- whether any projection exists;
- whether colleague GitLab is share-export rather than projection;
- where the Command Center is;
- which Phase is active;
- whether direct `main` pushes are forbidden;
- whether local hooks need installation;
- which methodology SHA the project is pinned to;
- that the Agent cannot self-Accept.

If that information only exists in an old chat, the project is not durably governed yet.

---

## 11. Existing repository adoption

A one-time chat instruction can help an Agent understand the methodology:

```text
Load https://github.com/Dylan5237/agent-project-ops,
read PRINCIPLES.md and the relevant skills,
and follow the playbooks.
```

But this is session guidance only.

For long-term use, deliberately add durable repo-level bindings, remote registry, Command Center, and protection capability. Do not assume later Agents will remember the adoption conversation.

---

## 12. Operational boundaries

`agent-project-ops` intentionally does not promise:

- a secure enclave;
- universal compliance from every third-party Agent;
- a business/domain framework;
- a deployment platform;
- GitLab as co-authority;
- GitLab as a full-tree projection of `agent-project-ops` bindings;
- that hooks cannot be bypassed;
- that a merged PR means accepted work;
- automatic trust when server-side protection is missing.

The model is simple:

> **Durable rules in the repo. Explicit authority in git. Critical enforcement at the server. Replayable evidence before human acceptance.**

---

## Next reads

- [PRINCIPLES.md](../PRINCIPLES.md) — the non-negotiable design rules
- [ADR 0004](./adr/0004-free-private-capability-c.md) — Free-private capability C is expected
- [bootstrap-project playbook](../playbooks/bootstrap-project.md) — bootstrap contract in detail
- [share-export playbook](../playbooks/share-export.md) — colleague GitLab = filtered business tree
- [start-project playbook](../playbooks/start-project.md) — establish the control plane
- [phase-lifecycle](../playbooks/phase-lifecycle.md) — run a Phase end to end
- [Agent skills](../skills/) — executable entrypoints for compatible Agents
- [Self-dogfood evidence](./evidence/phase-11-self-dogfood.md) — verified v0.1 lifecycle evidence
