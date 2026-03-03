#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKG_ROOT="${ROOT}/agent-automation"

command -v npm >/dev/null 2>&1 || { echo "[FAIL] npm is required"; exit 1; }
command -v npx >/dev/null 2>&1 || { echo "[FAIL] npx is required"; exit 1; }

pushd "${PKG_ROOT}" >/dev/null
pkg_tgz="$(npm pack --silent | tail -n1)"
popd >/dev/null

tmp_target="$(mktemp -d /tmp/agent-automation-npx.XXXXXX)"
trap 'rm -rf "${tmp_target}" "${PKG_ROOT}/${pkg_tgz}"' EXIT

npx --yes --package "${PKG_ROOT}/${pkg_tgz}" agent-automation-install "${tmp_target}" >/dev/null

[ -f "${tmp_target}/agents.md" ] || { echo "[FAIL] npx install missing agents.md"; exit 1; }
[ -x "${tmp_target}/scripts/agents/ship-pr.sh" ] || { echo "[FAIL] npx install missing executable scripts"; exit 1; }
[ -f "${tmp_target}/.agent-automation/state.json" ] || { echo "[FAIL] install did not write state file"; exit 1; }

npx --yes --package "${PKG_ROOT}/${pkg_tgz}" agent-automation-update "${tmp_target}" --check >/dev/null

echo "# local edit" >>"${tmp_target}/agents.md"
set +e
update_output="$(npx --yes --package "${PKG_ROOT}/${pkg_tgz}" agent-automation-update "${tmp_target}" 2>&1)"
update_rc=$?
set -e
[ "${update_rc}" -eq 3 ] || {
  echo "[FAIL] expected update exit code 3 on conflict, got ${update_rc}"
  exit 1
}
printf '%s' "${update_output}" | rg -q "\\[CONFLICT\\] agents.md \\(locally modified\\)" || {
  echo "[FAIL] expected conflict preservation for locally edited agents.md"
  exit 1
}
tail -n1 "${tmp_target}/agents.md" | rg -q "# local edit" || {
  echo "[FAIL] local modifications were overwritten unexpectedly"
  exit 1
}

set +e
npx --yes --package "${PKG_ROOT}/${pkg_tgz}" agent-automation-update "${tmp_target}" --check >/dev/null 2>&1
check_rc=$?
set -e
[ "${check_rc}" -eq 2 ] || {
  echo "[FAIL] expected --check to fail with exit code 2 when drift/conflicts exist; got ${check_rc}"
  exit 1
}

echo "[PASS] npm pack + npx install simulation passed"
