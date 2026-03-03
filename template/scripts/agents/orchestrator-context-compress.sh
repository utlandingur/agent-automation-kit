#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASK_DIR="${ROOT}/docs/tasks"
RUN_DIR="${ROOT}/.ops/agent-runs"
OUT_DIR="${ROOT}/.ops/orchestrator"
OUT_FILE="${OUT_DIR}/context-compact.md"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p "${OUT_DIR}"

ready_count="$(rg -l '^- Status:\s*`READY`' "${TASK_DIR}"/T*.md 2>/dev/null | wc -l | tr -d ' ')"
blocked_count="$(rg -l '^- Status:\s*`BLOCKED`' "${TASK_DIR}"/T*.md 2>/dev/null | wc -l | tr -d ' ')"

{
  echo "# Orchestrator Context (Compact)"
  echo
  echo "- Timestamp: ${TS}"
  echo "- Ready tasks: ${ready_count}"
  echo "- Blocked tasks: ${blocked_count}"
  echo
  echo "## Active Agents"

  found_active="no"
  for pid_file in "${RUN_DIR}"/*.pid; do
    [ -f "${pid_file}" ] || continue
    ticket_slug="$(basename "${pid_file}" .pid)"
    pid="$(cat "${pid_file}" 2>/dev/null || true)"
    [ -n "${pid}" ] || continue
    if ps -p "${pid}" >/dev/null 2>&1; then
      found_active="yes"
      echo "- ${ticket_slug}: running (pid ${pid})"
    fi
  done
  if [ "${found_active}" = "no" ]; then
    echo "- none"
  fi

  echo
  echo "## Recently Completed/Reported"
  ls -1t "${RUN_DIR}"/*.last.txt 2>/dev/null | head -n 8 | while read -r f; do
    [ -f "${f}" ] || continue
    size="$(wc -c < "${f}" | tr -d ' ')"
    base="$(basename "${f}" .last.txt)"
    if [ "${size}" -gt 0 ]; then
      echo "- ${base}: last message present (${size} bytes)"
    fi
  done
} > "${OUT_FILE}"

echo "Wrote ${OUT_FILE}"
