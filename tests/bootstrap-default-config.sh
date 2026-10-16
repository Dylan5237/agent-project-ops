#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

git clone -q --no-checkout "$root" "$tmp/source"
git -C "$tmp/source" checkout -q --detach "$(git -C "$root" rev-parse HEAD)"
[[ -z "$(git -C "$tmp/source" status --porcelain --untracked-files=all)" ]] || fail 'source fixture dirty'
sha="$(git -C "$tmp/source" rev-parse HEAD)"

# No remote-selection option or --yes is needed: origin-only is the only mode.
bash "$tmp/source/scripts/bootstrap-project.sh" --name default --dir "$tmp/default" --disposer @config-tester --skip-github </dev/null >"$tmp/default.out" 2>&1 || { cat "$tmp/default.out" >&2; fail "default bootstrap"; }
[[ "$(cat "$tmp/default/.agent-project-ops/remotes")" == 'authority=origin' ]] || fail 'authority registry is not origin-only'
grep -Fq "$sha" "$tmp/default/.github/ISSUE_TEMPLATE/command-center.md" || fail 'CC missing real PIN SHA'
grep -Fxq "sha=$sha" "$tmp/default/.agent-project-ops/PIN" || fail 'PIN mismatch'

custom='https://example.org/other/methodology'
bash "$tmp/source/scripts/bootstrap-project.sh" --name custom --dir "$tmp/custom" --disposer @config-tester --skip-github --yes --methodology-url "$custom" --methodology-ref topic >/dev/null
grep -Fxq "url=$custom" "$tmp/custom/.agent-project-ops/PIN" || fail 'custom URL missing from PIN'
grep -Fq "$custom" "$tmp/custom/.github/ISSUE_TEMPLATE/command-center.md" || fail 'CC did not render custom source URL'
grep -Fq 'PIN 分支或标签：topic' "$tmp/custom/.github/ISSUE_TEMPLATE/command-center.md" || fail 'CC did not render method ref'

for retired in --projection-url --no-projection; do
  rejected="$tmp/rejected-${retired#--}"
  if bash "$tmp/source/scripts/bootstrap-project.sh" --name rejected --dir "$rejected" --disposer @config-tester "$retired" --skip-github --yes >/dev/null 2>&1; then
    fail "retired option accepted: $retired"
  fi
  [[ ! -e "$rejected" ]] || fail "retired option created files before rejection: $retired"
done

if grep -Fq '方法论地址：https://github.com/Dylan5237/agent-project-ops' "$tmp/custom/.github/ISSUE_TEMPLATE/command-center.md"; then
  fail "CC still hardcodes the author\x27s methodology"
fi
echo 'PASS: origin-only bootstrap, retired option rejection and PIN-derived CC provenance'
