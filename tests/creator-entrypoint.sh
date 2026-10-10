#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
skill="$root/skills/apo-project-assistant/SKILL.md"
[[ -f "$skill" ]] || { echo 'missing creator skill' >&2; exit 1; }
grep -Fxq 'name: apo-project-assistant' "$skill"
for phrase in 'Intent A' 'Intent B' 'Intent C' 'PHASE ACCEPT' 'headless' 'origin'; do
  grep -Fq "$phrase" "$skill" || { echo "missing safety/intent: $phrase" >&2; exit 1; }
done
grep -Fq '已验证' "$root/docs/USER_JOURNEYS.zh-CN.md"
grep -Fq 'UNVERIFIED' "$root/docs/USER_JOURNEYS.md"
grep -Fq 'apo-project-assistant' "$root/README.md"
grep -Fq 'apo-project-assistant' "$root/README.zh-CN.md"
echo 'PASS: user-facing entrypoint routes three journeys without a second control plane'
