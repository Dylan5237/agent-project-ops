#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

git clone -q --no-checkout "$root" "$tmp/method"
git -C "$tmp/method" checkout -q --detach "$(git -C "$root" rev-parse HEAD)"
[[ -z "$(git -C "$tmp/method" status --porcelain --untracked-files=all)" ]] || fail 'fixture checkout is dirty'

bash "$tmp/method/scripts/bootstrap-project.sh" --name clean --dir "$tmp/clean" --disposer @pin-tester --no-projection --skip-github --yes >/dev/null
[[ -f "$tmp/clean/.agent-project-ops/PIN" ]] || fail 'clean checkout bootstrap failed'

printf '\n# uncommitted modification\n' >> "$tmp/method/templates/AGENTS.md"
if bash "$tmp/method/scripts/bootstrap-project.sh" --name dirty --dir "$tmp/dirty" --disposer @pin-tester --no-projection --skip-github --yes >"$tmp/dirty.out" 2>&1; then
  fail 'tracked dirty methodology accepted'
fi
grep -Fq 'snapshot would not match PIN SHA' "$tmp/dirty.out" || fail 'dirty source error not useful'
[[ ! -e "$tmp/dirty" ]] || fail 'partial destination created on dirty source'

git -C "$tmp/method" checkout -- templates/AGENTS.md
printf '# not in pin\n' > "$tmp/method/skills/untracked-skill-test.md"
if bash "$tmp/method/scripts/bootstrap-project.sh" --name untracked --dir "$tmp/untracked" --disposer @pin-tester --no-projection --skip-github --yes >"$tmp/untracked.out" 2>&1; then
  fail 'untracked copied source accepted'
fi
[[ ! -e "$tmp/untracked" ]] || fail 'partial untracked destination created'

# Dry-run is intentionally non-writing; it may still show the plan for inspection.
bash "$tmp/method/scripts/bootstrap-project.sh" --name dry --dir "$tmp/dry" --disposer @pin-tester --no-projection --skip-github --dry-run --yes >/dev/null
[[ ! -e "$tmp/dry" ]] || fail 'dry-run wrote a destination'
echo 'PASS: PIN provenance requires a clean method checkout'
