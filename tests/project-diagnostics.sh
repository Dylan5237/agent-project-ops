#!/usr/bin/env bash
set -euo pipefail
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

git init -q -b main "$tmp/project"
git init --bare -q --initial-branch=main "$tmp/remote.git"
git -C "$tmp/project" remote add origin 'https://github.com/example/project.git'
mkdir -p "$tmp/project/.agent-project-ops"
printf '# Agent instructions\n' > "$tmp/project/AGENTS.md"
printf 'url=https://github.com/example/method\nsha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n' > "$tmp/project/.agent-project-ops/PIN"
printf 'authority=origin\n' > "$tmp/project/.agent-project-ops/remotes"
cp "$tmp/project/.agent-project-ops/remotes" "$tmp/remotes.before"

doctor="$root/skills/project-diagnostics/scripts/doctor.sh"
pin="$tmp/project/.agent-project-ops/PIN"
registry="$tmp/project/.agent-project-ops/remotes"
check_case() {
  local name="$1" expected="$2" marker="$3" result=0
  local status_before config_before
  status_before="$(git -C "$tmp/project" status --porcelain --untracked-files=all)"
  cp "$pin" "$tmp/$name.pin.before"
  cp "$registry" "$tmp/$name.remotes.before"
  cp "$tmp/project/.git/config" "$tmp/$name.config.before"
  bash "$doctor" --dir "$tmp/project" > "$tmp/$name.out" 2> "$tmp/$name.err" || result=$?
  [[ "$result" -eq "$expected" ]] || fail "$name exit $result (expected $expected)"
  grep -Fq "$marker" "$tmp/$name.out" || fail "$name missing $marker"
  [[ "$(git -C "$tmp/project" status --porcelain --untracked-files=all)" == "$status_before" ]] || fail "$name changed Git status"
  cmp -s "$tmp/$name.pin.before" "$pin" || fail "$name changed PIN bytes"
  cmp -s "$tmp/$name.remotes.before" "$registry" || fail "$name changed remotes bytes"
  cmp -s "$tmp/$name.config.before" "$tmp/project/.git/config" || fail "$name changed Git config"
}
valid_sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
printf 'url=https://github.com/example/method\r\nsha=%s\r\n' "$valid_sha" > "$pin"
printf 'authority=origin\r\n' > "$registry"
check_case crlf-valid 0 PIN_FORMAT_OK
grep -Fq 'AUTHORITY_ORIGIN' "$tmp/crlf-valid.out" || fail 'CRLF authority rejected'
grep -Fq 'ORIGIN_ONLY' "$tmp/crlf-valid.out" || fail 'CRLF origin-only rejected'
printf 'url=https://github.com/example/method\nsha=%s\n' "$valid_sha" > "$pin"
printf 'authority=origin\n' > "$registry"
check_case lf-valid 0 PIN_FORMAT_OK
grep -Fq 'AUTHORITY_ORIGIN' "$tmp/lf-valid.out" || fail 'LF authority rejected'
grep -Fq 'ORIGIN_ONLY' "$tmp/lf-valid.out" || fail 'LF origin-only rejected'

printf 'url=https://github.com/example/method\nsha=bad\n' > "$pin"
check_case invalid-sha 1 PIN_INVALID
printf 'url=https://github.com/example/method\nsha=%s\n' "$valid_sha" > "$pin"
printf 'authority=other\n' > "$registry"
check_case invalid-authority 1 AUTHORITY_INVALID
printf 'authority=origin\n' > "$registry"
printf 'url=https://github.com/example/method\nsha=%s\r\r\n' "$valid_sha" > "$pin"
check_case double-cr-sha 1 PIN_INVALID
printf 'url=https://github.com/example/method\nsha=%s\rmore\n' "$valid_sha" > "$pin"
check_case embedded-cr-sha 1 PIN_INVALID
printf 'url=https://github.com/example/method\nsha=%s\n' "$valid_sha" > "$pin"
printf 'authority=origin\r\r\n' > "$registry"
check_case double-cr-authority 1 AUTHORITY_INVALID
printf 'authority=ori\rgin\n' > "$registry"
check_case embedded-cr-authority 1 AUTHORITY_INVALID
printf 'authority=origin-extra\n' > "$registry"
check_case extra-authority 1 AUTHORITY_INVALID
printf 'authority=origin\n' > "$registry"
printf 'url=https://private.example/sentinel-secret\r\r\nsha=%s\n' "$valid_sha" > "$pin"
check_case double-cr-url 1 PIN_INVALID
if grep -Fq 'sentinel-secret' "$tmp/double-cr-url.out" "$tmp/double-cr-url.err"; then fail 'private PIN URL leaked'; fi
printf 'url=https://private.example/sentinel-secret\rmore\nsha=%s\n' "$valid_sha" > "$pin"
check_case embedded-cr-url 1 PIN_INVALID
if grep -Fq 'sentinel-secret' "$tmp/embedded-cr-url.out" "$tmp/embedded-cr-url.err"; then fail 'private PIN URL leaked'; fi
printf 'url=https://private.example/sentinel-secret\nsha=%s\n' "$valid_sha" > "$pin"
printf 'authority=origin\n' > "$registry"
printf 'authority=origin\nprojection=\nexport=(none)\n' > "$registry"
check_case empty-legacy-roles 0 ORIGIN_ONLY
printf 'authority=origin\n' > "$registry"
before="$(git -C "$tmp/project" status --porcelain --untracked-files=all)"
bash "$doctor" --dir "$tmp/project" > "$tmp/one"
bash "$doctor" --dir "$tmp/project" > "$tmp/two"
cmp -s "$tmp/one" "$tmp/two" || fail "non-repeatable result"
[[ "$(git -C "$tmp/project" status --porcelain --untracked-files=all)" == "$before" ]] || fail "doctor modified files"
grep -Fq 'PASS' "$tmp/one" || fail "no success"
grep -Fq 'PIN_FORMAT_OK' "$tmp/one" || fail "pin not checked"
grep -Fq 'HOOK_INACTIVE' "$tmp/one" || fail "missing local hook not flagged"
grep -Fq 'SERVER_PROTECTION_NOT_CHECKED' "$tmp/one" || fail "unknown protection not reported"
grep -Fq 'ORIGIN_ONLY' "$tmp/one" || fail "origin-only authority not reported"
grep -Fq 'UNKNOWN' "$tmp/one" || fail "unverifiable checks lost UNKNOWN state"

