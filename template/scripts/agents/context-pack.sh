#!/usr/bin/env bash
set -euo pipefail

RUN_NAME=""
OUTPUT_FILE=""
CONTEXT_FILE=""
TODO_FILE=""
TASK_FILE=""
MAX_CHARS=18000
CONTEXT_CHARS=2000
TODO_CHARS=4000
TASK_CHARS=12000

usage() {
  cat <<'EOF_HELP'
Usage:
  scripts/agents/context-pack.sh \
    --run-name <name> \
    --output <file> \
    --context-file <file> \
    --todo-file <file> \
    --task-file <file> \
    [--max-chars <n>] \
    [--context-chars <n>] \
    [--todo-chars <n>] \
    [--task-chars <n>]

Creates deterministic packed context with fixed section order and explicit truncation metadata.
EOF_HELP
}

is_int() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

file_chars() {
  local file="$1"
  wc -c < "${file}" | tr -d ' '
}

sha256_file() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
    return 0
  fi
  sha256sum "${file}" | awk '{print $1}'
}

truncate_file_to_budget() {
  local src="$1"
  local budget="$2"
  local mode="$3"
  local tmp="$4"

  if [ "${budget}" -le 0 ]; then
    : > "${tmp}"
    return 0
  fi

  local total
  total="$(file_chars "${src}")"
  if [ "${total}" -le "${budget}" ]; then
    cp "${src}" "${tmp}"
    return 0
  fi

  if [ "${mode}" = "head" ]; then
    LC_ALL=C head -c "${budget}" "${src}" > "${tmp}"
    return 0
  fi

  local marker=$'\n\n[...truncated middle content...]\n\n'
  local marker_len
  marker_len="${#marker}"
  if [ "${budget}" -le $((marker_len + 2)) ]; then
    LC_ALL=C head -c "${budget}" "${src}" > "${tmp}"
    return 0
  fi

  local remain head_bytes tail_bytes
  remain=$((budget - marker_len))
  head_bytes=$((remain / 2))
  tail_bytes=$((remain - head_bytes))

  LC_ALL=C head -c "${head_bytes}" "${src}" > "${tmp}"
  printf "%s" "${marker}" >> "${tmp}"
  LC_ALL=C tail -c "${tail_bytes}" "${src}" >> "${tmp}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-name) shift; RUN_NAME="${1:-}" ;;
    --output) shift; OUTPUT_FILE="${1:-}" ;;
    --context-file) shift; CONTEXT_FILE="${1:-}" ;;
    --todo-file) shift; TODO_FILE="${1:-}" ;;
    --task-file) shift; TASK_FILE="${1:-}" ;;
    --max-chars) shift; MAX_CHARS="${1:-}" ;;
    --context-chars) shift; CONTEXT_CHARS="${1:-}" ;;
    --todo-chars) shift; TODO_CHARS="${1:-}" ;;
    --task-chars) shift; TASK_CHARS="${1:-}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

if [ -z "${RUN_NAME}" ] || [ -z "${OUTPUT_FILE}" ] || [ -z "${CONTEXT_FILE}" ] || [ -z "${TODO_FILE}" ] || [ -z "${TASK_FILE}" ]; then
  usage
  exit 1
fi

for n in "${MAX_CHARS}" "${CONTEXT_CHARS}" "${TODO_CHARS}" "${TASK_CHARS}"; do
  if ! is_int "${n}"; then
    echo "[FAIL] character budgets must be non-negative integers" >&2
    exit 1
  fi
done

for f in "${CONTEXT_FILE}" "${TODO_FILE}" "${TASK_FILE}"; do
  [ -f "${f}" ] || { echo "[FAIL] missing input file: ${f}" >&2; exit 1; }
done

budget_sum=$((CONTEXT_CHARS + TODO_CHARS + TASK_CHARS))
if [ "${budget_sum}" -gt "${MAX_CHARS}" ]; then
  # deterministically fit into max by shrinking task budget first, then todo, then context
  overflow=$((budget_sum - MAX_CHARS))
  if [ "${TASK_CHARS}" -gt "${overflow}" ]; then
    TASK_CHARS=$((TASK_CHARS - overflow))
  else
    overflow=$((overflow - TASK_CHARS))
    TASK_CHARS=0
    if [ "${TODO_CHARS}" -gt "${overflow}" ]; then
      TODO_CHARS=$((TODO_CHARS - overflow))
    else
      overflow=$((overflow - TODO_CHARS))
      TODO_CHARS=0
      if [ "${CONTEXT_CHARS}" -gt "${overflow}" ]; then
        CONTEXT_CHARS=$((CONTEXT_CHARS - overflow))
      else
        CONTEXT_CHARS=0
      fi
    fi
  fi
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

ctx_tmp="${workdir}/context.txt"
todo_tmp="${workdir}/todo.txt"
task_tmp="${workdir}/task.txt"

truncate_file_to_budget "${CONTEXT_FILE}" "${CONTEXT_CHARS}" "head" "${ctx_tmp}"
truncate_file_to_budget "${TODO_FILE}" "${TODO_CHARS}" "head" "${todo_tmp}"
truncate_file_to_budget "${TASK_FILE}" "${TASK_CHARS}" "middle" "${task_tmp}"

ctx_src_chars="$(file_chars "${CONTEXT_FILE}")"
todo_src_chars="$(file_chars "${TODO_FILE}")"
task_src_chars="$(file_chars "${TASK_FILE}")"
ctx_out_chars="$(file_chars "${ctx_tmp}")"
todo_out_chars="$(file_chars "${todo_tmp}")"
task_out_chars="$(file_chars "${task_tmp}")"

ctx_trunc="no"; [ "${ctx_src_chars}" -gt "${ctx_out_chars}" ] && ctx_trunc="yes"
todo_trunc="no"; [ "${todo_src_chars}" -gt "${todo_out_chars}" ] && todo_trunc="yes"
task_trunc="no"; [ "${task_src_chars}" -gt "${task_out_chars}" ] && task_trunc="yes"

mkdir -p "$(dirname "${OUTPUT_FILE}")"
cat > "${OUTPUT_FILE}" <<EOF_PACK
# Packed Context (${RUN_NAME})

generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
max_chars=${MAX_CHARS}
section.context.budget=${CONTEXT_CHARS}
section.todo.budget=${TODO_CHARS}
section.task.budget=${TASK_CHARS}
section.context.source_chars=${ctx_src_chars}
section.todo.source_chars=${todo_src_chars}
section.task.source_chars=${task_src_chars}
section.context.output_chars=${ctx_out_chars}
section.todo.output_chars=${todo_out_chars}
section.task.output_chars=${task_out_chars}
section.context.truncated=${ctx_trunc}
section.todo.truncated=${todo_trunc}
section.task.truncated=${task_trunc}
section.context.sha256=$(sha256_file "${CONTEXT_FILE}")
section.todo.sha256=$(sha256_file "${TODO_FILE}")
section.task.sha256=$(sha256_file "${TASK_FILE}")

## SECTION: CONTEXT SNAPSHOT

EOF_PACK

cat "${ctx_tmp}" >> "${OUTPUT_FILE}"

cat >> "${OUTPUT_FILE}" <<'EOF_PACK2'

## SECTION: RUN PLAN

EOF_PACK2
cat "${todo_tmp}" >> "${OUTPUT_FILE}"

cat >> "${OUTPUT_FILE}" <<'EOF_PACK3'

## SECTION: TASK BRIEF

EOF_PACK3
cat "${task_tmp}" >> "${OUTPUT_FILE}"

echo "[PASS] context pack written: ${OUTPUT_FILE}"
