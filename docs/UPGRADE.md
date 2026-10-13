# Upgrade an existing project's APO rules to v0.2.0

[简体中文与可直接转交 Agent 的指令](./UPGRADE.zh-CN.md)

A project contains a **pinned snapshot**. Updating a global Skill or changing only
PIN does not update that snapshot, its generated Agent rules, or live GitHub
Command Center policies. This workflow treats those as separate responsibilities.

## One-line URL-first entry

Use the following instruction in the current project:

```text
使用 https://github.com/Dylan5237/agent-project-ops 更新当前项目的apo规则。
```

For an unbound project, use `使用 https://github.com/Dylan5237/agent-project-ops 初始化当前项目。`. The user should not need to remember a Skill or CLI command. With the right GitHub/local Git access, the Agent locates the latest **published stable Release** and exact SHA, then loads the safe upgrade procedure below; with insufficient tools it reports a limitation. The selected upgrade `plan_id` still requires explicit approval.

## Supported path

The automatic generator supports the known v0.1.x bootstrap layout with a valid
four-field `.agent-project-ops/PIN` and reconstructable generated root `AGENTS.md`.
Project-specific, nonconflicting bridge text is preserved. Modified snapshot
files, an unknown source commit, hand-written unrecognizable root bindings,
symlinks, dirty work or conflicting changes **stop for manual three-way review**.
There is no overwrite-all escape hatch.

Use Git and Python 3.10+. Shell examples require Bash (Git Bash on Windows).
In a separate trusted directory, clone the release **with history**:

```bash
git clone --branch v0.2.0 https://github.com/Dylan5237/agent-project-ops.git ../apo-v0.2.0
```

Do not use `--depth 1`: the exact old PIN commit must exist locally. A trusted
old clone can be supplied as `--old-source`. Do not edit the old PIN to fake
compatibility. Source archives are useful for inspection, but have no `.git`
history and cannot be used directly as the upgrade source.

## Recommended Agent entrypoint

The short prompt above is enough to express intent. Internally the Agent should read
`skills/upgrade-project/SKILL.md` **from the verified release clone**, inspect the
selected project's real binding/CC/Phase, and follow its preview-first process. Scope this to one chosen project. No fleet-wide migration,
repository visibility change, automatic merge, deployment or Phase acceptance
is implied.

## Preview and export

1. Preserve the current project and its exact approved baseline commit. Create a
   dedicated upgrade topic branch/worktree using that baseline; do not guess
   `main`/`develop` and do not share this worktree with another writer.
2. Run the readonly preview, storing output outside both worktrees:

   ```bash
   python3 /path/apo-v0.2.0/scripts/prepare-upgrade.py \
     --project /path/project-upgrade > /safe/upgrade-plan.json
   ```

3. Review old/new SHA, baseline, changed paths, preserved rules and the exact
   `plan_id`. Only after approval export the patch:

   ```bash
   python3 /path/apo-v0.2.0/scripts/prepare-upgrade.py \
     --project /path/project-upgrade --patch --expect-plan APPROVED_PLAN_ID \
     > /safe/upgrade.patch
   ```

   Check exit status before proceeding. JSON errors go to stderr, never into
   a patch stream. Stderr receipt includes the patch checksum and baseline SHA.
   Do not blindly pipe generator output to `git apply`. On Windows use Git Bash
   byte-preserving redirection rather than legacy PowerShell UTF-16 redirection.

4. Verify the project is still clean at the recorded baseline, inspect the patch,
   then use Git's ordinary operations with the same absolute patch path:

   ```bash
   git -C /path/project-upgrade apply --stat /safe/upgrade.patch
   git -C /path/project-upgrade apply --check /safe/upgrade.patch
   # Only following successful checking and your explicit approval:
   git -C /path/project-upgrade apply /safe/upgrade.patch
   git -C /path/project-upgrade diff --check
   ```

The generator reads Git objects and does not modify the target, fetch, update
Git configuration, commit or push. Git performs the approved local application.
Never add `--reject`, `--unsafe-paths` or force-like fallbacks. The original
worktree/base commit and saved patch are your recovery material.

## Verify and reconcile the project control plane

Verify the new PIN SHA, custom AGENTS rules, business files, remotes,
`project-config`, export settings and original checkout. Run project checks and
prepare the normal reviewed upgrade PR. After committing the identical new
version, preview returns `UP_TO_DATE` (local PIN identity, not cloud acceptance).

**`PENDING_RECONCILIATION` is intentional.** The generator does not edit GitHub
Issues. The Agent/user must inspect the selected project's active CC/Phase/ADR
and identify inherited old Fleet/box/Bugbot requirements. Propose changing only
obsolete generic defaults, preserving explicitly approved project review policy,
owners, active tasks and historical evidence. Obtain the project-level decision
and reference the upgrade PR/new PIN in the control plane. Without GitHub access,
report **LOCAL PATCH READY, CONTROL PLANE PENDING**, not "project upgraded".

Do not backdate Freeze/Accept. The release itself never automatically changes
existing business projects or grants deployment authority.

## Rollback

Before committing, inspect subsequent work and run:

```bash
git -C /path/project-upgrade apply --reverse --check /safe/upgrade.patch
# Only if the check succeeds and rollback is authorized:
git -C /path/project-upgrade apply --reverse /safe/upgrade.patch
```

Conflicting later edits stop rollback. Do not overwrite them. After a commit or
merge, use a normal reviewed `git revert` and separately reconcile effective CC
policy. Do not discard unrelated work or delete its worktree.

## Evidence boundary

The release gate exercises local Git positive/negative fixtures and a project
created by the **real v0.1.2 bootstrap**, then upgrade, reverse, reapply and
idempotence. Platform results belong to the exact release Actions SHA. This is
not proof of arbitrary Agent-host behavior, live independent-human authorization
or business-level user acceptance. The general natural-language user-journey
feature in #75 remains outside this release pending real UX validation.
