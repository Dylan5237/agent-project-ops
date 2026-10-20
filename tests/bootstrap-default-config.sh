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
bash "$tmp/source/scripts/bootstrap-project.sh" --name default --dir "$tmp/default" --disposer @config-tester --process-mode standard --agent-tools codex,claude --external-tools none --skip-github </dev/null >"$tmp/default.out" 2>&1 || { cat "$tmp/default.out" >&2; fail "default bootstrap"; }
[[ "$(cat "$tmp/default/.agent-project-ops/remotes")" == 'authority=origin' ]] || fail 'authority registry is not origin-only'
grep -Fq "$sha" "$tmp/default/.github/ISSUE_TEMPLATE/command-center.md" || fail 'CC missing real PIN SHA'
grep -Fxq "sha=$sha" "$tmp/default/.agent-project-ops/PIN" || fail 'PIN mismatch'

custom='https://example.org/other/methodology'
bash "$tmp/source/scripts/bootstrap-project.sh" --name custom --dir "$tmp/custom" --disposer @config-tester --process-mode standard --agent-tools codex,claude --external-tools none --skip-github --yes --methodology-url "$custom" --methodology-ref topic >/dev/null
grep -Fxq "url=$custom" "$tmp/custom/.agent-project-ops/PIN" || fail 'custom URL missing from PIN'
grep -Fq "$custom" "$tmp/custom/.github/ISSUE_TEMPLATE/command-center.md" || fail 'CC did not render custom source URL'
grep -Fq 'PIN 分支或标签：topic' "$tmp/custom/.github/ISSUE_TEMPLATE/command-center.md" || fail 'CC did not render method ref'

for retired in --projection-url --no-projection; do
  rejected="$tmp/rejected-${retired#--}"
  if bash "$tmp/source/scripts/bootstrap-project.sh" --name rejected --dir "$rejected" --disposer @config-tester "$retired" --process-mode standard --agent-tools codex,claude --external-tools none --skip-github --yes >/dev/null 2>&1; then
    fail "retired option accepted: $retired"
  fi
  [[ ! -e "$rejected" ]] || fail "retired option created files before rejection: $retired"
done

if grep -Fq '方法论地址：https://github.com/Dylan5237/agent-project-ops' "$tmp/custom/.github/ISSUE_TEMPLATE/command-center.md"; then
  fail "CC still hardcodes the author\x27s methodology"
fi
# Run the actual creation path with a fake gh and SSH transport, keeping every
# Git/pre-push process real. No account, remote service or actual repo created.
mkdir -p "$tmp/bin"
git init --bare -q --initial-branch=main "$tmp/initial.git"
cat > "$tmp/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'auth status'|'repo edit') exit 0 ;;
  'repo create')
    [[ "${APO_INITIAL_BRANCH:-}" == main ]] || { echo 'initial branch env missing' >&2; exit 1; }
    git remote add origin git@github.com:example/initial.git
    git push -u origin HEAD
    exit 0 ;;
  'api user') echo example; exit 0 ;;
  'api '*) exit 1 ;;
esac
exit 1
SH
cat > "$tmp/fake-ssh.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${*: -1}" in
  git-receive-pack\ *) exec git-receive-pack "$APO_TEST_BARE" ;;
  git-upload-pack\ *) exec git-upload-pack "$APO_TEST_BARE" ;;
  *) exit 1 ;;
esac
SH
chmod +x "$tmp/bin/gh"
env PATH="$tmp/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
  APO_TEST_BARE="$tmp/initial.git" GIT_SSH_COMMAND="bash '$tmp/fake-ssh.sh'" GIT_SSH_VARIANT=ssh \
  bash "$tmp/source/scripts/bootstrap-project.sh" --name initial --dir "$tmp/initial" --disposer @config-tester \
    --process-mode standard --agent-tools codex --external-tools none --yes > "$tmp/initial.out" 2>&1 \
    || { cat "$tmp/initial.out"; fail 'actual bootstrap creation path did not carry explicit initial branch'; }
[[ "$(git --git-dir="$tmp/initial.git" rev-parse refs/heads/main)" == "$(git -C "$tmp/initial" rev-parse HEAD)" ]] \
  || fail 'initial push did not create the declared branch'
echo 'PASS: origin-only bootstrap, retired option rejection, PIN provenance and actual initial push environment'
