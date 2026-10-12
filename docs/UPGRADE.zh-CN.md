# 将已有项目的 APO 规则升级到 v0.2.0

适用于已通过旧版 bootstrap 建立 `.agent-project-ops/PIN` 的项目。**更新工具本身，不等于更新项目内固定的规则；只改 PIN 也不算升级。** 本指南把方法论快照、生成的 Agent 规则、项目特有要求和 GitHub 控制面分开处理。

## 推荐：交给你的本地 Agent

在需要升级的项目中发送以下指令。只处理当前项目，不批量操作其他仓库。

```text
将当前项目的 APO 规则升级到 Dylan5237/agent-project-ops v0.2.0。
先读取当前 AGENTS.md、.agent-project-ops/PIN、remotes 和真实 Command Center，
在独立目录准备该版本的可信完整 Git 克隆，并读取新版 skills/upgrade-project/SKILL.md。
不要在旧项目上重新 bootstrap，不要只改 PIN，不要全文覆盖项目自定义 AGENTS.md。
保留业务代码、审批人、CC 指针、Git 配置、远端分类和 project-config。
按已批准基线建立独立升级 worktree，记录原提交作为备份；执行只读升级预览，
向我说明旧/新 SHA、变更文件、规则冲突、回退路径，以及 GitHub 控制面待协调事项。
我确认具体 plan_id 后再导出补丁并用 git apply --check 校验，成功后应用同一补丁。
遇到自定义快照、未知 PIN、冲突或缺权限立即停止，不强制覆盖、不自动提交合并或部署。
本地验证后准备正常升级 PR；只针对本项目、按我确认的政策协调 CC/Phase 中继承的
旧 Fleet/box/Bugbot 通用约束，保留项目明确要求的审查、历史决定和未完成任务。
最后区分“本地补丁完成”“PR 已合并”“控制面已协调”，不要误报整个项目已升级。
```

## 前置条件

需要 Git、Python 3.10+；运行旧初始化兼容测试和 shell 工具还需要 Bash（Windows 使用 Git Bash）。Python 命令可能是 `python3`、`python` 或 `py -3`，先核对版本。代码升级在**干净的已命名任务分支/工作区**完成，已有工作必须由你或 Agent 明确保存；工具不会自动 stash、reset 或清理。

准备一个与业务项目分开的、来源和旧 PIN URL 一致的完整 Git 克隆：

```bash
git clone --branch v0.2.0 https://github.com/Dylan5237/agent-project-ops.git ../apo-v0.2.0
```

不要使用 `--depth 1`：升级时必须在本地找到旧 PIN 的精确提交。若可信克隆不包含它，先由用户确认并获取相应历史，或提供 `--old-source` 指向保存旧提交的可信克隆。**不要为通过校验修改旧 PIN。** ZIP 源码包可用于审阅，但没有 Git 历史，不能直接作为升级源。

## 一、选择基线、保留备份

下列路径均为例子，请换为实际路径。`APPROVED_BASE` 必须是已核实的项目开发基线，不要默认写死 `main`。

```bash
# 在业务项目执行；创建独立工作区，不修改原工作区。
git status --short
git rev-parse APPROVED_BASE
# 保存上一步的精确提交 SHA。原工作区和该提交是回退基线。
git worktree add -b upgrade/apo-v0.2.0 ../project-apo-upgrade APPROVED_BASE
```

不要与其他 Agent 共用该升级工作区，不要将工作区放到方法论源克隆中。预览报告、补丁和校验回执存放在**两个工作区之外**的安全位置；补丁可能包含项目专属说明，不应未经允许公开。

## 二、只读预览

```bash
python3 ../apo-v0.2.0/scripts/prepare-upgrade.py \
  --project ../project-apo-upgrade > ../apo-upgrade-plan.json
```

成功时输出 JSON：旧 PIN SHA、新方法论 SHA、基线提交、分支、逐文件变更摘要、稳定的 `plan_id` 和 `PENDING_RECONCILIATION` 控制面状态。此命令只读目标项目，不联网、不修改 Git 配置、不提交/推送。

审阅完整变化后，明确批准该次 `plan_id`。发生并行提交或规则修改后，预览 ID 会改变，需要重看计划。若返回 `UP_TO_DATE`，表示本地 PIN 已指向相同提交，不代表云端 CC/Phase 已协调，也不需要再次应用补丁。

## 三、导出、检查、应用

下面命令应逐条执行并检查退出码；不要用不检查错误的管道自动应用。

