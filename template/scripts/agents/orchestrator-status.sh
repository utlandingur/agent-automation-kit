#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="${ROOT}/.ops/agent-runs"
HEALTH_SCRIPT="${ROOT}/scripts/agents/check-agent-health.sh"
BRIEF=0

if [ "${1:-}" = "--brief" ]; then
  BRIEF=1
fi

active_runs=0
stalled_runs=0
struggling_runs=0
completed_waiting=0
failed_runs=0
missing_runs=0

active_list=""
idle_list=""

append_line() {
  local current="$1"
  local line="$2"
  if [ -z "${current}" ]; then
    printf "%s" "${line}"
  else
    printf "%s\n%s" "${current}" "${line}"
  fi
}

if [ ! -d "${RUN_DIR}" ]; then
  if [ "${BRIEF}" -eq 1 ]; then
    echo "IDLE | active=0 | reason=no_run_directory"
    exit 0
  fi
  echo "active_runs=0"
  echo "stalled_runs=0"
  echo "struggling_runs=0"
  echo "completed_waiting=0"
  echo "failed_runs=0"
  echo "missing_runs=0"
  echo "summary=IDLE no run directory"
  exit 0
fi

pid_files_count="$(find "${RUN_DIR}" -maxdepth 1 -type f -name '*.pid' | wc -l | tr -d ' ')"
if [ "${pid_files_count}" -eq 0 ]; then
  if [ "${BRIEF}" -eq 1 ]; then
    echo "IDLE | active=0 | reason=no_pid_files"
    exit 0
  fi
  echo "active_runs=0"
  echo "stalled_runs=0"
  echo "struggling_runs=0"
  echo "completed_waiting=0"
  echo "failed_runs=0"
  echo "missing_runs=0"
  echo "summary=IDLE no pid files"
  exit 0
fi

while IFS= read -r pid_file; do
  run_name="$(basename "${pid_file}" .pid)"
  health="$("${HEALTH_SCRIPT}" "${run_name}" 2>/dev/null || true)"

  status="$(printf "%s\n" "${health}" | awk -F= '/^status=/{print $2}')"
  reason="$(printf "%s\n" "${health}" | awk -F= '/^reason=/{print $2}')"
  running="$(printf "%s\n" "${health}" | awk -F= '/^running=/{print $2}')"
  log_age="$(printf "%s\n" "${health}" | awk -F= '/^log_age_seconds=/{print $2}')"
  pid="$(printf "%s\n" "${health}" | awk -F= '/^pid=/{print $2}')"

  if [ "${running}" = "yes" ]; then
    active_runs=$((active_runs + 1))
    active_list="$(append_line "${active_list}" "${run_name}|status=${status}|reason=${reason}|pid=${pid}|log_age_s=${log_age}")"
  else
    idle_list="$(append_line "${idle_list}" "${run_name}|status=${status}|reason=${reason}")"
  fi

  case "${status}" in
    stalled) stalled_runs=$((stalled_runs + 1)) ;;
    struggling) struggling_runs=$((struggling_runs + 1)) ;;
    completed_ready|completed_needs_commit|completed_no_commit) completed_waiting=$((completed_waiting + 1)) ;;
    failed) failed_runs=$((failed_runs + 1)) ;;
    missing) missing_runs=$((missing_runs + 1)) ;;
  esac
done < <(find "${RUN_DIR}" -maxdepth 1 -type f -name '*.pid' | sort)

if [ "${BRIEF}" -eq 1 ]; then
  if [ "${active_runs}" -gt 0 ]; then
    echo "ACTIVE | active=${active_runs} stalled=${stalled_runs} struggling=${struggling_runs} completed_waiting=${completed_waiting}"
  else
    echo "IDLE | active=0 stalled=${stalled_runs} struggling=${struggling_runs} completed_waiting=${completed_waiting}"
  fi
  exit 0
fi

echo "active_runs=${active_runs}"
echo "stalled_runs=${stalled_runs}"
echo "struggling_runs=${struggling_runs}"
echo "completed_waiting=${completed_waiting}"
echo "failed_runs=${failed_runs}"
echo "missing_runs=${missing_runs}"
if [ "${active_runs}" -gt 0 ]; then
  echo "summary=ACTIVE"
else
  echo "summary=IDLE"
fi
if [ -n "${active_list}" ]; then
  echo "active_details<<EOF"
  printf "%s\n" "${active_list}"
  echo "EOF"
fi
if [ -n "${idle_list}" ]; then
  echo "idle_details<<EOF"
  printf "%s\n" "${idle_list}"
  echo "EOF"
fi
