#!/usr/bin/env bash
set -euo pipefail

# User/system URL rewrites must not redirect the fixture's fake SSH transport.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

pass=0
fail=0
ok() { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s\n' "$1" >&2; fail=$((fail + 1)); }
expect_allow() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name (expected ALLOW)"; fi
}
expect_deny() {
  local name="$1"; shift
  if "$@" >"${tmp}/denial.log" 2>&1; then
    bad "$name (expected DENY)"
  elif grep -Fq 'agent-project-ops hook:' "${tmp}/denial.log"; then
    ok "$name"
  else
    bad "$name (failed before hook policy was exercised)"
    cat "${tmp}/denial.log" >&2
  fi
}

mkdir -p "${tmp}/remotes"
for remote in origin projection export share unknown; do
  git init --bare -q --initial-branch=main "${tmp}/remotes/${remote}.git"
done

# Exercise real git push/pre-push with canonical GitHub URLs, while a test-only
# SSH transport talks to the disposable local bare repo. No production bypass.
cat > "${tmp}/fake-ssh.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
command="${*: -1}"
case "$command" in
  git-receive-pack\ *) exec git-receive-pack "$APO_TEST_BARE" ;;
  git-upload-pack\ *)
    [[ "${APO_TEST_UPLOAD_FAIL:-0}" != 1 ]] || exit 1
    exec git-upload-pack "$APO_TEST_BARE" ;;
  *) echo 'unexpected test SSH command' >&2; exit 2 ;;
esac
EOF
export APO_TEST_BARE="${tmp}/remotes/origin.git"
export GIT_SSH_COMMAND="bash '${tmp}/fake-ssh.sh'"
export GIT_SSH_VARIANT=ssh

git init -q -b main "${tmp}/work"
cd "${tmp}/work"
git config user.name apo-test
git config user.email apo-test@example.invalid
printf 'base\n' > tracked.txt
mkdir -p .githooks .agent-project-ops/scripts/lib .agent-project-ops/scripts
cp "${repo_root}/scripts/hooks/pre-push-authority.sh" .githooks/pre-push
cp "${repo_root}/scripts/lib/url-guard.sh" .agent-project-ops/scripts/lib/url-guard.sh
cp "${repo_root}/scripts/install-hooks.sh" .agent-project-ops/scripts/install-hooks.sh
chmod +x .githooks/pre-push .agent-project-ops/scripts/install-hooks.sh
cat > .agent-project-ops/remotes <<'EOF'
authority=origin
projection=projection
export=export
share_export=share
EOF
git add tracked.txt .githooks .agent-project-ops
git commit -q -m base
git config core.hooksPath .githooks

for remote in origin projection export share unknown; do
  git remote add "$remote" "git@github.com:example/${remote}.git"
done

# Bootstrap may create the authority default branch once. The same commit must
# then be fetched before checking the direct-update rule.
expect_deny 'empty origin requires explicit first branch' git push -u origin main
expect_deny 'empty origin rejects undeclared topic' env APO_INITIAL_BRANCH=trunk git push origin main
expect_allow 'initial main -> origin' env APO_INITIAL_BRANCH=main git push -u origin main
git fetch -q origin main
base_tip="$(git rev-parse refs/remotes/origin/main)"

printf 'direct update\n' >> tracked.txt
git commit -qam direct-main
expect_deny 'direct main update -> origin' git push origin main
git reset -q --hard "${base_tip}"

# Topic branches remain pushable to the sole authority.
git checkout -q -b feat/test "${base_tip}"
printf 'topic\n' >> tracked.txt
git commit -qam topic
expect_allow 'topic -> origin' git push -u origin HEAD:refs/heads/feat/test

# Old role entries are deliberately present: none may authorize a non-origin push.
expect_deny 'legacy projection role -> projection' git push projection HEAD:refs/heads/feat/projection
expect_deny 'legacy export role -> export' git push export HEAD:refs/heads/feat/export
expect_deny 'legacy share_export role -> share' git push share HEAD:refs/heads/feat/share
expect_deny 'unregistered remote -> unknown' git push unknown HEAD:refs/heads/feat/unknown

# The actual process boundary must reject pushurl and URL rewrite bypasses.
git remote set-url --push origin 'git@elsewhere.invalid:example/origin.git'
expect_deny 'non-GitHub origin pushurl' git push origin HEAD:refs/heads/feat/bad-host
git remote set-url --push origin 'git@github.com:example/other.git'
expect_deny 'different-repository origin pushurl' git push origin HEAD:refs/heads/feat/bad-repo
git remote set-url --push origin 'ssh://git@github.com/EXAMPLE/origin.git'
expect_allow 'equivalent GitHub SSH pushurl' git push origin HEAD:refs/heads/feat/equivalent-url
git config --add remote.origin.pushurl 'git@elsewhere.invalid:example/origin.git'
expect_deny 'unsafe second pushurl' git push origin HEAD:refs/heads/feat/second-url
git config --unset-all remote.origin.pushurl
git config --add remote.origin.url 'git@github.com:example/other.git'
expect_deny 'unsafe second fetch URL' git push origin HEAD:refs/heads/feat/second-fetch
git config --unset-all remote.origin.url
git config remote.origin.url 'git@github.com:example/origin.git'
git config url.'git@elsewhere.invalid:'.insteadOf 'git@github.com:'
expect_deny 'resolved insteadOf bypass' git push origin HEAD:refs/heads/feat/fetch-rewrite
git config --unset-all url.'git@elsewhere.invalid:'.insteadOf
git config url.'git@elsewhere.invalid:'.pushInsteadOf 'git@github.com:'
expect_deny 'resolved pushInsteadOf bypass' git push origin HEAD:refs/heads/feat/rewrite
git config remote.origin.pushurl 'git@github.com:example/origin.git'
expect_allow 'explicit same-repository pushurl takes precedence' git push origin HEAD:refs/heads/feat/explicit-url
git config --unset-all remote.origin.pushurl
git config --unset-all url.'git@elsewhere.invalid:'.pushInsteadOf

