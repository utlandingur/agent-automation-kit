#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASK_DIR="${ROOT}/docs/tasks"
STATUS_SCRIPT="${ROOT}/scripts/agents/orchestrator-status.sh"
SPAWN_SCRIPT="${ROOT}/scripts/agents/spawn-codex-agent.sh"

if [ ! -x "${STATUS_SCRIPT}" ] || [ ! -x "${SPAWN_SCRIPT}" ]; then
  echo "missing required scripts"
  exit 1
fi

if [ ! -d "${TASK_DIR}" ]; then
  echo "tasks directory not found: ${TASK_DIR}"
  exit 1
fi

status_line="$("${STATUS_SCRIPT}" --brief)"
if printf "%s" "${status_line}" | rg -q '^ACTIVE'; then
  echo "skip: active agents already running (${status_line})"
  exit 0
fi

find_task_field() {
  local file="$1"
  local header="$2"
  awk -v h="${header}" '
    $0 ~ "^## " h "$" { in_section=1; next }
    /^## / && in_section { exit }
    in_section && /^`[^`]+`$/ {
      line=$0
      sub(/^`/, "", line)
      sub(/`$/, "", line)
      print line
      exit
    }
  ' "${file}"
}

is_ready_task() {
  local file="$1"
  rg -q '^- Status:\s*`READY`' "${file}"
}

for task_file in $(find "${TASK_DIR}" -maxdepth 1 -type f -name 'T*.md' | sort); do
  if ! is_ready_task "${task_file}"; then
    continue
  fi

  ticket_id="$(find_task_field "${task_file}" "Task ID")"
  slug="$(find_task_field "${task_file}" "Slug")"
  if [ -z "${ticket_id}" ] || [ -z "${slug}" ]; then
    continue
  fi

  branch="codex/${ticket_id}-${slug}"
  if git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${branch}"; then
    continue
  fi

  task_rel="docs/tasks/$(basename "${task_file}")"
  bash "${SPAWN_SCRIPT}" "${ticket_id}" "${slug}" "${task_rel}"
  echo "spawned=${ticket_id}-${slug}"
  exit 0
done

echo "no_spawn: no READY task eligible for new branch spawn"
exit 0
