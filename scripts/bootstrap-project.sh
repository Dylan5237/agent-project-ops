#!/usr/bin/env bash
# Scaffold a generic business git repo bound to agent-project-ops.
# Usage: bootstrap-project.sh [flags]
# See docs/rfcs/0001-bootstrap-and-binding.md and playbooks/bootstrap-project.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METHODOLOGY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

dry_run=0
assume_yes=0
skip_github=0
install_hooks=1
visibility="private"
no_projection=0
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

  --name NAME              Directory / repo slug (required unless --dir implies it)
  --dir PATH               Destination directory (default: ./NAME)
  --disposer HANDLE        GitHub handle of the disposer (e.g. @alice)
  --owner OWNER            GitHub user or org (default: gh api user)
  --github-repo OWNER/NAME Override GitHub repo nwo
  --private | --public     Visibility (default: --private)
  --projection-url URL     Optional git URL for remote "projection" (no credentials)
  --no-projection          Do not prompt; origin-only
  --skip-github            Local git only (no gh repo create)
  --no-hooks               Do not install .githooks / core.hooksPath
  --methodology-url URL    Override PIN url
  --methodology-ref REF    Informational ref for PIN (default: current branch or HEAD)
  --dry-run                Print actions only
  --yes                    Non-interactive (origin-only unless --projection-url)
  -h, --help               Show this help

Does not store tokens. Rejects URLs that embed credentials.
Does not Freeze, implement product code, or Accept phases.
EOF
}

log() { printf 'bootstrap: %s\n' "$*"; }
err() { printf 'bootstrap: error: %s\n' "$*" >&2; }

die() {
  err "$*"
  exit 1
}

run() {
  if [[ "${dry_run}" -eq 1 ]]; then
    printf 'dry-run:'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

url_has_secrets() {
  local u="$1"
  case "${u}" in
    *"://"*:*@*|*"ghp_"*|*"glpat-"*|*"github_pat_"*)
      return 0
      ;;
  esac
  return 1
}

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
    --skip-github) skip_github=1; shift ;;
    --no-hooks) install_hooks=0; shift ;;
    --methodology-url) methodology_url="${2:-}"; shift 2 ;;
    --methodology-ref) methodology_ref="${2:-}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --yes) assume_yes=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown flag: $1 (see --help)" ;;
  esac
done

if [[ -n "${projection_url}" && "${no_projection}" -eq 1 ]]; then
  die "use either --projection-url or --no-projection"
fi

if [[ -z "${name}" && -n "${dest}" ]]; then
  name="$(basename "${dest}")"
fi
if [[ -z "${name}" ]]; then
  if [[ "${assume_yes}" -eq 1 ]]; then
    die "--name is required with --yes"
  fi
  printf 'Project slug: '
  read -r name
fi
[[ -n "${name}" ]] || die "empty name"
[[ "${name}" =~ ^[A-Za-z0-9._-]+$ ]] || die "name must be a generic slug (letters, digits, ._-)"

if [[ -z "${dest}" ]]; then
  dest="$(pwd)/${name}"
fi

if [[ -z "${disposer}" && "${assume_yes}" -eq 0 && "${dry_run}" -eq 0 ]]; then
  printf 'Disposer GitHub handle (e.g. @alice): '
  read -r disposer
fi
[[ -n "${disposer}" ]] || disposer="@DISPOSER"
if [[ "${disposer}" != @* ]]; then
  disposer="@${disposer}"
fi

if [[ "${no_projection}" -eq 0 && -z "${projection_url}" && "${assume_yes}" -eq 0 && "${dry_run}" -eq 0 ]]; then
  printf 'Add a projection remote (GitLab or other mirror)? URL empty = origin-only: '
  read -r projection_url
fi

if [[ -n "${projection_url}" ]]; then
  url_has_secrets "${projection_url}" && die "projection URL must not embed credentials"
fi

