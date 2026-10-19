#!/usr/bin/env bash
# Disposable local Git repositories only. No real project or GitHub state is modified.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1 PYTHONUTF8=1
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

src_sha="$(git -C "$root" rev-parse HEAD)"
url="$(git -C "$root" remote get-url origin)"

exercise_upgrade() {
  local tag="$1" slug old_method project old baseline project_name
  slug="${tag//./-}"
  old_method="$tmp/old-method-$slug"
  project="$tmp/project-$slug"
  project_name="upgrade-$slug"
  old="$(git -C "$root" rev-parse --verify "$tag^{commit}")"

  git clone -q --no-checkout "$root" "$old_method"
  git -C "$old_method" checkout -q --detach "$old"
  bash "$old_method/scripts/bootstrap-project.sh" --name "$project_name" --dir "$project" \
    --disposer @upgrade-tester --methodology-url "$url" --no-projection --skip-github --yes \
    > "$tmp/bootstrap-$slug.log" 2>&1

  git -C "$project" config core.autocrlf false
  git -C "$project" config user.name upgrade-tester
  git -C "$project" config user.email upgrade-tester@local.invalid
  git -C "$project" remote add origin "https://github.com/example/$project_name.git"
  printf '\n## Project-specific rules\nPreserve the clinical data boundary.\n' >> "$project/AGENTS.md"
  printf 'business content must survive\n' > "$project/business.txt"
  printf 'task_base=origin/develop\ncustom_flag=preserve-me\n' > "$project/.agent-project-ops/project-config"
  git -C "$project" add .
  git -C "$project" commit -qm 'fixture: personal rules and business baseline'
  baseline="$(git -C "$project" rev-parse HEAD)"
  cp "$project/.agent-project-ops/remotes" "$tmp/remotes-$slug.before"
  cp "$project/AGENTS.md" "$tmp/agents-$slug.before"
  cp "$project/.agent-project-ops/project-config" "$tmp/project-config-$slug.before"

  git -C "$project" worktree add -q -b "upgrade/apo-$slug" "$tmp/upgrade-$slug" "$baseline"
  cp "$tmp/upgrade-$slug/.agent-project-ops/remotes" "$tmp/remotes-$slug.worktree-before"
  git -C "$tmp/upgrade-$slug" config --local --list > "$tmp/config-$slug.before"
  python3 "$root/scripts/prepare-upgrade.py" --source "$root" --project "$tmp/upgrade-$slug" \
    --process-mode standard --agent-tools codex,claude --external-tools none > "$tmp/plan-$slug.json"
  local plan_id
  plan_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["plan_id"])' "$tmp/plan-$slug.json")"
  [[ -z "$(git -C "$tmp/upgrade-$slug" status --porcelain)" ]] || fail "$tag preview modified target"
  python3 "$root/scripts/prepare-upgrade.py" --source "$root" --project "$tmp/upgrade-$slug" \
    --process-mode standard --agent-tools codex,claude --external-tools none \
    --patch --expect-plan "$plan_id" > "$tmp/upgrade-$slug.patch" 2> "$tmp/receipt-$slug.json"
  [[ -s "$tmp/upgrade-$slug.patch" ]] || fail "$tag produced no upgrade patch"
  [[ -z "$(git -C "$tmp/upgrade-$slug" status --porcelain)" ]] || fail "$tag patch generation modified target"

  git -C "$tmp/upgrade-$slug" apply --check "$tmp/upgrade-$slug.patch"
  git -C "$tmp/upgrade-$slug" apply "$tmp/upgrade-$slug.patch"
  grep -Fxq "sha=$src_sha" "$tmp/upgrade-$slug/.agent-project-ops/PIN" || fail "$tag new PIN does not match source SHA"
  grep -Fq 'Preserve the clinical data boundary.' "$tmp/upgrade-$slug/AGENTS.md" || fail "$tag custom AGENTS rules lost"
  grep -Fq 'business content must survive' "$tmp/upgrade-$slug/business.txt" || fail "$tag business file lost"
  cmp -s "$tmp/remotes-$slug.worktree-before" "$tmp/upgrade-$slug/.agent-project-ops/remotes" || fail "$tag remote registry altered"
  { cat "$tmp/project-config-$slug.before"; printf 'process_mode=standard\nagent_tools=codex,claude\nexternal_tools=none\n'; } > "$tmp/project-config-$slug.expected"
  cmp -s "$tmp/project-config-$slug.expected" "$tmp/upgrade-$slug/.agent-project-ops/project-config" || fail "$tag old project settings not preserved with explicit choices appended"
  cmp -s "$tmp/config-$slug.before" <(git -C "$tmp/upgrade-$slug" config --local --list) || fail "$tag local Git config altered"
  for retired in \
    .cursor/rules/agent-project-ops.mdc \
    .github/copilot-instructions.md \
    .aider.conf.yml \
    .continue/rules/agent-project-ops.md \
    .agent-project-ops/scripts/share-export.sh \
    .agent-project-ops/scripts/export-sync.sh \
    .agent-project-ops/scripts/lib/share-export-denylist.sh \
    .agent-project-ops/scripts/lib/export-strip-list.sh; do
    [[ ! -e "$tmp/upgrade-$slug/$retired" ]] || fail "$tag retained retired path $retired"
  done
  [[ -f "$tmp/upgrade-$slug/.agents/skills/upgrade-project/SKILL.md" ]] || fail "$tag Agent skills wrapper not generated"
  [[ -f "$tmp/upgrade-$slug/.claude/skills/upgrade-project/SKILL.md" ]] || fail "$tag Claude skills wrapper not generated"
  if [[ -f "$tmp/upgrade-$slug/.agent-project-ops/skills/github-multi-agent-project-ops/SKILL.md" ]] && \
      grep -Eqi 'bugbot run|Register to Fleet REGISTRY|fleet-morning-digest' "$tmp/upgrade-$slug/.agent-project-ops/skills/github-multi-agent-project-ops/SKILL.md"; then
    fail "$tag obsolete generic policy retained"
  fi
  [[ "$(git -C "$project" rev-parse HEAD)" == "$baseline" ]] || fail "$tag primary branch moved"
  [[ -z "$(git -C "$project" status --porcelain)" ]] || fail "$tag primary checkout modified"

  git -C "$tmp/upgrade-$slug" apply --reverse --check "$tmp/upgrade-$slug.patch"
  git -C "$tmp/upgrade-$slug" apply --reverse "$tmp/upgrade-$slug.patch"
  [[ -z "$(git -C "$tmp/upgrade-$slug" status --porcelain)" ]] || fail "$tag reverse patch did not restore baseline"
  cmp -s "$tmp/agents-$slug.before" "$tmp/upgrade-$slug/AGENTS.md" || fail "$tag original AGENTS bytes not restored"
  cmp -s "$tmp/remotes-$slug.before" "$tmp/upgrade-$slug/.agent-project-ops/remotes" || fail "$tag original remotes not restored"
  cmp -s "$tmp/project-config-$slug.before" "$tmp/upgrade-$slug/.agent-project-ops/project-config" || fail "$tag original project settings not restored"
  grep -Fxq "sha=$old" "$tmp/upgrade-$slug/.agent-project-ops/PIN" || fail "$tag old PIN not restored"

  git -C "$tmp/upgrade-$slug" apply --check "$tmp/upgrade-$slug.patch"
  git -C "$tmp/upgrade-$slug" apply "$tmp/upgrade-$slug.patch"
  git -C "$tmp/upgrade-$slug" add .
  git -C "$tmp/upgrade-$slug" commit -qm 'fixture: reviewed APO rule update'
  python3 "$root/scripts/prepare-upgrade.py" --source "$root" --project "$tmp/upgrade-$slug" > "$tmp/noop-$slug.json"
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["status"]=="UP_TO_DATE" and not d["changes"]' "$tmp/noop-$slug.json" || fail "$tag repeat preview is not a no-op"
  echo "PASS: real $tag $old -> $src_sha bootstrap/preview/apply/reverse/repeat; project state preserved"
}

exercise_upgrade v0.1.2
exercise_upgrade v0.2.1
