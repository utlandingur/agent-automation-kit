#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="${ROOT}/.ops/agent-runs"

usage() {
  cat <<'EOF_HELP'
Usage:
  scripts/agents/tool-state-machine.sh init <run_name>
  scripts/agents/tool-state-machine.sh get <run_name>
  scripts/agents/tool-state-machine.sh can <run_name> <action>
  scripts/agents/tool-state-machine.sh advance <run_name> <next_state>

States (ordered):
  plan -> implement -> verify -> finalize

Actions:
  read_context ask_lead edit_code run_local_checks update_docs open_pr merge_pr cleanup_artifacts
EOF_HELP
}

state_file_for() {
  local run_name="$1"
  echo "${RUN_DIR}/${run_name}.tool-state.env"
}

valid_state() {
  case "$1" in
    plan|implement|verify|finalize) return 0 ;;
    *) return 1 ;;
  esac
}

state_rank() {
  case "$1" in
    plan) echo 1 ;;
    implement) echo 2 ;;
    verify) echo 3 ;;
    finalize) echo 4 ;;
    *) echo 0 ;;
  esac
}

allowed_actions_for_state() {
  case "$1" in
    plan) echo "read_context ask_lead" ;;
    implement) echo "read_context ask_lead edit_code run_local_checks" ;;
    verify) echo "read_context ask_lead run_local_checks update_docs" ;;
    finalize) echo "read_context ask_lead open_pr merge_pr cleanup_artifacts" ;;
    *) echo "" ;;
  esac
}

write_state_file() {
  local run_name="$1"
  local state="$2"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "${RUN_DIR}"
  cat > "$(state_file_for "${run_name}")" <<EOF_STATE
run_name=${run_name}
state=${state}
state_rank=$(state_rank "${state}")
updated_at=${ts}
allowed_actions="$(allowed_actions_for_state "${state}")"
EOF_STATE
}

load_state() {
  local file="$1"
  if [ ! -f "${file}" ]; then
    echo "[FAIL] tool state file not found: ${file}" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "${file}"
}

contains_word() {
  local needle="$1"
  local haystack="$2"
  for item in ${haystack}; do
    if [ "${item}" = "${needle}" ]; then
      return 0
    fi
  done
  return 1
}

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

command="$1"
run_name="$2"
file="$(state_file_for "${run_name}")"

case "${command}" in
  init)
    write_state_file "${run_name}" "plan"
    echo "state=plan"
    ;;
  get)
    load_state "${file}"
    echo "state=${state}"
    echo "state_rank=${state_rank}"
    echo "allowed_actions=${allowed_actions}"
    ;;
  can)
    if [ "$#" -ne 3 ]; then
      usage
      exit 1
    fi
    action="$3"
    load_state "${file}"
    if contains_word "${action}" "${allowed_actions}"; then
      echo "ALLOW state=${state} action=${action}"
      exit 0
    fi
    echo "DENY state=${state} action=${action}"
    exit 1
    ;;
  advance)
    if [ "$#" -ne 3 ]; then
      usage
      exit 1
    fi
    next_state="$3"
    if ! valid_state "${next_state}"; then
      echo "[FAIL] invalid next state: ${next_state}" >&2
      exit 1
    fi
    load_state "${file}"
    current_rank="$(state_rank "${state}")"
    next_rank="$(state_rank "${next_state}")"
    if [ "${next_rank}" -lt "${current_rank}" ]; then
      echo "[FAIL] cannot move backward: ${state} -> ${next_state}" >&2
      exit 1
    fi
    write_state_file "${run_name}" "${next_state}"
    echo "state=${next_state}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
