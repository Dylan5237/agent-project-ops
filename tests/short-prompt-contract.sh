#!/usr/bin/env bash
# Contract test for the existing URL + short-action user experience.
# This tests documentation/Skill routing only, NOT live Agent-host tool compliance.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

init='使用 https://github.com/Dylan5237/agent-project-ops 初始化当前项目。'
upgrade='使用 https://github.com/Dylan5237/agent-project-ops 更新当前项目的apo规则。'
fail() { echo "FAIL: $*" >&2; exit 1; }

# Both exact user prompts must remain first-class, including the upgrade guide
# that an existing pinned v0.1.x project will use.
for path in README.zh-CN.md docs/GETTING_STARTED.zh-CN.md docs/UPGRADE.zh-CN.md README.md docs/GETTING_STARTED.md docs/UPGRADE.md; do
  [[ -f "$root/$path" ]] || fail "missing $path"
  grep -Fq "$init" "$root/$path" || fail "$path lost original initialization short prompt"
  grep -Fq "$upgrade" "$root/$path" || fail "$path lost original update short prompt"
done

# The two EXISTING Skills, not a new Agent runtime, must advertise the requests
# even to hosts that use only YAML-frontmatter Skill discovery.
bootstrap="$root/skills/bootstrap-project/SKILL.md"
upgrader="$root/skills/upgrade-project/SKILL.md"
sed -n '/^description: >/,/^---$/p' "$bootstrap" | grep -Fq "$init" || fail "bootstrap Skill description missing URL-first trigger"
sed -n '/^description: >/,/^---$/p' "$upgrader" | grep -Fq "$upgrade" || fail "upgrade Skill description missing URL-first trigger"
grep -Fq "$init" "$bootstrap" || fail "bootstrap Skill missing exact user prompt"
grep -Fq "$upgrade" "$upgrader" || fail "upgrade Skill missing exact user prompt"

# Safety remains explicit: observe, verify release provenance, pick the
# appropriate existing workflow and require real approval for consequential changes.
for key in 'latest published stable Release' 'playbooks/adopt-existing-project.md' 'authorization' 'local Git'; do
  grep -Fiq "$key" "$bootstrap" || fail "bootstrap lost routing/safety contract: $key"
done
for key in 'published stable Release' 'plan_id' 'full-history Git clone' 'read-only preview'; do
  grep -Fiq "$key" "$upgrader" || fail "upgrade lost provenance/approval contract: $key"
done
grep -Fq 'nonempty repository' "$bootstrap" || fail "greenfield/adoption boundary missing"
grep -Fq 'does not' "$upgrader" || fail "upgrade limitations missing"
grep -Fq 'PR merge' "$root/PRINCIPLES.md" || fail "methodology phase acceptance rule missing"

echo 'PASS: URL-first short prompts route existing Bootstrap/Adoption/Upgrade Skills without weakening approval gates'
