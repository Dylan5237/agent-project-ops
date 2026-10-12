#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
files=(
  skills/github-multi-agent-project-ops/SKILL.md
  skills/issues-prs-and-evidence/SKILL.md
  playbooks/issues-and-prs.md
  playbooks/phase-lifecycle.md
  templates/PULL_REQUEST_TEMPLATE/evidence.md
  templates/PULL_REQUEST_TEMPLATE/implementation.md
  docs/GETTING_STARTED.md
  docs/GETTING_STARTED.zh-CN.md
)
for file in "${files[@]}"; do
  if grep -Ein 'bugbot|bugbot run' "${root}/${file}"; then
    echo "FAIL: vendor-specific review gate in ${file}" >&2
    exit 1
  fi
done
grep -Fq 'required CI' "${root}/playbooks/issues-and-prs.md"
grep -Fq 'PHASE ACCEPT' "${root}/playbooks/phase-lifecycle.md"
echo 'PASS: review requirements are provider-neutral'
