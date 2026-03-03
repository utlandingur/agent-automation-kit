#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <ticket-slug-prefix>"
  echo "Example: $0 T014-core-quiz-navigation-e2e-guard"
  exit 1
fi

RUN_NAME="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="${ROOT}/.ops/agent-runs"
INBOX_DIR="${ROOT}/.ops/orchestrator/inbox"
EVENTS_FILE="${ROOT}/.ops/orchestrator/events.jsonl"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

removed=0

for f in \
  "${RUN_DIR}/${RUN_NAME}.pid" \
  "${RUN_DIR}/${RUN_NAME}.log" \
  "${RUN_DIR}/${RUN_NAME}.last.txt" \
  "${RUN_DIR}/${RUN_NAME}.prompt.txt"; do
  if [ -f "${f}" ]; then
    rm -f "${f}"
    removed=$((removed + 1))
  fi
done

if [ -d "${INBOX_DIR}" ]; then
  while IFS= read -r file; do
    [ -n "${file}" ] || continue
    rm -f "${file}"
    removed=$((removed + 1))
  done < <(find "${INBOX_DIR}" -type f -name "*-${RUN_NAME}.md" 2>/dev/null)
fi

mkdir -p "$(dirname "${EVENTS_FILE}")"
printf '{"time":"%s","run":"%s","event":"run_artifacts_cleaned","removed_files":%d}\n' \
  "${TS}" "${RUN_NAME}" "${removed}" >> "${EVENTS_FILE}"

if [ -x "${ROOT}/scripts/agents/orchestrator-context-compress.sh" ]; then
  "${ROOT}/scripts/agents/orchestrator-context-compress.sh" >/dev/null 2>&1 || true
fi

echo "cleaned_run_files=${removed}"
