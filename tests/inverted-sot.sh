#!/usr/bin/env bash
# Contract: inverted write-authority wording is must-fix; adoption fail-closes.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

scanner="${root}/skills/repo-reconciliation-cleanup/scripts/scan_inverted_sot.py"
wrapper="${root}/scripts/scan-inverted-sot.py"
[[ -f "${scanner}" ]] || fail "scanner missing"
[[ -f "${wrapper}" ]] || fail "wrapper missing"

python3 "${root}/skills/repo-reconciliation-cleanup/tests/test_scan_inverted_sot.py"
pass 'unit tests for find_hits / scan_root'

if ! python3 "${wrapper}" --root "${root}" >"${tmp}/methodology.out"; then
  cat "${tmp}/methodology.out" >&2
  fail 'methodology checkout rule files must stay non-inverted'
fi
pass 'methodology AGENTS.md / adapters are not inverted'

template_dir="${tmp}/template-only"
mkdir -p "${template_dir}"
cp "${root}/templates/AGENTS.md" "${template_dir}/AGENTS.md"
if ! python3 "${wrapper}" --root "${template_dir}" >"${tmp}/template.out"; then
  cat "${tmp}/template.out" >&2
  fail 'templates/AGENTS.md must be clean (correct contract)'
fi
pass 'templates/AGENTS.md is not inverted'

inverted="${tmp}/inverted-business"
mkdir -p "${inverted}"
cat > "${inverted}/AGENTS.md" <<'EOF'
GitLab is the production source of truth. GitHub is a mirror only.
EOF
set +e
python3 "${scanner}" --root "${inverted}" >"${tmp}/inverted.out"
inv_rc=$?
set -e
[[ "${inv_rc}" -eq 1 ]] || fail "inverted fixture should exit 1, got ${inv_rc}"
grep -q 'MUST-FIX' "${tmp}/inverted.out" || fail 'inverted fixture report lacks MUST-FIX'
pass 'inverted AGENTS.md is must-fix (exit 1)'

clean="${tmp}/clean-business"
mkdir -p "${clean}"
cat > "${clean}/AGENTS.md" <<'EOF'
origin (GitHub) is the only write authority.
Projection remotes are same-history mirror/FF only.
Colleague GitLab is share-export, not a projection.
Write authority tip: origin/main.
Deploy/manifest tip: projection/main — not write SoT.
EOF
python3 "${wrapper}" --root "${clean}" >"${tmp}/clean.out" || {
  cat "${tmp}/clean.out" >&2
  fail 'correct authority vs deploy-tip split should be clean'
}
pass 'write-authority tip vs deploy tip is clean'

existing="${tmp}/already-there"
mkdir -p "${existing}"
printf 'GitLab 是生产源码与部署事实源。GitHub 仅为镜像。\n' > "${existing}/AGENTS.md"
set +e
bash "${root}/scripts/bootstrap-project.sh" \
  --name already-there \
  --dir "${existing}" \
  --disposer @apo-test \
  --no-projection \
  --skip-github \
  --yes >"${tmp}/bootstrap-existing.out" 2>&1
boot_rc=$?
set -e
[[ "${boot_rc}" -ne 0 ]] || fail 'bootstrap must refuse a non-empty destination'
grep -Eq 'adopt-existing-project|inverted|MUST-FIX|not empty' "${tmp}/bootstrap-existing.out" \
  || { cat "${tmp}/bootstrap-existing.out" >&2; fail 'bootstrap refusal must name adoption / inverted SoT'; }
pass 'bootstrap fail-closes on existing dest (adoption, not greenfield)'

echo 'inverted-sot contract OK'
