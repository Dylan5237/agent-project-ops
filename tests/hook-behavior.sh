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
  if "$@" >/dev/null 2>&1; then ok "${name}"; else bad "${name} (expected ALLOW)"; fi
}

expect_deny() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then bad "${name} (expected DENY)"; else ok "${name}"; fi
}

mkdir -p "${tmp}/remotes"
for r in origin projection projection-bad unknown; do
  git init --bare -q "${tmp}/remotes/${r}.git"
done

git init -q -b main "${tmp}/work"
cd "${tmp}/work"
git config user.name apo-test
git config user.email apo-test@example.invalid
printf 'base\n' > tracked.txt
git add tracked.txt
git commit -q -m base

mkdir -p .githooks .agent-project-ops/scripts/lib .agent-project-ops/scripts
cp "${repo_root}/scripts/hooks/pre-push-authority.sh" .githooks/pre-push
cp "${repo_root}/scripts/lib/url-guard.sh" .agent-project-ops/scripts/lib/url-guard.sh
cp "${repo_root}/scripts/install-hooks.sh" .agent-project-ops/scripts/install-hooks.sh
chmod +x .githooks/pre-push .agent-project-ops/scripts/install-hooks.sh
cat > .agent-project-ops/remotes <<'EOF'
authority=origin
projection=projection,projection-bad
EOF

git add .githooks .agent-project-ops
git commit -q -m 'test binding'
git config core.hooksPath .githooks

git remote add origin "${tmp}/remotes/origin.git"
git remote add projection "${tmp}/remotes/projection.git"
git remote add projection-bad "${tmp}/remotes/projection-bad.git"
git remote add gitlab "${tmp}/remotes/unknown.git"

# 1. Bootstrap may publish authority main once.
expect_allow 'first main -> authority' git push -u origin main
git fetch -q origin main
base_tip="$(git rev-parse refs/remotes/origin/main)"

# 2. Later direct authority main update must fail.
printf 'direct\n' >> tracked.txt
git commit -qam direct-main
expect_deny 'update main -> authority' git push origin main
git reset -q --hard "${base_tip}"

# 3. Topic branches may go to authority.
git checkout -q -b feat/test "${base_tip}"
printf 'topic\n' >> tracked.txt
git commit -qam topic
expect_allow 'topic -> authority' git push -u origin HEAD:refs/heads/feat/test

# 4. Topic branches may not go to projection.
expect_deny 'topic -> projection' git push projection HEAD:refs/heads/feat/test

# 5-6. Unknown remotes fail closed for both topic and first main.
expect_deny 'topic -> unregistered remote' git push gitlab HEAD:refs/heads/feat/test
expect_deny 'first main -> unregistered remote' git push gitlab "${base_tip}":refs/heads/main

# 7. Default-branch deletion is denied.
expect_deny 'delete main -> authority' git push origin :refs/heads/main

# 8. First projection seed is allowed only when it equals current authority tip.
git checkout -q main
git reset -q --hard "${base_tip}"
expect_allow 'projection seed == authority tip' git push projection HEAD:refs/heads/main

# Create a commit that is not authority tip and try it as the first seed of a
# second registered projection.
printf 'diverge\n' >> tracked.txt
git commit -qam divergent-seed
expect_deny 'projection seed != authority tip' git push projection-bad HEAD:refs/heads/main
git reset -q --hard "${base_tip}"

# 9. Make projection diverge out-of-band, then confirm the hook rejects the
# authority tip because the update would not be fast-forward. First transfer
# the object to the bare repo under a temporary ref while deliberately bypassing
# the hook as test-fixture setup; then move projection/main to that object.
git checkout -q -b projection-only "${base_tip}"
printf 'projection-only\n' >> tracked.txt
git commit -qam projection-only
projection_only="$(git rev-parse HEAD)"
git push --no-verify -q projection HEAD:refs/heads/test-fixture-object
git --git-dir="${tmp}/remotes/projection.git" update-ref refs/heads/main "${projection_only}"
git --git-dir="${tmp}/remotes/projection.git" update-ref -d refs/heads/test-fixture-object
git checkout -q main
git reset -q --hard "${base_tip}"
expect_deny 'non-fast-forward projection update' git push projection HEAD:refs/heads/main

# 10. Fresh clone receives the hook file but not core.hooksPath; explicit
# installation must restore the local setting.
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
