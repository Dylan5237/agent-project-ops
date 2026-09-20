# Fleet project registry (agent-project-ops)

Canonical **source of truth** for the fleet index. Morning digest **only** scans rows in this table.

- **SoT:** this file in `Dylan5237/agent-project-ops`
- **Mirror:** `/home/box/agent-data/fleet-morning-digest/REGISTRY.md` (Agent 舰队晨报)
- **Upsert key:** `owner/repo` (idempotent; do not duplicate rows)
- Chat / 群消息不是状态源。

新项目按 agent-project-ops 建好并打开 Command Center 后，**必须** upsert 一行并确认 box 镜像同步，再向 disposer 确认「已纳入舰队晨报扫描」。跳过则 fail closed，不得声称 bootstrap 完成。

| 项目 | Repo | Command Center | 备注 |
|---|---|---|---|
| 天宫组件协同 | Dylan5237/tiangong-component-collab | #2 | Phase 看 #3 |
| 伏羲平台 | Dylan5237/prototype-manager | #11 | label status:done 但 issue 仍 open（卫生债） |
| Arckeep / kcc | Dylan5237/kcc-workbench | #2 | |
| safe-delete-cli | Dylan5237/safe-delete-cli | #1 | |
| agent-project-ops | Dylan5237/agent-project-ops | #10 | 负责人：apo项目经理（Grok Bot） |
| agent-team-workbench | Dylan5237/agent-team-workbench | #15 | |
| req-to-page | Dylan5237/req-to-page | #6 | |
| zentao-mcp | Dylan5237/zentao-mcp | #1 | 禅道 21.1 MCP（client lib + stdio + CLI）；CC #1；Phase #2 in progress |
| architecture-expert | Dylan5237/architecture-expert | （待确认 CC；门禁常看 #12） | 若无 CC，晨报标「未知+缺 Command Center」 |

## 晨报读法（强制）

对每一行：

1. 读 Command Center **正文第一节**（one-glance：当前 phase、next action、open gates）
2. 跟进第一节里点名的 **当前 Phase Issue**（状态 label：backlog/in-progress/blocked/verification/done）
3. 只把「需 Dylan 拍板 / blocked / HUMAN_REQUIRED / 未 Freeze 却想开工」抬进晨报
4. 不在登记表外的仓：默认不扫；例外需 Dylan 显式加入本表

## 保证边界

- **能保证**：登记表内、且 CC 第一节保持新鲜 → 晨报能覆盖「所有已纳入 ops 的项目」最新控制面状态
- **不能保证**：没有 CC、CC 不更新、状态写在聊天里、未加入登记表的仓
- **镜像漂移**：box 文件与本 SoT 不一致 → fail closed / `blocked`，不以聊天为准
