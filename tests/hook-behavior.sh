#!/usr/bin/env bash
set -euo pipefail

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
  if "$@" >/dev/null 2>&1; then bad "$name (expected DENY)"; else ok "$name"; fi
}

mkdir -p "${tmp}/remotes"
for remote in origin projection export share unknown; do
  git init --bare -q --initial-branch=main "${tmp}/remotes/${remote}.git"
done

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
  git remote add "$remote" "${tmp}/remotes/${remote}.git"
done

# Bootstrap may create the authority default branch once. The same commit must
# then be fetched before checking the direct-update rule.
expect_allow 'initial main -> origin' git push -u origin main
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

# The URL guard still rejects credentials/query tokens before contacting the remote.
git remote set-url origin 'https://github.com/example/repo.git?token=secret'
expect_deny 'unsafe origin URL' git push origin HEAD:refs/heads/feat/unsafe-url
git remote set-url origin "${tmp}/remotes/origin.git"

# The hook preserves the default-branch deletion prohibition.
expect_deny 'delete main -> origin' git push origin :refs/heads/main

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
