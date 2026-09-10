# agent-project-ops

Skill-first **project operations** for vibe-coding: the local coding Agent is often the day-to-day project owner, GitHub Issues/PRs are the control plane, and git worktrees keep parallel work honest.

本仓库是**方法论**，不是产品。零业务 SOP、零领域模型、零运行时/低代码栈。任何业务仓库都可以把 Agent 指向这里的 `skills/` 与 `PRINCIPLES.md`。

**Principles:** [PRINCIPLES.md](./PRINCIPLES.md) (v0.1.1)

## 给谁用 / Who

| Role | How they use this repo |
| --- | --- |
| Local coding Agent | Read `PRINCIPLES.md` + every `skills/*/SKILL.md`; follow playbooks step-by-step. New empty folder → [bootstrap](./playbooks/bootstrap-project.md) (proposed). |
| Human owner / reviewer | Dispose: freeze, Accept, merge policy, Architecture Exception. |
| Optional GitHub | Copy `templates/` into a **business** repo’s `.github/` — never required to use the skills. |

## 60 秒接入 / 60-second adopt

1. In the **business** repository (the one with product code), tell the Agent:

   > Load `https://github.com/Dylan5237/agent-project-ops` — read `PRINCIPLES.md` and every file under `skills/`. Follow those playbooks. Do not copy business logic into the methodology repo.

2. Optionally copy helpers (business repo only):

   ```bash
   # from this methodology clone
   mkdir -p /path/to/business/.github/ISSUE_TEMPLATE
   mkdir -p /path/to/business/.github/PULL_REQUEST_TEMPLATE
   cp templates/ISSUE_TEMPLATE/*.md /path/to/business/.github/ISSUE_TEMPLATE/
   cp templates/PULL_REQUEST_TEMPLATE/*.md /path/to/business/.github/PULL_REQUEST_TEMPLATE/
   # apply labels from templates/labels.md via gh or the GitHub UI
   ```

3. Open a **Command Center** issue in the business repo and run [playbooks/start-project.md](./playbooks/start-project.md).

No app `package.json`, deploy stack, or product CI in **this** repository. Optional bootstrap (below) scaffolds **binding files** in a business repo; it is not an application framework.

## Bootstrap (proposed)

End-state: tell a local Agent *“Initialize this project using Dylan5237/agent-project-ops.”* The Agent should create a folder, write auto-load binding (`AGENTS.md` and equivalents), vendor a **pinned** methodology snapshot, create `.worktrees/`, create a **GitHub private** `origin`, and ask whether to add a **projection** remote (mirror/FF only).

That path is specified in [docs/rfcs/0001-bootstrap-and-binding.md](./docs/rfcs/0001-bootstrap-and-binding.md) (depends on Principle 10 / [playbooks/git-authority-and-projection.md](./playbooks/git-authority-and-projection.md)). Stubs:

| Piece | Path |
| --- | --- |
| Skill | [skills/bootstrap-project/SKILL.md](./skills/bootstrap-project/SKILL.md) |
| Playbook | [playbooks/bootstrap-project.md](./playbooks/bootstrap-project.md) |
| Script | [scripts/bootstrap-project.sh](./scripts/bootstrap-project.sh) (`--dry-run` first) |
| Binding templates | [templates/AGENTS.md](./templates/AGENTS.md), `templates/CLAUDE.md`, `templates/cursor-rules/` |

Existing-repo adopt (chat URL, no scaffold) remains valid. Bootstrap does **not** replace start-project: after the repo exists, still open Command Center, label, Freeze before `feat/`.

Honest limit: files in the business repo raise the chance later Agents obey; they cannot stop `--no-verify`, admin bypass, or a non-compliant model. See the RFC threat model.

## 地图 / Map

### Playbooks

| File | Use when |
| --- | --- |
| [playbooks/bootstrap-project.md](./playbooks/bootstrap-project.md) | **No repo yet:** folder, binding, GitHub private origin, optional projection |
| [playbooks/start-project.md](./playbooks/start-project.md) | First Command Center, labels, protect `main`, first Phase |
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
| Bootstrap project (proposed) | [skills/bootstrap-project/SKILL.md](./skills/bootstrap-project/SKILL.md) |
| GitHub multi-agent project ops | [skills/github-multi-agent-project-ops/SKILL.md](./skills/github-multi-agent-project-ops/SKILL.md) |
| Git worktree and branch | [skills/git-worktree-and-branch/SKILL.md](./skills/git-worktree-and-branch/SKILL.md) |
| Git authority and projection | [skills/git-authority-and-projection/SKILL.md](./skills/git-authority-and-projection/SKILL.md) |
| Issues, PRs, and evidence | [skills/issues-prs-and-evidence/SKILL.md](./skills/issues-prs-and-evidence/SKILL.md) |

### Templates & examples

- Issue/PR markdown: [templates/](./templates/)
- Label dictionary: [templates/labels.md](./templates/labels.md)
- Optional helpers: [scripts/new-worktree.sh](./scripts/new-worktree.sh), [scripts/bootstrap-project.sh](./scripts/bootstrap-project.sh)
- RFCs: [docs/rfcs/](./docs/rfcs/)
- External illustrations only: [examples/README.md](./examples/README.md)

## NON-GOALS

- **Not a product.** No domain SOPs, stage graphs tied to a business, or vendor runtime docs.
- **Not a framework.** No app dependencies or deploy pipelines. Optional bootstrap scaffolds **agent binding** in an empty generic repo; it does not ship a product starter kit.
- **Not a second control plane.** Chat, Notion, and shop-floor bots are out of scope. GitHub + git + local Agent only.
- **Not a license to self-Accept.** Agents propose; the named disposer Accepts.
- **Not coupled to example repos.** Links in `examples/` are optional reading.

## License

[MIT](./LICENSE)
