# Agent Project Ops（APO）

APO 帮你把项目状态、改动范围和验收证据留在 GitHub 上，让后续 Agent 能从仓库和 Issue 接着工作。

## 当前版本

- **本版版本号：v0.3.1。** [这版改了什么](./docs/releases/v0.3.1.md)列出相对 v0.3.0 的四项边界修复；此前的新增与删除见 [v0.3.0 说明](./docs/releases/v0.3.0.md)。
- **正式可用性以发行页为准。** 修改版本号、PR 检查通过都不代表正式 Release 已生成。使用前核对 [v0.3.1 发行页](https://github.com/Dylan5237/agent-project-ops/releases/tag/v0.3.1)、标签提交和附件校验；若发行页尚未生成，继续使用已发布的 v0.3.0。
- **发行附件：** v0.3.1 沿用现有流程提供源码压缩包（tar.gz、zip）、`RELEASE_SHA.txt`、`SHA256SUMS` 和中文 `UPGRADE.md`，共 5 个。

[查看 v0.3.0 正式发行页](https://github.com/Dylan5237/agent-project-ops/releases/tag/v0.3.0)

## 推荐入口

在目标项目的 Agent 对话中发送其中一条：

```text
使用 https://github.com/Dylan5237/agent-project-ops 初始化当前项目。
使用 https://github.com/Dylan5237/agent-project-ops 更新当前项目的apo规则。
```

Agent 应核实最新**已发布稳定版**及其精确提交，再根据项目现状选择初始化、接入已有项目或升级。不要把未发布的 PR 或漂移的主线当成稳定版。

## APO 怎么工作

v0.3.0 初始化会收集流程档位、Agent 工具和可选外部工具三项选择，按选择生成文件并校验技能副本。规则正文统一维护在 AGENTS.md，CLAUDE.md 只保留一行导入；存量自有内容先保全迁入 AGENTS.md。操作见快速上手。

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
- [状态生成、派发检查与技能副本同步](./playbooks/automation.md)
- [Agent 技能](./skills/)
- [模板](./templates/)
- [历史决策](./docs/adr/README.md)、[历史提案](./docs/rfcs/README.md)、[研究记录](./docs/research/README.md)、[验证证据](./docs/evidence/)

这些文档随 v0.3.1 源码维护；正式使用仍须按上面的发行页核对版本。升级已有项目要先审阅具体计划，不能只改 PIN，也不会自动升级其他仓库。
