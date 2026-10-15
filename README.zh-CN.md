# Agent Project Ops（APO）

[English](./README.md) · [发行说明](./docs/releases/v0.2.1.md) · [旧项目升级](./docs/UPGRADE.zh-CN.md) · [新项目快速上手](./docs/GETTING_STARTED.zh-CN.md)

**让 AI 编写的软件，不依赖某一个会话，也能持续维护。**

APO 是以 GitHub 为项目事实源、以 Skill 为 Agent 入口的轻量项目治理方法论。它保存目标和决定、隔离任务改动、要求可复验证据，让不同 Agent 能够根据真实仓库状态接力。它不是新的编程 Harness、业务框架、云服务或自动部署平台。

## 最简使用方式（推荐）

在当前项目的 Coding Agent 对话框中，直接发送其中一句即可。**不需要记住 Skill 名称或手动输入 CLI 命令。**

```text
使用 https://github.com/Dylan5237/agent-project-ops 初始化当前项目。
使用 https://github.com/Dylan5237/agent-project-ops 更新当前项目的apo规则。
```

具备 GitHub、文件系统与 Git 操作能力的 Agent 应自行核实仓库最新**正式稳定 Release**和对应 Git SHA，再调用已有 Bootstrap/Adoption 或 Upgrade Skill；涉及仓库可见性、写入、升级 `plan_id` 时仍需授权。工具或权限不足则说明缺口，不声称所有宿主都能仅凭 URL 完成操作。

## v0.2.1：可独立采用，也能升级旧项目

