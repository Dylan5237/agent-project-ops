#!/usr/bin/env bash
# Create an isolated worktree from an explicitly selected or verified authority base.
# Usage: new-worktree.sh <issue> <owner> <slug> [feat|fix|docs|evidence] [--base-ref origin/BRANCH]
set -euo pipefail

usage() {
  echo "usage: $0 <issue> <owner> <slug> [feat|fix|docs|evidence] [--base-ref origin/BRANCH]" >&2
}

[[ $# -ge 3 ]] || { usage; exit 2; }
issue="$1"
owner="$2"
slug="$3"
shift 3
kind="feat"
base_ref=""
if [[ $# -gt 0 && "$1" != "--base-ref" ]]; then
  kind="$1"
  shift
fi
case "$kind" in feat|fix|docs|evidence) ;; *) usage; exit 2 ;; esac
if [[ $# -gt 0 ]]; then
  [[ $# -eq 2 && "$1" == "--base-ref" && -n "$2" ]] || { usage; exit 2; }
  base_ref="$2"
fi

[[ "$issue" =~ ^[A-Za-z0-9._-]+$ && "$owner" =~ ^[A-Za-z0-9._-]+$ && "$slug" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "issue, owner and slug must contain only letters, digits, dot, underscore or hyphen" >&2; exit 2;
}

git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "run inside a git repository" >&2; exit 1; }
root="$(git rev-parse --show-toplevel)"
registry="${root}/.agent-project-ops/remotes"
[[ -f "$registry" ]] || { echo "APO remote registry missing; classify authority first" >&2; exit 1; }
authority="$(sed -n 's/^authority=//p' "$registry" | head -1)"
[[ "$authority" == origin ]] || { echo "authority must be the registered origin remote" >&2; exit 1; }

# Never use an unverified local HEAD as the source of truth.
git fetch origin || { echo "cannot refresh origin; refusing to infer a stale task base" >&2; exit 1; }
if [[ -z "$base_ref" ]]; then
  base_ref="$(git symbolic-ref -q --short refs/remotes/origin/HEAD || true)"
  [[ -n "$base_ref" ]] || {
    echo "ambiguous task base: origin/HEAD is unavailable; use --base-ref origin/BRANCH after confirming the project/task choice" >&2
    exit 2
  }
fi
[[ "$base_ref" == origin/* && "$base_ref" != origin/HEAD ]] || {
  echo "base must be an explicit origin/BRANCH ref, not another remote or symbolic HEAD" >&2; exit 2;
}
base_branch="${base_ref#origin/}"
git check-ref-format --branch "$base_branch" >/dev/null 2>&1 || {
  echo "invalid base branch: $base_ref" >&2; exit 2;
}
git show-ref --verify --quiet "refs/remotes/${base_ref}" || {
  echo "base not found after fetch: $base_ref" >&2; exit 1;
}
slot="${issue}-${owner}-${slug}"
path="${root}/.worktrees/${slot}"
name="${kind}/${issue}-${slug}"
[[ ! -e "$path" ]] || { echo "worktree exists: $path" >&2; exit 1; }
[[ -z "$(git branch --list --format='%(refname:short)' "$name")" ]] || {
  echo "branch already exists: $name; inspect existing work before retrying" >&2; exit 1;
}
mkdir -p "${root}/.worktrees"
git worktree add -b "$name" "$path" "$base_ref"
echo "worktree: $path"
echo "branch:   $name"
echo "base:     $base_ref"
echo "next:     cd \"$path\" && git push -u origin HEAD"
