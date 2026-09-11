# agent-project-ops self-dogfood binding

This repository is the **methodology repository itself**. It is running a bounded self-dogfood governance test; do not treat it as a business/product repository and do not recursively vendor this repository into `.agent-project-ops/`.

## Durable control plane

- Chat is not project state.
- GitHub `origin` is the sole write authority.
- Projection remotes: `(none)` unless the Command Center explicitly changes that classification.
- Self-dogfood Command Center: https://github.com/Dylan5237/agent-project-ops/issues/10
- The **current Phase is discovered from the Command Center Phase index**, not from chat and not from a hard-coded phase number in this file.
- Methodology source: local `PRINCIPLES.md`, then the relevant files under `playbooks/` and `skills/`.

## Required operating rules

1. Read `PRINCIPLES.md` before changing repository state.
2. Open Command Center #10 and follow its current Phase index/status.
3. Do not create implementation work before that Phase has a disposer `FREEZE ACK`.
4. One task/Phase uses one dedicated branch/PR (and a worktree when operating locally).
5. Direct push to `main` is forbidden. Server-side GitHub protection is the real gate; client hooks are only an additional guard.
6. Agent proposes evidence; Agent must never self-issue `PHASE ACCEPT`, `PHASE RETURN`, `FREEZE ACK`, or `EXCEPTION ACCEPT`.
7. Merge is not Phase PASS. The disposer decision recorded on the Phase is authoritative.
8. Unknown remotes are BLOCKED until the Command Center classifies them.

## Fresh-clone hook check

A clone receives `.githooks/pre-push` but does **not** inherit repository-local `core.hooksPath` configuration.

Before pushing from a fresh clone:

```bash
git config --get core.hooksPath
bash scripts/install-hooks.sh
```

Expected installed value: `.githooks`.

## Self-binding boundary

For self-dogfood, `.agent-project-ops/remotes` is only the small runtime remote registry required by the shared hook. It is **not** a vendored methodology snapshot. Local `PRINCIPLES.md`, `playbooks/`, `skills/`, `templates/`, and `scripts/` remain canonical.
