#!/usr/bin/env bash
# Test-only network boundary. Guard/config queries use real Git unchanged;
# only transport subprocesses receive a temporary URL mapping to fixture bare
# repos. Production code has no test-mode switch or authority bypass.
export WT_REAL_GIT="$(type -P git)"
export WT_FIXTURE_ROOT="$tmp"
if command -v cygpath >/dev/null 2>&1; then
  export WT_FIXTURE_GIT_ROOT="$(cygpath -m "$tmp")"
else
  export WT_FIXTURE_GIT_ROOT="$(cd "$tmp" && pwd -P)"
fi

git() {
  local -a argv=("$@") prefix=()
  local index=0 sub root map nominal url target="" item resolved
  while [[ "$index" -lt "${#argv[@]}" ]]; do
    case "${argv[$index]}" in
      -C|-c|--git-dir|--work-tree) prefix+=("${argv[$index]}" "${argv[$((index + 1))]}"); index=$((index + 2)) ;;
      --git-dir=*|--work-tree=*|--no-pager) prefix+=("${argv[$index]}"); index=$((index + 1)) ;;
      *) break ;;
    esac
  done
  sub="${argv[$index]:-}"
  case "$sub" in
    fetch|push|ls-remote)
      if [[ -n "${WT_NETWORK_LOG:-}" ]]; then printf '%s\n' "$sub" >> "$WT_NETWORK_LOG"; fi
      [[ "${WT_DENY_NETWORK:-0}" != 1 ]] || return 97
      # Fixtures use the named origin only. An explicit URL or an unrecognised
      # option/value layout must never escape to the real network.
      for item in "${argv[@]:$((index + 1))}"; do
        [[ "$item" == -* ]] && continue
        target="$item"; break
      done
      [[ "$target" == origin ]] || return 97
      root="$("$WT_REAL_GIT" "${prefix[@]}" rev-parse --show-toplevel 2>/dev/null)" || return 97
      map="$("$WT_REAL_GIT" -C "$root" config --get apo-test.transport || true)"
      nominal="$("$WT_REAL_GIT" -C "$root" config --get apo-test.transport-url || true)"
      if [[ -n "$map" && -n "$nominal" ]] \
        && [[ "$map" == "$WT_FIXTURE_ROOT/"* || "$map" == "$WT_FIXTURE_GIT_ROOT/"* ]]; then
        # Prove every effective child transport URL is the fixture bare path.
        # SSH pushurl, extra URLs or competing rewrites are refused, not leaked.
        resolved="$("$WT_REAL_GIT" -c "url.$map.insteadOf=$nominal" "${prefix[@]}" remote get-url --all origin)" || return 97
        while IFS= read -r url; do [[ "$url" == "$map" ]] || return 97; done <<< "$resolved"
        resolved="$("$WT_REAL_GIT" -c "url.$map.insteadOf=$nominal" "${prefix[@]}" remote get-url --push --all origin)" || return 97
        while IFS= read -r url; do [[ "$url" == "$map" ]] || return 97; done <<< "$resolved"
        "$WT_REAL_GIT" -c "url.$map.insteadOf=$nominal" "${argv[@]}"
        return $?
      fi
      url="$("$WT_REAL_GIT" -C "$root" remote get-url origin 2>/dev/null)" || return 97
      [[ "$url" == "$WT_FIXTURE_ROOT/"* || "$url" == "$WT_FIXTURE_GIT_ROOT/"* ]] || return 97
      ;;
  esac
  "$WT_REAL_GIT" "${argv[@]}"
}
export -f git

worktree_test_bind() {
  "$WT_REAL_GIT" -C "$1" config apo-test.transport "$2"
  "$WT_REAL_GIT" -C "$1" config apo-test.transport-url "$3"
  "$WT_REAL_GIT" -C "$1" remote set-url origin "$3"
}
