# Reconciliation report skeleton

## Topology + pins
## Now (diagram)
## Before → after
## Disposition table (reclaimed / deleted / held / blocked / unreachable)
## Backlog Issues still open
## Residual debt

T1:

```mermaid
flowchart LR
  GH[authority main]
  LOC[local main]
  GH --- LOC
```

T2:

```mermaid
flowchart LR
  GH[authority main]
  LOC[local main]
  GLD[projection develop]
  GLM[projection main merge tip]
  GH --- LOC
  GH --- GLD
  GH -.-> GLM
```
