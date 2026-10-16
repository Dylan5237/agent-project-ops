#!/usr/bin/env bash
# Contract test for the v0.3.0 decision rules: major-change list, fixed
# decision-request format, process modes and where Agents must use them.
# Documentation contract only; it does not prove that a live Agent complies.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }
has() { grep -Fq -- "$2" "$root/$1" || fail "$1 is missing: $2"; }

principles="PRINCIPLES.md"
template="templates/decision-request.md"
[[ -f "$root/$template" ]] || fail "missing $template"

# Section text between a level-2 heading prefix and the next level-2 heading.
section() { awk -v h="$2" 'index($0, h) == 1 {on = 1; next} on && /^## / {exit} on {print}' "$root/$1"; }

# 1. Exactly eight major-change items, in the confirmed order, plus the rules
#    for applying them.
list="$(section "$principles" '## 11. ')"
[[ -n "$list" ]] || fail "PRINCIPLES §11 missing"
[[ "$(printf '%s\n' "$list" | grep -cE '^[0-9]+\. ')" -eq 8 ]] || fail "PRINCIPLES §11 must list exactly 8 items"
n=0
for key in '改架构或对外接口' '改数据库结构、做数据迁移或删除数据' '账号、密钥、权限、支付或隐私' \
           '发布、部署或推送到内网 GitLab' '强推、改写历史、删除 main 或还没合并的分支' \
           '引入付费服务或重要新依赖' '修改 APO 规则本身' '超出已确认目标的范围'; do
  n=$((n + 1))
  printf '%s\n' "$list" | grep -Eq "^${n}\. .*${key}" || fail "§11 item ${n} must be: ${key}"
done
for key in 'archive/<branch>-<sha7>' 'Unsure → treat it as a hit' '**one** request' 'only the work it covers waits'; do
  printf '%s\n' "$list" | grep -Fq -- "$key" || fail "§11 lost rule: $key"
done

# 2. Three layers, two modes, the disposer's three decisions, no self-acceptance.
for key in '## 0. Three layers' 'Fixed floor' 'Project settings' 'Per-change judgment' \
           'process_mode=light|standard' 'No recorded mode = `standard`' \
           'The disposer decides three things' 'Lead Agent' 'Executing Agent' \
           'No Agent accepts its own work' "$template" 'PR merge' '## 13. Write for the reader'; do
  has "$principles" "$key"
done
grep -Fq '# PRINCIPLES — v0.3.0' "$root/$principles" || fail "PRINCIPLES version header is not v0.3.0"
for f in README.md skills/github-multi-agent-project-ops/SKILL.md playbooks/start-project.md; do
  has "$f" 'v0.3.0'
done

# 3. Fixed request format: marker, required headings, reply syntax, result
#    record, legacy words and revision rules.
marker_re='^<!-- apo-decision v1 \| id: D-\{\{n\}\} \| rev: 1 \| type: [^|]+ \| target: #\{\{issue\}\} \| disposer: @\{\{handle\}\} -->$'
markers="$(grep -E '^<!-- apo-decision v1 \|' "$root/$template" || true)"
[[ "$(printf '%s\n' "$markers" | grep -c . || true)" -eq 2 ]] || fail "expected one marker per request kind"
if printf '%s\n' "$markers" | grep -Evq "$marker_re"; then fail "decision marker format changed"; fi
printf '%s\n' "$markers" | grep -Fq 'type: 最终验收 |' || fail "final-acceptance marker missing"
grep -Eq '^<!-- apo-decision-result v1 \| id: D-\{\{n\}\} \| rev: \{\{rev\}\} \| result: .+ \| reply: .+ -->$' "$root/$template" \
  || fail "decision result marker format changed"
for key in '## 需要你决定：' '**我的推荐：**' '**为什么需要你：**' '**不决定的影响：**' '### 背景' \
           '### 方案对比' '| 方案 | 具体做什么 | 好处 | 代价和风险 | 能否撤回 |' '### 依据' \
           '**影响范围：**' '**证据：**' '**尚未验证：**' '### 回复方式' \
           '### 验收对照表' '| 验收标准 | 结果 | 证据 | 结论 |' '### 已知问题' '### 你可以这样核实（1–2 步）' \
           '`批准 A` / `改用 B` / `退回：<原因>`' '`FREEZE ACK`' '`PHASE ACCEPT`' '`EXCEPTION ACCEPT`' \
           '**第一行**' '`rev` 加 1' '不是代签' '不带来任何新权限' '`reply` 写 `对话`'; do
  has "$template" "$key"
done

# 4. Agents are routed to the format where decisions happen.
has playbooks/phase-lifecycle.md 'templates/decision-request.md'
has playbooks/phase-lifecycle.md 'PHASE ACCEPT'
has playbooks/phase-lifecycle.md '大改动检查'
has playbooks/phase-lifecycle.md '最终验收+发布'
has "$principles" '**Pre-approval (提前批准).**'
has "$principles" 'final acceptance is never pre-approved'
has playbooks/phase-lifecycle.md '已由 D-n 提前批准'
has playbooks/blocked-and-exceptions.md 'templates/decision-request.md'
has playbooks/staff-and-dispatch.md 'templates/decision-request.md'
has skills/github-multi-agent-project-ops/SKILL.md 'templates/decision-request.md'
has templates/AGENTS.md '.agent-project-ops/templates/decision-request.md'
has templates/AGENTS.md '§11'
has templates/ISSUE_TEMPLATE/command-center.md '**待你决定**'
has templates/ISSUE_TEMPLATE/command-center.md 'process_mode'
has templates/ISSUE_TEMPLATE/phase.md '大改动检查'
has templates/ISSUE_TEMPLATE/architecture-exception.md 'decision-request.md'
has AGENTS.md 'Agent must never self-issue `PHASE ACCEPT`'
has AGENTS.md 'templates/decision-request.md'

echo 'PASS: major-change list, process modes and fixed decision format are wired into the rules'
