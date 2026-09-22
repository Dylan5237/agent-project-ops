#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

bash -n "${root}/scripts/export-sync.sh" || fail 'export-sync.sh does not parse'
bash -n "${root}/scripts/lib/export-strip-list.sh" || fail 'export-strip-list.sh does not parse'
pass 'export-sync scripts parse'

# shellcheck source=/dev/null
source "${root}/scripts/lib/export-strip-list.sh"

for required in \
  '.agent-project-ops/' \
  '.agents/' \
  '.githooks/' \
  '.github/' \
  '.claude/' \
  '.continue/' \
  '.cursor/' \
  'AGENTS.md' \
  'CLAUDE.md' \
  '.aider.conf.yml'
do
  export_strip_print_methodology | grep -Fxq "${required}" \
    || fail "methodology strip list missing ${required}"
done
export_strip_assert_methodology_intact || fail 'methodology strip list self-check failed'
pass 'default strip list contains every methodology entry'

if export_strip_add_extra '!AGENTS.md' 2>/dev/null; then
  fail 'shrink syntax !AGENTS.md was accepted'
fi
if export_strip_add_extra '-.github/' 2>/dev/null; then
  fail 'shrink syntax -.github/ was accepted'
fi
export_strip_add_extra 'internal-secret.conf' || fail 'extra strip path was refused'
export_path_is_stripped 'internal-secret.conf' || fail 'extra strip path not effective'
export_path_is_stripped 'AGENTS.md' || fail 'methodology AGENTS.md dropped after extra add'
export_path_is_stripped '.github/workflows/ci.yml' || fail '.github/ prefix does not strip workflows'
export_strip_assert_methodology_intact || fail 'methodology entries missing after extra add'
pass 'business extras may add; shrink syntax and methodology removals fail closed'

# Reset extras for fixture work.
EXPORT_STRIP_EXTRA_PATHS=()

src="${tmp}/business"
git init -q -b main "${src}"
git -C "${src}" config user.name apo-test
git -C "${src}" config user.email apo-test@example.invalid

mkdir -p \
  "${src}/.agent-project-ops/playbooks" \
  "${src}/.agents/skills/x" \
  "${src}/.claude/skills/x" \
  "${src}/.cursor/rules" \
  "${src}/.continue/rules" \
  "${src}/.githooks" \
  "${src}/.github/ISSUE_TEMPLATE" \
  "${src}/.github/workflows" \
  "${src}/src"

printf 'ops snapshot\n' > "${src}/.agent-project-ops/PRINCIPLES.md"
printf 'wrapper\n' > "${src}/.agents/skills/x/SKILL.md"
printf 'wrapper\n' > "${src}/.claude/skills/x/SKILL.md"
printf 'cursor\n' > "${src}/.cursor/rules/agent-project-ops.mdc"
printf 'continue\n' > "${src}/.continue/rules/agent-project-ops.md"
printf 'hook\n' > "${src}/.githooks/pre-push"
printf 'phase template\n' > "${src}/.github/ISSUE_TEMPLATE/phase.md"
printf 'name: ci\n' > "${src}/.github/workflows/ci.yml"
printf 'agents binding\n' > "${src}/AGENTS.md"
printf '@AGENTS.md\n' > "${src}/CLAUDE.md"
printf 'read: AGENTS.md\n' > "${src}/.aider.conf.yml"
printf 'product\n' > "${src}/src/app.py"
printf 'readme\n' > "${src}/README.md"

git -C "${src}" add -A
git -C "${src}" commit -q -m 'bound business fixture'
auth1="$(git -C "${src}" rev-parse HEAD)"

if bash "${root}/scripts/export-sync.sh" --dir "${src}" --ref HEAD --check >/dev/null 2>&1; then
  fail '--check passed on a bound authority tree'
fi
pass '--check fails closed when strip-list paths are present'

dry_out="${tmp}/dry.out"
bash "${root}/scripts/export-sync.sh" --dir "${src}" --ref HEAD --dry-run >"${dry_out}"
grep -q 'strip AGENTS.md' "${dry_out}" || fail 'dry-run did not strip AGENTS.md'
grep -q 'strip .github/workflows/ci.yml' "${dry_out}" || fail 'dry-run kept .github/workflows (export strips all of .github/)'
grep -q 'keep src/app.py' "${dry_out}" || fail 'dry-run dropped product file'
pass 'dry-run uses the #46 strip list (including .github/)'

if bash "${root}/scripts/export-sync.sh" --dir "${src}" --ref HEAD --export-url "${tmp}/nope.git" --yes >/dev/null 2>&1; then
  fail 'push without --authorized was accepted'
fi
pass 'push without --authorized fails closed'

