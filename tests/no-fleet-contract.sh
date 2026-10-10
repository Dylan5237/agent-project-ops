#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
files=(
  skills/bootstrap-project/SKILL.md
  skills/github-multi-agent-project-ops/SKILL.md
  playbooks/bootstrap-project.md
  playbooks/start-project.md
  playbooks/adopt-existing-project.md
  templates/ISSUE_TEMPLATE/command-center.md
)
bad='Register to Fleet REGISTRY|Fleet morning digest|fleet-morning-digest|Dylan5237/agent-project-ops.*fleet/REGISTRY|已纳入舰队晨报扫描|Fleet REGISTRY'
for file in "${files[@]}"; do
  if grep -Ein "${bad}" "${root}/${file}"; then
    printf 'FAIL: personal Fleet dependency remains: %s\n' "${file}" >&2
    exit 1
  fi
done
grep -Fq '.agent-project-ops/remotes' "${root}/playbooks/start-project.md"
grep -Fq 'Command Center **section 1**' "${root}/skills/github-multi-agent-project-ops/SKILL.md"
echo 'PASS: generic bootstrap contracts no longer require a personal Fleet'
