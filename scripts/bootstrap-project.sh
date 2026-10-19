#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METHODOLOGY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=/dev/null
source "${METHODOLOGY_ROOT}/scripts/lib/url-guard.sh"

INVERTED_SOT_SCANNER="${METHODOLOGY_ROOT}/skills/repo-reconciliation-cleanup/scripts/scan_inverted_sot.py"

scan_inverted_sot() {
  local target="$1"
  [[ -f "${INVERTED_SOT_SCANNER}" ]] || die "inverted-SoT scanner missing: ${INVERTED_SOT_SCANNER}"
  command -v python3 >/dev/null || die "python3 is required for the inverted-SoT scan"
  PYTHONDONTWRITEBYTECODE=1 python3 "${INVERTED_SOT_SCANNER}" --root "${target}"
}

refuse_existing_destination() {
  local target="$1"
  warn "destination exists and is not empty: ${target}"
  warn "existing repositories are adoption, not greenfield bootstrap. Follow playbooks/adopt-existing-project.md."
  if [[ -f "${target}/AGENTS.md" || -f "${target}/CLAUDE.md" ]]; then
    warn "inverted-SoT scan (must-fix, not optional):"
    if ! scan_inverted_sot "${target}"; then
      die "PIN binding is not complete: inverted write-authority contract (GitLab/non-GitHub Issues host as production/write SoT, or GitHub demoted to mirror-only). Rewrite AGENTS.md first; do not bootstrap over it."
    fi
    die "destination is not empty and the rule-file scan is clean, but bootstrap still refuses to overwrite. Use playbooks/adopt-existing-project.md."
  fi
  die "destination exists and is not empty: ${target}. Existing repositories are adoption (playbooks/adopt-existing-project.md), not this greenfield path."
}

dry_run=0
assume_yes=0
skip_github=0
visibility="private"
require_codeowner_review=0
name=""
dest=""
owner=""
disposer=""
github_repo=""
methodology_url=""
methodology_ref=""
process_mode=""
agent_tools=""
external_tools=""

usage() {
  cat <<'EOF'
bootstrap-project.sh — 为 GitHub 仓库创建 APO 规则绑定

  --name NAME                 项目目录名/仓库名
  --dir PATH                  目标目录（默认 ./NAME）
  --disposer @HANDLE          GitHub 拍板人账号，必填
  --owner OWNER               GitHub 用户或组织（默认当前 gh 账号）
  --github-repo OWNER/NAME    指定 GitHub 仓库名
  --private | --public        仓库可见性（默认 private）
  --require-codeowner-review  请求 A 级保护（要求 Code Owner 审查）
  --skip-github               只生成本地骨架，不创建 GitHub 仓库
  --methodology-url URL       覆盖写入 PIN 的方法论来源
  --methodology-ref REF       写入 PIN 的参考版本
  --process-mode MODE         流程档位 light / standard
  --agent-tools IDS           Agent 工具 ID，逗号分隔（见选项注册表）
  --external-tools IDS        外部工具 ID，逗号分隔；不接入写 none
  --dry-run                   只输出计划
  --yes                       非交互模式；必填值须通过参数提供
  -h, --help                  显示帮助

初始化只使用 GitHub origin 作为唯一写入权威。来源必须是 Git 仓库并含真实提交 SHA；
非空目标目录必须走现有项目接入流程。客户端 Hook 可绕过；服务端保护能力按实际
结果报告 A/B/C，不夸大保证。GitHub 免费私有仓库可能只能得到 C：如实记录并继续。
EOF
}

log() { printf 'bootstrap: %s\n' "$*"; }
warn() { printf 'bootstrap: warning: %s\n' "$*" >&2; }
err() { printf 'bootstrap: error: %s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) name="${2:-}"; shift 2 ;;
    --dir) dest="${2:-}"; shift 2 ;;
    --disposer) disposer="${2:-}"; shift 2 ;;
    --owner) owner="${2:-}"; shift 2 ;;
    --github-repo) github_repo="${2:-}"; shift 2 ;;
    --private) visibility="private"; shift ;;
    --public) visibility="public"; shift ;;
    --require-codeowner-review) require_codeowner_review=1; shift ;;
    --skip-github) skip_github=1; shift ;;
    --methodology-url) methodology_url="${2:-}"; shift 2 ;;
    --methodology-ref) methodology_ref="${2:-}"; shift 2 ;;
    --process-mode) [[ -n "${2:-}" ]] || die "empty --process-mode"; [[ -z "$process_mode" ]] || die "duplicate --process-mode"; process_mode="$2"; shift 2 ;;
    --agent-tools) [[ -n "${2:-}" ]] || die "empty --agent-tools"; [[ -z "$agent_tools" ]] || die "duplicate --agent-tools"; agent_tools="$2"; shift 2 ;;
    --external-tools) [[ -n "${2:-}" ]] || die "empty --external-tools"; [[ -z "$external_tools" ]] || die "duplicate --external-tools"; external_tools="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --yes) assume_yes=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown flag: $1 (see --help)" ;;
  esac
