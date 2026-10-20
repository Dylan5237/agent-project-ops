#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1 PYTHONUTF8=1
python3 - "$root" <<'PY'
from pathlib import Path
import re, sys
root = Path(sys.argv[1])
read = lambda name: (root / name).read_text(encoding='utf-8')
task = read('templates/ISSUE_TEMPLATE/task.md')
for required in ('type:task, status:backlog', '<!-- apo-task v1 -->', '## 目标',
                 '## 归属和负责人', '## 范围与非目标', '## 合同和开工依据',
                 '## 验收办法', '## 工作区和交付', '## 停止条件和交接',
                 'standard', 'light', 'CONTRACT FREEZE'):
    assert required in task, required

def block(name):
    blocks = re.findall(r'```markdown\n(.*?)\n```', read(name), re.S)
    assert len(blocks) == 1, name
    return blocks[0]

claim = block('templates/task-claim.md')
keys = ['action', 'task', 'phase', 'owner', 'contract', 'major_change',
        'start_approval', 'workdir', 'branch', 'head']
assert claim.splitlines()[0] == '<!-- apo-task-claim v1 -->'
assert [line.split(':', 1)[0] for line in claim.splitlines()[1:]] == keys
values = dict(CLAIM_OR_START='START', TASK_ISSUE='42', PHASE_ISSUE_OR_NONE='#40',
              AGENT_ID='Codex', FREEZE_URL='https://github.com/example/repo/issues/40#issuecomment-1',
              CHECK_RESULT='无', APPROVAL_URL_OR_NOT_REQUIRED_OR_PENDING='不需要',
              ABSOLUTE_PATH_OR_PENDING='/tmp/project', BRANCH_OR_PENDING='feat/42-example',
              HEAD_SHA_OR_PENDING='a' * 40)
def render(text, data):
    return re.sub(r'\{\{([A-Z_]+)\}\}', lambda m: data[m[1]], text)
def conform(comment):
    assert comment.splitlines()[0] == '<!-- apo-task-claim v1 -->'
    rows = [line.partition(':') for line in comment.splitlines()[1:]]
    assert [k for k, _, _ in rows] == keys
    fields = {k: v.strip() for k, sep, v in rows if sep}
    assert all(fields.values()) and '{{' not in comment
    assert not re.search(r'(?<!\w)@[A-Za-z]', comment)
    assert fields['action'] in ('CLAIM', 'START')
    if fields['action'] == 'START':
        assert all(fields[k] not in ('待分配', '等待') for k in ('workdir', 'branch', 'head', 'start_approval'))
        assert re.fullmatch('[0-9a-f]{40}', fields['head'])
        if fields['major_change'] != '无':
            assert fields['start_approval'] != '不需要'
    return fields
for agent in ('Codex', 'Claude Code', 'WorkBuddy'):
    for action in ('CLAIM', 'START'):
        conform(render(claim, dict(values, AGENT_ID=agent, CLAIM_OR_START=action)))
conform(render(claim, dict(values, CLAIM_OR_START='CLAIM', PHASE_ISSUE_OR_NONE='无',
                          ABSOLUTE_PATH_OR_PENDING='待分配', BRANCH_OR_PENDING='待分配',
                          HEAD_SHA_OR_PENDING='待分配', APPROVAL_URL_OR_NOT_REQUIRED_OR_PENDING='等待')))
valid = render(claim, values)
invalid = [valid.replace('owner: Codex', 'owner: ' + chr(64) + 'Codex'),
           valid.replace('owner: Codex\n', ''), valid + '\nowner: Other',
           valid.replace('/tmp/project', '待分配'), valid.replace('不需要', '等待'),
           valid.replace('major_change: 无', 'major_change: 命中第 7 条')]
for bad in invalid:
    try:
        conform(bad)
    except AssertionError:
        pass
    else:
        raise AssertionError('invalid claim/start example accepted')
completion = block('templates/task-completion.md')
assert completion.startswith('<!-- apo-task-completion v1 -->\n')
for field in ('task:', 'owner:', 'workdir:', 'branch:', 'head:', 'pr:', 'status: verification'):
    assert field in completion, field
for heading in ('## 实际改动', '## 验收证据', '## 失败和未验证', '## 合同偏差与阻塞', '## 下一步'):
    assert heading in completion, heading
assert not re.search(r'(?<!\w)@[A-Za-z]', claim + completion)
for name in ('playbooks/staff-and-dispatch.md', 'skills/github-multi-agent-project-ops/SKILL.md',
             'skills/github-multi-agent-task-executor/SKILL.md'):
    text = read(name)
    assert chr(64) + 'owner START' not in text, name
    assert 'task-claim.md' in text and 'task-completion.md' in text, name
for name in ('github-multi-agent-project-ops', 'github-multi-agent-task-executor'):
    assert re.search(r'^name: ' + re.escape(name) + r'$', read(f'skills/{name}/SKILL.md'), re.M)
print('PASS: three task formats, plain Agent identity, pending CLAIM and invalid START examples')
PY
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone -q --no-checkout "$root" "$tmp/source"
git -C "$tmp/source" checkout -q --detach "$(git -C "$root" rev-parse HEAD)"
bash "$tmp/source/scripts/bootstrap-project.sh" --name dispatch-fixture --dir "$tmp/project" \
  --disposer @tester --skip-github --yes --process-mode standard \
  --agent-tools codex,claude,workbuddy --external-tools none >"$tmp/bootstrap.log" 2>&1 \
  || { cat "$tmp/bootstrap.log"; exit 1; }
python3 - "$tmp/project" <<'PY'
from pathlib import Path
import re, sys
root = Path(sys.argv[1])
snapshot = root / '.agent-project-ops'
for path in ('ISSUE_TEMPLATE/task.md', 'task-claim.md', 'task-completion.md'):
    assert (snapshot / 'templates' / path).is_file(), path
assert (root / '.github/ISSUE_TEMPLATE/task.md').read_bytes() == (snapshot / 'templates/ISSUE_TEMPLATE/task.md').read_bytes()
for name in ('github-multi-agent-project-ops', 'github-multi-agent-task-executor'):
    full = snapshot / 'skills' / name / 'SKILL.md'
    text = full.read_text(encoding='utf-8')
    assert text.startswith('---\n') and f'name: {name}\n' in text
    for prefix in ('.agents', '.claude', '.codebuddy'):
        wrapper = root / prefix / 'skills' / name / 'SKILL.md'
        wrapped = wrapper.read_text(encoding='utf-8')
        assert f'name: {name}\n' in wrapped
        link = re.search(r'\]\(([^)]+/SKILL.md)\)', wrapped)[1]
        assert (wrapper.parent / link).resolve() == full.resolve()
        assert wrapper.read_bytes() == (root / '.agents/skills' / name / 'SKILL.md').read_bytes()
    for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', text):
        assert (full.parent / target).is_file(), (name, target)
assert 'github-multi-agent-task-executor' in (root / 'AGENTS.md').read_text(encoding='utf-8')
print('PASS: actual bootstrap installs task formats, role skills, reachable wrappers and selected host copies')
PY
