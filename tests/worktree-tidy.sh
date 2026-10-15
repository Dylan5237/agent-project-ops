#!/usr/bin/env bash
# Contract: finished task folders/branches are retired automatically; unfinished work never is.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester@local.invalid
export GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester@local.invalid
new="$root/scripts/new-worktree.sh"
tidy="$root/scripts/tidy-worktrees.sh"

# Fake GitHub CLI. PR facts for a head branch live in $FAKE_GH/<branch with / replaced by _>.
mkdir -p "$tmp/bin" "$tmp/gh"
cat > "$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
if [[ "${FAKE_GH_OFFLINE:-0}" == 1 ]]; then exit 1; fi
case "$1 $2" in
  "repo view") exit 0 ;;
  "pr list")
    head=""
    while [[ $# -gt 0 ]]; do if [[ "$1" == --head ]]; then head="$2"; fi; shift; done
    f="$FAKE_GH/$(printf '%s' "$head" | tr '/' '_')"
    if [[ -f "$f" ]]; then cat "$f"; fi
    exit 0 ;;
esac
exit 1
GH
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" FAKE_GH="$tmp/gh"
pr() { printf '%s %s %s\n' "$2" "$3" "$4" >> "$FAKE_GH/$(printf '%s' "$1" | tr '/' '_')"; }  # branch number state head

# fixture NAME [project-config lines]: bare origin + maintainer clone + project clone whose
# origin looks like github.com/apo-test/NAME but fetches/pushes the local bare repository.
fixture() {
  local name="$1"; shift
  git init --bare -q --initial-branch=main "$tmp/$name.git"
  git clone -q "$tmp/$name.git" "$tmp/$name-maint" 2>/dev/null
  if [[ $# -gt 0 ]]; then
    mkdir -p "$tmp/$name-maint/.agent-project-ops"
    printf '%s\n' "$@" > "$tmp/$name-maint/.agent-project-ops/project-config"
    git -C "$tmp/$name-maint" add -A
  fi
  git -C "$tmp/$name-maint" commit -q --allow-empty -m seed
  git -C "$tmp/$name-maint" push -q origin main
  git clone -q "$tmp/$name.git" "$tmp/$name"
  git -C "$tmp/$name" config "url.$tmp/$name.git.insteadOf" "https://github.com/apo-test/$name.git"
  git -C "$tmp/$name" remote set-url origin "https://github.com/apo-test/$name.git"
}
commit_in() { printf '%s\n' "$2" > "$1/$(printf '%s' "$2" | tr ' /' '__').txt"; git -C "$1" add -A; git -C "$1" commit -q -m "$2"; }
maint_merge() { # fixture branch [squash]
  local m="$tmp/$1-maint"
  git -C "$m" fetch -q origin
  git -C "$m" checkout -q main
  git -C "$m" merge -q --ff-only origin/main
  if [[ "${3:-}" == squash ]]; then
    git -C "$m" merge -q --squash "origin/$2" >/dev/null 2>&1
    git -C "$m" commit -q -m "squash $2"
  else
    git -C "$m" merge -q --no-ff -m "merge $2" "origin/$2"
  fi
  git -C "$m" push -q origin main
}
origin_deletes() { git -C "$tmp/$1-maint" push -q origin --delete "$2"; }
has_branch() { git show-ref --verify --quiet "refs/heads/$1"; }
on_origin() { [[ -n "$(git ls-remote --heads origin "$1")" ]]; }

# --- Main matrix: merged / squash / dirty / ahead / open / closed / fresh / foreign / origin-only ---
fixture m 'max_worktrees=0'
cd "$tmp/m"
for n in 1 2 3 4 5 6 7; do
  bash "$new" "$n" agent "s$n" feat --worktree > /dev/null 2>"$tmp/new-$n.err" || fail "start $n: $(cat "$tmp/new-$n.err")"
done
wt() { printf '%s' "$tmp/m/.worktrees/$1-agent-s$1"; }
for n in 1 2 3 4 5 6; do commit_in "$(wt "$n")" "work $n"; git -C "$(wt "$n")" push -q -u origin HEAD; done
t1="$(git -C "$(wt 1)" rev-parse HEAD)"; t2="$(git -C "$(wt 2)" rev-parse HEAD)"
t3="$(git -C "$(wt 3)" rev-parse HEAD)"; t4="$(git -C "$(wt 4)" rev-parse HEAD)"
t5="$(git -C "$(wt 5)" rev-parse HEAD)"; t6="$(git -C "$(wt 6)" rev-parse HEAD)"
printf 'draft\n' > "$(wt 3)/draft.txt"                    # uncommitted work after merge
commit_in "$(wt 4)" "after merge"                         # local commit newer than the merged head
git worktree add -q "$tmp/elsewhere" -b feat/8-foreign refs/remotes/origin/main
commit_in "$tmp/elsewhere" "foreign"; git -C "$tmp/elsewhere" push -q -u origin HEAD
t8="$(git -C "$tmp/elsewhere" rev-parse HEAD)"

maint_merge m feat/1-s1; origin_deletes m feat/1-s1        # GitHub deleted the head branch
maint_merge m feat/2-s2 squash                             # squash merge, head branch left behind
maint_merge m feat/3-s3
maint_merge m feat/4-s4
maint_merge m feat/8-foreign
git -C "$tmp/m-maint" checkout -q -b feat/16-remote origin/main
commit_in "$tmp/m-maint" "remote only"; git -C "$tmp/m-maint" push -q origin HEAD
r16="$(git -C "$tmp/m-maint" rev-parse HEAD)"; maint_merge m feat/16-remote
git -C "$tmp/m-maint" checkout -q -b feat/17-open origin/main
commit_in "$tmp/m-maint" "remote open"; git -C "$tmp/m-maint" push -q origin HEAD
r17="$(git -C "$tmp/m-maint" rev-parse HEAD)"
git branch -q develop "$t1"
git branch -q topic/old "$t1"

pr feat/1-s1 11 MERGED "$t1"; pr feat/2-s2 12 MERGED "$t2"; pr feat/3-s3 13 MERGED "$t3"
pr feat/4-s4 14 MERGED "$t4"; pr feat/5-s5 15 OPEN "$t5"; pr feat/6-s6 16 CLOSED "$t6"
pr feat/8-foreign 18 MERGED "$t8"; pr feat/16-remote 26 MERGED "$r16"; pr feat/17-open 27 OPEN "$r17"
pr develop 30 MERGED "$t1"; pr topic/old 31 MERGED "$t1"

bash "$tidy" > "$tmp/report.txt" || fail "report mode failed"
[[ -d "$(wt 1)" && -d "$(wt 2)" && -d "$(wt 6)" ]] && has_branch feat/1-s1 || fail "report mode changed something"
grep -Eq '^plan +remove-folder +\.worktrees/1-agent-s1 ' "$tmp/report.txt" || fail "report did not plan the merged folder"
grep -Eq '^plan +archive +feat/6-s6 -> archive/feat/6-s6-' "$tmp/report.txt" || fail "report did not plan the archive"
grep -Fq 'apo-tidy: mode=report gh=ok' "$tmp/report.txt" || fail "report summary missing"
if grep -Fq 'topic/old' "$tmp/report.txt"; then fail "non-task branch considered without --include-other"; fi
(cd "$(wt 1)" && bash "$tidy") > "$tmp/inside.txt"
grep -Eq '^keep +folder +\.worktrees/1-agent-s1 .*current directory' "$tmp/inside.txt" || fail "caller's own folder not protected"

bash "$tidy" --apply --include-other > "$tmp/apply.txt" || fail "apply failed: $(cat "$tmp/apply.txt")"
[[ ! -e "$(wt 1)" ]] && ! has_branch feat/1-s1 || fail "merged task not retired"
[[ ! -e "$(wt 2)" ]] && ! has_branch feat/2-s2 && ! on_origin feat/2-s2 || fail "squash-merged task or its origin branch not retired"
[[ -f "$(wt 3)/draft.txt" ]] || fail "folder with uncommitted changes was removed"
grep -Eq '^keep +folder +\.worktrees/3-agent-s3 .*uncommitted' "$tmp/apply.txt" || fail "uncommitted work not reported"
[[ -d "$(wt 4)" ]] && has_branch feat/4-s4 || fail "commits newer than the merged head were not protected"
grep -Fq 'newer than merged PR #14' "$tmp/apply.txt" || fail "ahead reason missing"
[[ -d "$(wt 5)" ]] || fail "open PR folder removed"
[[ ! -e "$(wt 6)" ]] && ! has_branch feat/6-s6 && ! on_origin feat/6-s6 || fail "closed PR not retired"
[[ "$(git ls-remote --tags origin "refs/tags/archive/feat/6-s6-${t6:0:7}" | cut -f1)" == "$t6" ]] || fail "closed PR was not archived on origin"
[[ -d "$(wt 7)" ]] || fail "fresh task without a PR was removed"
[[ -d "$tmp/elsewhere" ]] || fail "folder outside .worktrees/ was removed"
! on_origin feat/16-remote || fail "merged origin-only branch kept"
on_origin feat/17-open || fail "open origin-only branch deleted"
has_branch develop || fail "protected long-lived branch deleted"
! has_branch topic/old || fail "--include-other did not retire a merged non-task branch"
tail -1 "$tmp/apply.txt" | grep -Eq '^apo-tidy: mode=apply gh=ok fetch=ok .* failed=0 folders_left=4/unlimited$' \
  || fail "summary: $(tail -1 "$tmp/apply.txt")"
bash "$tidy" --apply > "$tmp/again.txt" || fail "second apply failed"
grep -Fq 'folders_removed=0 branches_deleted=0 remote_deleted=0 archived=0 ' "$tmp/again.txt" || fail "second run not a no-op: $(tail -1 "$tmp/again.txt")"

# --- Lifecycle: single task in the primary checkout, folder cap, park, abandon, resume ---
fixture l
cd "$tmp/l"
bash "$new" 10 agent ten feat > "$tmp/l10.out" 2>"$tmp/l10.err" || fail "start 10: $(cat "$tmp/l10.err")"
grep -Fxq 'mode:     here' "$tmp/l10.out" && [[ "$(git symbolic-ref --short HEAD)" == feat/10-ten && ! -e .worktrees ]] \
  || fail "single task should run in the idle primary checkout without a folder"
commit_in "$tmp/l" "ten"; git push -q -u origin HEAD; t10="$(git rev-parse HEAD)"
for n in 11 12 13; do
  bash "$new" "$n" agent "w$n" feat > /dev/null 2>"$tmp/l$n.err" || fail "start $n: $(cat "$tmp/l$n.err")"
  [[ -d ".worktrees/$n-agent-w$n" ]] || fail "parallel task $n got no folder"
done
set +e; bash "$new" 14 agent w14 feat > "$tmp/cap.out" 2>&1; rc=$?; set -e
[[ "$rc" -eq 3 ]] || fail "folder cap not enforced (rc=$rc)"
[[ ! -e .worktrees/14-agent-w14 ]] && ! has_branch feat/14-w14 || fail "cap refusal still created something"
grep -Fq 'folder limit reached' "$tmp/cap.out" || fail "cap message missing"

w11="$tmp/l/.worktrees/11-agent-w11"; w12="$tmp/l/.worktrees/12-agent-w12"; w13="$tmp/l/.worktrees/13-agent-w13"
commit_in "$w11" "eleven"; git -C "$w11" push -q -u origin HEAD; t11="$(git -C "$w11" rev-parse HEAD)"
printf 'scratch\n' > "$w12/scratch.txt"
if bash "$tidy" --park feat/12-w12 > /dev/null 2>&1; then fail "parked a folder with uncommitted changes"; fi
[[ -f "$w12/scratch.txt" ]] || fail "refused park touched the folder"
bash "$tidy" --park feat/11-w11 > "$tmp/park.out" || fail "park failed: $(cat "$tmp/park.out")"
[[ ! -e "$w11" ]] && has_branch feat/11-w11 && on_origin feat/11-w11 || fail "park must remove the folder and keep the branch"
commit_in "$w13" "thirteen"; t13="$(git -C "$w13" rev-parse HEAD)"
if bash "$tidy" --park feat/13-w13 > /dev/null 2>&1; then fail "parked unpushed commits"; fi
bash "$tidy" --abandon feat/13-w13 > "$tmp/abandon.out" || fail "abandon failed: $(cat "$tmp/abandon.out")"
[[ "$(git ls-remote --tags origin "refs/tags/archive/feat/13-w13-${t13:0:7}" | cut -f1)" == "$t13" ]] || fail "abandon did not archive unpushed commits"
[[ ! -e "$w13" ]] && ! has_branch feat/13-w13 || fail "abandon left the folder or branch"

maint_merge l feat/10-ten; origin_deletes l feat/10-ten; pr feat/10-ten 40 MERGED "$t10"
bash "$new" 14 agent w14 feat > "$tmp/l14.out" 2>"$tmp/l14.err" || fail "start after merge failed: $(cat "$tmp/l14.err")"
! has_branch feat/10-ten || fail "merged single-task branch not retired before the next task: $(cat "$tmp/l14.err")"
grep -Fxq 'mode:     here' "$tmp/l14.out" && [[ "$(git symbolic-ref --short HEAD)" == feat/14-w14 ]] || fail "primary not returned and reused"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || fail "next task not based on the merged default branch"
bash "$new" 11 agent w11 feat > /dev/null 2>&1 || fail "resuming a parked task failed"
[[ "$(git -C "$w11" rev-parse HEAD)" == "$t11" ]] || fail "resumed task lost its pushed commit"

# --- Without GitHub CLI: only offline proof counts ---
fixture o 'max_worktrees=0'
cd "$tmp/o"
export FAKE_GH_OFFLINE=1
for n in 1 2 3; do bash "$new" "$n" agent "o$n" feat --worktree > /dev/null 2>"$tmp/o$n.err" || fail "offline start $n: $(cat "$tmp/o$n.err")"; done
for n in 1 2; do w="$tmp/o/.worktrees/$n-agent-o$n"; commit_in "$w" "offline $n"; git -C "$w" push -q -u origin HEAD; done
maint_merge o feat/1-o1; origin_deletes o feat/1-o1
maint_merge o feat/2-o2 squash; origin_deletes o feat/2-o2
bash "$tidy" --apply > "$tmp/offline.txt" || fail "offline apply failed: $(cat "$tmp/offline.txt")"
[[ ! -e "$tmp/o/.worktrees/1-agent-o1" ]] && ! has_branch feat/1-o1 || fail "offline: landed task with deleted upstream not retired"
[[ -d "$tmp/o/.worktrees/2-agent-o2" ]] || fail "offline: unprovable squash merge must be kept"
grep -Fq 'cannot verify merge without gh' "$tmp/offline.txt" || fail "offline reason missing"
[[ -d "$tmp/o/.worktrees/3-agent-o3" ]] || fail "offline: fresh task removed"
grep -Fq 'apo-tidy: mode=apply gh=off' "$tmp/offline.txt" || fail "offline summary missing"
unset FAKE_GH_OFFLINE

echo 'PASS: merged/squash/closed retired (closed archived first); dirty, newer, open, fresh, foreign and protected kept; single task in primary; folder cap; park/abandon/resume; offline proof only'
