#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="${ROOT}/.ops/agent-runs"
OUT_DIR="${ROOT}/.ops/evals"
OUT_JSON="${OUT_DIR}/latest.json"
OUT_MD="${OUT_DIR}/latest.md"
REQUIRE_RUNS=0
MAX_STREAM_ERRORS=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --require-runs)
      REQUIRE_RUNS=1
      ;;
    --max-stream-errors)
      shift
      MAX_STREAM_ERRORS="${1:-}"
      ;;
    -h|--help)
      cat <<'EOF_HELP'
Usage: scripts/agents/run-eval-smoke.sh [--require-runs] [--max-stream-errors <n>]

Generates lightweight run-quality metrics from .ops/agent-runs and writes:
- .ops/evals/latest.json
- .ops/evals/latest.md

Flags:
- --require-runs: fail if no run logs are present
- --max-stream-errors <n>: fail if aggregate stream_error count exceeds n
EOF_HELP
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

mkdir -p "${OUT_DIR}"

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

total_runs=0
completed_runs=0
failed_runs=0
stream_errors=0
attempts=0
agent_messages=0
token_counts=0
context_snapshots=0
run_plans=0
tool_state_files=0
context_pack_files=0
context_pack_truncated_runs=0
retry_strategy_events=0
failure_signature_events=0
repeat_failure_guardrail_triggers=0
max_failure_repeat_count=0

if [ -d "${RUN_DIR}" ]; then
  for log_file in "${RUN_DIR}"/*.log; do
    [ -f "${log_file}" ] || continue
    total_runs=$((total_runs + 1))
    run_name="$(basename "${log_file}" .log)"
    last_file="${RUN_DIR}/${run_name}.last.txt"
    context_file="${RUN_DIR}/${run_name}.context.txt"
    todo_file="${RUN_DIR}/${run_name}.todo.md"
    tool_state_file="${RUN_DIR}/${run_name}.tool-state.env"
    context_pack_file="${RUN_DIR}/${run_name}.context.pack.txt"

    attempts=$((attempts + $(count_or_zero "\\[agent-supervisor\\].*launch attempt" "${log_file}")))
    stream_errors=$((stream_errors + $(count_or_zero '"type":"stream_error"' "${log_file}")))
    agent_messages=$((agent_messages + $(count_or_zero '"type":"agent_message"' "${log_file}")))
    token_counts=$((token_counts + $(count_or_zero '"type":"token_count"' "${log_file}")))
    if [ -s "${context_file}" ]; then
      context_snapshots=$((context_snapshots + 1))
    fi
    if [ -s "${todo_file}" ]; then
      run_plans=$((run_plans + 1))
    fi
    if [ -s "${tool_state_file}" ]; then
      tool_state_files=$((tool_state_files + 1))
    fi
    if [ -s "${context_pack_file}" ]; then
      context_pack_files=$((context_pack_files + 1))
      if rg -q "section\\..*\\.truncated=yes" "${context_pack_file}" 2>/dev/null; then
        context_pack_truncated_runs=$((context_pack_truncated_runs + 1))
      fi
    fi
    retry_strategy_events=$((retry_strategy_events + $(count_or_zero "retry_strategy=" "${log_file}")))
    failure_signature_events=$((failure_signature_events + $(count_or_zero "failure_signature=" "${log_file}")))
    repeat_failure_guardrail_triggers=$((repeat_failure_guardrail_triggers + $(count_or_zero "repeat_failure_guardrail_triggered" "${log_file}")))

    run_max_repeat="$(awk -F'repeat_count=' '/failure_signature=/{split($2,a,/[^0-9]/); if (a[1] > max) max=a[1]} END {print max+0}' "${log_file}" 2>/dev/null)"
    if [ -z "${run_max_repeat}" ]; then
      run_max_repeat=0
    fi
    if [ "${run_max_repeat}" -gt "${max_failure_repeat_count}" ]; then
      max_failure_repeat_count="${run_max_repeat}"
    fi

    if [ -s "${last_file}" ] && ! rg -q "stopped unexpectedly before completion" "${last_file}" 2>/dev/null; then
      completed_runs=$((completed_runs + 1))
    else
      failed_runs=$((failed_runs + 1))
    fi
  done
fi

if [ "${total_runs}" -gt 0 ]; then
  completion_rate_pct=$((completed_runs * 100 / total_runs))
else
  completion_rate_pct=0
fi

generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "${OUT_JSON}" <<EOF_JSON
{
  "generatedAt": "${generated_at}",
  "totalRuns": ${total_runs},
  "completedRuns": ${completed_runs},
  "failedRuns": ${failed_runs},
  "completionRatePct": ${completion_rate_pct},
  "attempts": ${attempts},
  "streamErrors": ${stream_errors},
  "agentMessages": ${agent_messages},
  "tokenCounts": ${token_counts},
  "contextSnapshots": ${context_snapshots},
  "runPlans": ${run_plans},
  "toolStateFiles": ${tool_state_files},
  "contextPackFiles": ${context_pack_files},
  "contextPackTruncatedRuns": ${context_pack_truncated_runs},
  "retryStrategyEvents": ${retry_strategy_events},
  "failureSignatureEvents": ${failure_signature_events},
  "repeatFailureGuardrailTriggers": ${repeat_failure_guardrail_triggers},
  "maxFailureRepeatCount": ${max_failure_repeat_count}
}
EOF_JSON

cat > "${OUT_MD}" <<EOF_MD
# Agent Eval Smoke Report

- Generated at (UTC): ${generated_at}
- Total runs: ${total_runs}
- Completed runs: ${completed_runs}
- Failed runs: ${failed_runs}
- Completion rate: ${completion_rate_pct}%
- Supervisor launch attempts: ${attempts}
- Stream errors: ${stream_errors}
- Agent messages: ${agent_messages}
- Token count events: ${token_counts}
- Context snapshots present: ${context_snapshots}
- Run plans present: ${run_plans}
- Tool state files present: ${tool_state_files}
- Context pack files present: ${context_pack_files}
- Context pack truncated runs: ${context_pack_truncated_runs}
- Retry strategy events: ${retry_strategy_events}
- Failure signature events: ${failure_signature_events}
- Repeat-failure guardrail triggers: ${repeat_failure_guardrail_triggers}
- Max failure repeat count: ${max_failure_repeat_count}
EOF_MD

if [ "${REQUIRE_RUNS}" -eq 1 ] && [ "${total_runs}" -eq 0 ]; then
  echo "[FAIL] No run logs found under ${RUN_DIR}" >&2
  exit 1
fi

if [ -n "${MAX_STREAM_ERRORS}" ]; then
  if ! [[ "${MAX_STREAM_ERRORS}" =~ ^[0-9]+$ ]]; then
    echo "[FAIL] --max-stream-errors expects a non-negative integer" >&2
    exit 1
  fi
  if [ "${stream_errors}" -gt "${MAX_STREAM_ERRORS}" ]; then
    echo "[FAIL] stream_errors=${stream_errors} exceeds threshold=${MAX_STREAM_ERRORS}" >&2
    exit 1
  fi
fi

echo "[PASS] Eval smoke complete (${OUT_JSON})"
