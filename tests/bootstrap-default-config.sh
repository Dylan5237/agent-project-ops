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

# No --no-projection or --yes needed: origin-only is a non-prompting default.
bash "$tmp/source/scripts/bootstrap-project.sh" --name default --dir "$tmp/default" --disposer @config-tester --skip-github </dev/null >"$tmp/default.out" 2>&1 || { cat "$tmp/default.out" >&2; fail "default bootstrap"; }
grep -Fxq 'projection=(none)' "$tmp/default/.agent-project-ops/remotes" || fail 'projection not disabled by default'
grep -Fq "$sha" "$tmp/default/.github/ISSUE_TEMPLATE/command-center.md" || fail 'CC missing real PIN SHA'
grep -Fxq "sha=$sha" "$tmp/default/.agent-project-ops/PIN" || fail 'PIN mismatch'

custom='https://example.org/other/methodology'
bash "$tmp/source/scripts/bootstrap-project.sh" --name custom --dir "$tmp/custom" --disposer @config-tester --skip-github --yes --methodology-url "$custom" --methodology-ref topic >/dev/null
grep -Fxq "url=$custom" "$tmp/custom/.agent-project-ops/PIN" || fail 'custom URL missing from PIN'
grep -Fq "$custom" "$tmp/custom/.github/ISSUE_TEMPLATE/command-center.md" || fail 'CC did not render custom source URL'
grep -Fq 'ref topic' "$tmp/custom/.github/ISSUE_TEMPLATE/command-center.md" || fail 'CC did not render method ref'

bash "$tmp/source/scripts/bootstrap-project.sh" --name mirror --dir "$tmp/mirror" --disposer @config-tester --skip-github --yes --projection-url git@internal.example:team/repo.git >/dev/null
grep -Fxq 'projection=projection' "$tmp/mirror/.agent-project-ops/remotes" || fail 'explicit projection missing'
grep -Fxq 'projection_url=git@internal.example:team/repo.git' "$tmp/mirror/.agent-project-ops/remotes" || fail 'projection URL missing'

if grep -Fq 'Methodology: https://github.com/Dylan5237/agent-project-ops' "$tmp/custom/.github/ISSUE_TEMPLATE/command-center.md"; then
  fail "CC still hardcodes the author\x27s methodology"
fi
echo 'PASS: origin-only default, optional projection and PIN-derived CC provenance'
