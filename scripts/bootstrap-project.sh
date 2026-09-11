#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METHODOLOGY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=/dev/null
source "${METHODOLOGY_ROOT}/scripts/lib/url-guard.sh"

dry_run=0
assume_yes=0
skip_github=0
visibility="private"
no_projection=0
require_codeowner_review=0
name=""
dest=""
owner=""
disposer=""
projection_url=""
github_repo=""
methodology_url=""
methodology_ref=""

usage() {
  cat <<'EOF'
bootstrap-project.sh — scaffold a generic repo bound to agent-project-ops

  --name NAME                 Project directory / repo slug
  --dir PATH                  Destination directory (default: ./NAME)
  --disposer @HANDLE          Required real GitHub disposer handle
  --owner OWNER               GitHub user/org (default: authenticated gh user)
  --github-repo OWNER/NAME    Override GitHub repository name
  --private | --public        Visibility (default: private)
  --projection-url URL        Optional credential-free projection git URL
  --no-projection             Explicitly create origin-only configuration
  --require-codeowner-review  Request protection level A (independent review)
  --skip-github               Local scaffold only; do not create GitHub repo
  --methodology-url URL       Override canonical methodology URL written to PIN
  --methodology-ref REF       Informational ref written to PIN
  --dry-run                   Print the plan only
  --yes                       Non-interactive; required values must be flags
  -h, --help                  Show this help

Supported bootstrap requires a real methodology git SHA. It never writes
`sha=unknown`. Client hooks are bypassable; server policy is reported as
capability A/B/C and is never overstated.
EOF
}

log() { printf 'bootstrap: %s\n' "$*"; }
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
    --projection-url) projection_url="${2:-}"; shift 2 ;;
    --no-projection) no_projection=1; shift ;;
    --require-codeowner-review) require_codeowner_review=1; shift ;;
    --skip-github) skip_github=1; shift ;;
    --methodology-url) methodology_url="${2:-}"; shift 2 ;;
    --methodology-ref) methodology_ref="${2:-}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --yes) assume_yes=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown flag: $1 (see --help)" ;;
  esac
done

[[ ! ( -n "${projection_url}" && "${no_projection}" -eq 1 ) ]] || \
  die "use either --projection-url or --no-projection"

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

if [[ "${no_projection}" -eq 0 && -z "${projection_url}" && "${assume_yes}" -eq 0 && "${dry_run}" -eq 0 ]]; then
  printf 'Projection remote URL (empty = origin-only): '
  read -r projection_url
fi
if [[ -n "${projection_url}" ]]; then
  url_has_secrets "${projection_url}" && die "projection URL is unsafe; credentials/query strings are forbidden"
fi

# Supported provenance: methodology must be a real git checkout.
methodology_sha="$(git -C "${METHODOLOGY_ROOT}" rev-parse --verify HEAD 2>/dev/null || true)"
[[ -n "${methodology_sha}" ]] || die "cannot determine methodology SHA; clone agent-project-ops instead of using a ZIP/non-git copy"

sanitize_methodology_url() {
  local u="$1"
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

projection_name="(none)"
projection_record_url=""
if [[ -n "${projection_url}" ]]; then
  projection_name="projection"
  projection_record_url="${projection_url}"
fi

log "methodology: ${methodology_url} @ ${methodology_sha} (${methodology_ref})"
log "destination: ${dest}"
log "disposer: ${disposer}"
log "authority: origin"
log "projection: ${projection_name}"
log "GitHub protection target: $([[ "${require_codeowner_review}" -eq 1 ]] && printf 'A' || printf 'B')"

if [[ "${dry_run}" -eq 1 ]]; then
  log "plan: create git repo + durable Agent binding + pinned methodology snapshot"
  log "plan: write clone-portable remotes registry and install .githooks/pre-push"
  log "plan: create .worktrees/ and ignore nested worktrees"
  if [[ "${skip_github}" -eq 1 ]]; then
    log "plan: skip GitHub creation"
  else
    log "plan: gh repo create --${visibility}; push initial authority main; verify protection capability"
  fi
  log "plan: next = playbooks/start-project.md; no product implementation"
  exit 0
fi

command -v git >/dev/null || die "git is required"
if [[ "${skip_github}" -eq 0 ]]; then
  command -v gh >/dev/null || die "gh is required unless --skip-github"
  gh auth status >/dev/null 2>&1 || die "gh is not authenticated"
fi

if [[ -e "${dest}" && -n "$(ls -A "${dest}" 2>/dev/null)" ]]; then
  die "destination exists and is not empty: ${dest}"
fi

mkdir -p "${dest}"
cd "${dest}"
git init -q -b main

mkdir -p \
  .cursor/rules \
  .agents/skills \
  .claude/skills \
  .github/ISSUE_TEMPLATE \
  .github/PULL_REQUEST_TEMPLATE \
  .continue/rules \
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
cp "${METHODOLOGY_ROOT}/scripts/install-hooks.sh" .agent-project-ops/scripts/install-hooks.sh
cp "${METHODOLOGY_ROOT}/scripts/lib/url-guard.sh" .agent-project-ops/scripts/lib/url-guard.sh
chmod +x .agent-project-ops/scripts/new-worktree.sh .agent-project-ops/scripts/install-hooks.sh

cat > .agent-project-ops/PIN <<EOF
url=${methodology_url}
sha=${methodology_sha}
ref=${methodology_ref}
fetched_at=${fetched_at}
EOF

cat > .agent-project-ops/remotes <<EOF
authority=origin
projection=${projection_name}
projection_url=${projection_record_url}
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
    -e "s|{{PROJECTION_REMOTE}}|${projection_name}|g" \
    "${src}" > "${dst}"
}

