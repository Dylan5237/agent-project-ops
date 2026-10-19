#!/usr/bin/env bash
# Client-side pre-push guard for agent-project-ops.
# Bypassable with --no-verify; server-side repository policy remains the real gate.
#
# stdin: <local_ref> <local_sha> <remote_ref> <remote_sha>
# args:  $1 remote name, $2 remote URL
set -euo pipefail

remote_name="${1:-}"
remote_url="${2:-}"
zero="0000000000000000000000000000000000000000"
default_branch="${APO_DEFAULT_BRANCH:-main}"

root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "${root}" ]] || { echo "agent-project-ops hook: cannot resolve repository root" >&2; exit 1; }

deny() {
  echo "agent-project-ops hook: $*" >&2
  echo "This client hook is bypassable; do not use --no-verify to defeat project policy." >&2
  exit 1
}

# Use one URL guard implementation in both the methodology repo and generated
# business repos. Missing guard is a configuration error, not permission to push.
url_guard=""
for candidate in \
  "${root}/.agent-project-ops/scripts/lib/url-guard.sh" \
  "${root}/scripts/lib/url-guard.sh"
do
  if [[ -f "${candidate}" ]]; then
    url_guard="${candidate}"
    break
  fi
done
[[ -n "${url_guard}" ]] || deny "shared URL guard not found; reinstall/refresh agent-project-ops binding"
# shellcheck source=/dev/null
source "${url_guard}"
url_has_secrets "${remote_url}" && deny "remote URL is unsafe or may embed credentials/query tokens"

registry="${root}/.agent-project-ops/remotes"
[[ -f "${registry}" ]] || deny "remote registry missing: ${registry}; classify remotes before pushing"

authority="$(sed -n 's/^authority=//p' "${registry}" | head -1)"
[[ -n "${authority}" ]] || deny "remote registry has no authority entry"
[[ "${authority}" == "origin" ]] || deny "remote registry must name origin as the only write authority"
[[ "${remote_name}" == "origin" ]] || \
  deny "only GitHub origin is an allowed push target; legacy remote-role entries do not authorize '${remote_name}'"

origin_identity="$(github_origin_identity "$root")" || \
  deny "origin fetch/push URLs must resolve to the same supported GitHub repository"
push_identity="$(github_repo_identity "$remote_url")" || \
  deny "actual push URL is not a supported GitHub repository URL"
[[ "$push_identity" == "$origin_identity" ]] || \
  deny "actual push destination differs from the GitHub origin repository"

# Selected-layout repositories verify the generated bindings on every push.
# The methodology's self-dogfood checkout has no vendored descriptor.
if [[ -f "$root/.agent-project-ops/templates/project-options.json" || -f "$root/.agent-project-ops/scripts/project-settings.py" ]]; then
  checker="$root/.agent-project-ops/scripts/project-settings.py"
  [[ -f "$checker" ]] || deny "project settings checker missing"
  command -v python3 >/dev/null || deny "python3 required for binding checks"
  python3 "$checker" check --root "$root" || deny "project bindings differ from selected settings"
  python3 "$checker" check-core --root "$root" || deny "project core contract failed"
fi

while read -r local_ref local_sha remote_ref remote_sha; do
  [[ -z "${local_ref:-}" ]] && continue

  # Default branch deletion is forbidden on every registered remote.
  if [[ "${local_sha}" == "${zero}" ]]; then
    if [[ "${remote_ref}" == "refs/heads/${default_branch}" ]]; then
      deny "refusing to delete ${default_branch} on ${remote_name}"
    fi
    continue
  fi

  # Topic branches may be pushed to origin. Bootstrap may create the authority
  # default branch once; later direct updates must go through PRs.
  if [[ "${remote_ref}" == "refs/heads/${default_branch}" ]]; then
    if [[ "${remote_sha}" == "${zero}" ]]; then
      continue
    fi
    deny "direct push to ${default_branch} on authority '${authority}' is forbidden; open a PR"
  fi
done