# Invoke the hook directly for destinations whose transport must never run.
hook_topic() { printf 'refs/heads/feat/test %s refs/heads/feat/test %s\n' "$(git rev-parse HEAD)" "$zero" | bash .githooks/pre-push origin "$1"; }
zero=0000000000000000000000000000000000000000
expect_deny 'unsafe actual URL' hook_topic 'https://user:secret@github.com/example/origin.git'
expect_deny 'actual destination differs from configured origin' hook_topic 'https://github.com/example/other.git'
for ref in bad-host bad-repo second-url second-fetch fetch-rewrite rewrite; do
  if git --git-dir="$APO_TEST_BARE" show-ref --verify --quiet "refs/heads/feat/$ref"; then bad "denied push created $ref"; fi
done

# The hook preserves the default-branch deletion prohibition.
expect_deny 'delete main -> origin' git push origin :refs/heads/main

# Remote HEAD is authoritative even when local origin/HEAD and an old override
# disagree. The old main is now an ordinary branch; trunk is protected instead.
git --git-dir="$APO_TEST_BARE" update-ref refs/heads/trunk "$base_tip"
git --git-dir="$APO_TEST_BARE" symbolic-ref HEAD refs/heads/trunk
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
expect_deny 'real trunk update despite stale local HEAD and override' env APO_DEFAULT_BRANCH=main git push origin HEAD:refs/heads/trunk
expect_deny 'delete real trunk default' git push origin :refs/heads/trunk
expect_allow 'old main is now a topic branch' git push origin HEAD:refs/heads/main
expect_deny 'remote HEAD query failure fails closed' env APO_TEST_UPLOAD_FAIL=1 git push origin HEAD:refs/heads/feat/unverified
if git --git-dir="$APO_TEST_BARE" show-ref --verify --quiet refs/heads/feat/unverified; then bad 'failed query changed remote'; fi
git --git-dir="$APO_TEST_BARE" symbolic-ref HEAD refs/heads/missing
expect_deny 'existing heads with missing default fail closed' env APO_INITIAL_BRANCH=main git push origin HEAD:refs/heads/feat/ambiguous
git --git-dir="$APO_TEST_BARE" symbolic-ref HEAD refs/heads/trunk

# Test unusual successful advertisements at the native hook process boundary.
# This wrapper affects only ls-remote, delegating all other Git commands.
real_git="$(command -v git)"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/git" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == ls-remote ]]; then printf '%s\n' "$APO_TEST_ADVERTISEMENT"; exit 0; fi
exec "$APO_TEST_REAL_GIT" "$@"
SH
chmod +x "$tmp/bin/git"
export APO_TEST_REAL_GIT="$real_git"
hook_default_create() { printf 'refs/heads/trunk %s refs/heads/trunk %s\n' "$(git rev-parse HEAD)" "$zero" | bash .githooks/pre-push origin git@github.com:example/origin.git; }
export APO_TEST_ADVERTISEMENT=$'ref: refs/heads/trunk\tHEAD'
expect_deny 'empty heads plus HEAD symref still requires initial declaration' env PATH="$tmp/bin:$PATH" bash -c 'printf "refs/heads/main %s refs/heads/main %s\n" "$(git rev-parse HEAD)" 0000000000000000000000000000000000000000 | bash .githooks/pre-push origin git@github.com:example/origin.git'
export APO_TEST_ADVERTISEMENT=$'ref: refs/heads/trunk\tHEAD\n'"$base_tip"$'\trefs/heads/trunk'
saved_path="$PATH"; export PATH="$tmp/bin:$PATH"
expect_deny 'noninitial default creation is forbidden' hook_default_create
export PATH="$saved_path"

# A fresh clone receives the tracked hook but not local hooksPath configuration.
cd "${tmp}"
git clone -q work clone-check
if git -C clone-check config --get core.hooksPath >/dev/null 2>&1; then
  bad 'fresh clone hooksPath initially unset'
else
  ok 'fresh clone hooksPath initially unset'
fi
expect_allow 'fresh clone explicit hook install' bash -lc "cd '${tmp}/clone-check' && bash .agent-project-ops/scripts/install-hooks.sh"
if [[ "$(git -C clone-check config --get core.hooksPath)" == '.githooks' ]]; then
  ok 'fresh clone hooksPath restored'
else
  bad 'fresh clone hooksPath restored'
fi

printf '\nResult: %d passed, %d failed\n' "${pass}" "${fail}"
[[ "${fail}" -eq 0 ]]
