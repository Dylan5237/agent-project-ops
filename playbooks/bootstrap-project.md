# Playbook: Bootstrap project / 从零脚手架

## Goal

From one human sentence — *initialize this project using Dylan5237/agent-project-ops* — produce a **generic** local git repo that:

1. Contains always-on agent binding (`AGENTS.md` and equivalents).
2. Contains a **pinned snapshot** of this methodology plus auto-discovered skill wrappers.
3. Has `.worktrees/` gitignored.
4. Has GitHub **private** `origin` as write authority (unless the user explicitly skips GitHub).
5. Optionally has a `projection` remote that is **not** a second source of truth.

Then hand off to [start-project.md](./start-project.md) for Command Center / labels / first Phase.

Design: [docs/rfcs/0001-bootstrap-and-binding.md](../docs/rfcs/0001-bootstrap-and-binding.md).

## When

- There is **no** business repo yet (empty folder or a path to create).
- The user asked to scaffold / bootstrap / initialize using this methodology.

If the git repo already exists, **do not** re-run full bootstrap. Add missing binding files only with disposer ACK, or follow start-project.

## Preconditions

- Agent can read this methodology (clone or fetched files).
- `git` available. `gh` available and authenticated for GitHub create.
- [PRINCIPLES.md](../PRINCIPLES.md) in force (including §10 if a second remote will exist).
- No product/domain requirements belong in the generated files.

## Steps

1. **Dry-run the helper** from this methodology clone:

   ```bash
   scripts/bootstrap-project.sh --dry-run \
     --name <slug> \
     --dir <absolute-or-relative-path> \
     --disposer @<github-handle>
   ```

2. **Create** (same flags, drop `--dry-run`). Default visibility is **private**. Pass `--skip-github` only when the user wants a local draft. Pass `--projection-url <git-url>` or answer the prompt; empty means origin-only.

3. **Verify binding** (acceptance from the RFC): `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/agent-project-ops.mdc`, `.github/copilot-instructions.md`, `.agent-project-ops/PIN`, `.agents/skills/*/SKILL.md`, `.gitignore` lists `.worktrees/`.

4. **Remotes.** `git remote -v`:
   - `origin` → GitHub (authority).
   - optional `projection` → named on Command Center as mirror/FF only.
   - anything else → stop; disposer must classify.

5. **Hooks (if installed).** `git config core.hooksPath` → `.githooks`. Allows the **first** push that **creates** `main` on `origin` (empty remote); denies later direct updates to `main` and topic pushes to `projection`. Client-side only; `--no-verify` still exists. Server protection is the real gate.

6. **Continue with start-project.** Open Command Center (include methodology PIN + remotes). Create labels. Protect `main` if bootstrap could not. Open Phase-0. **No implementation branches.**

## Done when

- [ ] Local directory is a git repo with binding files and a methodology PIN.
- [ ] `.worktrees/` exists and is ignored.
- [ ] `origin` is a private GitHub repo **or** user explicitly chose `--skip-github` and that is recorded.
- [ ] Projection, if any, is named `projection` and documented as non-SoT.
- [ ] Command Center exists or is the next immediate step (start-project).
- [ ] No secrets in the tree.

## Anti-patterns

- Treating the methodology clone as the product repo.
- `git push --mirror` to projection.
- Embedding tokens in remote URLs.
- Skipping `AGENTS.md` because “the Agent already knows.”
- Starting `feat/` work in the primary checkout on day one.
- Making GitLab (or any projection) the Issues/PR host.