done

if [[ -z "${name}" && -n "${dest}" ]]; then name="$(basename "${dest}")"; fi
if [[ -z "${name}" ]]; then
  [[ "${assume_yes}" -eq 0 ]] || die "--name is required with --yes"
  printf 'Project slug: '
  read -r name
fi
[[ "${name}" =~ ^[A-Za-z0-9._-]+$ ]] || die "name must contain only letters, digits, ._-"
[[ -n "${dest}" ]] || dest="$(pwd)/${name}"

if [[ -z "${disposer}" ]]; then
  [[ "${assume_yes}" -eq 0 ]] || die "--disposer is required with --yes"
  printf 'Disposer GitHub handle (e.g. @alice): '
  read -r disposer
fi
[[ -n "${disposer}" ]] || die "disposer is required"
[[ "${disposer}" == @* ]] || disposer="@${disposer}"
[[ "${disposer}" != '@DISPOSER' && "${disposer}" != '@example' ]] || die "placeholder disposer is not allowed"
[[ "${disposer}" =~ ^@[A-Za-z0-9-]+$ ]] || die "invalid disposer GitHub handle: ${disposer}"

command -v python3 >/dev/null || die "python3 is required"
selection_args=()
[[ "$assume_yes" -eq 0 ]] || selection_args+=(--non-interactive)
settings="$(python3 "${SCRIPT_DIR}/project-settings.py" select --source "$METHODOLOGY_ROOT" \
  --process-mode "$process_mode" --agent-tools "$agent_tools" --external-tools "$external_tools" "${selection_args[@]}")" || die "project choices are missing or invalid"
while IFS='=' read -r key value; do
  value="${value%$'\r'}"
  case "$key" in
    process_mode) process_mode="$value" ;;
    agent_tools) agent_tools="$value" ;;
    external_tools) external_tools="$value" ;;
    *) die "invalid project selection output" ;;
  esac
done <<< "$settings"

# Supported provenance: methodology must be a real git checkout.
methodology_sha="$(git -C "${METHODOLOGY_ROOT}" rev-parse --verify HEAD 2>/dev/null || true)"
[[ -n "${methodology_sha}" ]] || die "cannot determine methodology SHA; clone agent-project-ops instead of using a ZIP/non-git copy"

sanitize_methodology_url() {
  local u="$1"
  # Cloud Agent / CI remotes often embed x-access-token userinfo. PIN must stay
  # credential-free; this is not permission to pass secrets via --methodology-url.
  u="$(printf '%s' "${u}" | sed -E 's#^(https?://)[^/]*@#\1#')"
  u="${u%.git}"
  case "${u}" in
    git@github.com:*) printf 'https://github.com/%s\n' "${u#git@github.com:}" ;;
    ssh://git@github.com/*) printf 'https://github.com/%s\n' "${u#ssh://git@github.com/}" ;;
    *) printf '%s\n' "${u}" ;;
  esac
}

if [[ -z "${methodology_url}" ]]; then
  if git -C "${METHODOLOGY_ROOT}" remote get-url origin >/dev/null 2>&1; then
    methodology_url="$(sanitize_methodology_url "$(git -C "${METHODOLOGY_ROOT}" remote get-url origin)")"
  else
    methodology_url="https://github.com/Dylan5237/agent-project-ops"
  fi
fi
url_has_secrets "${methodology_url}" && die "methodology URL is unsafe"

if [[ -z "${methodology_ref}" ]]; then
  methodology_ref="$(git -C "${METHODOLOGY_ROOT}" symbolic-ref --short -q HEAD 2>/dev/null || printf 'HEAD')"