subst "${METHODOLOGY_ROOT}/templates/AGENTS.md" AGENTS.md
cp "${METHODOLOGY_ROOT}/templates/CLAUDE.md" CLAUDE.md
cp "${METHODOLOGY_ROOT}/templates/cursor-rules/agent-project-ops.mdc" .cursor/rules/agent-project-ops.mdc
cp "${METHODOLOGY_ROOT}/templates/github/copilot-instructions.md" .github/copilot-instructions.md
subst "${METHODOLOGY_ROOT}/templates/github/CODEOWNERS" .github/CODEOWNERS
cp "${METHODOLOGY_ROOT}/templates/gitignore-agent-ops" .gitignore
cp "${METHODOLOGY_ROOT}/templates/gitattributes-agent-ops" .gitattributes
cp "${METHODOLOGY_ROOT}/templates/aider.conf.yml" .aider.conf.yml
cp "${METHODOLOGY_ROOT}/templates/continue-rules/agent-project-ops.md" .continue/rules/agent-project-ops.md
cp "${METHODOLOGY_ROOT}/templates/ISSUE_TEMPLATE/"*.md .github/ISSUE_TEMPLATE/
cp "${METHODOLOGY_ROOT}/templates/PULL_REQUEST_TEMPLATE/"*.md .github/PULL_REQUEST_TEMPLATE/

write_wrapper() {
  local skill_dir="$1" skill_name src fm
  skill_name="$(basename "${skill_dir}")"
  src="${skill_dir}/SKILL.md"
  [[ -f "${src}" ]] || return 0
  fm="$(awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; print; if(n==2) exit; next} n==1{print}' "${src}")"
  mkdir -p ".agents/skills/${skill_name}" ".claude/skills/${skill_name}"
  {
    printf '%s\n\n' "${fm}"
    printf '# %s (pinned wrapper)\n\n' "${skill_name}"
    printf 'Follow the full pinned skill at [../../../.agent-project-ops/skills/%s/SKILL.md](../../../.agent-project-ops/skills/%s/SKILL.md).\n\n' "${skill_name}" "${skill_name}"
    printf '%s\n' 'Do not invent a parallel process. `.agent-project-ops/PRINCIPLES.md` wins.'
  } > ".agents/skills/${skill_name}/SKILL.md"
  cp ".agents/skills/${skill_name}/SKILL.md" ".claude/skills/${skill_name}/SKILL.md"
}

shopt -s nullglob
for d in "${METHODOLOGY_ROOT}/skills"/*; do
  [[ -d "${d}" ]] && write_wrapper "${d}"
done
shopt -u nullglob

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

if [[ -n "${projection_url}" ]]; then
  git remote add projection "${projection_url}"
  log "added local projection remote; committed registry remains the clone-portable classification"
fi

protection_level='C'
protection_label='unprotected/BLOCKED'
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
  err "BLOCKED: requested branch protection could not be enabled/verified. Record capability C on Command Center before feature work."
  exit 2
fi
if [[ "${require_codeowner_review}" -eq 1 && "${protection_level}" != 'A' ]]; then
  err "BLOCKED: level A was requested but not verified. Record actual capability before feature work."
  exit 2
fi

log "done. Next: open Command Center using .agent-project-ops/playbooks/start-project.md; do not implement product work before Freeze."
