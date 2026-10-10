#!/usr/bin/env bash
# Isolate a task in a worktree from a verified origin ref, not an assumed origin/main.
# Usage: new-worktree.sh <issue> <owner> <slug> [feat|fix|docs|evidence] [--base origin/BRANCH] [--save-base]
set -euo pipefail

usage() { echo "usage: $0 <issue> <owner> <slug> [feat|fix|docs|evidence] [--base origin/BRANCH] [--save-base]"; }
die() { printf 'new-worktree: error: %s\n' "$*" >&2; exit 2; }

if [[ $# -lt 3 ]]; then usage >&2; exit 2; fi
issue="$1"
owner="$2"
slug="$3"
shift 3
for token in "$issue" "$owner" "$slug"; do
  [[ "$token" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && "$token" != *..* ]] || die "unsafe issue/owner/slug: $token"
done
kind="feat"
if [[ $# -gt 0 && "$1" != --* ]]; then kind="$1"; shift; fi
case "$kind" in feat|fix|docs|evidence) ;; *) die "invalid kind: $kind" ;; esac

explicit_base=""
save_base=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      [[ $# -ge 2 && -n "$2" ]] || die "--base requires origin/BRANCH"
      [[ -z "$explicit_base" ]] || die "--base specified twice"
      explicit_base="$2"; shift 2 ;;
    --save-base) save_base=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run inside a git repository"
git -C "$root" remote get-url origin >/dev/null 2>&1 || die "GitHub authority remote origin is missing"
branch="$kind/$issue-$slug"
git check-ref-format --branch "$branch" >/dev/null 2>&1 || die "invalid branch: $branch"
path="$root/.worktrees/$issue-$owner-$slug"
[[ ! -e "$path" ]] || die "worktree slot already exists: $path"
git -C "$root" fetch --quiet origin || die "cannot fetch origin; no worktree created"

project_base=""
seen_base=0
config="$root/.agent-project-ops/project-config"
if [[ -f "$config" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      ''|\#*) ;;
      task_base=*)
        [[ "$seen_base" -eq 0 ]] || die "duplicate task_base in $config"
        seen_base=1
        project_base="$(printf '%s\n' "$line" | sed 's/^task_base=//')" ;;
      *) die "unknown project-config entry (not executed): $line" ;;
    esac
  done < "$config"
fi

base=""
source_name=""
if [[ -n "$explicit_base" ]]; then
  base="$explicit_base"; source_name="explicit --base"
elif [[ -n "$project_base" ]]; then
  base="$project_base"; source_name="project-config"
else
  remote_head="$(git -C "$root" ls-remote --symref origin HEAD 2>/dev/null | awk '$1=="ref:" && $3=="HEAD" {print $2; exit}' || true)"
  local_head="$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ "$remote_head" == refs/heads/* ]]; then
    base="$(printf '%s\n' "$remote_head" | sed 's#^refs/heads/#origin/#')"
    source_name="verified remote HEAD"
    if [[ -n "$local_head" && "$local_head" != "$base" ]]; then
      die "local origin/HEAD ($local_head) conflicts with verified remote default ($base); review and pass --base"
    fi
  else
    candidates="$(git -C "$root" for-each-ref --format='%(refname:short)' refs/remotes/origin | grep -v '^origin/HEAD$' || true)"
    count="$(printf '%s\n' "$candidates" | grep -c . || true)"
    if [[ "$count" -eq 1 ]]; then
      base="$candidates"; source_name="only origin branch"
    else
      printf 'new-worktree: available origin refs:\n%s\n' "$candidates" >&2
      die "task base is ambiguous; ask user with the host choice tool or pass --base origin/BRANCH"
    fi
  fi
fi

[[ "$base" == origin/* && "$base" != origin/HEAD ]] || die "task base must be origin/BRANCH, got: $base"
git check-ref-format "refs/remotes/$base" >/dev/null 2>&1 || die "invalid origin ref: $base"
git -C "$root" show-ref --verify --quiet "refs/remotes/$base" || die "origin ref not found after fetch: $base"
git -C "$root" rev-parse --verify --quiet "refs/remotes/$base^{commit}" >/dev/null || die "origin ref is not a commit: $base"

mkdir -p "$root/.worktrees"
if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
  [[ -z "$explicit_base" && "$save_base" -eq 0 ]] || die "branch exists; cannot change its base with --base/--save-base"
  git -C "$root" worktree add "$path" "$branch"
else
  git -C "$root" worktree add -b "$branch" "$path" "refs/remotes/$base"
fi

if [[ "$save_base" -eq 1 ]]; then
  mkdir -p "$path/.agent-project-ops"
  printf 'task_base=%s\n' "$base" > "$path/.agent-project-ops/project-config"
  echo "project default created on task branch; include project-config in the reviewed PR"
fi

echo "worktree: $path"
echo "branch:   $branch"
echo "base:     $base ($source_name)"
echo "next:     cd \"$path\" && git push -u origin HEAD"
