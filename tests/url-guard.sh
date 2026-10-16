#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "${root}/scripts/lib/url-guard.sh"

fails=0
check() {
  local expected="$1" url="$2" label="$3"
  local got='safe'
  if url_has_secrets "${url}"; then got='unsafe'; fi
  if [[ "${got}" == "${expected}" ]]; then
    printf 'PASS  %s\n' "${label}"
  else
    printf 'FAIL  %s expected=%s got=%s url=%s\n' "${label}" "${expected}" "${got}" "${url}" >&2
    fails=$((fails + 1))
  fi
}

check unsafe 'https://user:pass@github.com/o/r.git' 'http basic credential'
check unsafe 'https://ghp_AAA111@github.com/o/r.git' 'GitHub token prefix'
check unsafe 'https://gitlab.example/x.git?access_token=abc' 'query-string token'
check unsafe 'https://gitlab.example/x.git?private_token=abc' 'query string'
check unsafe 'https://gitlab.example/x.git?anything=abc' 'all canonical git URL queries fail closed'
check safe 'https://github.com/o/r.git' 'plain https'
check safe 'ssh://git@github.com/o/r.git' 'ssh scheme'
check safe 'git@github.com:o/r.git' 'scp-like ssh'

identity() {
  local expected="$1" url="$2" got
  got="$(github_repo_identity "$url" || true)"
  if [[ "$got" == "$expected" ]]; then
    printf 'PASS  GitHub identity: %s\n' "$url"
  else
    printf 'FAIL  GitHub identity expected=%s got=%s\n' "$expected" "$got" >&2
    fails=$((fails + 1))
  fi
}
identity o/r 'https://github.com/O/R.git'
identity o/r 'ssh://git@github.com/o/r/'
identity o/r 'git@github.com:o/r.git'
for url in 'https://user@github.com/o/r.git' 'https://github.com/o/r?x=1' 'ssh://git@github.com/o/r#x' \
  'http://github.com/o/r.git' 'https://github.com:443/o/r.git' 'git@elsewhere.invalid:o/r.git' \
  'https://github.com/o/../r' 'https://github.com/o/..' 'https://github.com/./r' \
  'https://github.com/o/.git' 'https://github.com/o/r//'; do
  identity '' "$url"
done

[[ "${fails}" -eq 0 ]]
