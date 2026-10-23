#!/usr/bin/env bash
# Real Git URL/config parsing, recorded local-only transport, disposable repos.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester@local.invalid
export GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester@local.invalid
source "$root/tests/lib/worktree-transport.sh"
git init --bare -q --initial-branch=main "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/seed" 2>/dev/null
mkdir -p "$tmp/seed/.agent-project-ops"
printf 'authority=origin\n' > "$tmp/seed/.agent-project-ops/remotes"
git -C "$tmp/seed" add .agent-project-ops/remotes
git -C "$tmp/seed" commit -qm seed
git -C "$tmp/seed" push -q origin main
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
[[ -z "${WT_NETWORK_LOG:-}" ]] || echo gh >> "$WT_NETWORK_LOG"
if [[ "${WT_MUTATE_REGISTRY:-0}" == 1 ]]; then
  case "$1 $2" in
    'repo view') git config remote.origin.pushurl https://example.invalid/wrong/project.git ;;
    'pr list') printf '110 MERGED %s fix/110-prior false apo-test project\n' "$(git rev-parse HEAD)" ;;
  esac
fi
exit 0
GH
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH"

snapshot() {
  python3 -B - "$1" <<'PY'
import hashlib, json, pathlib, sys
p=pathlib.Path(sys.argv[1])
print(json.dumps({str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest()
                 for f in p.rglob('*') if f.is_file()},sort_keys=True))
PY
}
fixture() {
  git clone -q "$tmp/origin.git" "$tmp/$1" 2>/dev/null
  worktree_test_bind "$tmp/$1" "$tmp/origin.git" 'https://github.com/apo-test/project.git'
}
negative() {
  local name="$1" mode rc before
  fixture "$name"
  cd "$tmp/$name"
  case "$name" in
    no-origin) git remote remove origin ;;
    non-github) git remote set-url origin https://example.invalid/team/project.git ;;
    push-other) git remote set-url --push origin https://github.com/other/project.git ;;
    mixed-push)
      git config --add remote.origin.pushurl https://github.com/apo-test/project.git
      git config --add remote.origin.pushurl https://github.com/other/project.git ;;
    fetch-second) git config --add remote.origin.url https://github.com/other/project.git ;;
    rewrite) git config "url.$tmp/origin.git.insteadOf" 'https://github.com/apo-test/project.git' ;;
    push-rewrite) git config "url.$tmp/origin.git.pushInsteadOf" 'https://github.com/apo-test/project.git' ;;
    credentials) git remote set-url origin 'https://user:SECRET_SENTINEL@github.com/apo-test/project.git' ;;
    query) git remote set-url origin 'https://github.com/apo-test/project.git?token=SECRET_SENTINEL' ;;
    extra-remote) git remote add legacy https://example.invalid/team/project.git ;;
    missing-registry) mv .agent-project-ops/remotes "$tmp/held-registry" ;;
    duplicate-registry) printf 'authority=origin\nauthority=origin\n' > .agent-project-ops/remotes ;;
    legacy-registry) printf 'authority=origin\nexport=legacy\n' > .agent-project-ops/remotes ;;
    wrong-registry) printf 'authority=other\n' > .agent-project-ops/remotes ;;
    mirror) git config remote.origin.mirror true ;;
    *) fail "unknown case $name" ;;
  esac
  before="$(snapshot "$PWD")"
  local -a modes=(apply new)
  # The shared entry must cover every lifecycle route, including no-fetch/report.
  if [[ "$name" == mixed-push ]]; then modes=(report no-fetch apply park abandon new); fi
  for mode in "${modes[@]}"; do
    : > "$tmp/network.log"
    export WT_NETWORK_LOG="$tmp/network.log" WT_DENY_NETWORK=1
    set +e
    case "$mode" in
      report) bash "$root/scripts/tidy-worktrees.sh" > "$tmp/rejected" 2>&1 ;;
      no-fetch) bash "$root/scripts/tidy-worktrees.sh" --no-fetch > "$tmp/rejected" 2>&1 ;;
      apply) bash "$root/scripts/tidy-worktrees.sh" --apply > "$tmp/rejected" 2>&1 ;;
      park) bash "$root/scripts/tidy-worktrees.sh" --park feat/110-test > "$tmp/rejected" 2>&1 ;;
      abandon) bash "$root/scripts/tidy-worktrees.sh" --abandon feat/110-test > "$tmp/rejected" 2>&1 ;;
      new) bash "$root/scripts/new-worktree.sh" 110 agent test fix --here --base origin/main --save-base > "$tmp/rejected" 2>&1 ;;
    esac
    rc=$?
    set -e
    unset WT_DENY_NETWORK WT_NETWORK_LOG
    [[ "$rc" -eq 2 ]] || fail "$name/$mode did not hard-stop (rc=$rc)"
    grep -Fq 'origin authority check failed' "$tmp/rejected" || fail "$name/$mode missing safe diagnostic"
    ! grep -Fq SECRET_SENTINEL "$tmp/rejected" || fail "$name/$mode disclosed credentials"
    [[ ! -s "$tmp/network.log" ]] || fail "$name/$mode attempted transport/GitHub lookup"
    [[ "$(snapshot "$PWD")" == "$before" ]] || fail "$name/$mode changed repository files/refs/config/worktrees"
  done
}
for name in no-origin non-github push-other mixed-push fetch-second rewrite push-rewrite \
  credentials query extra-remote missing-registry duplicate-registry legacy-registry wrong-registry mirror; do
  negative "$name"
