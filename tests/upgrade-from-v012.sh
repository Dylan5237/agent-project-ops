#!/usr/bin/env bash
# Disposable local Git repositories only. No external project is modified.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1 PYTHONUTF8=1
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
sha="$(git -C "$root" rev-parse HEAD)"
old="$(git -C "$root" rev-parse --verify 'v0.1.2^{commit}')"
url="$(git -C "$root" remote get-url origin)"

git clone -q --no-checkout "$root" "$tmp/old-method"
git -C "$tmp/old-method" checkout -q --detach "$old"
bash "$tmp/old-method/scripts/bootstrap-project.sh" --name upgrade-demo --dir "$tmp/project" \
  --disposer @upgrade-tester --methodology-url "$url" --no-projection --skip-github --yes > "$tmp/bootstrap-old.log" 2>&1

git -C "$tmp/project" config user.name upgrade-tester
git -C "$tmp/project" config user.email upgrade-tester@local.invalid
printf '\n## Project-specific rules\nPreserve the clinical data boundary.\n' >> "$tmp/project/AGENTS.md"
printf 'business content must survive\n' > "$tmp/project/business.txt"
printf 'task_base=origin/develop\n' > "$tmp/project/.agent-project-ops/project-config"
git -C "$tmp/project" add .
git -C "$tmp/project" commit -qm 'fixture: personal rules and business baseline'
baseline="$(git -C "$tmp/project" rev-parse HEAD)"
cp "$tmp/project/.agent-project-ops/remotes" "$tmp/remotes.before"
cp "$tmp/project/AGENTS.md" "$tmp/agents.before"

git -C "$tmp/project" worktree add -q -b upgrade/apo-fixture "$tmp/upgrade" "$baseline"
python3 "$root/scripts/prepare-upgrade.py" --source "$root" --project "$tmp/upgrade" > "$tmp/plan.json"
plan_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["plan_id"])' "$tmp/plan.json")"
[[ -z "$(git -C "$tmp/upgrade" status --porcelain)" ]] || fail 'preview modified target'
python3 "$root/scripts/prepare-upgrade.py" --source "$root" --project "$tmp/upgrade" \
  --patch --expect-plan "$plan_id" > "$tmp/upgrade.patch" 2> "$tmp/receipt.json"
[[ -s "$tmp/upgrade.patch" ]] || fail 'no upgrade patch'
[[ -z "$(git -C "$tmp/upgrade" status --porcelain)" ]] || fail 'patch generation modified target'

git -C "$tmp/upgrade" apply --check "$tmp/upgrade.patch"
git -C "$tmp/upgrade" apply "$tmp/upgrade.patch"
grep -Fxq "sha=$sha" "$tmp/upgrade/.agent-project-ops/PIN" || fail 'new PIN does not match source SHA'
grep -Fq 'Preserve the clinical data boundary.' "$tmp/upgrade/AGENTS.md" || fail 'custom AGENTS rules lost'
grep -Fq 'business content must survive' "$tmp/upgrade/business.txt" || fail 'business file lost'
cmp -s "$tmp/remotes.before" "$tmp/upgrade/.agent-project-ops/remotes" || fail 'remote classification altered'
grep -Fxq 'task_base=origin/develop' "$tmp/upgrade/.agent-project-ops/project-config" || fail 'project setting lost'
grep -Fq 'upgrade-project' "$tmp/upgrade/.agents/skills/upgrade-project/SKILL.md" || fail 'upgrade Skill wrapper not generated'
if grep -Eqi 'bugbot run|Register to Fleet REGISTRY|fleet-morning-digest' "$tmp/upgrade/.agent-project-ops/skills/github-multi-agent-project-ops/SKILL.md"; then
  fail 'obsolete generic policy retained'
fi
[[ "$(git -C "$tmp/project" rev-parse HEAD)" == "$baseline" ]] || fail 'primary branch moved'
[[ -z "$(git -C "$tmp/project" status --porcelain)" ]] || fail 'primary checkout modified'

git -C "$tmp/upgrade" apply --reverse --check "$tmp/upgrade.patch"
git -C "$tmp/upgrade" apply --reverse "$tmp/upgrade.patch"
[[ -z "$(git -C "$tmp/upgrade" status --porcelain)" ]] || fail 'reverse patch failed to restore baseline'
cmp -s "$tmp/agents.before" "$tmp/upgrade/AGENTS.md" || fail 'original AGENTS bytes not restored'
grep -Fxq "sha=$old" "$tmp/upgrade/.agent-project-ops/PIN" || fail 'old PIN not restored'

git -C "$tmp/upgrade" apply --check "$tmp/upgrade.patch"
git -C "$tmp/upgrade" apply "$tmp/upgrade.patch"
git -C "$tmp/upgrade" add .
git -C "$tmp/upgrade" commit -qm 'fixture: reviewed APO rule update'
python3 "$root/scripts/prepare-upgrade.py" --source "$root" --project "$tmp/upgrade" > "$tmp/noop.json"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["status"]=="UP_TO_DATE" and not d["changes"]' "$tmp/noop.json"
echo "PASS: real v0.1.2 $old -> $sha preview/apply/reverse/repeat; primary checkout preserved"
