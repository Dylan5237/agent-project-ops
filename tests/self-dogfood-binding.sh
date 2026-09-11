#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

for path in \
  AGENTS.md \
  CLAUDE.md \
  .cursor/rules/agent-project-ops-self.mdc \
  .github/copilot-instructions.md \
  .agent-project-ops/remotes \
  .githooks/pre-push
 do
  [[ -f "${root}/${path}" ]] || fail "missing self-binding file: ${path}"
done
pass 'self-binding adapters and hook entrypoint exist'

# Self-dogfood must not recursively vendor this methodology repository.
[[ ! -e "${root}/.agent-project-ops/PRINCIPLES.md" ]] || fail 'recursive PRINCIPLES snapshot detected'
[[ ! -e "${root}/.agent-project-ops/playbooks" ]] || fail 'recursive playbooks snapshot detected'
[[ ! -e "${root}/.agent-project-ops/skills" ]] || fail 'recursive skills snapshot detected'
pass 'self-binding contains no recursive methodology snapshot'

agents="${root}/AGENTS.md"
grep -Fq 'https://github.com/Dylan5237/agent-project-ops/issues/10' "${agents}" || fail 'Command Center #10 pointer missing'
grep -Fq 'GitHub `origin` is the sole write authority' "${agents}" || fail 'origin authority missing'
grep -Fq 'Projection remotes: `(none)`' "${agents}" || fail 'projection none missing'
grep -Fq 'Direct push to `main` is forbidden' "${agents}" || fail 'direct-main prohibition missing'
grep -Fq 'PHASE ACCEPT' "${agents}" || fail 'Accept separation missing'
grep -Fq 'scripts/install-hooks.sh' "${agents}" || fail 'fresh-clone hook installer pointer missing'
grep -Fq 'current Phase is discovered from the Command Center Phase index' "${agents}" || fail 'durable current-Phase discovery rule missing'
pass 'AGENTS.md contains takeover-critical control-plane facts'

grep -Fq '@AGENTS.md' "${root}/CLAUDE.md" || fail 'Claude bridge does not load AGENTS.md'
grep -Fq 'AGENTS.md' "${root}/.cursor/rules/agent-project-ops-self.mdc" || fail 'Cursor adapter does not load AGENTS.md'
grep -Fq 'AGENTS.md' "${root}/.github/copilot-instructions.md" || fail 'Copilot adapter does not load AGENTS.md'
pass 'supported adapters converge on one binding'

[[ "$(sed -n 's/^authority=//p' "${root}/.agent-project-ops/remotes")" == 'origin' ]] || fail 'self remote authority is not origin'
[[ "$(sed -n 's/^projection=//p' "${root}/.agent-project-ops/remotes")" == '(none)' ]] || fail 'self projection is not none'
pass 'self remote registry is explicit'

bash -n "${root}/.githooks/pre-push"
bash -n "${root}/scripts/install-hooks.sh"
pass 'hook entrypoint and installer parse'

# Fresh clone contract: the tracked hook arrives, but local config does not.
git clone -q "${root}" "${tmp}/fresh"
git -C "${tmp}/fresh" fetch -q "${root}" HEAD
git -C "${tmp}/fresh" checkout -q FETCH_HEAD
[[ -f "${tmp}/fresh/.githooks/pre-push" ]] || fail 'fresh clone missing tracked pre-push entrypoint'
if git -C "${tmp}/fresh" config --get core.hooksPath >/dev/null 2>&1; then
  fail 'fresh clone incorrectly inherited core.hooksPath'
fi
(
  cd "${tmp}/fresh"
  bash scripts/install-hooks.sh >/dev/null
)
[[ "$(git -C "${tmp}/fresh" config --get core.hooksPath)" == '.githooks' ]] || fail 'installer did not restore core.hooksPath=.githooks'
pass 'fresh clone detects missing local hook config and installer restores it'

# The fresh clone itself must expose enough durable state for takeover without chat.
grep -Fq 'issues/10' "${tmp}/fresh/AGENTS.md" || fail 'fresh clone lost Command Center pointer'
grep -Fq 'PRINCIPLES.md' "${tmp}/fresh/AGENTS.md" || fail 'fresh clone lost methodology entrypoint'
grep -Fq 'Agent must never self-issue `PHASE ACCEPT`' "${tmp}/fresh/AGENTS.md" || fail 'fresh clone lost disposer separation'
pass 'fresh clone exposes takeover-critical durable state'

echo 'self-dogfood-binding: all contract checks passed'
