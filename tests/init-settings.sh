#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1 PYTHONUTF8=1
python3 "$root/tests/test_project_settings.py" -v
python3 "$root/scripts/project-settings.py" check-core --root "$root"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone -q --no-checkout "$root" "$tmp/source"
git -C "$tmp/source" checkout -q --detach "$(git -C "$root" rev-parse HEAD)"
boot="$tmp/source/scripts/bootstrap-project.sh"
for choice in --process-mode --agent-tools --external-tools; do
  opts=(--process-mode standard --agent-tools codex --external-tools none)
  case "$choice" in
    --process-mode) opts=(--agent-tools codex --external-tools none) ;;
    --agent-tools) opts=(--process-mode standard --external-tools none) ;;
    --external-tools) opts=(--process-mode standard --agent-tools codex) ;;
  esac
  if bash "$boot" --name missing --dir "$tmp/missing" --disposer @tester --skip-github --yes "${opts[@]}" >"$tmp/missing.out" 2>&1; then
    echo "FAIL: headless choice accepted missing $choice" >&2; exit 1
  fi
  test ! -e "$tmp/missing"
  if bash "$boot" --name empty --dir "$tmp/empty" --disposer @tester --skip-github --yes \
      "$choice" '' --process-mode standard --agent-tools codex --external-tools none >"$tmp/empty.out" 2>&1; then
    echo "FAIL: empty first $choice bypassed duplicate validation" >&2; exit 1
  fi
  test ! -e "$tmp/empty"
done
bash "$boot" --name dry --dir "$tmp/dry" --disposer @tester --skip-github --yes --dry-run \
  --process-mode light --agent-tools workbuddy --external-tools none >"$tmp/dry.out"
test ! -e "$tmp/dry"
bash "$boot" --name generated --dir "$tmp/generated" --disposer @tester --skip-github --yes \
  --process-mode light --agent-tools codex,claude,workbuddy --external-tools arckeep,grok-bot >"$tmp/boot.out" 2>&1 || { cat "$tmp/boot.out"; exit 1; }
python3 "$tmp/generated/.agent-project-ops/scripts/project-settings.py" check --root "$tmp/generated"
test -f "$tmp/generated/.codebuddy/skills/github-multi-agent-project-ops/SKILL.md"
test -f "$tmp/generated/.agent-project-ops/integrations/arckeep.md"
python3 - "$tmp/source" "$tmp/generated" <<'PY'
import importlib.util, os, pathlib, sys
source, root = map(pathlib.Path, sys.argv[1:])
spec = importlib.util.spec_from_file_location('parity_upgrade', source / 'scripts/prepare-upgrade.py')
u = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = u
spec.loader.exec_module(u)
pin = dict(line.split('=', 1) for line in (root / '.agent-project-ops/PIN').read_text().splitlines())
values = dict(PROJECT_NAME='generated', DISPOSER='@tester', METHODOLOGY_URL=pin['url'],
              METHODOLOGY_SHA=pin['sha'], METHODOLOGY_REF=pin['ref'], FETCHED_AT=pin['fetched_at'],
              PROCESS_MODE='light', AGENT_TOOLS='codex,claude,workbuddy', EXTERNAL_TOOLS='arckeep,grok-bot')
expected = u.render(u.Source(source, 'HEAD'), values)
actual = set(u.git(root, 'ls-files').decode().splitlines()) - {'.agent-project-ops/PIN', '.agent-project-ops/remotes'}
assert actual == set(expected), (actual - set(expected), set(expected) - actual)
for name, file in expected.items():
    assert (root / name).read_bytes().replace(b'\r\n', b'\n') == file.data, name
    if os.name != 'nt':
        assert bool((root / name).stat().st_mode & 0o111) == (file.mode == 0o755), name
print('PASS: actual bootstrap files/content/modes equal selected-layout upgrade rendering')
PY
git -C "$tmp/generated" remote add origin https://github.com/example/generated.git
(
  cd "$tmp/generated"
  bash .githooks/pre-push origin https://github.com/example/generated.git </dev/null
  printf 'extra rule\n' >> CLAUDE.md
  if bash .githooks/pre-push origin https://github.com/example/generated.git </dev/null >"$tmp/hook.out" 2>&1; then
    echo 'FAIL: generated pre-push accepted a multiline CLAUDE.md' >&2; exit 1
  fi
  grep -q 'CLAUDE.md must contain only' "$tmp/hook.out"
)
echo 'PASS: selected initialization process, missing input/dry-run zero-write and actual pre-push binding gate'
