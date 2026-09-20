#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

bash -n "${root}/scripts/share-export.sh" || fail 'share-export.sh does not parse'
bash -n "${root}/scripts/lib/share-export-denylist.sh" || fail 'denylist lib does not parse'
pass 'share-export scripts parse'

# --- fixture: a bound business repo ---
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
  "${src}/.github/PULL_REQUEST_TEMPLATE" \
  "${src}/.github/workflows" \
  "${src}/src"

printf 'ops snapshot\n' > "${src}/.agent-project-ops/PRINCIPLES.md"
printf 'wrapper\n' > "${src}/.agents/skills/x/SKILL.md"
printf 'wrapper\n' > "${src}/.claude/skills/x/SKILL.md"
printf 'cursor\n' > "${src}/.cursor/rules/agent-project-ops.mdc"
printf 'continue\n' > "${src}/.continue/rules/agent-project-ops.md"
printf 'hook\n' > "${src}/.githooks/pre-push"
printf 'phase template\n' > "${src}/.github/ISSUE_TEMPLATE/phase.md"
printf 'impl template\n' > "${src}/.github/PULL_REQUEST_TEMPLATE/implementation.md"
printf '* @owner\n' > "${src}/.github/CODEOWNERS"
printf 'copilot\n' > "${src}/.github/copilot-instructions.md"
printf 'name: ci\n' > "${src}/.github/workflows/ci.yml"
printf 'agents binding\n' > "${src}/AGENTS.md"
printf '@AGENTS.md\n' > "${src}/CLAUDE.md"
printf 'read: AGENTS.md\n' > "${src}/.aider.conf.yml"
printf 'product\n' > "${src}/src/app.py"
printf 'readme\n' > "${src}/README.md"

git -C "${src}" add -A
git -C "${src}" commit -q -m 'bound business fixture'

# --check must fail closed on a bound tree (unfiltered push would leak ops).
if bash "${root}/scripts/share-export.sh" --dir "${src}" --check >/dev/null 2>&1; then
  fail '--check passed on a bound repository'
fi
pass '--check fails closed when denylist paths are present'

# --dry-run lists excludes and does not write.
dry_out="${tmp}/dry.out"
bash "${root}/scripts/share-export.sh" --dir "${src}" --dry-run >"${dry_out}"
grep -q 'exclude AGENTS.md' "${dry_out}" || fail 'dry-run did not exclude AGENTS.md'
grep -q 'exclude .githooks/pre-push' "${dry_out}" || fail 'dry-run did not exclude .githooks'
grep -q 'include src/app.py' "${dry_out}" || fail 'dry-run did not include product file'
grep -q 'include .github/workflows/ci.yml' "${dry_out}" || fail 'dry-run dropped business CI workflow'
grep -q 'exclude .github/CODEOWNERS' "${dry_out}" || fail 'dry-run did not exclude CODEOWNERS'
pass 'dry-run splits denylist vs business files and keeps workflows'

# Filtered --out repo.
out="${tmp}/export"
bash "${root}/scripts/share-export.sh" --dir "${src}" --out "${out}"
[[ -f "${out}/src/app.py" ]] || fail 'product file missing from export'
[[ -f "${out}/README.md" ]] || fail 'README missing from export'
[[ -f "${out}/.github/workflows/ci.yml" ]] || fail 'business workflow missing from export'
[[ ! -e "${out}/AGENTS.md" ]] || fail 'AGENTS.md leaked into export'
[[ ! -e "${out}/CLAUDE.md" ]] || fail 'CLAUDE.md leaked into export'
[[ ! -e "${out}/.aider.conf.yml" ]] || fail '.aider.conf.yml leaked into export'
[[ ! -e "${out}/.agent-project-ops" ]] || fail '.agent-project-ops leaked into export'
[[ ! -e "${out}/.agents" ]] || fail '.agents leaked into export'
[[ ! -e "${out}/.claude" ]] || fail '.claude leaked into export'
[[ ! -e "${out}/.cursor" ]] || fail '.cursor leaked into export'
[[ ! -e "${out}/.continue" ]] || fail '.continue leaked into export'
[[ ! -e "${out}/.githooks" ]] || fail '.githooks leaked into export'
[[ ! -e "${out}/.github/CODEOWNERS" ]] || fail 'CODEOWNERS leaked into export'
[[ ! -e "${out}/.github/copilot-instructions.md" ]] || fail 'copilot instructions leaked into export'
[[ ! -e "${out}/.github/ISSUE_TEMPLATE" ]] || fail 'ISSUE_TEMPLATE leaked into export'
[[ ! -e "${out}/.github/PULL_REQUEST_TEMPLATE" ]] || fail 'PULL_REQUEST_TEMPLATE leaked into export'
pass 'export strips denylist and keeps business tree + CI workflow'

bash "${root}/scripts/share-export.sh" --dir "${out}" --check >/dev/null \
  || fail '--check failed on a clean filtered export'
pass '--check passes on a filtered export'

# Unsafe push URL fails before any network.
if bash "${root}/scripts/share-export.sh" --dir "${src}" --push 'https://gitlab.example/r.git?token=secret' --yes >/dev/null 2>&1; then
  fail 'query-bearing push URL was accepted'
fi
pass 'unsafe share-export URL fails closed'

# --push to a local bare repo (first seed + second snapshot).
bare="${tmp}/colleague.git"
git init --bare -q "${bare}"
bash "${root}/scripts/share-export.sh" --dir "${src}" --push "${bare}" --yes >/dev/null
git clone -q -b main "${bare}" "${tmp}/clone1"
[[ -f "${tmp}/clone1/src/app.py" ]] || fail 'pushed export missing product file'
[[ ! -e "${tmp}/clone1/AGENTS.md" ]] || fail 'pushed export leaked AGENTS.md'
[[ -f "${tmp}/clone1/.github/workflows/ci.yml" ]] || fail 'pushed export dropped business CI'
pass 'first --push publishes a filtered seed'

printf 'product2\n' > "${src}/src/app.py"
git -C "${src}" commit -qam 'business change'
bash "${root}/scripts/share-export.sh" --dir "${src}" --push "${bare}" --yes >/dev/null
git clone -q -b main "${bare}" "${tmp}/clone2"
grep -q 'product2' "${tmp}/clone2/src/app.py" || fail 'second push did not update business file'
[[ ! -e "${tmp}/clone2/.githooks" ]] || fail 'second push leaked hooks'
pass 'second --push updates GitLab without copying ops'

# --strip-all-github drops workflows too.
stripped="${tmp}/stripped"
bash "${root}/scripts/share-export.sh" --dir "${src}" --out "${stripped}" --strip-all-github
[[ ! -e "${stripped}/.github" ]] || fail '--strip-all-github left .github'
[[ -f "${stripped}/src/app.py" ]] || fail '--strip-all-github dropped product files'
pass '--strip-all-github removes remaining .github paths'

# Refuse --out onto an existing path.
if bash "${root}/scripts/share-export.sh" --dir "${src}" --out "${out}" >/dev/null 2>&1; then
  fail '--out overwrote an existing path'
fi
pass '--out fails closed when destination exists'

echo 'share-export: all contract checks passed'
