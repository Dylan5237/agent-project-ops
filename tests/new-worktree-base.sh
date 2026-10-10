#!/usr/bin/env bash
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
git init -q --bare "$tmp/origin.git"
git init -q -b main "$tmp/seed"
git -C "$tmp/seed" config user.name Test
git -C "$tmp/seed" config user.email test@example.invalid
printf 'test\n' > "$tmp/seed/README.md"
git -C "$tmp/seed" add README.md
git -C "$tmp/seed" commit -qm seed
git -C "$tmp/seed" remote add origin "$tmp/origin.git"
git -C "$tmp/seed" push -q -u origin main
git -C "$tmp/seed" checkout -qb develop
git -C "$tmp/seed" push -q -u origin develop
git --git-dir="$tmp/origin.git" symbolic-ref HEAD refs/heads/main
git clone -q "$tmp/origin.git" "$tmp/work"
mkdir -p "$tmp/work/.agent-project-ops"
printf 'authority=origin\nprojection=(none)\n' > "$tmp/work/.agent-project-ops/remotes"
cd "$tmp/work"
git remote set-head origin -a >/dev/null
bash "$src/scripts/new-worktree.sh" 11 agent one >/dev/null
[[ "$(git -C .worktrees/11-agent-one branch --show-current)" == feat/11-one ]] || fail "default base branch creation"
base="$(git rev-parse refs/remotes/origin/main)"
[[ "$(git -C .worktrees/11-agent-one rev-parse HEAD)" == "$base" ]] || fail "default base must be origin/main"
bash "$src/scripts/new-worktree.sh" 12 agent two fix --base-ref origin/develop >/dev/null
[[ "$(git -C .worktrees/12-agent-two rev-parse HEAD)" == "$(git rev-parse origin/develop)" ]] || fail "explicit develop base"
if bash "$src/scripts/new-worktree.sh" 13 agent missing --base-ref origin/unknown >/dev/null 2>&1; then fail "unknown base accepted"; fi
if bash "$src/scripts/new-worktree.sh" 14 agent unsafe --base-ref upstream/main >/dev/null 2>&1; then fail "unregistered remote accepted"; fi
if bash "$src/scripts/new-worktree.sh" 12 agent two fix --base-ref origin/develop >/dev/null 2>&1; then fail "existing worktree overwritten"; fi
git symbolic-ref -d refs/remotes/origin/HEAD
if bash "$src/scripts/new-worktree.sh" 15 agent ambiguous >/dev/null 2>&1; then fail "missing default should fail closed"; fi
echo "PASS: task base default/explicit/invalid/repeated/ambiguous"