```bash
python3 ../apo-v0.2.0/scripts/prepare-upgrade.py \
  --project ../project-apo-upgrade \
  --patch --expect-plan APPROVED_PLAN_ID > ../apo-upgrade.patch

# 只有上一条退出码为 0、补丁经审阅且工作区仍符合基线时才执行：
git -C ../project-apo-upgrade apply --stat ../apo-upgrade.patch
git -C ../project-apo-upgrade apply --check ../apo-upgrade.patch
git -C ../project-apo-upgrade apply ../apo-upgrade.patch
git -C ../project-apo-upgrade diff --check
git -C ../project-apo-upgrade diff --stat
```

推荐为补丁使用绝对路径，避免 `git -C` 改变相对路径基准。PowerShell 用户应使用 Git Bash 保存原始 UTF-8 补丁，或使用能保持原始字节的重定向方式；不要将 Windows PowerShell 5 的 UTF-16 文本重定向结果当成 Git 补丁。

导出回执在 stderr，包含补丁 SHA-256 与原提交 SHA。保存回执、计划和补丁。工具本身**没有 apply/rollback 写文件函数**；由 Git 的原生检查/应用操作负责文件变化。禁止 `--reject`、`--unsafe-paths` 和强制覆盖。

## 四、验证文件和规则

核对新 PIN 与选定 release 的精确 SHA、项目 AGENTS 附加规则、审批人、业务文件、`.agent-project-ops/remotes`、`project-config`、导出配置和原工作区。运行项目适用测试，再准备普通 PR。

生成器升级的是已知旧版 bootstrap 拥有的文件；方法论快照必须可与旧提交核对。桥接文件的非冲突自定义内容会保留。**未知所有权/自定义快照/无法重建的手写根绑定会停止，不提供“忽略冲突继续”开关。** 对这些项目，由 Agent 做新旧版本与项目规则的人工三方审阅；不要当作自动兼容。

### GitHub 控制面是第二个必要步骤

脚本不更改远端 CC、Phase、Issue、分支保护或旧审批记录。你的 Agent 还应：

1. 读取当前项目真实 CC/活动 Phase/项目级规则，列出继承的旧通用 Fleet、box 和 Bugbot 前提；分清项目显式选定的政策与旧模板默认。
2. 仅在你确认后，用升级 PR/新 PIN 作为依据，更新当前项目的生效规则引用和下一步。不能取消你仍然需要的审查、改变审批人或丢失活动任务。
3. 保留历史 ADR/Issue/旧验证记录，不倒签 Freeze/Accept。缺 GitHub 权限时报告“本地补丁就绪，控制面待协调”，不宣布整个项目升级完成。

只有规则变更按正常 PR 生效、PIN 与生效规则一致、控制面协调完成后，才把项目标记为使用新版。**方法论版本发布不会自动迁移你的所有项目。**

## 五、回退

尚未提交时，使用导出的同一份补丁；回退前必须核对工作区没有新增不相关修改，并先反向检查：

```bash
git -C ../project-apo-upgrade apply --reverse --check /absolute/apo-upgrade.patch
# 仅在检查成功且确认回退后：
git -C ../project-apo-upgrade apply --reverse /absolute/apo-upgrade.patch
```

如果后来编辑的规则与补丁冲突，Git 会拒绝。不要强行覆盖。若已提交/合并，使用正常、经审查的 `git revert` 流程；云端 CC/Phase 的生效规则也要单独协调回退。工具不会删除工作区或清理未提交数据。

## 支持范围和常见阻塞

| 输出 | 含义与处理 |
| --- | --- |
| `SOURCE_DIRTY` / `PROJECT_DIRTY` | 先由你保存或整理工作，不自动丢弃 |
| `OLD_PIN_NOT_FOUND` / `COMMAND_FAILED` | 在可信历史克隆中核实旧 SHA，不修改 PIN 冒充 |
| `SOURCE_URL_MISMATCH` | 来源身份不同；不自动把 fork 切到另一来源 |
| `CUSTOM_SNAPSHOT` / `CUSTOM_RULE_CONFLICT` | 需要项目级三方审阅，不强制替换 |
| `CUSTOM_BINDING_NEEDS_REVIEW` | 手写根绑定超出自动重建范围，走人工审阅路径 |
| `PLAN_CHANGED` | 基线/规则变化；重新预览、重新确认 |
| `DEFAULT_BRANCH_REFUSED` | 先创建升级任务工作区，再预览导出 |
| `PENDING_RECONCILIATION` | 本地文件计划不等于远端项目规则已协调 |

回归包含隔离 Git 正负例和真实 v0.1.2 bootstrap 项目迁移/反向恢复；是否已在某个平台通过，以该发行提交的 Actions 日志为准。CI 不能证明任意 AI 宿主都会正确执行 Skill，也不能替代你的业务验收。
