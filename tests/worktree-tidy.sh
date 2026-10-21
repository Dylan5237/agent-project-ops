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
source "$root/tests/lib/worktree-transport.sh"

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
  mkdir -p "$tmp/$name-maint/.agent-project-ops"
  printf 'authority=origin\n' > "$tmp/$name-maint/.agent-project-ops/remotes"
  if [[ $# -gt 0 ]]; then
    mkdir -p "$tmp/$name-maint/.agent-project-ops"
    printf '%s\n' "$@" > "$tmp/$name-maint/.agent-project-ops/project-config"
  fi
  git -C "$tmp/$name-maint" add -A
  git -C "$tmp/$name-maint" commit -q --allow-empty -m seed
  git -C "$tmp/$name-maint" push -q origin main
  git clone -q "$tmp/$name.git" "$tmp/$name"
  worktree_test_bind "$tmp/$name" "$tmp/$name.git" "https://github.com/apo-test/$name.git"
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

# --- Ignored files protect finished folders; report is read-only ---
fixture ig 'max_worktrees=0'
printf '/from-gitignore.data\n/park-only.data\n/abandon-only.data\n/.worktrees/\n' \
  > "$tmp/ig-maint/.gitignore"
git -C "$tmp/ig-maint" add .gitignore
git -C "$tmp/ig-maint" commit -q -m 'ignore local-only fixture data'
git -C "$tmp/ig-maint" push -q origin main
printf '/from-exclude.data\n' >> "$tmp/ig/.git/info/exclude"
cd "$tmp/ig"
bash "$new" 51 agent gitignore feat --worktree > /dev/null
bash "$new" 52 agent exclude feat --worktree > /dev/null
bash "$new" 53 agent safe feat --worktree > /dev/null
w51="$tmp/ig/.worktrees/51-agent-gitignore"
w52="$tmp/ig/.worktrees/52-agent-exclude"
w53="$tmp/ig/.worktrees/53-agent-safe"
commit_in "$w51" "gitignore task"; git -C "$w51" push -q -u origin HEAD; t51="$(git -C "$w51" rev-parse HEAD)"
commit_in "$w52" "exclude task"; git -C "$w52" push -q -u origin HEAD; t52="$(git -C "$w52" rev-parse HEAD)"
commit_in "$w53" "safe task"; git -C "$w53" push -q -u origin HEAD; t53="$(git -C "$w53" rev-parse HEAD)"
printf 'gitignore unique data\n' > "$w51/from-gitignore.data"
mkdir -p "$w51/.worktrees/leaf"
printf 'nested ignored unique data\n' > "$w51/.worktrees/leaf/unique.data"
printf 'exclude unique data\n' > "$w52/from-exclude.data"
git -C "$w51" check-ignore -q from-gitignore.data || fail ".gitignore fixture is not ignored"
git -C "$w51" check-ignore -q .worktrees/leaf/unique.data || fail "nested .worktrees fixture is not ignored"
git -C "$w52" check-ignore -q from-exclude.data || fail "info/exclude fixture is not ignored"
maint_merge ig feat/51-gitignore
maint_merge ig feat/53-safe
pr feat/51-gitignore 51 MERGED "$t51"
pr feat/52-exclude 52 CLOSED "$t52"
pr feat/53-safe 53 MERGED "$t53"

ig_refs_before="$(git show-ref || true)"
ig_archive_before="$(git for-each-ref --format='%(refname) %(objectname)' refs/tags/archive)"
ig_worktrees_before="$(git worktree list --porcelain)"
ig_dirs_before="$(for p in "$w51" "$w52" "$w53"; do if [[ -d "$p" ]]; then printf 'present %s\n' "$p"; else printf 'absent %s\n' "$p"; fi; done)"
ig_status_before="$(for p in "$w51" "$w52" "$w53"; do git -C "$p" status --porcelain --ignored --untracked-files=all; done)"
bash "$tidy" --no-fetch > "$tmp/ignored-report.txt" || fail "ignored report failed: $(cat "$tmp/ignored-report.txt")"
grep -Eq '^keep +folder +\.worktrees/51-agent-gitignore .*ignored files' "$tmp/ignored-report.txt" \
  || fail "report did not explain ignored .gitignore data"
grep -Eq '^keep +folder +\.worktrees/52-agent-exclude .*ignored files' "$tmp/ignored-report.txt" \
  || fail "report did not explain ignored info/exclude data"
grep -Eq '^plan +remove-folder +\.worktrees/53-agent-safe ' "$tmp/ignored-report.txt" \
  || fail "report lost the safe task plan row"
if grep -Eq '^plan +archive +feat/52-exclude ' "$tmp/ignored-report.txt"; then
  fail "report planned an archive before checking ignored data"
fi
tail -1 "$tmp/ignored-report.txt" \
  | grep -Eq '^apo-tidy: mode=report gh=ok fetch=skipped folders_removed=0 branches_deleted=0 remote_deleted=0 archived=0 .*folders_left=3/unlimited$' \
  || fail "ignored report summary or actual folder count: $(tail -1 "$tmp/ignored-report.txt")"
[[ "$(git show-ref || true)" == "$ig_refs_before" ]] || fail "report changed task or archive refs"
[[ "$(git for-each-ref --format='%(refname) %(objectname)' refs/tags/archive)" == "$ig_archive_before" ]] \
  || fail "report changed archive tags"
[[ "$(git worktree list --porcelain)" == "$ig_worktrees_before" ]] || fail "report changed registered worktrees"
[[ "$(for p in "$w51" "$w52" "$w53"; do if [[ -d "$p" ]]; then printf 'present %s\n' "$p"; else printf 'absent %s\n' "$p"; fi; done)" == "$ig_dirs_before" ]] \
  || fail "report changed worktree directories"
[[ "$(for p in "$w51" "$w52" "$w53"; do git -C "$p" status --porcelain --ignored --untracked-files=all; done)" == "$ig_status_before" ]] \
  || fail "report changed worktree file status"

mkdir -p "$tmp/ig/.worktrees/orphan" "$tmp/ig/.worktrees/.hidden"
bash "$tidy" --no-fetch > "$tmp/physical-folders.txt" || fail "physical folder report failed"
tail -1 "$tmp/physical-folders.txt" | grep -Eq 'folders_left=5/unlimited$' \
  || fail "report did not count hidden and unregistered directories"

bash "$tidy" --apply --no-fetch > "$tmp/ignored-apply.txt" || fail "ignored apply failed: $(cat "$tmp/ignored-apply.txt")"
[[ -d "$w51" && -f "$w51/from-gitignore.data" && -f "$w51/.worktrees/leaf/unique.data" ]] \
  || fail "merged task with ignored files was removed or altered"
[[ -d "$w52" && -f "$w52/from-exclude.data" ]] || fail "closed task with ignored files was removed or altered"
[[ -d "$w53" ]] && fail "safe merged task folder was not retired"
[[ -d "$tmp/ig/.worktrees/orphan" && -d "$tmp/ig/.worktrees/.hidden" ]] \
  || fail "unregistered directories were removed"
has_branch feat/51-gitignore && on_origin feat/51-gitignore || fail "merged ignored task refs were removed"
has_branch feat/52-exclude && on_origin feat/52-exclude || fail "closed ignored task refs were removed"
grep -Eq '^keep +folder +\.worktrees/51-agent-gitignore .*ignored files' "$tmp/ignored-apply.txt" \
  || fail "apply did not explain ignored .gitignore data"
grep -Eq '^keep +folder +\.worktrees/52-agent-exclude .*ignored files' "$tmp/ignored-apply.txt" \
  || fail "apply did not explain ignored info/exclude data"
closed_tag="archive/feat/52-exclude-${t52:0:7}"
[[ -z "$(git ls-remote --tags origin "refs/tags/$closed_tag")" ]] || fail "closed ignored task was archived before refusal"
if git show-ref --verify --quiet "refs/tags/$closed_tag"; then fail "closed ignored task received a local archive tag"; fi

bash "$new" 54 agent park feat --worktree > /dev/null
w54="$tmp/ig/.worktrees/54-agent-park"
commit_in "$w54" "park task"; git -C "$w54" push -q -u origin HEAD
printf 'park unique data\n' > "$w54/park-only.data"
set +e; bash "$tidy" --park feat/54-park > "$tmp/ignored-park.txt" 2>&1; ignored_park_rc=$?; set -e
[[ "$ignored_park_rc" -eq 1 ]] || fail "park with ignored files was not refused (rc=$ignored_park_rc)"
grep -Fq 'ignored files' "$tmp/ignored-park.txt" || fail "park refusal did not explain ignored files"
[[ -d "$w54" && -f "$w54/park-only.data" ]] && has_branch feat/54-park && on_origin feat/54-park \
  || fail "refused park changed its folder, data, or branches"

bash "$new" 55 agent abandon feat --worktree > /dev/null
w55="$tmp/ig/.worktrees/55-agent-abandon"
commit_in "$w55" "abandon task"
t55="$(git -C "$w55" rev-parse HEAD)"
printf 'abandon unique data\n' > "$w55/abandon-only.data"
set +e; bash "$tidy" --abandon feat/55-abandon > "$tmp/ignored-abandon.txt" 2>&1; ignored_abandon_rc=$?; set -e
[[ "$ignored_abandon_rc" -eq 1 ]] || fail "abandon with ignored files was not refused (rc=$ignored_abandon_rc)"
grep -Fq 'ignored files' "$tmp/ignored-abandon.txt" || fail "abandon refusal did not explain ignored files"
[[ -d "$w55" && -f "$w55/abandon-only.data" ]] && has_branch feat/55-abandon \
  || fail "refused abandon changed its folder, data, or branch"
abandon_tag="archive/feat/55-abandon-${t55:0:7}"
[[ -z "$(git ls-remote --tags origin "refs/tags/$abandon_tag")" ]] || fail "abandon archived before refusing ignored files"
if git show-ref --verify --quiet "refs/tags/$abandon_tag"; then fail "refused abandon created a local archive tag"; fi

# --- Primary checkout: ignored data blocks reuse/removal; ignored .worktrees is scoped out ---
fixture primary 'max_worktrees=0'
printf '/.worktrees/\n/default-cache.data\n/collision.data\n/primary-cache.data\n/park-cache.data\n/abandon-cache.data\n' \
  > "$tmp/primary-maint/.gitignore"
printf 'default tracked collision\n' > "$tmp/primary-maint/collision.data"
git -C "$tmp/primary-maint" add .gitignore
git -C "$tmp/primary-maint" add -f collision.data
git -C "$tmp/primary-maint" commit -q -m 'add ignored-path fixture'
git -C "$tmp/primary-maint" push -q origin main
cd "$tmp/primary"
git fetch -q origin
git merge -q --ff-only origin/main
printf 'default ignored unique data\n' > default-cache.data
git check-ignore -q default-cache.data || fail "default primary ignored fixture is not ignored"
set +e; bash "$new" 60 agent defaultignored feat --here > "$tmp/default-here.txt" 2>&1; default_here_rc=$?; set -e
[[ "$default_here_rc" -eq 2 ]] || fail "--here accepted a primary checkout with ignored data (rc=$default_here_rc)"
grep -Fq 'primary checkout is busy' "$tmp/default-here.txt" || fail "--here refusal did not explain the busy primary"
[[ "$(git symbolic-ref --short HEAD)" == main && -f default-cache.data ]] || fail "--here changed the default branch or ignored data"
! has_branch feat/60-defaultignored || fail "--here refusal still created a branch"
bash "$new" 60 agent defaultignored feat > "$tmp/default-auto.txt" 2>"$tmp/default-auto.err" \
  || fail "auto task with ignored primary data failed: $(cat "$tmp/default-auto.err")"
grep -Fxq 'mode:     worktree' "$tmp/default-auto.txt" || fail "auto task reused an ignored primary checkout"
w60="$tmp/primary/.worktrees/60-agent-defaultignored"
[[ -d "$w60" && "$(git symbolic-ref --short HEAD)" == main && -f default-cache.data ]] \
  || fail "auto task changed the primary checkout or its ignored data"
rm -f "$tmp/primary/default-cache.data"

# A root-level ignored .worktrees folder must not make an otherwise clean primary busy.
bash "$new" 61 agent primaryreuse feat --here > "$tmp/primary-here.txt" 2>"$tmp/primary-here.err" \
  || fail "safe primary checkout refused because .worktrees is ignored: $(cat "$tmp/primary-here.err")"
grep -Fxq 'mode:     here' "$tmp/primary-here.txt" || fail "safe task did not use the primary checkout"
[[ "$(git symbolic-ref --short HEAD)" == feat/61-primaryreuse && -d "$tmp/primary/.worktrees" ]] \
  || fail "primary task setup failed with ignored .worktrees"
commit_in "$tmp/primary" "primary reuse"; git push -q -u origin HEAD; t61="$(git rev-parse HEAD)"
maint_merge primary feat/61-primaryreuse
pr feat/61-primaryreuse 61 MERGED "$t61"
bash "$new" 62 agent primaryagain feat > "$tmp/primary-again.txt" 2>"$tmp/primary-again.err" \
  || fail "primary reuse after merge failed: $(cat "$tmp/primary-again.err")"
grep -Fxq 'mode:     here' "$tmp/primary-again.txt" || fail "merged task did not safely reuse primary"
[[ "$(git symbolic-ref --short HEAD)" == feat/62-primaryagain ]] \
  || fail "safe primary was not switched back and reused"

# The task removes a default-tracked path, then holds unique ignored bytes at that same path.
git rm -q collision.data
git commit -q -m 'remove collision on task branch'
git push -q -u origin HEAD
t62="$(git rev-parse HEAD)"
printf 'unique primary ignored bytes\n' > collision.data
git check-ignore -q collision.data || fail "primary collision fixture is not ignored"
maint_merge primary feat/62-primaryagain
pr feat/62-primaryagain 62 MERGED "$t62"
git -C "$tmp/primary-maint" checkout -q main
printf 'default tracked collision\n' > "$tmp/primary-maint/collision.data"
git -C "$tmp/primary-maint" add -f collision.data
git -C "$tmp/primary-maint" commit -q -m 'restore tracked default collision path'
git -C "$tmp/primary-maint" push -q origin main
git show origin/main:collision.data | grep -Fxq 'default tracked collision' \
  || fail "default branch does not track the colliding path"
bash "$tidy" --apply > "$tmp/primary-ignored-apply.txt" \
  || fail "primary ignored apply failed: $(cat "$tmp/primary-ignored-apply.txt")"
grep -Eq '^keep +folder +primary checkout .*ignored files' "$tmp/primary-ignored-apply.txt" \
  || fail "primary apply did not explain ignored data"
[[ "$(git symbolic-ref --short HEAD)" == feat/62-primaryagain && "$(cat collision.data)" == 'unique primary ignored bytes' ]] \
  || fail "automatic apply switched the primary or overwrote colliding ignored bytes"
[[ "$(git show origin/main:collision.data)" == 'default tracked collision' ]] \
  || fail "default branch lost its tracked collision path"

set +e; bash "$tidy" --park feat/62-primaryagain > "$tmp/primary-park.txt" 2>&1; primary_park_rc=$?; set -e
[[ "$primary_park_rc" -eq 1 ]] || fail "primary park with ignored data was not refused (rc=$primary_park_rc)"
grep -Fq 'ignored files' "$tmp/primary-park.txt" || fail "primary park refusal did not explain ignored files"
[[ "$(git symbolic-ref --short HEAD)" == feat/62-primaryagain && "$(cat collision.data)" == 'unique primary ignored bytes' ]] \
  || fail "refused primary park switched branches or changed ignored data"
set +e; bash "$tidy" --abandon feat/62-primaryagain > "$tmp/primary-abandon.txt" 2>&1; primary_abandon_rc=$?; set -e
[[ "$primary_abandon_rc" -eq 1 ]] || fail "primary abandon with ignored data was not refused (rc=$primary_abandon_rc)"
grep -Fq 'ignored files' "$tmp/primary-abandon.txt" || fail "primary abandon refusal did not explain ignored files"
[[ "$(git symbolic-ref --short HEAD)" == feat/62-primaryagain && "$(cat collision.data)" == 'unique primary ignored bytes' ]] \
  || fail "refused primary abandon switched branches or changed ignored data"
primary_tag="archive/feat/62-primaryagain-${t62:0:7}"
[[ -z "$(git ls-remote --tags origin "refs/tags/$primary_tag")" ]] || fail "primary abandon archived before refusing ignored files"
if git show-ref --verify --quiet "refs/tags/$primary_tag"; then fail "primary abandon created a local archive tag"; fi
bash "$new" 63 agent parallel feat > "$tmp/primary-parallel.txt" 2>"$tmp/primary-parallel.err" \
  || fail "new task with ignored primary data failed: $(cat "$tmp/primary-parallel.err")"
grep -Fxq 'mode:     worktree' "$tmp/primary-parallel.txt" || fail "new task switched away from ignored primary data"
[[ -d "$tmp/primary/.worktrees/63-agent-parallel" \
  && "$(git symbolic-ref --short HEAD)" == feat/62-primaryagain \
  && "$(cat collision.data)" == 'unique primary ignored bytes' ]] \
  || fail "ignored root .worktrees blocked a parallel task or primary data was changed"

# The primary exclusion applies to an actual task directory, never a same-named file.
fixture shape
cd "$tmp/shape"
printf '/.worktrees\n' >> .git/info/exclude
printf 'unique ignored file\n' > .worktrees
set +e; bash "$new" 70 agent shape feat --here > "$tmp/shape-here.txt" 2>&1; shape_rc=$?; set -e
[[ "$shape_rc" -eq 2 ]] || fail "--here excluded an ignored .worktrees file"
git checkout -qb feat/70-shape
pr feat/70-shape 70 MERGED "$(git rev-parse HEAD)"
bash "$tidy" --apply > "$tmp/shape-apply.txt" || fail "same-named file protection failed"
grep -Fq 'ignored files' "$tmp/shape-apply.txt" || fail "same-named file was hidden from status"
[[ "$(git symbolic-ref --short HEAD)" == feat/70-shape && "$(cat .worktrees)" == 'unique ignored file' ]] \
  || fail "same-named ignored file or its task branch was changed"

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

# A failed primary fast-forward is an actual failed retirement, with task refs
# preserved. Use trunk to exercise a non-main default throughout the path.
for scenario in ff-fail ff-ok; do
  fixture "$scenario"
  git --git-dir="$tmp/$scenario.git" symbolic-ref HEAD refs/heads/trunk
  git -C "$tmp/$scenario-maint" branch -m main trunk
  git -C "$tmp/$scenario-maint" push -q origin trunk
  cd "$tmp/$scenario"
  git branch -m main trunk
  git fetch -q origin
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
  base="$(git rev-parse HEAD)"
  if [[ "$scenario" == ff-fail ]]; then commit_in "$PWD" 'local-only'; fi
  git switch -qc "feat/106-$scenario" "$base"
  git push -qu origin HEAD
  tip="$(git rev-parse HEAD)"
  pr "feat/106-$scenario" 106 MERGED "$tip"
  commit_in "$tmp/$scenario-maint" 'remote-only'
  git -C "$tmp/$scenario-maint" push -q origin trunk
  if [[ "$scenario" == ff-fail ]]; then
    if bash "$tidy" --apply > "$tmp/$scenario.out" 2>&1; then fail 'divergent primary silently succeeded'; fi
    grep -Fq 'fast-forward failed' "$tmp/$scenario.out" || fail "missing explicit fast-forward error: $(cat "$tmp/$scenario.out")"
    grep -Fq 'failed=1' "$tmp/$scenario.out" || fail 'fast-forward failure missing from summary'
    [[ "$(git rev-parse "refs/heads/feat/106-$scenario")" == "$tip" ]] || fail 'failed retirement lost task ref'
    [[ "$(git show trunk:local-only.txt)" == local-only ]] || fail 'failed retirement lost local mainline work'
  else
    bash "$tidy" --apply > "$tmp/$scenario.out" 2>&1 || fail 'valid primary fast-forward failed'
    [[ "$(git symbolic-ref --short HEAD)" == trunk && "$(git rev-parse HEAD)" == "$(git rev-parse origin/trunk)" ]] || fail 'primary was not updated to trunk'
    ! has_branch "feat/106-$scenario" || fail 'successful retirement kept task branch'
    grep -Fq 'failed=0' "$tmp/$scenario.out" || fail 'successful retirement summary failed'
  fi
done

echo 'PASS: merged/squash/closed retirement; ignored data protection/report snapshot; primary ignored-data and .worktrees reuse; dirty/open/fresh/protected kept; folder cap; park/abandon/resume; offline proof only'