git -C "$tmp/project" remote add unknown "$tmp/remote.git"
if bash "$doctor" --dir "$tmp/project" > "$tmp/unregistered"; then fail "unregistered remote accepted"; fi
grep -Fq 'EXTRA_REMOTE_UNSUPPORTED' "$tmp/unregistered" || fail "missing extra-remote reason"
git -C "$tmp/project" remote remove unknown

printf 'authority=origin\nprojection=projection\n' > "$tmp/project/.agent-project-ops/remotes"
cp "$tmp/project/.agent-project-ops/remotes" "$tmp/active-role.before"
if bash "$doctor" --dir "$tmp/project" > "$tmp/active-role"; then fail "active legacy role accepted"; fi
grep -Fq 'REMOTE_ROLE_UNSUPPORTED' "$tmp/active-role" || fail "missing active legacy role reason"
cmp -s "$tmp/active-role.before" "$tmp/project/.agent-project-ops/remotes" || fail "doctor changed legacy role registry"
cp "$tmp/remotes.before" "$tmp/project/.agent-project-ops/remotes"

git -C "$tmp/project" remote remove origin
if bash "$doctor" --dir "$tmp/project" > "$tmp/no-origin"; then fail "missing origin accepted"; fi
grep -Fq 'AUTHORITY_INVALID' "$tmp/no-origin" || fail "missing authority reason"
if grep -Fq 'ORIGIN_ONLY' "$tmp/no-origin"; then fail "missing origin reported as configured"; fi
git -C "$tmp/project" remote add origin 'https://github.com/example/project.git'

for url in 'git@elsewhere.invalid:example/project.git' 'git@github.com:example/other.git' \
  'https://user:secret@github.com/example/project.git' \
  $'https://github.com/example/project\nhttps://github.com/example/project' \
  $'https://github.com/example/project\n'; do
  git -C "$tmp/project" config remote.origin.pushurl "$url"
  cp "$tmp/project/.git/config" "$tmp/config.before"
  if bash "$doctor" --dir "$tmp/project" > "$tmp/bad-url"; then fail "unsafe/mismatched pushurl accepted"; fi
  grep -Fq 'ORIGIN_URL_INVALID' "$tmp/bad-url" || fail "pushurl reason missing"
  if grep -Fq 'ORIGIN_ONLY' "$tmp/bad-url"; then fail "unsafe origin reported valid"; fi
  if grep -Fq 'secret' "$tmp/bad-url"; then fail "unsafe URL leaked"; fi
  cmp -s "$tmp/config.before" "$tmp/project/.git/config" || fail "doctor changed Git config"
done
git -C "$tmp/project" config remote.origin.pushurl 'git@github.com:EXAMPLE/project.git'
bash "$doctor" --dir "$tmp/project" > "$tmp/equivalent-url"
grep -Fq 'ORIGIN_ONLY' "$tmp/equivalent-url" || fail "equivalent SSH identity rejected"
git -C "$tmp/project" config --add remote.origin.pushurl 'git@github.com:example/other.git'
if bash "$doctor" --dir "$tmp/project" > "$tmp/multiple-urls"; then fail "second pushurl accepted"; fi
git -C "$tmp/project" config --unset-all remote.origin.pushurl
git -C "$tmp/project" config url.'git@elsewhere.invalid:'.pushInsteadOf 'https://github.com/'
if bash "$doctor" --dir "$tmp/project" > "$tmp/rewritten-url"; then fail "pushInsteadOf accepted"; fi
git -C "$tmp/project" config --unset-all url.'git@elsewhere.invalid:'.pushInsteadOf

printf 'url=https://github.com/example/method\nsha=unknown\n' > "$tmp/project/.agent-project-ops/PIN"
if bash "$doctor" --dir "$tmp/project" > "$tmp/invalid"; then fail "invalid PIN accepted"; fi
grep -Fq 'PIN_INVALID' "$tmp/invalid" || fail "invalid PIN not flagged"

rm "$tmp/project/.agent-project-ops/PIN"
if bash "$doctor" --dir "$tmp/project" > "$tmp/missing"; then fail "missing PIN accepted"; fi
grep -Fq 'PIN_MISSING' "$tmp/missing" || fail "missing PIN not reported"
echo 'PASS: doctor is read-only, preserves UNKNOWN, and rejects extra remotes and active legacy roles'
