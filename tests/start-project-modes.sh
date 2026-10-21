#!/usr/bin/env bash
# Offline scaffold/document contract; this does not claim an Agent Host run.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

python3 -B - "$root" <<'PY'
import pathlib,sys
root=pathlib.Path(sys.argv[1])
guide=(root/'playbooks/start-project.md').read_text(encoding='utf-8')
step7=guide.split('7. **',1)[1].split('\n8. **',1)[0]
assert '**`light`:** Open a task using `templates/ISSUE_TEMPLATE/task.md`' in step7
assert 'its own contract and no parent Phase. Do not create a Phase issue.' in step7
assert '**`standard` (including unrecorded mode):** Open Phase-0/Phase-1' in step7
assert 'templates/ISSUE_TEMPLATE/phase.md' in step7
step8=guide.split('8. **',1)[1].split('\n\n',1)[0]
for rule in ['that task (`light`) or Phase (`standard`)', 'before any `feat/` / `fix/` branch',
             '§11 major-change check', "wait for the disposer's start confirmation", 'explicitly covers the scope']:
    assert rule in step8,rule
done=guide.split('## Done when',1)[1].split('## Anti-patterns',1)[0]
assert 'task with its own contract and no Phase (`light`), or a Phase (`standard`)' in done
assert 'At least one Phase issue' not in done
assert 'Merge is not acceptance.' in guide
assert "disposer's final acceptance together with release confirmation before each release" in guide
skill=(root/'skills/bootstrap-project/SKILL.md').read_text(encoding='utf-8').split('8. Run ',1)[1].split('\n',1)[0]
for rule in ['For `light`, open a task with its own contract and no Phase', 'for `standard`',
             'Freeze that task/Phase', 'required §11 start confirmation', 'Final acceptance and release confirmation']:
    assert rule in skill,rule
print('PASS: both documented paths retain Freeze, major-change approval and final acceptance gates')
PY

# Bootstrap requires a clean, pinned source. Commit the two candidate documents
# only inside a disposable local clone so this test also works before source commit.
git clone -q --no-checkout "$root" "$tmp/source"
git -C "$tmp/source" checkout -q --detach "$(git -C "$root" rev-parse HEAD)"
cp "$root/playbooks/start-project.md" "$tmp/source/playbooks/start-project.md"
cp "$root/skills/bootstrap-project/SKILL.md" "$tmp/source/skills/bootstrap-project/SKILL.md"
git -C "$tmp/source" add playbooks/start-project.md skills/bootstrap-project/SKILL.md
git -C "$tmp/source" -c user.name=tester -c user.email=tester@local.invalid commit -qm candidate-docs --allow-empty
for mode in light standard; do
  project="$tmp/$mode"
  bash "$tmp/source/scripts/bootstrap-project.sh" --name "$mode" --dir "$project" --disposer @apo-test \
    --process-mode "$mode" --agent-tools codex --external-tools none --skip-github --yes > "$tmp/$mode.log" 2>&1 \
    || { cat "$tmp/$mode.log" >&2; fail "$mode local bootstrap"; }
  grep -Fxq "process_mode=$mode" "$project/.agent-project-ops/project-config" || fail "$mode setting missing"
  python3 -B "$project/.agent-project-ops/scripts/project-settings.py" check --root "$project"
  cmp "$root/playbooks/start-project.md" "$project/.agent-project-ops/playbooks/start-project.md" || fail 'pinned guide differs'
  cmp "$root/skills/bootstrap-project/SKILL.md" "$project/.agent-project-ops/skills/bootstrap-project/SKILL.md" || fail 'pinned skill differs'
  if [[ "$mode" == light ]]; then
    grep -Fq '无（light 独立任务）' "$project/.github/ISSUE_TEMPLATE/task.md" || fail 'light task contract missing'
    echo 'PASS: light offline scaffold -> independent task contract, no Phase required; Freeze/approval first'
  else
    [[ -f "$project/.github/ISSUE_TEMPLATE/phase.md" ]] || fail 'standard Phase template missing'
    echo 'PASS: standard offline scaffold -> Phase contract; Freeze/approval first'
  fi
done
echo 'PASS: local generation and document contracts verified; live Issues and Agent Host behavior are unverified'