fi
fetched_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

log "methodology: ${methodology_url} @ ${methodology_sha} (${methodology_ref})"
log "destination: ${dest}"
log "disposer: ${disposer}"
log "authority: origin"
log "settings: process_mode=$process_mode agent_tools=$agent_tools external_tools=$external_tools"
log "GitHub protection target: $([[ "${require_codeowner_review}" -eq 1 ]] && printf 'A' || printf 'B')"

if [[ "${dry_run}" -eq 1 ]]; then
  log "plan: create git repo + durable Agent binding + pinned methodology snapshot"
  log "plan: write origin-only authority registry and install .githooks/pre-push"
  log "plan: create .worktrees/ and ignore nested worktrees"
  log "plan: retire finished task folders/branches automatically (tidy-worktrees.sh; GitHub deletes merged PR branches)"
  if [[ "${skip_github}" -eq 1 ]]; then
    log "plan: skip GitHub creation"
  else
    log "plan: gh repo create --${visibility}; push initial authority main; report protection capability A/B/C (C on Free private is expected; do not abort)"
  fi
  log "plan: next = playbooks/start-project.md; no product implementation"
  if [[ -e "${dest}" && -n "$(ls -A "${dest}" 2>/dev/null)" ]]; then
    log "plan: FAIL CLOSED — destination exists; existing repos use playbooks/adopt-existing-project.md (scan inverted SoT before PIN)"
  fi
  exit 0
fi

command -v git >/dev/null || die "git is required"
if [[ "${skip_github}" -eq 0 ]]; then
  command -v gh >/dev/null || die "gh is required unless --skip-github"
  gh auth status >/dev/null 2>&1 || die "gh is not authenticated"
fi

if [[ -e "${dest}" && -n "$(ls -A "${dest}" 2>/dev/null)" ]]; then
  refuse_existing_destination "${dest}"
fi

# PIN identifies committed HEAD, but the snapshot copies working-tree files.
# Ignore interpreter bytecode caches (never ship them); reject real source drift.
methodology_dirty="$(git -C "${METHODOLOGY_ROOT}" status --porcelain --untracked-files=all -- PRINCIPLES.md LICENSE playbooks skills templates scripts integrations | grep -Ev '(/__pycache__/|\.pyc$)' || true)"
[[ -z "${methodology_dirty}" ]] || die "methodology checkout has uncommitted or untracked source files: snapshot would not match PIN SHA. Commit or clean the source checkout first."
python3 "${SCRIPT_DIR}/project-settings.py" check-core --root "$METHODOLOGY_ROOT" || die "methodology core contract failed"

mkdir -p "${dest}"
cd "${dest}"
git init -q -b main

mkdir -p \
  .agents/skills \
  .github/ISSUE_TEMPLATE \
  .github/PULL_REQUEST_TEMPLATE \
  .githooks \
  .worktrees \
  .agent-project-ops/scripts/lib

# Vendor a full generic methodology snapshot, then place the scripts required
# by generated-repository runtime behavior in stable snapshot paths.
cp -a "${METHODOLOGY_ROOT}/PRINCIPLES.md" .agent-project-ops/PRINCIPLES.md
cp -a "${METHODOLOGY_ROOT}/LICENSE" .agent-project-ops/LICENSE
cp -a "${METHODOLOGY_ROOT}/playbooks" .agent-project-ops/playbooks
cp -a "${METHODOLOGY_ROOT}/skills" .agent-project-ops/skills
cp -a "${METHODOLOGY_ROOT}/templates" .agent-project-ops/templates
cp "${METHODOLOGY_ROOT}/scripts/new-worktree.sh" .agent-project-ops/scripts/new-worktree.sh
cp "${METHODOLOGY_ROOT}/scripts/tidy-worktrees.sh" .agent-project-ops/scripts/tidy-worktrees.sh
cp "${METHODOLOGY_ROOT}/scripts/install-hooks.sh" .agent-project-ops/scripts/install-hooks.sh
cp "${METHODOLOGY_ROOT}/scripts/scan-inverted-sot.py" .agent-project-ops/scripts/scan-inverted-sot.py
cp "${METHODOLOGY_ROOT}/scripts/project-settings.py" .agent-project-ops/scripts/project-settings.py
cp "${METHODOLOGY_ROOT}/scripts/lib/url-guard.sh" .agent-project-ops/scripts/lib/url-guard.sh
# Remove transient Python bytecode that may have been produced by prior tests.
# Only touch the new snapshot; never delete files from the method checkout.
find .agent-project-ops -type d -name '__pycache__' -prune -exec rm -rf {} +
find .agent-project-ops -type f -name '*.pyc' -delete
chmod +x .agent-project-ops/scripts/new-worktree.sh .agent-project-ops/scripts/tidy-worktrees.sh .agent-project-ops/scripts/install-hooks.sh .agent-project-ops/scripts/scan-inverted-sot.py .agent-project-ops/scripts/project-settings.py

