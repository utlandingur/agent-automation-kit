#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASK_ROOT="${ROOT}/docs/tasks"

lanes=(todo doing blocked done)

task_files() {
  local lane="$1"
  find "${TASK_ROOT}/${lane}" -maxdepth 1 -type f -name 'T*.md' | sort
}

task_id() {
  awk '/^## Task ID/{getline; gsub(/`/,"",$0); print $0; exit}' "$1"
}

task_stage() {
  awk '/^- Stage: `/{gsub(/^- Stage: `|`$/,"",$0); print $0; exit}' "$1"
}

task_units() {
  awk '/^- Unit Estimate: `/{gsub(/^- Unit Estimate: `|`$/,"",$0); print $0; exit}' "$1"
}

task_slug() {
  awk '/^## Slug/{getline; gsub(/`/,"",$0); print $0; exit}' "$1"
}

echo "Task Board"
echo "Date: $(date +%Y-%m-%d)"
echo

total_count=0
total_units=0

for lane in "${lanes[@]}"; do
  files=()
  while IFS= read -r f; do
    files+=("$f")
  done < <(task_files "${lane}")
  lane_count=0
  lane_units=0

  if [ "${#files[@]}" -gt 0 ]; then
    for f in "${files[@]}"; do
      [ -f "${f}" ] || continue
      units="$(task_units "${f}")"
      lane_count=$((lane_count + 1))
      lane_units=$((lane_units + units))
    done
  fi

  total_count=$((total_count + lane_count))
  total_units=$((total_units + lane_units))

  lane_label="$(echo "${lane}" | tr '[:lower:]' '[:upper:]')"
  printf "%s: %d tasks, %d units\n" "${lane_label}" "${lane_count}" "${lane_units}"
  if [ "${#files[@]}" -gt 0 ]; then
    for f in "${files[@]}"; do
      [ -f "${f}" ] || continue
      printf "  - %s | %s | %s unit(s)\n" "$(task_id "${f}")" "$(task_slug "${f}")" "$(task_units "${f}")"
    done
  fi
  echo
done

echo "Total: ${total_count} tasks, ${total_units} units"
