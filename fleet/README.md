# Fleet index

Canonical fleet index for repositories that run `agent-project-ops`.

| Role | Path |
| --- | --- |
| **Source of truth** | [`REGISTRY.md`](./REGISTRY.md) in this repository |
| **Runtime mirror** | `/home/box/agent-data/fleet-morning-digest/REGISTRY.md` (Agent 舰队晨报) |

Decision record: [ADR 0002](../docs/adr/0002-canonical-fleet-index.md) (disposer Option 3 on #26).

## Bootstrap duty

After Command Center exists, the Agent **must** **Register to Fleet REGISTRY**:

1. Upsert one row in `fleet/REGISTRY.md` keyed by `owner/repo` (open/update a PR on this repo).
2. Confirm the box mirror matches the SoT (or record `BLOCKED:` on GitHub if the mirror cannot be written).
3. Confirm to the disposer: **「已纳入舰队晨报扫描」**.

Do not mark bootstrap / start-project done if this step is skipped. Fail closed.

## Scan rule

Agent 舰队晨报 reads **only** registered rows, then each project's Command Center **section 1** and the current Phase status label. Unlisted repos are not scanned. Stale CC §1 is a false green — keeping §1 fresh is a mandatory Agent duty (`skills/github-multi-agent-project-ops`).
