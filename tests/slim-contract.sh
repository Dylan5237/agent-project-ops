#!/usr/bin/env bash
# Frozen Step2 contract. Historical evidence and old-PIN descriptors are excluded
# deliberately; runtime refusals and actual migration have their own tests.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONDONTWRITEBYTECODE=1 python3 - "$root" <<'PY'
from pathlib import Path
import re, subprocess, sys
root = Path(sys.argv[1])
retired = [
    'fleet/REGISTRY.md', 'fleet/README.md',
    'README.zh-CN.md', 'docs/GETTING_STARTED.zh-CN.md', 'docs/UPGRADE.zh-CN.md',
    '.cursor/rules/agent-project-ops-self.mdc', '.github/copilot-instructions.md',
    'templates/cursor-rules/agent-project-ops.mdc', 'templates/github/copilot-instructions.md',
    'templates/continue-rules/agent-project-ops.md', 'templates/aider.conf.yml',
    'scripts/share-export.sh', 'scripts/export-sync.sh',
    'scripts/lib/share-export-denylist.sh', 'scripts/lib/export-strip-list.sh',
    'skills/git-authority-and-projection/SKILL.md', 'skills/export-remote/SKILL.md', 'skills/share-export/SKILL.md',
    'playbooks/git-authority-and-projection.md', 'playbooks/export-remote.md', 'playbooks/share-export.md',
]
for name in retired:
    assert not (root / name).exists(), f'retired feature remains: {name}'
for name in ['.agent-project-ops/remotes', 'templates/remotes']:
    lines = [s.strip() for s in (root / name).read_text(encoding='utf-8').splitlines() if s.strip() and not s.lstrip().startswith('#')]
    assert lines == ['authority=origin'], f'unsupported current registry: {name}'
assert (root / 'VERSION').read_text(encoding='utf-8').strip() == '0.2.1', 'Step2 must not change package version'
principles = (root / 'PRINCIPLES.md').read_text(encoding='utf-8')
assert principles.startswith('# PRINCIPLES — v0.3.0'), 'rules version does not match freeze'
assert 'A separate evidence PR is **optional**' in principles
for name in ['README.md', 'docs/GETTING_STARTED.md', 'docs/UPGRADE.md']:
    text = (root / name).read_text(encoding='utf-8')
    for prompt in ['使用 https://github.com/Dylan5237/agent-project-ops 初始化当前项目。', '使用 https://github.com/Dylan5237/agent-project-ops 更新当前项目的apo规则。']:
        assert prompt in text, f'short prompt missing in {name}'
# Literal links in active documents must resolve. Historical bodies are immutable
# evidence and may legitimately describe paths removed by this phase.
tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
history = ('docs/evidence/', 'docs/adr/', 'docs/research/', 'docs/rfcs/', 'docs/releases/')
checked = 0
for name in tracked:
    p = root / name
    if not name.endswith('.md') or not p.is_file():
        continue
    if name.startswith(history) and p.name != 'README.md':
        continue
    text = re.sub(r'```.*?```', '', p.read_text(encoding='utf-8'), flags=re.S)
    for raw in re.findall(r'\[[^\]\n]*\]\(([^)\n]+)\)', text):
        target = raw.strip().split(' "', 1)[0].strip('<>')
        if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target) or target.startswith('#') or '{{' in target:
            continue
        target = target.split('#', 1)[0]
        if target and not any(c in target for c in '*?'):
            assert (p.parent / target).exists(), f'broken active link in {name}: {target}'
            checked += 1
workflow = (root / '.github/workflows/release.yml').read_text(encoding='utf-8')
push = workflow.split('  push:', 1)[1].split('\npermissions:', 1)[0]
assert re.findall(r"^\s+- '([^']+)'", push, re.M) == ['VERSION'], 'non-version edits must not trigger publishing'
assert 'for test_file in tests/*.sh' in workflow and 'python3 tests/test_prepare_upgrade.py -v' in workflow
assert 'UPGRADE.zh-CN.md' not in workflow and 'cp docs/UPGRADE.md' in workflow
assert 'refusing to replace it' in workflow, 'release tag immutability weakened'
print(f'PASS: retired paths absent, origin-only registry, optional evidence, Chinese entry links ({checked}), release boundary')
PY
