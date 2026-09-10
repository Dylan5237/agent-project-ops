#!/usr/bin/env bash
# Client-side pre-push for agent-project-ops binding.
# Installed at .githooks/pre-push. Bypassable with --no-verify (not a server).
#
# stdin: <local_ref> <local_sha> <remote_ref> <remote_sha>
# args: $1 remote name, $2 remote URL
set -euo pipefail

remote_name="${1:-}"
remote_url="${2:-}"

deny() {
  echo "agent-project-ops hook: $*" >&2
  echo "This is a client hook. Server branch protection is the real gate." >&2
  echo "Do not use --no-verify to push main or to treat projection as SoT." >&2
  exit 1
}

# Never push credentials in the URL we log; only name + host-ish url.
case "${remote_url}" in
  *":@"*|*"://"*:*@*)
    deny "remote URL looks like it embeds credentials; fix the remote, do not push"
    ;;
esac

zero="0000000000000000000000000000000000000000"
default_branch="${APO_DEFAULT_BRANCH:-main}"

is_projection=0
if [[ "${remote_name}" == "projection" ]]; then
  is_projection=1
fi

while read -r local_ref local_sha remote_ref remote_sha; do
  [[ -z "${local_ref:-}" ]] && continue

  # Deletion
  if [[ "${local_sha}" == "${zero}" ]]; then
    if [[ "${remote_ref}" == "refs/heads/${default_branch}" ]]; then
      deny "refusing to delete ${default_branch} on ${remote_name}"
    fi
    continue
  fi

  if [[ "${is_projection}" -eq 1 ]]; then
    if [[ "${remote_ref}" != "refs/heads/${default_branch}" ]]; then
      deny "projection accepts only ${default_branch} (got ${remote_ref}). Topic branches push to origin."
    fi
    if [[ "${remote_sha}" != "${zero}" ]]; then
      if ! git merge-base --is-ancestor "${remote_sha}" "${local_sha}" 2>/dev/null; then
        deny "non-fast-forward to projection ${default_branch} is forbidden (projection ahead or diverged). Fail closed."
      fi
    fi
    continue
  fi

  # origin / other: do not update an existing default branch (PRs only).
  # Allow the first publish when the remote ref does not exist yet (all-zero
  # remote SHA): bootstrap `gh repo create --push`, or later `git push -u origin main`
  # after --skip-github. That is creating the authority tip, not a silent force.
  if [[ "${remote_ref}" == "refs/heads/${default_branch}" ]]; then
    if [[ "${remote_sha}" == "${zero}" ]]; then
      continue
    fi
    deny "direct push to ${default_branch} on ${remote_name} is forbidden; open a PR on GitHub (authority)"
  fi
done