cat > .agent-project-ops/PIN <<EOF
url=${methodology_url}
sha=${methodology_sha}
ref=${methodology_ref}
fetched_at=${fetched_at}
EOF

cat > .agent-project-ops/remotes <<EOF
authority=origin
EOF

subst() {
  local src="$1" dst="$2"
  sed \
    -e "s|{{PROJECT_NAME}}|${name}|g" \
    -e "s|{{METHODOLOGY_URL}}|${methodology_url}|g" \
    -e "s|{{METHODOLOGY_SHA}}|${methodology_sha}|g" \
    -e "s|{{METHODOLOGY_REF}}|${methodology_ref}|g" \
    -e "s|{{FETCHED_AT}}|${fetched_at}|g" \
    -e "s|{{DISPOSER}}|${disposer}|g" \
    -e "s|{{PROCESS_MODE}}|${process_mode}|g" \
    -e "s|{{AGENT_TOOLS}}|${agent_tools}|g" \
    -e "s|{{EXTERNAL_TOOLS}}|${external_tools}|g" \
    "${src}" > "${dst}"
}

subst "${METHODOLOGY_ROOT}/templates/AGENTS.md" AGENTS.md
if ! scan_inverted_sot "$(pwd)"; then
  die "generated AGENTS.md failed the inverted-SoT scan; templates/AGENTS.md is not a valid authority contract"
fi
cp "${METHODOLOGY_ROOT}/templates/CLAUDE.md" CLAUDE.md
subst "${METHODOLOGY_ROOT}/templates/github/CODEOWNERS" .github/CODEOWNERS
cp "${METHODOLOGY_ROOT}/templates/gitignore-agent-ops" .gitignore
cp "${METHODOLOGY_ROOT}/templates/gitattributes-agent-ops" .gitattributes
cp "${METHODOLOGY_ROOT}/templates/ISSUE_TEMPLATE/"*.md .github/ISSUE_TEMPLATE/
# Command Center provenance must match the actual PIN, not a hardcoded author/tag.
subst "${METHODOLOGY_ROOT}/templates/ISSUE_TEMPLATE/command-center.md" .github/ISSUE_TEMPLATE/command-center.md
cp "${METHODOLOGY_ROOT}/templates/PULL_REQUEST_TEMPLATE/"*.md .github/PULL_REQUEST_TEMPLATE/

write_wrapper() {
  local skill_dir="$1" skill_name src fm
  skill_name="$(basename "${skill_dir}")"
  src="${skill_dir}/SKILL.md"
  [[ -f "${src}" ]] || return 0
  fm="$(awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; print; if(n==2) exit; next} n==1{print}' "${src}")"
  mkdir -p ".agents/skills/${skill_name}"
  {
    printf '%s\n\n' "${fm}"
    printf '# %s (pinned wrapper)\n\n' "${skill_name}"
    printf 'Follow the full pinned skill at [../../../.agent-project-ops/skills/%s/SKILL.md](../../../.agent-project-ops/skills/%s/SKILL.md).\n\n' "${skill_name}" "${skill_name}"
    printf '%s\n' 'Do not invent a parallel process. `.agent-project-ops/PRINCIPLES.md` wins.'
  } > ".agents/skills/${skill_name}/SKILL.md"
}

