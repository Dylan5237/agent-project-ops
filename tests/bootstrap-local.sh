#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

src_sha="$(git -C "${root}" rev-parse HEAD)"
dest="${tmp}/sample-project"
bootstrap_out="${tmp}/bootstrap-local.out"

root_eol="$(git -C "${root}" check-attr eol -- scripts/bootstrap-project.sh)"
[[ "${root_eol}" == *'eol: lf' ]] || fail "methodology bootstrap script is not pinned to LF: ${root_eol}"
pass 'methodology shell scripts are pinned to LF'

bash "${root}/scripts/bootstrap-project.sh" \
  --name sample-project \
  --dir "${dest}" \
  --disposer @apo-test \
  --no-projection \
  --skip-github \
  --yes >"${bootstrap_out}" 2>&1

if grep -Fq '.agent-project-ops/PRINCIPLES.md:' "${bootstrap_out}"; then
  cat "${bootstrap_out}" >&2
  fail 'bootstrap executed Markdown while rendering skill wrappers'
fi
if grep -Eq 'command not found|syntax error near unexpected token' "${bootstrap_out}"; then
  cat "${bootstrap_out}" >&2
  fail 'bootstrap emitted shell execution errors while rendering files'
fi
pass 'wrapper rendering does not execute Markdown/backticks'

[[ -d "${dest}/.git" ]] || fail 'generated git repository missing'
[[ -f "${dest}/AGENTS.md" ]] || fail 'AGENTS.md missing'
[[ -f "${dest}/CLAUDE.md" ]] || fail 'CLAUDE.md missing'
[[ -f "${dest}/.cursor/rules/agent-project-ops.mdc" ]] || fail 'Cursor rule missing'
[[ -f "${dest}/.github/copilot-instructions.md" ]] || fail 'Copilot instructions missing'
[[ -f "${dest}/.github/CODEOWNERS" ]] || fail 'CODEOWNERS missing'
[[ -f "${dest}/.agent-project-ops/PRINCIPLES.md" ]] || fail 'pinned principles missing'
[[ -f "${dest}/.agent-project-ops/scripts/install-hooks.sh" ]] || fail 'hook installer missing from snapshot'
[[ -f "${dest}/.agent-project-ops/scripts/lib/url-guard.sh" ]] || fail 'URL guard missing from snapshot'
[[ -f "${dest}/.githooks/pre-push" ]] || fail 'tracked pre-push hook missing'
[[ -f "${dest}/.gitattributes" ]] || fail '.gitattributes missing'
[[ -d "${dest}/.worktrees" ]] || fail '.worktrees local directory missing'
pass 'binding/scaffold files exist'

hook_eol="$(git -C "${dest}" check-attr eol -- .githooks/pre-push)"
install_eol="$(git -C "${dest}" check-attr eol -- .agent-project-ops/scripts/install-hooks.sh)"
[[ "${hook_eol}" == *'eol: lf' ]] || fail "generated hook is not pinned to LF: ${hook_eol}"
[[ "${install_eol}" == *'eol: lf' ]] || fail "generated shell script is not pinned to LF: ${install_eol}"
pass 'generated executable shell surfaces are pinned to LF'

pin_sha="$(sed -n 's/^sha=//p' "${dest}/.agent-project-ops/PIN")"
[[ "${pin_sha}" == "${src_sha}" ]] || fail "PIN SHA mismatch: ${pin_sha} != ${src_sha}"
[[ "${pin_sha}" != 'unknown' && "${pin_sha}" != 'local:unknown' ]] || fail 'unsupported unknown PIN emitted'
pass 'PIN carries the real methodology SHA'

[[ "$(sed -n 's/^authority=//p' "${dest}/.agent-project-ops/remotes")" == 'origin' ]] || fail 'authority registry is not origin'
[[ "$(sed -n 's/^projection=//p' "${dest}/.agent-project-ops/remotes")" == '(none)' ]] || fail 'origin-only registry incorrect'
pass 'remote registry is explicit and clone-portable'

[[ "$(git -C "${dest}" config --get core.hooksPath)" == '.githooks' ]] || fail 'bootstrap checkout hook not installed'
pass 'bootstrap checkout has core.hooksPath=.githooks'

grep -q '^\.worktrees/$' "${dest}/.gitignore" || fail '.worktrees not ignored'
grep -q '@apo-test' "${dest}/.github/CODEOWNERS" || fail 'real disposer not substituted'
if grep -q '{{DISPOSER}}\|@DISPOSER' "${dest}/.github/CODEOWNERS"; then fail 'placeholder disposer remains'; fi
pass 'gitignore and disposer substitution are correct'

wrapper="${dest}/.agents/skills/github-multi-agent-project-ops/SKILL.md"
[[ -f "${wrapper}" ]] || fail 'project skill wrapper missing'
grep -q '^name: github-multi-agent-project-ops$' "${wrapper}" || fail 'wrapper name frontmatter incorrect'
grep -Fq 'Do not invent a parallel process. `.agent-project-ops/PRINCIPLES.md` wins.' "${wrapper}" || fail 'wrapper literal methodology path missing'
[[ -f "${dest}/.claude/skills/github-multi-agent-project-ops/SKILL.md" ]] || fail 'Claude wrapper missing'
pass 'project skill wrappers are discoverable and rendered literally'

# Fresh clone: tracked hook arrives, local core.hooksPath does not.
git clone -q "${dest}" "${tmp}/clone-check"
[[ -f "${tmp}/clone-check/.githooks/pre-push" ]] || fail 'fresh clone did not receive tracked hook'
if git -C "${tmp}/clone-check" config --get core.hooksPath >/dev/null 2>&1; then
  fail 'fresh clone incorrectly inherited core.hooksPath'
fi
(
  cd "${tmp}/clone-check"
  bash .agent-project-ops/scripts/install-hooks.sh >/dev/null
)
[[ "$(git -C "${tmp}/clone-check" config --get core.hooksPath)" == '.githooks' ]] || fail 'fresh clone installer did not restore hooksPath'
pass 'fresh-clone hook installation path works'

# Placeholder disposer must fail.
if bash "${root}/scripts/bootstrap-project.sh" --name bad-disposer --dir "${tmp}/bad-disposer" --disposer @DISPOSER --no-projection --skip-github --yes >/dev/null 2>&1; then
  fail 'placeholder disposer was accepted'
fi
pass 'placeholder disposer fails closed'

# Query-bearing projection URL must fail before writing a project.
if bash "${root}/scripts/bootstrap-project.sh" --name bad-url --dir "${tmp}/bad-url" --disposer @apo-test --projection-url 'https://gitlab.example/r.git?token=secret' --skip-github --yes >/dev/null 2>&1; then
  fail 'query-bearing projection URL was accepted'
fi
pass 'unsafe projection URL fails closed'

# A non-git methodology source must not silently write sha=unknown.
mkdir -p "${tmp}/nongit/scripts/lib"
cp "${root}/scripts/bootstrap-project.sh" "${tmp}/nongit/scripts/bootstrap-project.sh"
cp "${root}/scripts/lib/url-guard.sh" "${tmp}/nongit/scripts/lib/url-guard.sh"
if bash "${tmp}/nongit/scripts/bootstrap-project.sh" --name nongit --dir "${tmp}/nongit-output" --disposer @apo-test --no-projection --skip-github --yes >/dev/null 2>&1; then
  fail 'non-git methodology source was accepted'
fi
pass 'non-git methodology source fails closed instead of sha=unknown'

echo 'bootstrap-local: all contract checks passed'
