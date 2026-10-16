# Playbook: Bootstrap project / 新项目初始化

For a new/empty repository only. Existing repositories use [adopt-existing-project.md](adopt-existing-project.md); never overwrite an existing working tree.

## Preconditions

- A trusted clean full-history methodology Git checkout at the verified selected release SHA. A ZIP is not a provenance source.
- Git, Bash and Python; authenticated gh and explicit authorization when creating a GitHub repository.
- A real project slug and named disposer, no placeholder identity.

## Steps

1. Inspect the destination. If it is nonempty, scan inherited rules and use adoption; an inverted authority contract must be fixed before PIN binding.
2. Use the local script's `--help` / `--dry-run`, then the approved command, for example:

   ```bash
   bash scripts/bootstrap-project.sh --name example --dir ../example --disposer @OWNER --skip-github --yes
   ```

3. Only GitHub origin is supported. The snapshot contains a real PIN, AGENTS.md, the existing CLAUDE.md bridge, shared Skill wrappers, Issue/PR templates, hooks and worktree retirement helpers. No extra tool adapters or publishing channels are installed.
4. Verify PIN SHA equals the clean source HEAD, `authority=origin`, generated `.githooks/pre-push`, `core.hooksPath=.githooks` and discoverable Skill wrappers.
5. With approved GitHub creation, verify the observed protection capability: A independent code-owner gate, B PR-only, C unavailable/unverifiable. C on GitHub Free private may be expected; record it and continue honestly. Hooks remain bypassable. Shared human/Agent identity is not an independent review boundary.
6. Continue with [start-project.md](start-project.md): labels, Command Center, process mode (unrecorded = standard), first task/Phase contract. No implementation before freeze and any required start confirmation.

## Stop conditions

Unknown source SHA, dirty copied source, unsafe URL, nonempty destination, placeholder disposer, missing required GitHub permission or unsupported remote option stops before a partial binding can be claimed complete. Bootstrap never rewrites an existing project or invents `sha=unknown`.
