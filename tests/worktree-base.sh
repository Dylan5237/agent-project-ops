#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

git init --bare -q --initial-branch=main "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/seed" 2>/dev/null
git -C "$tmp/seed" config user.name tester
git -C "$tmp/seed" config user.email tester@local.invalid
git -C "$tmp/seed" commit -q --allow-empty -m seed
git -C "$tmp/seed" push -q origin main
git -C "$tmp/seed" checkout -qb develop
git -C "$tmp/seed" commit -q --allow-empty -m develop
git -C "$tmp/seed" push -q origin develop
git clone -q "$tmp/origin.git" "$tmp/project"

(
  cd "$tmp/project"
  bash "$root/scripts/new-worktree.sh" 101 agent first feat > "$tmp/default"
  main_sha="$(git rev-parse refs/remotes/origin/main)"
  [[ "$(git -C .worktrees/101-agent-first rev-parse HEAD)" == "$main_sha" ]] || fail "default origin HEAD base"

  bash "$root/scripts/new-worktree.sh" 102 agent second fix --base origin/develop --save-base > "$tmp/explicit"
  develop_sha="$(git rev-parse refs/remotes/origin/develop)"
  [[ "$(git -C .worktrees/102-agent-second rev-parse HEAD)" == "$develop_sha" ]] || fail "explicit origin/develop base"
  grep -Fxq 'task_base=origin/develop' .worktrees/102-agent-second/.agent-project-ops/project-config || fail "missing saved config"
  [[ ! -e .agent-project-ops/project-config ]] || fail "primary checkout changed"

  if bash "$root/scripts/new-worktree.sh" 103 agent third feat --base origin/missing > "$tmp/missing" 2>&1; then fail "missing ref accepted"; fi
  [[ ! -e .worktrees/103-agent-third ]] || fail "created from missing ref"

  mkdir -p .agent-project-ops
  printf 'task_base=origin/develop\n' > .agent-project-ops/project-config
  bash "$root/scripts/new-worktree.sh" 104 agent fourth docs > "$tmp/configured"
  [[ "$(git -C .worktrees/104-agent-fourth rev-parse HEAD)" == "$develop_sha" ]] || fail "project default not honored"

  bash "$root/scripts/new-worktree.sh" 108 agent override feat --base origin/main > "$tmp/override"
  [[ "$(git -C .worktrees/108-agent-override rev-parse HEAD)" == "$main_sha" ]] || fail "explicit override did not outrank project base"

  if bash "$root/scripts/new-worktree.sh" 105 ../evil fifth feat > "$tmp/traversal" 2>&1; then fail "unsafe slot accepted"; fi
  if bash "$root/scripts/new-worktree.sh" 106 agent sixth feat --base projection/main > "$tmp/foreign" 2>&1; then fail "non-origin base accepted"; fi

  rm .agent-project-ops/project-config
  git remote set-head origin develop
  if bash "$root/scripts/new-worktree.sh" 107 agent seventh feat > "$tmp/stale" 2>&1; then fail "stale origin/HEAD accepted"; fi
  [[ ! -e .worktrees/107-agent-seventh ]] || fail "created despite HEAD conflict"
)

# A non-main default branch must work without a hard-coded origin/main.
git init --bare -q --initial-branch=master "$tmp/master-origin.git"
git clone -q "$tmp/master-origin.git" "$tmp/master-seed" 2>/dev/null
git -C "$tmp/master-seed" config user.name tester
git -C "$tmp/master-seed" config user.email tester@local.invalid
git -C "$tmp/master-seed" commit -q --allow-empty -m masterseed
git -C "$tmp/master-seed" push -q origin master
git clone -q "$tmp/master-origin.git" "$tmp/master-project"
(
  cd "$tmp/master-project"
  bash "$root/scripts/new-worktree.sh" 201 agent master-task fix > "$tmp/master.log"
  [[ "$(git -C .worktrees/201-agent-master-task rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/master)" ]] || fail "master default ignored"
)
# Separate negative fixture: remote HEAD is UNVERIFIABLE although origin has
# multiple fetchable branches. This is not the local-vs-remote HEAD conflict
# exercised above; both local and remote default pointers are unavailable.
git clone -q "$tmp/origin.git" "$tmp/ambiguous-project"
git -C "$tmp/ambiguous-project" symbolic-ref --delete refs/remotes/origin/HEAD
git --git-dir="$tmp/origin.git" symbolic-ref HEAD refs/heads/default-not-present
(
  cd "$tmp/ambiguous-project"
  [[ -z "$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)" ]] || fail "fixture unexpectedly retained local origin/HEAD"
  [[ -z "$(git ls-remote --symref origin HEAD)" ]] || fail "fixture unexpectedly advertises a valid remote HEAD"
  git fetch -q origin || fail "fixture origin cannot fetch available branches"
  candidates="$(git for-each-ref --format='%(refname:short)' refs/remotes/origin)"
  [[ "$(printf '%s\\n' "$candidates" | grep -c '^origin/' || true)" -ge 2 ]] || fail "fixture needs at least two origin branch candidates"
  printf '%s\\n' "$candidates" | grep -Fxq 'origin/main' || fail "fixture missing origin/main"
  printf '%s\\n' "$candidates" | grep -Fxq 'origin/develop' || fail "fixture missing origin/develop"

  if bash "$root/scripts/new-worktree.sh" 301 agent unresolved feat > "$tmp/ambiguous.log" 2>&1; then
    fail "unverifiable remote HEAD with multiple branches was accepted"
  fi
  grep -Fq 'new-worktree: available origin refs:' "$tmp/ambiguous.log" || fail "available refs were not reported"
  grep -Fq 'origin/main' "$tmp/ambiguous.log" || fail "output omitted main candidate"
  grep -Fq 'origin/develop' "$tmp/ambiguous.log" || fail "output omitted develop candidate"
  grep -Fq 'pass --base origin/BRANCH' "$tmp/ambiguous.log" || fail "output omitted explicit selection instruction"
  [[ ! -e .worktrees/301-agent-unresolved ]] || fail "worktree created with unverifiable remote HEAD"
  if git show-ref --verify --quiet refs/heads/feat/301-unresolved; then fail "branch created with unverifiable remote HEAD"; fi
)

echo 'PASS: main/master defaults, develop/explicit choices, invalid refs and unsafe paths; missing remote HEAD with multiple candidates fails closed'
