# Agent Project Ops（APO）

APO 帮你把项目状态、改动范围和验收证据留在 GitHub 上，让后续 Agent 能从仓库和 Issue 接着工作。

## 当前版本

- **最近的正式稳定版：v0.2.1。** 它已发布，发行页有 6 个附件。正式使用时，应以已发布版本和精确提交为准。
- **当前主线规则：v0.3.0，尚未正式发布。** 这次主线改动不等于已发布软件，也不代表发行检查或用户验收已经通过。
- **下一次发行计划：** 发行附件计划为 5 个，升级说明统一使用中文 `docs/UPGRADE.md`。计划尚未发布，不能据此声称新版本已通过检查。

[查看 v0.2.1 正式发行页](https://github.com/Dylan5237/agent-project-ops/releases/tag/v0.2.1)

## 推荐入口

在目标项目的 Agent 对话中发送其中一条：

```text
使用 https://github.com/Dylan5237/agent-project-ops 初始化当前项目。
使用 https://github.com/Dylan5237/agent-project-ops 更新当前项目的apo规则。
```

Agent 应核实最新**已发布稳定版**，再根据项目现状选择初始化、接入已有项目或升级。当前主线 v0.3.0 尚未发行，不要把它当成稳定版。

## APO 怎么工作

- GitHub 仓库、Issue、PR 和提交记录保存项目状态；聊天记录不代替项目记录。
- 一个任务使用一条任务分支和一个 PR；并行任务用各自的工作区。
- 开始一个阶段前先冻结范围、接口和验收办法；命中大改动清单时，等拍板人确认后再开工。
- 检查结果可以记在 Phase Issue 或实现 PR 中。需要单独存放大型材料时，可以自愿开证据 PR；这不是必需流程。
- PR 合并和 CI 通过都不等于阶段验收。最终验收由拍板人完成，Agent 不能替拍板人回复。
- 当前流程只使用 GitHub `origin` 作为写入仓库。其他远端不属于当前支持范围。

## 文档入口

- [快速上手](./docs/GETTING_STARTED.md)
- [升级已有项目](./docs/UPGRADE.md)
- [核心原则](./PRINCIPLES.md)
- [工作流程](./playbooks/)
- [Agent 技能](./skills/)
- [模板](./templates/)
- [历史决策](./docs/adr/README.md)、[历史提案](./docs/rfcs/README.md)、[研究记录](./docs/research/README.md)、[验证证据](./docs/evidence/)

这些文档中的主线规则属于尚未发行的 v0.3.0。正式发行前，请以 v0.2.1 发布包为稳定使用依据。