if bash "${root}/scripts/export-sync.sh" --dir "${src}" --ref HEAD --export-url "${tmp}/nope.git" --authorized --yes --force >/dev/null 2>&1; then
  fail '--force was accepted'
fi
pass '--force is rejected'

if bash "${root}/scripts/export-sync.sh" --dir "${src}" --ref HEAD --export-url 'https://gitlab.example/r.git?token=secret' --authorized --yes >/dev/null 2>&1; then
  fail 'query-bearing export URL was accepted'
fi
pass 'unsafe export URL fails closed'

bare="${tmp}/export.git"
git init --bare -q "${bare}"
bash "${root}/scripts/export-sync.sh" \
  --dir "${src}" --ref HEAD --export-url "${bare}" --authorized --yes >/dev/null
git clone -q -b main "${bare}" "${tmp}/clone1"
[[ -f "${tmp}/clone1/src/app.py" ]] || fail 'seed export missing product file'
[[ -f "${tmp}/clone1/README.md" ]] || fail 'seed export missing README'
[[ ! -e "${tmp}/clone1/AGENTS.md" ]] || fail 'seed leaked AGENTS.md'
[[ ! -e "${tmp}/clone1/.agent-project-ops" ]] || fail 'seed leaked .agent-project-ops'
[[ ! -e "${tmp}/clone1/.githooks" ]] || fail 'seed leaked .githooks'
[[ ! -e "${tmp}/clone1/.github" ]] || fail 'seed leaked .github (including workflows)'
[[ ! -e "${tmp}/clone1/.cursor" ]] || fail 'seed leaked .cursor'
export1="$(git -C "${tmp}/clone1" rev-parse HEAD)"
[[ "${export1}" != "${auth1}" ]] || fail 'seed tip should be ahead of authority after strip commit'
git -C "${tmp}/clone1" merge-base --is-ancestor "${auth1}" "${export1}" \
  || fail 'seed history is not based on authority'
pass 'seed publishes authority − strip list and is legitimately ahead'

printf 'product2\n' > "${src}/src/app.py"
mkdir -p "${src}/.cursor/rules"
printf 'new cursor\n' > "${src}/.cursor/rules/new.mdc"
printf 'secret\n' > "${src}/internal-secret.conf"
git -C "${src}" add -A
git -C "${src}" commit -q -m 'authority advanced with product + strip-list + extra'
auth2="$(git -C "${src}" rev-parse HEAD)"

bash "${root}/scripts/export-sync.sh" \
  --dir "${src}" --ref HEAD --export-url "${bare}" \
  --extra-strip internal-secret.conf \
  --authorized --yes >/dev/null
git clone -q -b main "${bare}" "${tmp}/clone2"
grep -q 'product2' "${tmp}/clone2/src/app.py" || fail 'sync did not fast-forward product content'
[[ ! -e "${tmp}/clone2/.cursor" ]] || fail 'sync left newly introduced .cursor path'
[[ ! -e "${tmp}/clone2/internal-secret.conf" ]] || fail 'sync left extra strip path'
[[ ! -e "${tmp}/clone2/.github" ]] || fail 'sync reintroduced .github'
export2="$(git -C "${tmp}/clone2" rev-parse HEAD)"
git -C "${tmp}/clone2" merge-base --is-ancestor "${export1}" "${export2}" \
  || fail 'second sync was not a fast-forward of the previous export tip'
[[ "${export2}" != "${auth2}" ]] || fail 'export tip should remain ahead after replay-strip commit'
pass 'sync replays strip on the export tip and FF-pushes (content does not lag)'

# Wrong workflow: reset to authority and strip would not be FF of export tip.
wrong="${tmp}/wrong"
git clone -q -b main "${bare}" "${wrong}"
git -C "${wrong}" checkout -q -B main "${auth2}"
rm -rf \
  "${wrong}/.agent-project-ops" \
  "${wrong}/.agents" \
  "${wrong}/.githooks" \
  "${wrong}/.github" \
  "${wrong}/.claude" \
  "${wrong}/.continue" \
  "${wrong}/.cursor"
rm -f "${wrong}/AGENTS.md" "${wrong}/CLAUDE.md" "${wrong}/.aider.conf.yml" "${wrong}/internal-secret.conf"
git -C "${wrong}" add -A
git -C "${wrong}" -c user.name=apo-test -c user.email=apo-test@example.invalid \
  commit -q -m 'wrong: strip from origin/main'
if git -C "${wrong}" push origin HEAD:refs/heads/main >/dev/null 2>&1; then
  fail 'non-FF reset-to-authority strip was accepted (force/non-FF hole)'
fi
pass 'non-FF (reset to origin/main, dropping export strip commits) is rejected; no force'

echo 'export-sync: all contract checks passed'
