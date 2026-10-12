#!/usr/bin/env bash
# Read-only diagnostic; never fetches, writes git config, or modifies project files.
set -euo pipefail
target="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) [[ $# -ge 2 ]] || { echo "--dir requires a path" >&2; exit 2; }; target="$2"; shift 2 ;;
    -h|--help) echo "usage: bash doctor.sh [--dir PATH]"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

failed=0
emit() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3"
  [[ "$1" != FAIL ]] || failed=1
}
root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" || {
  emit FAIL REPO_MISSING "Not inside a Git repository."
  exit 1
}

[[ -f "$root/AGENTS.md" ]] && emit PASS AGENT_BINDING_PRESENT "Root AGENTS.md found." ||
  emit FAIL AGENT_BINDING_MISSING "Root AGENTS.md missing; inspect adoption before writing."

pin="$root/.agent-project-ops/PIN"
if [[ -f "$pin" ]]; then
  sha="$(sed -n 's/^sha=//p' "$pin" | head -1)"
  url="$(sed -n 's/^url=//p' "$pin" | head -1)"
  if [[ "$sha" =~ ^[A-Fa-f0-9]{40}([A-Fa-f0-9]{24})?$ && -n "$url" ]]; then
    emit PASS PIN_FORMAT_OK "Pinned methodology SHA and URL recorded."
  else
    emit FAIL PIN_INVALID "PIN must contain a real 40/64-character commit SHA and a nonempty URL."
  fi
else
  if [[ -f "$root/PRINCIPLES.md" && -d "$root/skills" ]]; then
    emit WARN SELF_METHODOLOGY_REPO "Methodology self-binding uses local PRINCIPLES, not a nested PIN."
  else
    emit FAIL PIN_MISSING "Pinned methodology not found."
  fi
fi

registry="$root/.agent-project-ops/remotes"
if [[ -f "$registry" ]]; then
  authority="$(sed -n 's/^authority=//p' "$registry" | head -1)"
  if [[ "$authority" == origin ]] && git -C "$root" remote get-url origin >/dev/null 2>&1; then
    emit PASS AUTHORITY_ORIGIN "Configured sole write authority is GitHub origin (URL not externally verified)."
  else
    emit FAIL AUTHORITY_INVALID "Expected authority=origin with a configured origin remote."
  fi

  projections="$(sed -n 's/^projection=//p' "$registry" | head -1)"
  exports="$(sed -n 's/^export=//p' "$registry" | head -1)"
  shared="$(sed -n 's/^share_export=//p' "$registry" | head -1)"
  allowed="$(printf '%s\n' "$projections" "$exports" "$shared" | tr ',' '\n' | grep -v -e '^$' -e '^(none)' || true)"
  while IFS= read -r remote; do
    [[ -n "$remote" ]] || continue
    [[ "$remote" != origin ]] || continue
    if printf '%s\n' "$allowed" | grep -Fxq "$remote"; then
      emit PASS REMOTE_CLASSIFIED "Additional remote '$remote' has a declared role."
    else
      emit FAIL REMOTE_UNCLASSIFIED "Unregistered remote '$remote'; do not push until classified."
    fi
  done < <(git -C "$root" remote)
else
  emit FAIL REMOTE_REGISTRY_MISSING "Clone-portable remote classification missing."
fi

hook="$(git -C "$root" config --get core.hooksPath 2>/dev/null || true)"
if [[ "$hook" == .githooks && -x "$root/.githooks/pre-push" ]]; then
  emit PASS HOOK_INSTALLED "Local tracked pre-push hook is active (bypassable)."
else
  emit WARN HOOK_INACTIVE "Local hook not active. Follow pinned install-hooks guidance; never claim this is server protection."
fi

emit UNKNOWN SERVER_PROTECTION_NOT_CHECKED "Read-only local scan cannot prove GitHub A/B/C protection or independent human identity."
emit UNKNOWN CONTROL_PLANE_NOT_CHECKED "Live GitHub Issues, PRs and acceptance evidence require separate read-only inspection."
exit "$failed"
