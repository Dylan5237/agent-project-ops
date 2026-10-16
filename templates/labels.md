# Label dictionary / 标签字典

Apply these on the **business** repository (GitHub UI or `gh label create`). Names are identifiers — keep them in English.

Do not add product-domain labels in the methodology repo. Business repos may add extra labels; they must not **replace** the status set.

## Status (exactly one per issue)

| Name | Color (suggested) | Meaning |
| --- | --- | --- |
| `status:backlog` | `BFD4F2` | Not dispatched |
| `status:in-progress` | `FBCA04` | Owner + worktree + branch |
| `status:blocked` | `D93F0B` | Fail closed; gap on the issue |
| `status:verification` | `5319E7` | Waiting evidence and/or Accept |
| `status:done` | `0E8A16` | Accepted (task: lead Agent; Phase or release: disposer) or explicitly cancelled |

## Type (issues)

| Name | Color | Meaning |
| --- | --- | --- |
| `type:command-center` | `1D76DB` | Single control-plane issue |
| `type:phase` | `0052CC` | One core problem; lifecycle Freeze→Accept |
| `type:task` | `006B75` | Optional child of a Phase |
| `type:exception` | `B60205` | Architecture Exception |
| `type:docs` | `C5DEF5` | Docs-only work item |

## PR kind

| Name | Color | Meaning |
| --- | --- | --- |
| `pr:implementation` | `0E8A16` | Product/library/test code |
| `pr:evidence` | `5319E7` | Proofs only; `evidence/` branch |

## Optional lifecycle tags (not a substitute for status)

| Name | Meaning |
| --- | --- |
| `freeze:pending` | Contract not frozen, or its start confirmation is pending |
| `freeze:acked` | Frozen; start confirmation approved when the §11 list was hit |
| `accept:proposed` | Final-acceptance request posted |
| `accept:returned` | Disposer replied `退回：…` (or `PHASE RETURN`) |

## `gh` example

```bash
gh label create "status:backlog" --color BFD4F2 --description "Not dispatched"
gh label create "status:in-progress" --color FBCA04 --description "Owner + worktree"
gh label create "status:blocked" --color D93F0B --description "Fail closed"
gh label create "status:verification" --color 5319E7 --description "Evidence / Accept"
gh label create "status:done" --color 0E8A16 --description "Disposer finished"
gh label create "type:command-center" --color 1D76DB --description "Control plane"
gh label create "type:phase" --color 0052CC --description "One core problem"
gh label create "type:task" --color 006B75 --description "Child task"
gh label create "type:exception" --color B60205 --description "Architecture exception"
gh label create "type:docs" --color C5DEF5 --description "Docs work item"
gh label create "pr:implementation" --color 0E8A16 --description "Code PR"
gh label create "pr:evidence" --color 5319E7 --description "Evidence PR"
```
