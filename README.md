# Agent Project Ops (APO)

[简体中文](./README.zh-CN.md) · [Release notes](./docs/releases/v0.2.0.md) · [Upgrade existing projects](./docs/UPGRADE.md) · [Getting started](./docs/GETTING_STARTED.md)

**Keep AI-built software maintainable beyond a single session or Agent.**

APO is a Skill-first project-operations methodology with GitHub as the durable
project source of truth. It records decisions, isolates task changes, requires
replayable evidence and supports Agent handoff based on actual repository state.
It is not another coding Harness, business framework, cloud service or deployment
stack.

## v0.2.0: portable defaults and reviewable rule upgrades

The **package version is 0.2.0** ([VERSION](./VERSION)). Published artifacts are
listed under [GitHub Releases](https://github.com/Dylan5237/agent-project-ops/releases);
a draft candidate or CI-only PR is not a release. `PRINCIPLES.md` continues to
identify the **v0.1.2 invariant contract**, independently of package version.
Project PIN files identify the exact methodology Git commit.

| Capability | Behavior |
| --- | --- |
| Generic bootstrap | No mandatory registration in the author's personal Fleet/box digest |
| Review policy | No universal Cursor Bugbot dependency; explicit project CI/review/Accept gates remain |
| Worktree base | Explicit choice, recorded project setting or verified remote default; ambiguous choices stop |
| Provenance | Clean committed source and a real PIN SHA, not silently following main |
| Defaults/templates | origin-only by default, extra remotes opt-in, actual source/PIN in CC templates |
| Local Doctor | Read-only binding/remote/hook diagnostics; unchecked server guarantees remain UNKNOWN |
| Existing-project upgrade | `upgrade-project` Skill and read-only three-way preview/Git patch generator; preserve custom project rules, stop on conflicts, use isolated application and checked rollback |

The methodology repository's own self-dogfood Fleet pointer remains intact;
it is not an external adopter prerequisite. The general three-journey natural-
language entrypoint proposed in #75 is **not included** pending real user and
cross-host UX validation.

## Install a fixed release

Use Git, Bash (Git Bash on Windows), and Python 3.10+ for the upgrade generator.
Creating a real GitHub project additionally needs an authorized GitHub CLI `gh`;
local-only bootstrap is available with explicit `--skip-github`.

```bash
git clone --branch v0.2.0 https://github.com/Dylan5237/agent-project-ops.git apo-v0.2.0
cd apo-v0.2.0
```

Keep complete history so the old project PIN can be resolved. Source ZIPs contain
no Git history and are not upgrade-source clones. Release assets include
`RELEASE_SHA.txt` and `SHA256SUMS`.

### New project

Load `skills/bootstrap-project/SKILL.md` in a compatible Agent, or run:

```bash
bash scripts/bootstrap-project.sh \
  --name my-project --dir ../my-project \
  --github-repo OWNER/my-project --disposer @OWNER --private --yes
```

Replace OWNER with actual account information and authorize real remote writes.
The default is just GitHub `origin`, not a mandatory extra-remote questionnaire.
See [Getting Started](./docs/GETTING_STARTED.md). Existing nonempty repositories
that never adopted APO use [adoption](./playbooks/adopt-existing-project.md), not
greenfield bootstrap over their files.

### Project already using an older APO version

Do not rerun bootstrap, edit only PIN, or overwrite the entire project AGENTS.
Ask your local Agent to use `skills/upgrade-project/SKILL.md` **from the trusted
release clone**. It should inspect the project's actual PIN/CC, create an isolated
upgrade task worktree at the approved baseline, and show a readonly preview.
Only after you approve that exact `plan_id` should it export the Git patch,
run `git apply --check`, apply, test and prepare the ordinary project PR.

[Full upgrade instructions, CLI and rollback](./docs/UPGRADE.md).
The generator does not modify target files or contact GitHub. The original
worktree and baseline commit remain recovery material. Project-specific rules,
remotes, Git configuration and business files are not replaced blindly.

**Local files and live GitHub rules are separate steps.** The upgrade Skill
requires the Agent to reconcile only the selected project's inherited old
Fleet/box/Bugbot defaults under project-level approval, preserve explicit local
review policies, owners and history, and reference the upgrade PR/new PIN in CC.
Without access, report LOCAL PATCH READY / CONTROL PLANE PENDING, not completion.

## Core operating contract

GitHub `origin` is the single write authority. Chat is not project state. Each
task is isolated and linked through Issue/worktree/branch/PR. Unknown remotes
must not be guessed safe. Scope, verification evidence and human decisions are
explicit. A merged PR is **not** a Phase Accept.

Projection/export/share-export are advanced Git roles loaded only when needed.
A local hook is bypassable, not a server-side security guarantee. Report A/B/C
from observed capabilities; never call C a verified A/B gate, and never turn
missing optional integrations into a universal stop-all-work rule.

## Verification and limits

The release workflow tests core shell contracts, Python upgrade positive/negative
fixtures and Linux/Windows/macOS migration using a project produced by the **real
v0.1.2 bootstrap**, including preservation, reverse application and repeat calls.
Read the Actions results at the exact release SHA. CI does not establish arbitrary
Agent compliance, live user experience, independent reviewer identity or business
acceptance.

Automatic migration supports recognized bootstrap-owned layouts. Modified
snapshots, unrecognized hand-written bindings, unknown old PINs, conflicting
changes, symlinks and dirty work stop for manual three-way review. There is no
force-overwrite escape hatch. Releasing APO never automatically migrates all
existing business projects.

Historical v0.1 bootstrap/protection/self-dogfood evidence remains in
[docs/evidence](./docs/evidence/phase-11-self-dogfood.md); do not reuse it as proof
for every new environment. #85 records the historical missing pre-implementation
Freeze deviation and prospective exception; packaging is not retroactive Freeze
or per-Phase Accept.

## Documentation

[Principles](./PRINCIPLES.md) · [Playbooks](./playbooks/) · [Skills](./skills/) ·
[ADRs](./docs/adr/) · [RFCs](./docs/rfcs/) · [Research](./docs/research/) ·
[Evidence](./docs/evidence/) · [Templates](./templates/) · [Tests](./tests/)

Common Skills: [bootstrap-project](./skills/bootstrap-project/SKILL.md),
[upgrade-project](./skills/upgrade-project/SKILL.md),
[github-multi-agent-project-ops](./skills/github-multi-agent-project-ops/SKILL.md),
[git-worktree-and-branch](./skills/git-worktree-and-branch/SKILL.md),
[project-diagnostics](./skills/project-diagnostics/SKILL.md), and
[issues-prs-and-evidence](./skills/issues-prs-and-evidence/SKILL.md).

License: [MIT](./LICENSE). Business SOPs, domain models and production data do not
belong in this methodology repository.
