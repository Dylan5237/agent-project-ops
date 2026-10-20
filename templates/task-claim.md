# 认领和开工评论

只复制代码块内正文，替换所有占位符。Agent 标识用纯文本，例如 `owner: Codex`；评论不使用 at 符号提及 Agent。GitHub 评论只记录任务，不启动 Agent 或机器人；实际派发走当前宿主已经授权的任务机制。

CLAIM 只登记认领，不授权实施。任务仍待认领时，它只是认领申请；主 Agent 须先在任务单和宿主分配中确认 owner。已有指定 owner 时，评论身份必须与任务单和宿主分配一致。尚未分配的 workdir、branch、head 写 `待分配`；必要批准未到位写 `等待`，任务状态仍是 backlog。已有他人负责人时先停止并交主 Agent 协调，不覆盖原记录。

START 前确认合同已冻结、大改动批准已覆盖、依赖可用、owner 已由主 Agent 确认且与宿主分配一致。通过现有工作区脚本取得真实 workdir、branch，再运行 `git -C "<workdir>" rev-parse HEAD` 取得完整 SHA；不能用 base ref 代替 HEAD。START 不接受 `待分配` 或 `等待`，随后才将任务 Issue 标 in-progress 并同步总控台。无需单独 CLAIM 的自执行任务也必须记录完整 START。standard 的 phase 填父 Phase；任务本身是 Phase 时可填自身；light 独立任务填 `无`。普通子任务不直接改变父 Phase 标签，父 Phase 由主 Agent 按整体生命周期更新。

```markdown
<!-- apo-task-claim v1 -->
action: {{CLAIM_OR_START}}
task: #{{TASK_ISSUE}}
phase: {{PHASE_ISSUE_OR_NONE}}
owner: {{AGENT_ID}}
contract: {{FREEZE_URL}}
major_change: {{CHECK_RESULT}}
start_approval: {{APPROVAL_URL_OR_NOT_REQUIRED_OR_PENDING}}
workdir: {{ABSOLUTE_PATH_OR_PENDING}}
branch: {{BRANCH_OR_PENDING}}
head: {{HEAD_SHA_OR_PENDING}}
```

字段不齐、冻结或批准来源无法核实、归属冲突时先说明缺口，不把评论当成开工许可。拍板人身份和正式决策请求仍按决策模板记录，不受 Agent 纯文本标识约束影响。
