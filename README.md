<p align="center">
  <img src="./docs/assets/readme-hero.svg" alt="agent-project-ops overview" width="100%" />
</p>

<p align="center">
  <a href="./LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-0ea5e9.svg"></a>
  <img alt="version" src="https://img.shields.io/badge/version-v0.1-10b981.svg">
  <img alt="GitHub native" src="https://img.shields.io/badge/control%20plane-GitHub-181717.svg?logo=github">
  <img alt="skill first" src="https://img.shields.io/badge/architecture-skill--first-6366f1.svg">
  <a href="https://github.com/Dylan5237/agent-project-ops/actions/workflows/bootstrap-contract.yml"><img alt="bootstrap contract" src="https://github.com/Dylan5237/agent-project-ops/actions/workflows/bootstrap-contract.yml/badge.svg"></a>
  <a href="https://github.com/Dylan5237/agent-project-ops/actions/workflows/enforcement-contract.yml"><img alt="enforcement contract" src="https://github.com/Dylan5237/agent-project-ops/actions/workflows/enforcement-contract.yml/badge.svg"></a>
</p>

<p align="center">
  <strong>Bootstrap once. Enforce continuously. Verify independently.</strong><br/>
  把 AI Agent 从“这次对话里的临时助手”，变成真实项目中可持续、可审计、可接力的协作成员。
</p>

<p align="center">
  <a href="./docs/GETTING_STARTED.md"><strong>Getting Started</strong></a> ·
  <a href="./PRINCIPLES.md">Principles</a> ·
  <a href="./playbooks/">Playbooks</a> ·
  <a href="./skills/">Skills</a> ·
  <a href="./docs/evidence/phase-11-self-dogfood.md">Self-dogfood evidence</a>
</p>

---

## What is agent-project-ops?

`agent-project-ops` 是一套 **Skill-first 的多 Agent 项目治理方法论**。

它不提供业务框架，也不发明新的代码托管平台。它解决的是一个更底层的问题：

> 当 ChatGPT、Claude Code、Cursor、Copilot 和本地 Coding Agent 长期参与真实项目时，如何让项目状态、写权威、分支纪律、验证证据和人类拍板边界不随着会话切换而失控？

核心约束只有几条：

| Rule | Meaning |
| --- | --- |
| **GitHub `origin` = authority** | 唯一写权威；其他远端只能是 projection |
| **Chat ≠ state** | 项目事实进入 repo、Issue、PR、CI、evidence |
| **One task = one worktree / branch / PR** | 并行工作彼此隔离 |
| **Unknown remotes fail closed** | 未分类远端默认拒绝 |
| **Merge ≠ Phase PASS** | Agent 提证据，Disposer 决定 `ACCEPT / RETURN` |
| **Server protection is the real gate** | client hook 可被绕过，不能当最终安全边界 |

> v0.1 已完成真实仓库 bootstrap、server-side protection 绕过测试和 self-dogfood 全生命周期验证，可用于 **real controlled use**。

## Start in 3 minutes

### Recommended: tell an Agent what you want

```text
Run the bootstrap-project skill from agent-project-ops and initialize this project.
```

### Or run the bootstrap directly

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

Bootstrap creates durable repo bindings, pins the methodology SHA, installs the tracked local hook, registers authority/projection remotes, creates GitHub `origin`, and reports protection capability **A / B / C**.

**Then read → [Getting Started](./docs/GETTING_STARTED.md)** for protection choices, fresh-clone recovery, Command Center setup, daily Phase workflow, and projection rules.

> GitHub Free + **private repo** cannot provide the branch protection required by this methodology, so bootstrap correctly reports **Capability C / BLOCKED**. Client hooks are bypassable with `--no-verify`; server-side protection is the real gate.

<p align="center">
  <img src="./docs/assets/how-it-works.svg" alt="How agent-project-ops works" width="100%" />
</p>

## What changes after bootstrap?

A project gains a small, durable control surface rather than a second framework:

```text
your-project/
├── AGENTS.md                     # canonical Agent instructions
├── CLAUDE.md                     # adapter → AGENTS.md
├── .agent-project-ops/
│   ├── PIN                       # pinned methodology repo/ref/SHA
│   ├── remotes                   # authority / projection registry
│   ├── PRINCIPLES.md
│   ├── playbooks/
│   └── scripts/
├── .agents/skills/               # project-facing skill wrappers
├── .githooks/pre-push            # bypassable local guard
├── .github/CODEOWNERS
├── .github/copilot-instructions.md
├── .cursor/rules/
└── ... your product code
```

A fresh Agent should be able to recover the project's authority, rules, current control plane, and handoff path from durable state instead of relying on the bootstrap chat.

See the full structure and takeover procedure in [Getting Started](./docs/GETTING_STARTED.md#what-bootstrap-writes).

## Daily operating model

```text
Issue / Phase → Freeze → Worktree / Branch → Implement → PR / CI
                                             ↓
                                  replayable evidence
                                             ↓
                             Disposer ACCEPT / RETURN
```

AI 可以自主推进实现、测试、CI 和证据整理；只有在 Freeze、Accept、Architecture Exception 等真正需要 disposer 决策的边界才打断人。

Detailed lifecycle: [phase-lifecycle](./playbooks/phase-lifecycle.md) · [verification-and-evidence](./playbooks/verification-and-evidence.md)

## Protection capability

| Level | Server-side state | Project posture |
| --- | --- | --- |
| **A** | PR + independently enforceable reviewer / code-owner gate | strongest |
| **B** | PR required + admins enforced; no independent-human guarantee | accepted for controlled use |
| **C** | protection unavailable or unverifiable | **BLOCKED / fail closed** |

`agent-project-ops` never upgrades a C environment by wording alone. Capability is reported from the environment that actually exists.

## Verified v0.1

| Gate | Result |
| --- | --- |
| Bootstrap contract | ✅ PASS |
| Real private/public bootstrap smoke | ✅ PASS |
| `git push --no-verify origin main` rejected server-side | ✅ PASS |
| Fresh-clone hook recovery | ✅ PASS |
| Full self-dogfood: Command Center → Phase → implementation → evidence → disposer Accept | ✅ PASS |

Replayable evidence: [docs/evidence/phase-11-self-dogfood.md](./docs/evidence/phase-11-self-dogfood.md)

## Documentation

| Start here | Purpose |
| --- | --- |
| **[Getting Started](./docs/GETTING_STARTED.md)** | bootstrap, protection, first project, daily workflow |
| [PRINCIPLES.md](./PRINCIPLES.md) | non-negotiable design rules |
| [playbooks/](./playbooks/) | operational procedures |
| [skills/](./skills/) | Agent entrypoints |
| [docs/rfcs/](./docs/rfcs/) | design contracts |
| [docs/research/](./docs/research/) | research and audit history |
| [docs/evidence/](./docs/evidence/) | replayable acceptance evidence |
| [templates/](./templates/) | binding / Issue / PR templates |
| [tests/](./tests/) | enforcement and bootstrap contracts |

## Design boundaries

This project deliberately does **not** claim:

- a product/app runtime, domain model, deploy stack, or business SOP;
- universal Agent compliance with repo instructions;
- client hooks as a security boundary;
- GitLab or another mirror as a second source of truth;
- PR merge as project acceptance;
- silent upgrades to the latest methodology revision.

Business repos pin a real methodology SHA. Agents propose. The named disposer accepts.

## License

[MIT](./LICENSE)
