#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="${REPO_ROOT}/.ops/agent-runs"
DEFAULT_WORKTREE_ROOT="$(cd "${REPO_ROOT}/.." && pwd)/agent-worktrees"
WORKTREE_ROOT="${AGENT_WORKTREE_ROOT:-${DEFAULT_WORKTREE_ROOT}}"

STALE_AGENT_LOG_AGE_SECONDS="${STALE_AGENT_LOG_AGE_SECONDS:-1800}" # 30m
STALE_VITEST_AGE_SECONDS="${STALE_VITEST_AGE_SECONDS:-900}" # 15m
DRY_RUN="${DRY_RUN:-0}"

now_epoch="$(date +%s)"

file_mtime_epoch() {
  local file="$1"
  if stat -f %m "${file}" >/dev/null 2>&1; then
    stat -f %m "${file}"
    return 0
  fi
  stat -c %Y "${file}"
}

kill_tree() {
  local pid="$1"
  local label="$2"

  if ! ps -p "${pid}" >/dev/null 2>&1; then
    return 0
  fi

  if [ "${DRY_RUN}" = "1" ]; then
    echo "[dry-run] kill ${label} pid=${pid}"
    return 0
  fi

  # kill children first
  for child in $(pgrep -P "${pid}" 2>/dev/null || true); do
    kill -TERM "${child}" 2>/dev/null || true
  done
  sleep 1
  for child in $(pgrep -P "${pid}" 2>/dev/null || true); do
    kill -KILL "${child}" 2>/dev/null || true
  done

  kill -TERM "${pid}" 2>/dev/null || true
  sleep 1
  if ps -p "${pid}" >/dev/null 2>&1; then
    kill -KILL "${pid}" 2>/dev/null || true
  fi
  echo "killed ${label} pid=${pid}"
}

process_cwd() {
  local pid="$1"
  lsof -a -p "${pid}" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1
}

process_cmd() {
  local pid="$1"
  ps -o command= -p "${pid}" 2>/dev/null || true
}

etime_to_seconds() {
  local etime="$1"
  local days=0
  local rest="${etime}"
  local hms h m s

  if [[ "${rest}" == *-* ]]; then
    days="${rest%%-*}"
    rest="${rest#*-}"
  fi

  IFS=':' read -r -a parts <<< "${rest}"
  if [ "${#parts[@]}" -eq 3 ]; then
    h="${parts[0]}"
    m="${parts[1]}"
    s="${parts[2]}"
  elif [ "${#parts[@]}" -eq 2 ]; then
    h=0
    m="${parts[0]}"
    s="${parts[1]}"
  else
    h=0
    m=0
    s="${parts[0]:-0}"
  fi

  echo $(( days * 86400 + h * 3600 + m * 60 + s ))
}

process_age_seconds() {
  local pid="$1"
  local etime
  etime="$(ps -o etime= -p "${pid}" 2>/dev/null | tr -d ' ' || true)"
  if [ -z "${etime}" ]; then
    echo 0
    return 0
  fi
  etime_to_seconds "${etime}"
}

cleanup_agent_supervisors() {
  [ -d "${RUN_DIR}" ] || return 0

  for pid_file in "${RUN_DIR}"/*.pid; do
    [ -f "${pid_file}" ] || continue
    local pid base log_file log_mtime age_s
    pid="$(cat "${pid_file}" 2>/dev/null || true)"
    base="$(basename "${pid_file}" .pid)"
    log_file="${RUN_DIR}/${base}.log"

    if [[ -z "${pid}" ]] || ! [[ "${pid}" =~ ^[0-9]+$ ]]; then
      rm -f "${pid_file}"
      continue
    fi

    if ! ps -p "${pid}" >/dev/null 2>&1; then
      rm -f "${pid_file}"
      continue
    fi

    if [ ! -f "${log_file}" ]; then
      continue
    fi

    log_mtime="$(file_mtime_epoch "${log_file}" 2>/dev/null || echo 0)"
    age_s=0
    if [ "${log_mtime}" -gt 0 ]; then
      age_s=$((now_epoch - log_mtime))
    fi

    if [ "${age_s}" -gt "${STALE_AGENT_LOG_AGE_SECONDS}" ]; then
      kill_tree "${pid}" "stale-agent-supervisor(${base})"
      rm -f "${pid_file}"
    fi
  done
}

cleanup_stale_vitest() {
  for pid in $(pgrep -f "vitest" 2>/dev/null || true); do
    [ -n "${pid}" ] || continue
    local age_s cwd cmd
    age_s="$(process_age_seconds "${pid}")"
    if [ "${age_s}" -lt "${STALE_VITEST_AGE_SECONDS}" ]; then
      continue
    fi

    cwd="$(process_cwd "${pid}")"
    cmd="$(process_cmd "${pid}")"
    if [[ "${cwd}" == "${REPO_ROOT}"* ]] || [[ "${cwd}" == "${WORKTREE_ROOT}"* ]] || \
       [[ "${cmd}" == *"${REPO_ROOT}"* ]] || [[ "${cmd}" == *"${WORKTREE_ROOT}"* ]]; then
      kill_tree "${pid}" "stale-vitest"
    fi
  done
}

echo "cleanup_start dry_run=${DRY_RUN} stale_agent_log_age=${STALE_AGENT_LOG_AGE_SECONDS}s stale_vitest_age=${STALE_VITEST_AGE_SECONDS}s"
cleanup_agent_supervisors
cleanup_stale_vitest
echo "cleanup_done"