本版软件包版本为 **0.2.1**（[VERSION](./VERSION)）。正式可下载版本以 [GitHub Releases](https://github.com/Dylan5237/agent-project-ops/releases) 为准；候选分支和临时测试 PR 不等于发行。治理规则以 `PRINCIPLES.md` 的 **v0.2.0 规则版本**为准，与软件包版本分开；项目 PIN 记录完整提交 SHA。

| 能力 | 本版行为 |
| --- | --- |
| 通用初始化 | 不要求加入作者个人 Fleet、box 晨报或购买 Cursor Bugbot |
| 项目审查 | 保留项目实际要求的 CI、评审和人工验收，不绑定指定厂商工具 |
| 工作基线 | 显式选择、项目持久配置或核实远端默认；无法决定时报告候选、请求选择 |
| 来源固定 | 干净的已提交方法论源与真实 PIN SHA，不静默跟随 main |
| 配置与模板 | 默认 origin-only，高级远端显式启用；CC 使用真实方法论来源 |
| 本地诊断 | Doctor 只读检查 PIN 格式、远端和 Hook；服务端保护/在线控制面未检查则 UNKNOWN |
| 旧项目升级 | `upgrade-project` Skill + 只读预览/标准 Git 补丁；保留项目规则、冲突阻断、隔离应用和可校验回退 |

本仓自用的 self-dogfood Fleet 指针保留；它不是外部项目的注册前提。原自然语言三旅程实验 #75 未完成真实用户/跨宿主验证，**不包含在本版**；不要据此宣传任意 Agent 都能可靠全自动管理项目。

## 安装固定版本

需要 Git；初始化 shell 需要 Bash（Windows 使用 Git Bash）；升级补丁生成需要 Python 3.10+。创建 GitHub 项目需要已授权的 GitHub CLI `gh`；只做本地初始化可显式使用 `--skip-github`。

```bash
git clone --branch v0.2.1 https://github.com/Dylan5237/agent-project-ops.git apo-v0.2.1
cd apo-v0.2.1
```

保留完整历史，便于核实旧项目 PIN；源码 ZIP 没有 Git 历史，不能直接替代升级源克隆。发行附件的 `RELEASE_SHA.txt` / `SHA256SUMS` 用于核对来源与包完整性。

### 新项目

推荐发送上方「初始化当前项目」简短提示词。需要手动排查时，CLI 方式如下（不是使用前提）：

```bash
bash scripts/bootstrap-project.sh \
  --name my-project --dir ../my-project \
  --github-repo OWNER/my-project --disposer @OWNER --private --yes
```

按实际账户替换 OWNER；创建真实远端前需要明确授权。默认仅 GitHub `origin`，没有多余的投影选择问题。完整流程见 [快速上手](./docs/GETTING_STARTED.zh-CN.md)。已有业务仓但从未采用 APO 的情况走 [adoption](./playbooks/adopt-existing-project.md)，不要覆盖现有目录。

### 已经使用旧版 APO 的项目

不要重新 bootstrap，不要只改 `.agent-project-ops/PIN`，也不要覆盖整份项目 `AGENTS.md`。**推荐直接发送上方「更新当前项目的apo规则」简短提示词。** Agent 内部仍需获取正式发行版、检验旧 PIN/控制面、创建独立升级工作区、先生成只读计划并获得 `plan_id` 确认，再由 Git 安全应用补丁和提交普通 PR。
[完整中文操作步骤、CLI、冲突处理及回退](./docs/UPGRADE.zh-CN.md)。补丁生成器不修改项目文件或远端；Git 在用户明确授权的隔离工作区应用。**本地规则更新与 GitHub 控制面协调是两步**，缺权限时不能声称整个项目升级完成。

## 保留的治理原则

GitHub `origin` 是唯一写权威；聊天不是项目状态；一项任务使用可追溯的分支/worktree/PR；未知远端不允许猜测写入；范围先确认、证据可复验；PR 合并不等于 Phase Accept，人类仍负责最终决定。

可选 projection/export/share-export 属于高级 Git 场景，只有明确需要时才加载相应 Skill；不作为普通用户入门负担。客户端 Hook 可绕过，不是服务端安全边界。A/B/C 保护能力必须按真实检查报告；C 不得被说成 A/B，也不等于所有本地工作都必须停止。

## 验证与限制

发行流程在同一提交上运行核心 shell 合同、升级 Python 正负例、Linux/Windows/macOS 升级矩阵，以及**真实 v0.1.2 bootstrap 项目的迁移、反向恢复和重复执行**；最终结果见该 release SHA 的 Actions 日志。CI 不替代真实用户体验、宿主能力检查、独立人员审查或业务验收。

自动升级支持已知旧版 bootstrap 绑定。自定义方法论快照、无法重建的手写绑定、未知旧 SHA、冲突、符号链接或脏工作树需要人工三方审阅；没有“覆盖一切”的开关。现存项目不会因为 APO 发布新版本而自行迁移。

历史 v0.1 self-dogfood、真实初始化和保护实验保留在 [验证证据](./docs/evidence/phase-11-self-dogfood.md)。它们是历史记录，不冒充本版所有环境的验证。#85 记录既有候选的历史程序偏差及前瞻性例外；不倒签 Freeze，不将发版等同于逐 Phase Accept。

## 文档与技能

[核心原则](./PRINCIPLES.md) · [Playbooks](./playbooks/) · [Skills](./skills/) · [架构决策](./docs/adr/) · [研究](./docs/research/) · [RFC](./docs/rfcs/) · [证据](./docs/evidence/) · [模板](./templates/) · [测试](./tests/)

常用入口：[bootstrap-project](./skills/bootstrap-project/SKILL.md)、[upgrade-project](./skills/upgrade-project/SKILL.md)、[github-multi-agent-project-ops](./skills/github-multi-agent-project-ops/SKILL.md)、[git-worktree-and-branch](./skills/git-worktree-and-branch/SKILL.md)、[project-diagnostics](./skills/project-diagnostics/SKILL.md)、[issues-prs-and-evidence](./skills/issues-prs-and-evidence/SKILL.md)。

许可证：[MIT](./LICENSE)。业务 SOP、领域模型和生产数据不属于本方法论仓库。
