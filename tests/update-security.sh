#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmp_target="$(mktemp -d /tmp/agent-automation-update-security-target.XXXXXX)"
tmp_origin_dir="$(mktemp -d /tmp/agent-automation-update-security-origin.XXXXXX)"
tmp_source="$(mktemp -d /tmp/agent-automation-update-security-source.XXXXXX)"
trap 'rm -rf "${tmp_target}" "${tmp_origin_dir}" "${tmp_source}"' EXIT

contains_text() {
  local needle="$1"
  local haystack="$2"
  if command -v rg >/dev/null 2>&1; then
    printf '%s' "${haystack}" | rg -q "${needle}"
    return
  fi
  printf '%s' "${haystack}" | grep -Eq "${needle}"
}

git clone --bare "${ROOT}" "${tmp_origin_dir}/kit.git" >/dev/null 2>&1
git clone "${tmp_origin_dir}/kit.git" "${tmp_source}" >/dev/null 2>&1
git -C "${tmp_source}" checkout -B main >/dev/null 2>&1
git -C "${tmp_source}" push -u origin main >/dev/null 2>&1

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
contains_text "Missing required source/ref" "${missing_ref_out}" || {
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
contains_text "not an immutable commit SHA or tag" "${unpinned_out}" || {
  echo "[FAIL] expected unpinned-ref failure message"
  exit 1
}

sha="$(git -C "${tmp_source}" rev-parse HEAD)"
"${UPDATE_SCRIPT}" "${tmp_source}" "${sha}" --dry-run >/dev/null

AGENT_AUTOMATION_ALLOW_UNPINNED=1 "${UPDATE_SCRIPT}" "${tmp_source}" main --dry-run >/dev/null

echo "[PASS] update security checks passed"
