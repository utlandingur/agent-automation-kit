#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for mode in install update; do
  tmp_target="$(mktemp -d /tmp/agent-automation-smoke.XXXXXX)"
  trap 'rm -rf "${tmp_target}"' EXIT

  if [ "${mode}" = "install" ]; then
    node "${ROOT}/bin/install.js" "${tmp_target}" >/dev/null
  else
    node "${ROOT}/bin/install.js" "${tmp_target}" --update >/dev/null
  fi

  [ -f "${tmp_target}/agents.md" ] || { echo "[FAIL] missing agents.md in ${tmp_target}"; exit 1; }
  [ -x "${tmp_target}/scripts/agents/spawn-codex-agent.sh" ] || { echo "[FAIL] missing executable spawn script in ${tmp_target}"; exit 1; }
  [ -x "${tmp_target}/scripts/agents/update-agent-automation.sh" ] || { echo "[FAIL] missing update helper script in ${tmp_target}"; exit 1; }
  [ -x "${tmp_target}/scripts/agents/tool-state-machine.sh" ] || { echo "[FAIL] missing tool state script in ${tmp_target}"; exit 1; }
  [ -x "${tmp_target}/scripts/agents/context-pack.sh" ] || { echo "[FAIL] missing context pack script in ${tmp_target}"; exit 1; }
  [ -f "${tmp_target}/docs/agent-project-alignment.md" ] || { echo "[FAIL] missing alignment doc in ${tmp_target}"; exit 1; }
  [ -f "${tmp_target}/docs/agent-project-profile.md" ] || { echo "[FAIL] missing project profile template in ${tmp_target}"; exit 1; }

  rm -rf "${tmp_target}"
done

echo "[PASS] Installer smoke checks passed"
