#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmp_target="$(mktemp -d /tmp/agent-automation-update-security-target.XXXXXX)"
tmp_origin_dir="$(mktemp -d /tmp/agent-automation-update-security-origin.XXXXXX)"
tmp_source="$(mktemp -d /tmp/agent-automation-update-security-source.XXXXXX)"
trap 'rm -rf "${tmp_target}" "${tmp_origin_dir}" "${tmp_source}"' EXIT

git clone --bare "${ROOT}" "${tmp_origin_dir}/kit.git" >/dev/null 2>&1
git clone "${tmp_origin_dir}/kit.git" "${tmp_source}" >/dev/null 2>&1

node "${ROOT}/bin/install.js" "${tmp_target}" >/dev/null

UPDATE_SCRIPT="${tmp_target}/scripts/agents/update-agent-automation.sh"
[ -x "${UPDATE_SCRIPT}" ] || { echo "[FAIL] update helper missing in target install"; exit 1; }

set +e
missing_ref_out="$(${UPDATE_SCRIPT} "${tmp_source}" 2>&1)"
missing_ref_rc=$?
set -e
[ "${missing_ref_rc}" -ne 0 ] || {
  echo "[FAIL] expected missing-ref invocation to fail"
  exit 1
}
printf '%s' "${missing_ref_out}" | rg -q "Missing required source/ref" || {
  echo "[FAIL] expected missing-ref failure message"
  exit 1
}

set +e
unpinned_out="$(${UPDATE_SCRIPT} "${tmp_source}" main --dry-run 2>&1)"
unpinned_rc=$?
set -e
[ "${unpinned_rc}" -ne 0 ] || {
  echo "[FAIL] expected unpinned branch ref to fail by default"
  exit 1
}
printf '%s' "${unpinned_out}" | rg -q "not an immutable commit SHA or tag" || {
  echo "[FAIL] expected unpinned-ref failure message"
  exit 1
}

sha="$(git -C "${tmp_source}" rev-parse HEAD)"
"${UPDATE_SCRIPT}" "${tmp_source}" "${sha}" --dry-run >/dev/null

AGENT_AUTOMATION_ALLOW_UNPINNED=1 "${UPDATE_SCRIPT}" "${tmp_source}" main --dry-run >/dev/null

echo "[PASS] update security checks passed"
