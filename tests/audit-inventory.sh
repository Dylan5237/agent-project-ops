#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export AUDIT_REAL_GIT="$(type -P git)"
mkdir -p "$tmp/standalone/scripts"
cp "$root/skills/repo-reconciliation-cleanup/scripts/audit-inventory.sh" "$tmp/standalone/scripts/"
git init -q "$tmp/project"
git -C "$tmp/project" -c user.name=tester -c user.email=tester@local.invalid commit -qm seed --allow-empty
git -C "$tmp/project" remote add origin https://github.com/apo-test/project.git
cp "$tmp/project/.git/config" "$tmp/base-config"
export AUDIT_NETWORK_LOG="$tmp/network.log"
: > "$AUDIT_NETWORK_LOG"
git() {
case " $* " in
  *' fetch '*|*' push '*|*' ls-remote '*) echo forbidden >> "$AUDIT_NETWORK_LOG"; return 97 ;;
esac
if [[ "${AUDIT_FAIL_STATUS:-0}" == 1 && " $* " == *' status '* ]]; then
  echo 'SECRET_SENTINEL should never escape Git stderr' >&2
  return 42
fi
"$AUDIT_REAL_GIT" "$@"
}
export -f git
snapshot() {
  python3 -B - "$tmp/project" <<'PY'
import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1])
print(json.dumps({str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in root.rglob('*') if p.is_file()},sort_keys=True))
PY
}
for scenario in safe userinfo query fragment pushurl mixed-push rewrite push-rewrite extra unsafe-name missing-url failure; do
  cp "$tmp/base-config" "$tmp/project/.git/config"
  unset AUDIT_FAIL_STATUS
  expected=REVIEW_REQUIRED
  case "$scenario" in
    safe)
      expected=SAFE_GITHUB
      git -C "$tmp/project" config --add remote.origin.pushurl git@github.com:apo-test/project.git
      git -C "$tmp/project" config --add remote.origin.pushurl ssh://git@github.com/apo-test/project.git ;;
    userinfo) git -C "$tmp/project" remote set-url origin 'https://user:SECRET_SENTINEL@github.com/apo-test/project.git' ;;
    query) git -C "$tmp/project" remote set-url origin 'https://github.com/apo-test/project.git?token=SECRET_SENTINEL' ;;
    fragment) git -C "$tmp/project" remote set-url origin 'https://github.com/apo-test/project.git#SECRET_SENTINEL' ;;
    pushurl) git -C "$tmp/project" remote set-url --push origin 'https://user:SECRET_SENTINEL@github.com/apo-test/project.git' ;;
    mixed-push)
      git -C "$tmp/project" config --add remote.origin.pushurl https://github.com/apo-test/project.git
      git -C "$tmp/project" config --add remote.origin.pushurl 'https://github.com/apo-test/project.git?SECRET_SENTINEL' ;;
    rewrite) git -C "$tmp/project" config 'url.https://user:SECRET_SENTINEL@github.com/.insteadOf' 'https://github.com/' ;;
    push-rewrite) git -C "$tmp/project" config 'url.https://user:SECRET_SENTINEL@github.com/.pushInsteadOf' 'https://github.com/' ;;
    extra)
      expected=SAFE_GITHUB
      git -C "$tmp/project" remote add legacy 'https://user:SECRET_SENTINEL@example.invalid/project.git' ;;
    unsafe-name)
      expected=SAFE_GITHUB
      git -C "$tmp/project" remote add 'user@SECRET_SENTINEL' 'https://example.invalid/project.git' ;;
    missing-url)
      git -C "$tmp/project" config --unset remote.origin.url
      git -C "$tmp/project" config remote.origin.pushurl 'https://user:SECRET_SENTINEL@github.com/apo-test/project.git' ;;
    failure) expected=SAFE_GITHUB; export AUDIT_FAIL_STATUS=1 ;;
  esac
  before="$(snapshot)"
  # Execute the Skill alone: no methodology root or shared libraries installed.
  bash "$tmp/standalone/scripts/audit-inventory.sh" "$tmp/project" > "$tmp/stdout" 2> "$tmp/stderr"
  ! grep -Eq 'SECRET_SENTINEL|https://|ssh://|git@' "$tmp/stdout" "$tmp/stderr" || fail "$scenario leaked URL/credentials"
  grep -Fq "$(printf 'origin\t%s' "$expected")" "$tmp/stdout" || fail "$scenario missing classification"
  if [[ "$scenario" == extra ]]; then
    grep -Fq "$(printf 'legacy\tREVIEW_REQUIRED')" "$tmp/stdout" || fail 'extra remote was not flagged'
  fi
  if [[ "$scenario" == unsafe-name ]]; then
    grep -Fq 'remote_inventory=REVIEW_REQUIRED' "$tmp/stdout" || fail 'unsafe remote name was echoed'
  fi
  [[ "$(snapshot)" == "$before" ]] || fail "$scenario changed repo files/refs/config"
done
unset AUDIT_FAIL_STATUS
cp "$tmp/base-config" "$tmp/project/.git/config"
# Inject a failed dependency at the embedded Python boundary as well. A Bash
# git wrapper cannot intercept Python's native executable lookup on Windows.
AUDIT_SCRIPT="$tmp/standalone/scripts/audit-inventory.sh" python3 -B - "$tmp/project" <<'PY'
import contextlib,io,os,pathlib,subprocess,sys
from unittest import mock
script=pathlib.Path(os.environ['AUDIT_SCRIPT'])
if os.name == 'nt':
    script=pathlib.Path(subprocess.check_output(['cygpath','-w',str(script)],text=True).strip())
code=script.read_text(encoding='utf-8').split("<<'PY'\n",1)[1].split('\nPY\n',1)[0]
run=subprocess.run
def failing(args, **kwargs):
    if 'get-url' in args:
        return subprocess.CompletedProcess(args,42,'SECRET_SENTINEL_stdout','SECRET_SENTINEL_stderr')
    return run(args,**kwargs)
out=io.StringIO()
with mock.patch.object(subprocess,'run',failing), mock.patch.object(sys,'argv',['inventory',sys.argv[1]]), contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
    exec(compile(code,'inventory-remote-section','exec'),{})
assert 'SECRET_SENTINEL' not in out.getvalue()
assert 'origin\tREVIEW_REQUIRED' in out.getvalue()
PY
[[ ! -s "$AUDIT_NETWORK_LOG" ]] || fail 'inventory attempted network access'
echo 'PASS: standalone inventory omits all remote URLs and secret stderr, classifies unsafe metadata, and performs zero repo/network writes'
