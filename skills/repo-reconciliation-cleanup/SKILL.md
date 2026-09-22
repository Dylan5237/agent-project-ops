---
name: repo-reconciliation-cleanup
description: >
  对脏 Git 仓做安全对账与清理：先识别拓扑（仅本地 / GitHub+本地 / 含投影 / 仅远程 /
  双写源），钉 Dev SoT 与可选 PROD 地板，三面只读盘点，用确定性脚本把枝/worktree
  分成 SAME·ANCESTOR·AHEAD·DIVERGED，经处置人授权后再删/回收/放弃，并出图示报告。
  在 tip 混乱、陈旧 cursor/codex/sync/feat 枝、多余 worktree、本地与远程完全分叉、
  或用户说「有多脏」「今天清干净」时使用。不做产品功能开发；不把投影 merge tip
  盖成权威；不关 backlog Issue；无授权不删枝。
---

# Repo reconciliation & cleanup

**治理作用域：** SINGLE_SKILL（可与 [`git-authority-and-projection`](../git-authority-and-projection/SKILL.md) 协作，不合并入口）

**能力画像（有证据）：** `external_system` · `external_write` · 流程状态落在 recon Issue（轻量 stateful）

**本次动作风险：** 只读盘点 = 0；删枝/关 PR/拆 worktree/hard reset = **2**（须本次明确授权）

**确定性机制：** [`scripts/classify_ref.py`](scripts/classify_ref.py)（KIND 唯一结果；不裁决删留）

**不做：** 业务功能开发 · 静默 force 保护枝 · 假装不可达面已清理 · 关闭产品 backlog Issue · 把 PROD 投影 merge SHA reset 到权威 `main`

有投影远程时，对齐/镜像合同另遵 companion
[`git-authority-and-projection`](../git-authority-and-projection/SKILL.md)
/ playbook [`git-authority-and-projection.md`](../../playbooks/git-authority-and-projection.md)
（§F inventory，§G red lines）；本技能管**脏仓卫生**。

## 入口流程（必须按序）

1. **Topology** — Read [`references/topologies.md`](references/topologies.md)；记下 T0–T4。T4 停。
2. **Pins** — Dev SoT、可选 PROD（可 UNKNOWN）、protect list、local path → 写入 recon Issue。
3. **Inventory** — 只读；不可达面标 `UNREACHABLE`。
4. **Classify** — 对每个 ref 跑 `classify_ref.py`；Read [`references/classification.md`](references/classification.md)。本地 default vs origin 同样分类。
5. **Edge gates** — 若本地↔origin 为 DIVERGED，Read [`references/edge-cases.md`](references/edge-cases.md) **E-DIVERGE**，先选 A/B/C。
6. **Disposer batch** — 用 [`assets/disposer-batch-template.md`](assets/disposer-batch-template.md) 一次提问；**未授权不得进入删除**。
7. **Execute** — 仅执行批准桶；删前再跑 classify，非 ANCESTOR 则跳过；统计 **拦截 / 失败 / 成功** 分列。
8. **Report** — [`assets/report-skeleton.md`](assets/report-skeleton.md)：拓扑、现况图、前后对比、处置表、backlog 仍开、残留债。

T1（GitHub+本地）：整段跳过投影步骤。T0：无远程删除。

## 授权与受控写（风险 2）

高影响写包括：删远程/本地枝、关 PR、`worktree remove --force`、`reset --hard`、force-with-lease、投影 FF（非只读）。

- 授权必须覆盖**对象列表**；历史「曾经同意过」无效。
- 禁止顺手扩大范围（F7）。
- 护栏命中记 **拦截**，不要记成执行失败。

## 真相规则

- tip / ahead / behind / 发版身份必须来自 `git`/`gh`/manifest 回查，禁止编造。
- 缺凭证或不可达：阻塞或 `UNREACHABLE`，禁止用假 tip 报成功。
- 「干净」的成功条件：批准桶执行完 + 报告已发 + 残留债点名；缺一面不可达则不得称 fully clean。

## 验证

- 程序：在本技能目录 `python3 -m pytest tests/ -q`；或在仓库根 `python3 -m pytest skills/repo-reconciliation-cleanup/tests/ -q`（KIND 映射）
- 手工：`python3 scripts/classify_ref.py --cwd <repo> --tip <tip> --ref <ref>`（从本技能目录）
- 行为用例：[`tests/behavior-cases.md`](tests/behavior-cases.md)（未真实跑过标 UNVERIFIED）

## 已知限制

- 分类脚本不替代处置人决策；DIVERGED 永远需要语义判断（回收 vs 放弃）。
- 无法在无网络主机上证明投影面已清理。
- 不内置密钥扫描器；E-SECRETS 依赖执行环境已有工具。