done

# Valid HTTPS/SSH equivalents, multiple safe URLs and CRLF comments are accepted
# by the same real parser; this check itself is local and has no network calls.
fixture valid
cd "$tmp/valid"
printf '# binding\r\n\r\nauthority=origin\r\n' > .agent-project-ops/remotes
git config --add remote.origin.url git@github.com:apo-test/project.git
git config --add remote.origin.pushurl ssh://git@github.com/apo-test/project.git
git config --add remote.origin.pushurl https://github.com/apo-test/project.git
identity="$(source "$root/scripts/lib/url-guard.sh"; github_worktree_authority "$PWD")"
[[ "$identity" == apo-test/project ]] || fail 'safe equivalent authorities were refused'
# The test transport must refuse aliases it has not explicitly mapped, as well
# as explicit URLs. Neither can escape the local bare transport boundary.
set +e
git push origin HEAD > "$tmp/unmapped.log" 2>&1
unmapped_rc=$?
git ls-remote https://github.com/apo-test/project.git > "$tmp/explicit-url.log" 2>&1
explicit_rc=$?
set -e
[[ "$unmapped_rc" -eq 97 && "$explicit_rc" -eq 97 ]] || fail 'test transport accepted an unmapped destination'

# A guard refusal from tidy must not become new-worktree's old warning/continue.
# Mutate the push destination at GitHub lookup, after new's initial preflight.
fixture drift
cd "$tmp/drift"
git switch -qc fix/110-prior
head="$(git rev-parse HEAD)"
export WT_MUTATE_REGISTRY=1
set +e
bash "$root/scripts/new-worktree.sh" 111 agent drift fix --here --save-base > "$tmp/drift.log" 2>&1
rc=$?
set -e
unset WT_MUTATE_REGISTRY
[[ "$rc" -eq 2 ]] || fail "new task continued after tidy authority refusal (rc=$rc)"
grep -Fq 'tidy-worktrees authority/preflight refused' "$tmp/drift.log" || fail 'fixture did not reach the tidy refusal boundary'
! grep -Fq continuing "$tmp/drift.log" || fail 'authority error was only a warning'
[[ "$(git rev-parse HEAD)" == "$head" && "$(git branch --show-current)" == fix/110-prior ]] || fail 'refused new task switched branches'
[[ ! -e .worktrees && ! -e .agent-project-ops/project-config ]] || fail 'refused new task wrote a folder/config'
! git show-ref --verify --quiet refs/heads/fix/111-drift || fail 'refused new task created a branch'
echo 'PASS: all lifecycle entries hard-stop unsafe resolved authority before transport or repo writes; valid aliases accepted; tidy refusal cannot be swallowed'
