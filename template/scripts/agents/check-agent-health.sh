#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <ticket-slug-prefix>"
  echo "Example: $0 T009-foundation-hardening"
  exit 1
fi

PREFIX="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="${ROOT}/.ops/agent-runs"
DEFAULT_WORKTREE_ROOT="$(cd "${ROOT}/.." && pwd)/agent-worktrees"
WORKTREE_ROOT="${AGENT_WORKTREE_ROOT:-${DEFAULT_WORKTREE_ROOT}}"

PID_FILE="${RUN_DIR}/${PREFIX}.pid"
LOG_FILE="${RUN_DIR}/${PREFIX}.log"
LAST_FILE="${RUN_DIR}/${PREFIX}.last.txt"

running="no"
pid=""
if [ -f "${PID_FILE}" ]; then
  pid="$(cat "${PID_FILE}")"
  if [ -n "${pid}" ] && ps -p "${pid}" >/dev/null 2>&1; then
    running="yes"
  fi
fi

log_size=0
log_mtime=0
if [ -f "${LOG_FILE}" ]; then
  log_size="$(wc -c < "${LOG_FILE}")"
  log_mtime="$(stat -f %m "${LOG_FILE}")"
fi

now="$(date +%s)"
age_s=0
if [ "${log_mtime}" -gt 0 ]; then
  age_s=$(( now - log_mtime ))
fi

attempts=0
stream_errors=0
exec_begins=0
exec_ends=0
agent_msgs=0
token_counts=0

if [ -f "${LOG_FILE}" ]; then
  count_or_zero() {
    local pattern file count
    pattern="$1"
    file="$2"
    count="$(rg -c "${pattern}" "${file}" 2>/dev/null || true)"
    if [ -z "${count}" ]; then
      echo 0
    else
      echo "${count}"
    fi
  }
  attempts="$(count_or_zero "\\[agent-supervisor\\].*launch attempt" "${LOG_FILE}")"
  stream_errors="$(count_or_zero "\"type\":\"stream_error\"" "${LOG_FILE}")"
  exec_begins="$(count_or_zero "\"type\":\"exec_command_begin\"" "${LOG_FILE}")"
  exec_ends="$(count_or_zero "\"type\":\"exec_command_end\"" "${LOG_FILE}")"
  agent_msgs="$(count_or_zero "\"type\":\"agent_message\"" "${LOG_FILE}")"
  token_counts="$(count_or_zero "\"type\":\"token_count\"" "${LOG_FILE}")"
fi

last_size=0
if [ -f "${LAST_FILE}" ]; then
  last_size="$(wc -c < "${LAST_FILE}")"
fi

worktree_dir="${WORKTREE_ROOT}/${PREFIX}"
commits_ahead=0
dirty_changes=0
if [ -d "${worktree_dir}" ]; then
  commits_ahead="$(git -C "${worktree_dir}" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)"
  dirty_changes="$(git -C "${worktree_dir}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
fi

health="unknown"
reason="insufficient_data"
if [ "${running}" = "yes" ]; then
  if [ "${age_s}" -gt 900 ]; then
    health="stalled"
    reason="no_log_updates_over_900s"
  elif [ "${exec_begins}" -gt 0 ] && [ "${exec_ends}" -gt 0 ]; then
    health="healthy"
    reason="active_exec_flow"
  elif [ "${attempts}" -gt 1 ] || [ "${stream_errors}" -gt 2 ]; then
    health="struggling"
    reason="retries_or_stream_errors"
  else
    health="starting"
    reason="startup_phase"
  fi
else
  if [ "${last_size}" -gt 0 ]; then
    if [ "${commits_ahead}" -gt 0 ] && [ "${dirty_changes}" -eq 0 ]; then
      health="completed_ready"
      reason="not_running_with_last_message_and_clean_commit"
    elif [ "${dirty_changes}" -gt 0 ]; then
      health="completed_needs_commit"
      reason="not_running_with_uncommitted_changes"
    else
      health="completed_no_commit"
      reason="not_running_with_report_but_no_branch_commit"
    fi
  else
    if [ -f "${LOG_FILE}" ]; then
      health="failed"
      reason="not_running_no_last_message"
    else
      health="missing"
      reason="no_pid_log_or_last_message"
    fi
  fi
fi

echo "status=${health}"
echo "reason=${reason}"
echo "pid=${pid}"
echo "running=${running}"
echo "attempts=${attempts}"
echo "stream_errors=${stream_errors}"
echo "exec_begins=${exec_begins}"
echo "exec_ends=${exec_ends}"
echo "agent_messages=${agent_msgs}"
echo "token_counts=${token_counts}"
echo "log_size_bytes=${log_size}"
echo "log_age_seconds=${age_s}"
echo "last_message_size_bytes=${last_size}"
echo "worktree_dir=${worktree_dir}"
echo "commits_ahead_of_main=${commits_ahead}"
echo "dirty_changes=${dirty_changes}"
