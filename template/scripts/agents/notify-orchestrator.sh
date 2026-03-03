#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVENT=""
RUN_NAME=""
ATTEMPT=""
EXIT_CODE=""
RUNTIME_SECONDS=""
HAS_LAST_MESSAGE=""
PID_FILE=""
LOG_FILE=""
LAST_FILE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --event) EVENT="${2:-}"; shift 2 ;;
    --run-name) RUN_NAME="${2:-}"; shift 2 ;;
    --attempt) ATTEMPT="${2:-}"; shift 2 ;;
    --exit-code) EXIT_CODE="${2:-}"; shift 2 ;;
    --runtime-seconds) RUNTIME_SECONDS="${2:-}"; shift 2 ;;
    --has-last-message) HAS_LAST_MESSAGE="${2:-}"; shift 2 ;;
    --pid-file) PID_FILE="${2:-}"; shift 2 ;;
    --log-file) LOG_FILE="${2:-}"; shift 2 ;;
    --last-file) LAST_FILE="${2:-}"; shift 2 ;;
    *) shift 1 ;;
  esac
done

if [ -z "${RUN_NAME}" ] || [ -z "${EVENT}" ]; then
  exit 0
fi

INBOX_DIR="${ROOT}/.ops/orchestrator/inbox"
EVENTS_FILE="${ROOT}/.ops/orchestrator/events.jsonl"
mkdir -p "${INBOX_DIR}"

health="$(bash "${ROOT}/scripts/agents/check-agent-health.sh" "${RUN_NAME}" 2>/dev/null || true)"
status="$(printf "%s\n" "${health}" | awk -F= '/^status=/{print $2}')"
reason="$(printf "%s\n" "${health}" | awk -F= '/^reason=/{print $2}')"
dirty="$(printf "%s\n" "${health}" | awk -F= '/^dirty_changes=/{print $2}')"
ahead="$(printf "%s\n" "${health}" | awk -F= '/^commits_ahead_of_main=/{print $2}')"

ts_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
ts_file="$(date -u +"%Y%m%d-%H%M%S")"
ticket_id="${RUN_NAME%%-*}"

next_action="inspect_and_decide"
if [ "${status}" = "completed_needs_commit" ]; then
  next_action="commit_and_pr"
elif [ "${status}" = "completed_no_commit" ]; then
  next_action="relaunch_or_manual_finish"
elif [ "${status}" = "failed" ] || [ "${status}" = "missing" ]; then
  next_action="relaunch_and_unblock"
fi

cat > "${INBOX_DIR}/${ts_file}-${RUN_NAME}.md" <<EOF
# Agent Event
- time: ${ts_utc}
- run: ${RUN_NAME}
- ticket: ${ticket_id}
- event: ${EVENT}
- attempt: ${ATTEMPT}
- exit_code: ${EXIT_CODE}
- runtime_seconds: ${RUNTIME_SECONDS}
- has_last_message: ${HAS_LAST_MESSAGE}
- status: ${status}
- reason: ${reason}
- commits_ahead_of_main: ${ahead}
- dirty_changes: ${dirty}
- next_action: ${next_action}
- pid_file: ${PID_FILE}
- log_file: ${LOG_FILE}
- last_file: ${LAST_FILE}
EOF

printf '{"time":"%s","run":"%s","event":"%s","status":"%s","reason":"%s","dirty_changes":"%s","commits_ahead_of_main":"%s","next_action":"%s"}\n' \
  "${ts_utc}" "${RUN_NAME}" "${EVENT}" "${status}" "${reason}" "${dirty}" "${ahead}" "${next_action}" >> "${EVENTS_FILE}"

# Keep orchestrator snapshot fresh for immediate handoff.
if [ -x "${ROOT}/scripts/agents/orchestrator-context-compress.sh" ]; then
  "${ROOT}/scripts/agents/orchestrator-context-compress.sh" >/dev/null 2>&1 || true
fi

# Local desktop nudge when available.
if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"${status} (${reason})\" with title \"Agent ${RUN_NAME}\" subtitle \"${EVENT}\"" >/dev/null 2>&1 || true
fi

exit 0
