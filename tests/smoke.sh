#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

tmp_one="$(mktemp -d /tmp/agent-kit-smoke.XXXXXX)"
tmp_two="$(mktemp -d /tmp/agent-automation-smoke.XXXXXX)"
trap 'rm -rf "${tmp_one}" "${tmp_two}"' EXIT

bash "${ROOT}/agent-kit/install.sh" "${tmp_one}" >/dev/null
node "${ROOT}/agent-automation/bin/install.js" "${tmp_two}" >/dev/null

for target in "${tmp_one}" "${tmp_two}"; do
  [ -f "${target}/agents.md" ] || { echo "[FAIL] missing agents.md in ${target}"; exit 1; }
  [ -x "${target}/scripts/agents/spawn-codex-agent.sh" ] || { echo "[FAIL] missing executable spawn script in ${target}"; exit 1; }
  [ -f "${target}/docs/agent-project-alignment.md" ] || { echo "[FAIL] missing alignment doc in ${target}"; exit 1; }
  [ -f "${target}/docs/agent-project-profile.md" ] || { echo "[FAIL] missing project profile template in ${target}"; exit 1; }
done

echo "[PASS] Installer smoke checks passed"