sanitize_public_git_url() {
  local u="$1"
  u="${u%.git}"
  case "${u}" in
    git@github.com:*)
      printf 'https://github.com/%s\n' "${u#git@github.com:}"
      ;;
    *github.com/*)
      printf 'https://github.com/%s\n' "${u##*github.com/}"
      ;;
    git@*:* )
      # git@host:group/repo → leave host, drop credentials
      printf '%s\n' "${u}"
      ;;
    *)
      printf '%s\n' "${u}"
      ;;
  esac
}

if [[ -z "${methodology_url}" ]]; then
  if git -C "${METHODOLOGY_ROOT}" remote get-url origin >/dev/null 2>&1; then
    methodology_url="$(sanitize_public_git_url "$(git -C "${METHODOLOGY_ROOT}" remote get-url origin)")"
  else
    methodology_url="https://github.com/Dylan5237/agent-project-ops"
  fi
fi
url_has_secrets "${methodology_url}" && die "methodology URL must not embed credentials"

methodology_sha="unknown"
if git -C "${METHODOLOGY_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
  methodology_sha="$(git -C "${METHODOLOGY_ROOT}" rev-parse HEAD)"
fi
if [[ -z "${methodology_ref}" ]]; then
  methodology_ref="$(git -C "${METHODOLOGY_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
fi
fetched_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

projection_label="(none — origin only)"
if [[ -n "${projection_url}" ]]; then
  projection_label="${projection_url}"
fi

log "methodology root: ${METHODOLOGY_ROOT}"
log "destination: ${dest}"
log "name: ${name}"
log "visibility: ${visibility}"
log "disposer: ${disposer}"
log "pin: ${methodology_url} @ ${methodology_sha}"
log "projection: ${projection_label}"

if [[ "${dry_run}" -eq 1 ]]; then
  log "plan: mkdir ${dest}; git init -b main; write AGENTS.md CLAUDE.md binding files;"
  log "plan: snapshot PRINCIPLES/playbooks/skills/templates into .agent-project-ops/;"
  log "plan: skill wrappers in .agents/skills and .claude/skills; gitignore .worktrees/;"
  if [[ "${install_hooks}" -eq 1 ]]; then
    log "plan: install .githooks/pre-push and core.hooksPath"
  fi
  if [[ "${skip_github}" -eq 1 ]]; then
    log "plan: skip GitHub"
  else
    log "plan: first commit; gh repo create --${visibility} --source=. --remote=origin --push"
    log "plan: best-effort default-branch protection (fail closed / report if API rejects)"
  fi
  if [[ -n "${projection_url}" ]]; then
    log "plan: git remote add projection <url> (no topic push, no --mirror)"
  fi
  log "plan: next = playbooks/start-project.md (Command Center). No feat/fix yet."
  exit 0
fi

command -v git >/dev/null || die "git is required"
if [[ "${skip_github}" -eq 0 ]]; then
  command -v gh >/dev/null || die "gh is required unless --skip-github"
fi

if [[ -e "${dest}" && -n "$(ls -A "${dest}" 2>/dev/null)" ]]; then
  die "destination exists and is not empty: ${dest}"
fi

mkdir -p "${dest}"
cd "${dest}"
git init -b main

mkdir -p \
  .cursor/rules \
  .agents/skills \
  .claude/skills \
  .github/ISSUE_TEMPLATE \
  .github/PULL_REQUEST_TEMPLATE \
  .github/instructions \
  .continue/rules \
  .githooks \
  .worktrees \
  .agent-project-ops

# Snapshot (generic methodology files only)
cp -a "${METHODOLOGY_ROOT}/PRINCIPLES.md" .agent-project-ops/PRINCIPLES.md
cp -a "${METHODOLOGY_ROOT}/LICENSE" .agent-project-ops/LICENSE
cp -a "${METHODOLOGY_ROOT}/playbooks" .agent-project-ops/playbooks
cp -a "${METHODOLOGY_ROOT}/skills" .agent-project-ops/skills
cp -a "${METHODOLOGY_ROOT}/templates" .agent-project-ops/templates
mkdir -p .agent-project-ops/scripts
cp -a "${METHODOLOGY_ROOT}/scripts/new-worktree.sh" .agent-project-ops/scripts/new-worktree.sh
chmod +x .agent-project-ops/scripts/new-worktree.sh

# PIN
{
  echo "url=${methodology_url}"
  echo "sha=${methodology_sha}"
  echo "ref=${methodology_ref}"
  echo "fetched_at=${fetched_at}"
} > .agent-project-ops/PIN

subst() {
  local src="$1" dst="$2"
  sed \
    -e "s|{{PROJECT_NAME}}|${name}|g" \
    -e "s|{{METHODOLOGY_URL}}|${methodology_url}|g" \
    -e "s|{{METHODOLOGY_SHA}}|${methodology_sha}|g" \
    -e "s|{{METHODOLOGY_REF}}|${methodology_ref}|g" \
    -e "s|{{FETCHED_AT}}|${fetched_at}|g" \
    -e "s|{{DISPOSER}}|${disposer}|g" \
    -e "s|{{PROJECTION_REMOTE}}|${projection_label}|g" \
    "${src}" > "${dst}"
}

subst "${METHODOLOGY_ROOT}/templates/AGENTS.md" AGENTS.md
subst "${METHODOLOGY_ROOT}/templates/CLAUDE.md" CLAUDE.md
cp "${METHODOLOGY_ROOT}/templates/cursor-rules/agent-project-ops.mdc" .cursor/rules/agent-project-ops.mdc
cp "${METHODOLOGY_ROOT}/templates/github/copilot-instructions.md" .github/copilot-instructions.md
sed "s/@DISPOSER/${disposer}/g" "${METHODOLOGY_ROOT}/templates/github/CODEOWNERS" > .github/CODEOWNERS
cp "${METHODOLOGY_ROOT}/templates/gitignore-agent-ops" .gitignore
cp "${METHODOLOGY_ROOT}/templates/aider.conf.yml" .aider.conf.yml
cp "${METHODOLOGY_ROOT}/templates/continue-rules/agent-project-ops.md" .continue/rules/agent-project-ops.md

# GitHub issue/PR templates (start-project)
cp "${METHODOLOGY_ROOT}/templates/ISSUE_TEMPLATE/"*.md .github/ISSUE_TEMPLATE/
cp "${METHODOLOGY_ROOT}/templates/PULL_REQUEST_TEMPLATE/"*.md .github/PULL_REQUEST_TEMPLATE/

write_wrapper() {
  local skill_dir="$1"
  local skill_name
  skill_name="$(basename "${skill_dir}")"
  local src="${skill_dir}/SKILL.md"
  [[ -f "${src}" ]] || return 0
  local fm
  fm="$(awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; if(n==1){print; next} if(n==2){print; exit}} n==1{print}' "${src}")"
  local body
  body="$(cat <<EOF

# ${skill_name} (wrapper)

This project vendors agent-project-ops under \`.agent-project-ops/\` (see \`PIN\`).

**Follow the full skill:** [../../../.agent-project-ops/skills/${skill_name}/SKILL.md](../../../.agent-project-ops/skills/${skill_name}/SKILL.md)

Do not invent a parallel process. PRINCIPLES in the snapshot win. Topic pushes go to \`origin\` only. Projection remotes are mirror/FF, never a second SoT.
EOF
)"
  mkdir -p ".agents/skills/${skill_name}" ".claude/skills/${skill_name}"
  printf '%s\n' "${fm}${body}" > ".agents/skills/${skill_name}/SKILL.md"
  printf '%s\n' "${fm}${body}" > ".claude/skills/${skill_name}/SKILL.md"
}

shopt -s nullglob
for d in "${METHODOLOGY_ROOT}/skills"/*; do
  [[ -d "${d}" ]] || continue
  write_wrapper "${d}"
done
shopt -u nullglob

if [[ "${install_hooks}" -eq 1 ]]; then
  cp "${METHODOLOGY_ROOT}/scripts/hooks/pre-push-authority.sh" .githooks/pre-push
  chmod +x .githooks/pre-push
  git config core.hooksPath .githooks
fi

# Keep an empty worktrees dir in tree via .gitkeep? RFC says gitignore the dir.
# Use a README that is not ignored: put note in AGENTS only. Directory created above;
# git cannot track ignored empty dirs — fine.

if ! git config user.email >/dev/null 2>&1; then
  git config user.email "bootstrap@local"
  git config user.name "agent-project-ops-bootstrap"
fi
git add -A
git commit -m "chore: bootstrap agent-project-ops binding (generic)."

if [[ "${skip_github}" -eq 1 ]]; then
  log "skipped GitHub. Next: playbooks/start-project.md once origin exists."
else
  if [[ -z "${github_repo}" ]]; then
    if [[ -z "${owner}" ]]; then
      owner="$(gh api user --jq .login)"
    fi
    github_repo="${owner}/${name}"
  fi
  vis_flag="--private"
  if [[ "${visibility}" == "public" ]]; then
    vis_flag="--public"
  fi
  gh repo create "${github_repo}" "${vis_flag}" --source=. --remote=origin --push --description "Business repo bound to agent-project-ops (generic)."
  log "created ${github_repo} (${visibility})"

  if ! gh api -X PUT "repos/${github_repo}/branches/main/protection" \
    --input - >/dev/null 2>protect.err <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
  then
    log "BLOCKED: could not enable branch protection via API (plan or permission)."
    log "Record this on Command Center. Do not treat main as protected."
    if [[ -f protect.err ]]; then
      log "api: $(tr '\n' ' ' < protect.err)"
      rm -f protect.err
    fi
  else
    rm -f protect.err
    log "default branch protection requested (no force, reviews object present)."
  fi
fi

if [[ -n "${projection_url}" ]]; then
  git remote add projection "${projection_url}"
  log "added remote projection (mirror/FF only; not pushed)"
fi

log "done. Next: open Command Center (playbooks/start-project.md). Do not implement yet."
log "worktrees: ${dest}/.worktrees/"
git remote -v || true
