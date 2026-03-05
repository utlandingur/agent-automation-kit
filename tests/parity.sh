#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${ROOT}/template/scripts/agents"

[ -d "${SCRIPTS_DIR}" ] || { echo "[FAIL] missing scripts directory: ${SCRIPTS_DIR}"; exit 1; }

required=(
  "spawn-codex-agent.sh"
  "ship-pr.sh"
  "promote-staging-to-main.sh"
  "usage-guard.sh"
  "update-agent-automation.sh"
  "init-project-context.sh"
  "launch-agent-daemon.py"
  "run-eval-smoke.sh"
  "export-agent-traces.sh"
  "tool-state-machine.sh"
  "context-pack.sh"
  "worktree-task.sh"
)

for file in "${required[@]}"; do
  [ -f "${SCRIPTS_DIR}/${file}" ] || { echo "[FAIL] missing required script: ${file}"; exit 1; }
  if [[ "${file}" == *.sh || "${file}" == "launch-agent-daemon.py" ]]; then
    [ -x "${SCRIPTS_DIR}/${file}" ] || { echo "[FAIL] script is not executable: ${file}"; exit 1; }
  fi
done

echo "[PASS] Template parity checks passed"
