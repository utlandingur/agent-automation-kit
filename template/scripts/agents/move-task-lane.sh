#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASK_ROOT="${ROOT}/docs/tasks"

usage() {
  cat <<'EOF'
Usage:
  scripts/agents/move-task-lane.sh <task_id_or_path> <todo|doing|blocked|done> [--ac-pass] [--tests-pass] [--evidence "text"]

Examples:
  scripts/agents/move-task-lane.sh T007 doing
  scripts/agents/move-task-lane.sh docs/tasks/doing/T007-sample-task.md done --ac-pass --tests-pass --evidence "main@abc123 (#77)"
EOF
}

fail() {
  echo "[FAIL] $1"
  exit 1
}

[ "$#" -ge 2 ] || { usage; exit 1; }

task_ref="$1"
target_lane="$2"
shift 2

ac_pass=0
tests_pass=0
evidence=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --ac-pass) ac_pass=1 ;;
    --tests-pass) tests_pass=1 ;;
    --evidence)
      shift
      [ "$#" -gt 0 ] || fail "--evidence requires a value"
      evidence="$1"
      ;;
    *) fail "Unknown arg: $1" ;;
  esac
  shift
done

case "${target_lane}" in
  todo|doing|blocked|done) ;;
  *) fail "Invalid target lane '${target_lane}'" ;;
esac

target_stage="$(echo "${target_lane}" | tr '[:lower:]' '[:upper:]')"

resolve_task_path() {
  local ref="$1"
  if [ -f "${ref}" ]; then
    echo "${ref}"
    return 0
  fi

  if [[ "${ref}" =~ ^T[0-9]{3}$ ]]; then
    local match
    match="$(find "${TASK_ROOT}" -mindepth 2 -maxdepth 2 -type f -name "${ref}-*.md" | head -n1 || true)"
    [ -n "${match}" ] || fail "Task not found for id ${ref}"
    echo "${match}"
    return 0
  fi

  fail "Task path/id not found: ${ref}"
}

task_path="$(resolve_task_path "${task_ref}")"
task_base="$(basename "${task_path}")"
current_lane="$(basename "$(dirname "${task_path}")")"

if [ "${target_lane}" = "done" ]; then
  [ "${ac_pass}" -eq 1 ] || fail "Moving to done requires --ac-pass"
  [ "${tests_pass}" -eq 1 ] || fail "Moving to done requires --tests-pass"
  [ -n "${evidence}" ] || fail "Moving to done requires --evidence"
fi

if [ -z "${evidence}" ]; then
  evidence="N/A"
fi

tmp="$(mktemp)"
today="$(date +%Y-%m-%d)"
awk -v stage="${target_stage}" -v evidence="${evidence}" -v today="${today}" '
  /^- Stage: / { print "- Stage: `" stage "`"; next }
  /^- Last Updated: / { print "- Last Updated: `" today "`"; next }
  /^- Completion Evidence: / { print "- Completion Evidence: `" evidence "`"; next }
  { print }
' "${task_path}" > "${tmp}"
mv "${tmp}" "${task_path}"

# Keep Dependencies status aligned with lifecycle stage/lane.
if [ "${target_lane}" = "blocked" ]; then
  sed -i '' -E 's/^- Status: `READY`/- Status: `BLOCKED`/' "${task_path}"
else
  sed -i '' -E 's/^- Status: `BLOCKED`/- Status: `READY`/' "${task_path}"
fi

if [ "${target_lane}" = "done" ]; then
  if ! rg -q '^## Completion Record$' "${task_path}"; then
    cat >> "${task_path}" <<EOF

## Completion Record
- Acceptance Criteria: \`PASS\`
- Required Tests: \`PASS\`
- Evidence: \`${evidence}\`
EOF
  else
    sed -i '' -E 's/^- Acceptance Criteria: .*/- Acceptance Criteria: `PASS`/' "${task_path}"
    sed -i '' -E 's/^- Required Tests: .*/- Required Tests: `PASS`/' "${task_path}"
    if rg -q '^- Evidence:' "${task_path}"; then
      sed -i '' -E "s#^- Evidence: .*#- Evidence: \`${evidence}\`#" "${task_path}"
    else
      cat >> "${task_path}" <<EOF
- Evidence: \`${evidence}\`
EOF
    fi
  fi
else
  # Non-done lanes should not carry PASS completion semantics.
  if rg -q '^## Completion Record$' "${task_path}"; then
    sed -i '' -E 's/^- Acceptance Criteria: .*/- Acceptance Criteria: `N\/A`/' "${task_path}"
    sed -i '' -E 's/^- Required Tests: .*/- Required Tests: `N\/A`/' "${task_path}"
    sed -i '' -E 's/^- Evidence: .*/- Evidence: `N\/A`/' "${task_path}"
  fi
fi

mkdir -p "${TASK_ROOT}/${target_lane}"
target_path="${TASK_ROOT}/${target_lane}/${task_base}"
mv "${task_path}" "${target_path}"

echo "[PASS] moved ${task_base}: ${current_lane} -> ${target_lane}"
