#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

git init -q -b main "$tmp/project"
git init --bare -q --initial-branch=main "$tmp/remote.git"
git -C "$tmp/project" remote add origin "$tmp/remote.git"
mkdir -p "$tmp/project/.agent-project-ops"
printf '# Agent instructions\n' > "$tmp/project/AGENTS.md"
printf 'url=https://github.com/example/method\nsha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n' > "$tmp/project/.agent-project-ops/PIN"
printf 'authority=origin\nprojection=(none)\nexport=(none)\nshare_export=(none)\n' > "$tmp/project/.agent-project-ops/remotes"

doctor="$root/skills/project-diagnostics/scripts/doctor.sh"
before="$(git -C "$tmp/project" status --porcelain --untracked-files=all)"
bash "$doctor" --dir "$tmp/project" > "$tmp/one"
bash "$doctor" --dir "$tmp/project" > "$tmp/two"
cmp -s "$tmp/one" "$tmp/two" || fail "non-repeatable result"
[[ "$(git -C "$tmp/project" status --porcelain --untracked-files=all)" == "$before" ]] || fail "doctor modified files"
grep -Fq 'PASS' "$tmp/one" || fail "no success"
grep -Fq 'PIN_FORMAT_OK' "$tmp/one" || fail "pin not checked"
grep -Fq 'HOOK_INACTIVE' "$tmp/one" || fail "missing local hook not flagged"
grep -Fq 'SERVER_PROTECTION_NOT_CHECKED' "$tmp/one" || fail "unknown protection not reported"

git -C "$tmp/project" remote add unknown "$tmp/remote.git"
if bash "$doctor" --dir "$tmp/project" > "$tmp/unregistered"; then fail "unregistered remote accepted"; fi
grep -Fq 'REMOTE_UNCLASSIFIED' "$tmp/unregistered" || fail "missing remote reason"
git -C "$tmp/project" remote remove unknown

printf 'url=https://github.com/example/method\nsha=unknown\n' > "$tmp/project/.agent-project-ops/PIN"
if bash "$doctor" --dir "$tmp/project" > "$tmp/invalid"; then fail "invalid PIN accepted"; fi
grep -Fq 'PIN_INVALID' "$tmp/invalid" || fail "invalid PIN not flagged"

rm "$tmp/project/.agent-project-ops/PIN"
if bash "$doctor" --dir "$tmp/project" > "$tmp/missing"; then fail "missing PIN accepted"; fi
grep -Fq 'PIN_MISSING' "$tmp/missing" || fail "missing PIN not reported"
echo 'PASS: doctor reads without mutating, separates PASS/WARN/UNKNOWN and rejects invalid state'
