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
assert 'Register that task/Phase number' in step7
assert "Keep the section title `## 阶段索引`" in step7
assert '`Task Issue`' in step7 and '--phase <task-or-Phase-number>' in step7
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
  # Exercise the installed status command's real parser and preview/apply logic
  # with GitHub calls replaced at the API boundary. No live Issues are created.
  python3 -B - "$project" "$mode" <<'PY'
import contextlib,copy,importlib.util,io,pathlib,re,sys
from unittest import mock
sys.dont_write_bytecode=True
project=pathlib.Path(sys.argv[1]); mode=sys.argv[2]
script=project/'.agent-project-ops/scripts/project-automation.py'
spec=importlib.util.spec_from_file_location('offline_status',script)
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
body=(project/'.github/ISSUE_TEMPLATE/command-center.md').read_text(encoding='utf-8')
class GitHubFixture:
    repo='example/offline'
    def __init__(self):
        self.cc={'body':body,'labels':[{'name':'type:command-center'}],'html_url':'https://example.invalid/cc'}
        self.target={'body':'Frozen offline fixture','title':'First work item','state':'open',
                     'labels':[{'name':'type:task' if mode=='light' else 'type:phase'},{'name':'status:backlog'}]}
        self.writes=[]
    def api(self,path,*,data=None,pages=False):
        if data is not None:
            assert path=='issues/1'
            self.writes.append(copy.deepcopy(data));self.cc.update(data)
        return copy.deepcopy(self.cc if path=='issues/1' else self.target if path=='issues/20' else [])
fixture=GitHubFixture()
argv=[str(script),'--root',str(project),'status','--cc','1','--phase','20',
      '--recent','offline fixture','--next-action','Freeze and required approval first','--tidy','apo-tidy: offline fixture']
def cli(*suffix):
    out=io.StringIO()
    with mock.patch.object(a,'authority',return_value=fixture.repo), mock.patch.object(a,'GitHub',return_value=fixture), \
         mock.patch.object(sys,'argv',argv+list(suffix)), contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        rc=a.main()
    return rc,out.getvalue()
rc,out=cli()
assert rc==2 and 'absent from the Command Center index' in out and not fixture.writes
fixture.cc['body']=body.replace('| # | | backlog | |','| #20 | First work item | backlog | |')
if mode=='light':
    fixture.cc['body']=fixture.cc['body'].replace('| Phase Issue |','| Task Issue |')
indexed=fixture.cc['body']
rc,out=cli()
assert rc==0 and '#20 First work item' in out and '未开工' in out and not fixture.writes,out
token=re.search(r'plan_id=([0-9a-f]{64})',out)[1]
rc,out=cli('--apply','--expect-plan',token)
assert rc==0 and 'APPLIED:' in out and len(fixture.writes)==1,out
start,end=a.first_section(indexed)
assert fixture.cc['body'].startswith(indexed[:start]) and fixture.cc['body'].endswith(indexed[end:])
print('PASS: '+mode+' indexed Issue accepted by installed status command; absent index refuses; preview zero-write, fixture apply preserves index')
PY
done
echo 'PASS: local generation and document contracts verified; live Issues and Agent Host behavior are unverified'
