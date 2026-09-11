# agent-project-ops

Skill-first **project operations** for vibe-coding: the local coding Agent is often the day-to-day project owner, GitHub Issues/PRs are the control plane, and git worktrees keep parallel work honest.

本仓库是**方法论**，不是产品。零业务 SOP、零领域模型、零运行时/低代码栈。GitHub `origin` 是写权威；可选第二远端只作为 projection。

**Principles:** [PRINCIPLES.md](./PRINCIPLES.md) (v0.1.1)

## 给谁用 / Who

| Role | How they use this repo |
| --- | --- |
| Local coding Agent | Read `PRINCIPLES.md` + relevant `skills/*/SKILL.md`; follow playbooks step-by-step. |
| Human owner / reviewer | Dispose: freeze, Accept, merge policy, Architecture Exception. |
| Business repository | Stores durable binding + pinned methodology snapshot so later Agents do not depend on the bootstrap chat. |

## 新项目：durable bootstrap

Preferred path for a **new/empty** project:

```bash
# from a real git checkout of this methodology
scripts/bootstrap-project.sh --dry-run \
  --name sample-project \
  --disposer @your-handle \
  --no-projection

scripts/bootstrap-project.sh \
  --name sample-project \
  --disposer @your-handle \
  --no-projection
```

Default GitHub creation is private. Optional projection:

```bash
scripts/bootstrap-project.sh \
  --name sample-project \
  --disposer @your-handle \
  --projection-url git@gitlab.example:group/sample-project.git
```

Bootstrap writes root Agent bindings, project skill wrappers, `.worktrees/`, a real-SHA `.agent-project-ops/PIN`, a clone-portable remote registry, and the tracked pre-push hook. It then creates GitHub `origin` unless `--skip-github` is explicitly used.

**Fresh-clone caveat:** Git does not clone `core.hooksPath`. Later clones must verify it is `.githooks` and run `.agent-project-ops/scripts/install-hooks.sh` when needed. Client hooks remain bypassable; they are not a security boundary.

**Protection reporting:** bootstrap reports observed capability **A** (code-owner/independent review enforced), **B** (PR-only), or **C** (unprotected/BLOCKED). If the Agent and human disposer share one GitHub identity, GitHub cannot distinguish them; do not call PR-only/CODEOWNERS configuration a human-vs-Agent hard gate.

Then run [playbooks/start-project.md](./playbooks/start-project.md): Command Center → labels → record PIN/remotes/protection → first Phase → Freeze before implementation.

## Existing repo / session-only adopt

For an existing repository, manually telling the current Agent to load this methodology is still useful, but it is **session-level guidance, not durable binding** by itself:

> Load `https://github.com/Dylan5237/agent-project-ops`, read `PRINCIPLES.md` and the relevant skills, and follow the playbooks.

Use `start-project` and deliberately add/approve binding files rather than pretending the chat instruction will be remembered by every later Agent.

## 地图 / Map

### Playbooks

| File | Use when |
| --- | --- |
| [playbooks/bootstrap-project.md](./playbooks/bootstrap-project.md) | New empty project: repo + binding + GitHub authority + optional projection |
| [playbooks/start-project.md](./playbooks/start-project.md) | Command Center, labels, protection capability, first Phase |
| [playbooks/phase-lifecycle.md](./playbooks/phase-lifecycle.md) | Freeze → Implement → Verify → Accept → CLOSED |
| [playbooks/staff-and-dispatch.md](./playbooks/staff-and-dispatch.md) | Who owns what; how to dispatch Agents |
| [playbooks/git-worktree.md](./playbooks/git-worktree.md) | One task, one worktree; start from current authority tip |
| [playbooks/git-branch-and-remote.md](./playbooks/git-branch-and-remote.md) | Default: `origin` only; branch names; never push `main` |
| [playbooks/git-authority-and-projection.md](./playbooks/git-authority-and-projection.md) | Optional second remote = projection/mirror only |
| [playbooks/issues-and-prs.md](./playbooks/issues-and-prs.md) | Issues, PRs, status labels |
| [playbooks/verification-and-evidence.md](./playbooks/verification-and-evidence.md) | Evidence vs implementation |
| [playbooks/blocked-and-exceptions.md](./playbooks/blocked-and-exceptions.md) | `blocked` + Architecture Exception |

### Skills (Agent entrypoints)

| Skill | Path |
| --- | --- |
| Bootstrap project | [skills/bootstrap-project/SKILL.md](./skills/bootstrap-project/SKILL.md) |
| GitHub multi-agent project ops | [skills/github-multi-agent-project-ops/SKILL.md](./skills/github-multi-agent-project-ops/SKILL.md) |
| Git worktree and branch | [skills/git-worktree-and-branch/SKILL.md](./skills/git-worktree-and-branch/SKILL.md) |
| Git authority and projection | [skills/git-authority-and-projection/SKILL.md](./skills/git-authority-and-projection/SKILL.md) |
| Issues, PRs, and evidence | [skills/issues-prs-and-evidence/SKILL.md](./skills/issues-prs-and-evidence/SKILL.md) |

### Contracts, research, templates

- RFC 0001 + post-audit hardening: [docs/rfcs/](./docs/rfcs/)
- Research + methodology audit: [docs/research/](./docs/research/)
- Issue/PR and binding templates: [templates/](./templates/)
- Enforcement CI/tests: `.github/workflows/enforcement-contract.yml`, `tests/`
- Worktree helper: [scripts/new-worktree.sh](./scripts/new-worktree.sh)

## NON-GOALS

- **Not a product/app framework.** No runtime, domain SOP, business stage graph, or deploy stack.
- **Not a secure enclave.** Instruction files can be ignored; client hooks can be bypassed; admins can defeat controls they own.
- **Not a second control plane.** GitHub Issues/PRs + git remain authoritative; chat is not state.
- **Not a license to self-Accept.** Agents propose; the named disposer Accepts.
- **Not GitLab-as-authority.** Other git hosts are projection or out of scope for this methodology.
- **Not silently latest.** Business repos pin a methodology SHA; updates are explicit rather than floating with methodology `main`.

## License

[MIT](./LICENSE)
