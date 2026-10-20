# 快速上手

本指南介绍如何把 APO 接入一个项目，以及日常改动如何记录、验证和验收。

## 先看版本状态

本指南对应 **v0.3.0**，变化见[发布说明](./releases/v0.3.0.md)。使用前先核对 [v0.3.0 正式发行页](https://github.com/Dylan5237/agent-project-ops/releases/tag/v0.3.0)和精确提交；发行页尚未生成时继续使用已发布的 v0.2.1，不把候选 PR 当作稳定包。v0.3.0 发行流程提供 5 个附件，升级说明统一为中文 `docs/UPGRADE.md`。

新项目初始化或升级时，Agent 应先核实最新的正式稳定版和精确提交，不要默认使用主线。

## 推荐入口

在目标项目中发送对应指令：

```text
使用 https://github.com/Dylan5237/agent-project-ops 初始化当前项目。
使用 https://github.com/Dylan5237/agent-project-ops 更新当前项目的apo规则。
```

Agent 应先检查项目目录和 APO 绑定，再选择操作：

- 空的新项目：初始化。
- 已有业务代码、尚未接入 APO：按已有项目接入流程处理，不要覆盖现有规则。
- 已固定旧版 APO：走升级预览流程，不要只改 PIN。

## 开始前需要

- 一个 GitHub 项目仓库，用于 Issue、PR 和代码提交。
- 本机可运行 Git；命令行初始化时需要 Python 3.10+（规则扫描）和 Bash（Windows 可用 Git Bash）。
- 如果希望脚本创建 GitHub 仓库或检查权限，需要已登录的 GitHub CLI（`gh`）。
- 明确的拍板人账号，例如 `@your-handle`。

拍板人只在三种情况下作决定：大改动开工确认、阶段或发布最终验收、已冻结合同的例外。其他拆分、派发和常规审查由主 Agent 处理。

## 初始化新项目

v0.3.0 增加三项选择：流程档位（轻量或标准）、Agent 工具（可多选）、外部工具（默认不接）。Agent 会用可用的选项界面或普通对话收集选择，再按选择生成文件。非交互命令必须把三项都写明；下面示例选择标准档、Codex 和 Claude Code，不接外部工具。旧版接口以该版本的实际帮助为准。

推荐先使用上面的短提示词，让 Agent 核实正式发行版和目标目录，再按初始化流程执行。也可以从可信的 APO 仓库副本运行脚本：

```bash
bash scripts/bootstrap-project.sh \
  --name my-project \
  --dir ../my-project \
  --github-repo OWNER/my-project \
  --disposer @OWNER \
  --private \
  --process-mode standard \
  --agent-tools codex,claude \
  --external-tools none \
  --yes
```

如果只需要本地脚手架、不创建 GitHub 仓库，可加 `--skip-github`。首次执行前也可以加 `--dry-run` 查看计划。不要把已有项目目录交给新项目初始化脚本；已有项目应使用接入流程。

初始化后核对项目绑定、GitHub `origin` 和本地 Hook：

```bash
cat .agent-project-ops/PIN
git remote -v
git config --get core.hooksPath
python3 .agent-project-ops/scripts/project-settings.py check --root .
```

当前流程只支持 GitHub `origin` 作为写入仓库。发现其他远端时先停止并查明用途，不要自行推送、删除或改写远端。

规则正文只维护在 AGENTS.md，CLAUDE.md 保留一行导入。选中 Claude Code 或 WorkBuddy 时，脚本分别复制到对应技能目录并自动校验。WorkBuddy 的项目读取入口已在 Craft（做一做）模式实测；Ask（问一问）不在本次保证范围内。未选中的外部工具不会获得接入说明，也不会自动连接任何服务。

## 接入已有项目

已有代码、规则或 GitHub 控制面的项目应按 [接入已有项目流程](../playbooks/adopt-existing-project.md) 处理。Agent 应先核实默认分支、当前规则、未完成任务和实际远端，再提出最小接入改动。不得覆盖项目自有规则，也不得把生产部署所用提交自动当成开发写入权威。

接入前发现规则冲突、来源不明或无法核实的改动时，应说明缺口并暂停相关操作；不要通过重置、强推或删除文件来“整理干净”。

## 日常改动和验收

1. 在 GitHub Issue 中写清要解决的问题和不做的事。
2. `standard` 标准档按阶段组织工作：在 Phase Issue 中写合同（范围、接口、验收办法和风险），并记录 `CONTRACT FREEZE` 及大改动检查结果。`light` 轻量档不要求创建 Phase Issue；每个任务 Issue 自带自己的合同和验收办法。
3. 对应 Phase 或任务命中大改动清单时，等拍板人的开工确认。已获书面提前批准的后续阶段，仍须冻结各自合同并确认没有超出批准方案。
4. 按一个任务、一条分支、一个 PR 实施；并行任务各用自己的工作区。不要直接推送默认分支。
5. 在 Phase Issue、任务 Issue 或实现 PR 中记录验证命令、结果和可复核材料链接。证据 PR 可选；只有材料确实需要单独存放时才开，不得因此把功能改动混入证据 PR。
6. 检查当前 PR 提交对应的必需 CI 和审查条件。检查通过后可以按仓库规则合并；合并不代表最终验收。
7. `standard` 标准档在每个阶段结束时提交固定格式的最终验收请求。`light` 轻量档在每次发布前与发布确认一并请求最终验收；项目没有发布时，在所有已确认目标完成后统一请求。拍板人回复后，Agent 如实记录结果；Agent 不得自行写 `批准 A` 或宣布 Phase PASS。

## 任务派发和回报

主 Agent 用[任务单](../templates/ISSUE_TEMPLATE/task.md)写清目标、范围和验收办法；执行 Agent 按[认领/开工格式](../templates/task-claim.md)核对合同和批准、记录真实工作区，再实施任务。[完成回报](../templates/task-completion.md)逐项列证据，交主 Agent 复核。认领不代表可以开工，回报不代表通过验收。Agent 名称写纯文本，不通过提及评论唤醒机器人。

项目统筹使用 `github-multi-agent-project-ops`；只负责一个已分配任务时使用 `github-multi-agent-task-executor`。自己的实现不能自己验收，阶段最终验收仍由拍板人决定。

## GitHub 保护能力

只报告实际核实的服务端保护能力：

| 等级 | 含义 |
| --- | --- |
| A | PR 必需，并核实了独立审查或代码所有者门禁 |
| B | PR 必需，但不能保证审查人身份独立于 Agent |
| C | 必需的服务端保护不可用或无法核实 |

C 可以是实际环境的结果；应在总控台如实记录，不要把 C 写成 A 或 B。客户端 Hook 可以帮助发现错误，但不能代替 GitHub 服务端保护。

## 新克隆后的 Hook

Git 克隆不会复制本机 `core.hooksPath` 设置。新克隆后检查：

```bash
git config --get core.hooksPath
```

如果不是 `.githooks`，按项目绑定的安装脚本安装 Hook，并再次核对。缺少 Hook 不是直接推默认分支的理由。

## 适用边界

APO 管理代码协作、阶段合同、项目状态和验收记录；不替代业务需求、部署操作或业务验收。不要据本指南修改其他项目、发布版本或推送到其他仓库。