shopt -s nullglob
for d in "${METHODOLOGY_ROOT}/skills"/*; do
  [[ -d "${d}" ]] && write_wrapper "${d}"
done
shopt -u nullglob

python3 "${SCRIPT_DIR}/project-settings.py" generate --source "$METHODOLOGY_ROOT" --root "$(pwd)" \
  --process-mode "$process_mode" --agent-tools "$agent_tools" --external-tools "$external_tools" --non-interactive

cp "${METHODOLOGY_ROOT}/scripts/hooks/pre-push-authority.sh" .githooks/pre-push
chmod +x .githooks/pre-push
git config core.hooksPath .githooks

if ! git config user.email >/dev/null 2>&1; then
  git config user.email "bootstrap@local.invalid"
  git config user.name "agent-project-ops bootstrap"
  log "git identity was unset; configured repository-local bootstrap identity"
fi

git add -A
git commit -q -m "chore: bootstrap agent-project-ops binding"

if [[ "${skip_github}" -eq 1 ]]; then
  log "local scaffold complete; GitHub protection capability: n/a (--skip-github)"
  log "next: create/record origin, then run .agent-project-ops/playbooks/start-project.md"
  exit 0
fi

if [[ -z "${github_repo}" ]]; then
  if [[ -z "${owner}" ]]; then owner="$(gh api user --jq .login)"; fi
  github_repo="${owner}/${name}"
fi

vis_flag="--private"
[[ "${visibility}" == "public" ]] && vis_flag="--public"
gh repo create "${github_repo}" "${vis_flag}" --source=. --remote=origin --push --description "Project bound to agent-project-ops"
log "created GitHub authority: ${github_repo} (${visibility})"
gh repo edit "${github_repo}" --enable-issues=true >/dev/null 2>&1 || true
if gh repo edit "${github_repo}" --delete-branch-on-merge >/dev/null 2>&1; then
  log "GitHub deletes merged PR head branches automatically (restorable from the PR page)"
else
  warn "could not enable automatic deletion of merged PR branches; run: gh repo edit ${github_repo} --delete-branch-on-merge (Settings > General > Pull Requests)"
fi

protection_level='C'
protection_label='unprotected/unverifiable'
protect_payload="$(mktemp)"
trap 'rm -f "${protect_payload}"' EXIT

if [[ "${require_codeowner_review}" -eq 1 ]]; then
  cat > "${protect_payload}" <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "require_code_owner_reviews": true,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
else
  cat > "${protect_payload}" <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
fi

if gh api -X PUT "repos/${github_repo}/branches/main/protection" --input "${protect_payload}" >/dev/null 2>&1; then
  review_count="$(gh api "repos/${github_repo}/branches/main/protection" --jq '.required_pull_request_reviews.required_approving_review_count // 0' 2>/dev/null || printf 'unknown')"
  codeowners="$(gh api "repos/${github_repo}/branches/main/protection" --jq '.required_pull_request_reviews.require_code_owner_reviews // false' 2>/dev/null || printf 'unknown')"
  force_enabled="$(gh api "repos/${github_repo}/branches/main/protection" --jq '.allow_force_pushes.enabled // false' 2>/dev/null || printf 'unknown')"

  if [[ "${review_count}" =~ ^[1-9][0-9]*$ && "${codeowners}" == 'true' && "${force_enabled}" == 'false' ]]; then
    protection_level='A'
    protection_label='code-owner review enforced'
  elif [[ "${review_count}" == '0' && "${force_enabled}" == 'false' ]]; then
    protection_level='B'
    protection_label='PR-only; no independent human-review guarantee'
  fi
fi

log "GitHub protection capability: ${protection_level} — ${protection_label}"
log "IMPORTANT: if Agent and disposer share one GitHub identity, GitHub cannot distinguish human vs Agent actions."

if [[ "${protection_level}" == 'C' ]]; then
  warn "capability C: requested branch protection could not be enabled/verified."
  if [[ "${visibility}" == "private" ]]; then
    warn "GitHub Free private repositories commonly cannot enable this protection; C is expected. Record C on Command Center and continue. Do not claim B or A. Do not treat this as bootstrap failure. GitHub Pro is not required to finish init."
  else
    warn "Record C on Command Center and continue. Do not claim B or A. Do not treat this as bootstrap failure."
  fi
fi
if [[ "${require_codeowner_review}" -eq 1 && "${protection_level}" != 'A' ]]; then
  warn "level A was requested but not verified (actual: ${protection_level}). Record the actual capability. Never claim A."
fi

log "done. Next: open Command Center using .agent-project-ops/playbooks/start-project.md; record the reported capability; do not implement product work before Freeze."
