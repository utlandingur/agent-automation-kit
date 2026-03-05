#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <ticket_id> <slug> <task_brief_path>"
  echo "Example: $0 T012 sample-task docs/tasks/todo/T012-sample-task.md"
  exit 1
fi

TICKET_ID="$1"
SLUG="$2"
TASK_BRIEF="$3"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRANCH="codex/${TICKET_ID}-${SLUG}"
DEFAULT_WORKTREE_ROOT="$(cd "${REPO_ROOT}/.." && pwd)/agent-worktrees"
WORKTREE_ROOT="${AGENT_WORKTREE_ROOT:-${DEFAULT_WORKTREE_ROOT}}"
WORKTREE_DIR="${WORKTREE_ROOT}/${TICKET_ID}-${SLUG}"
RUN_DIR="${REPO_ROOT}/.ops/agent-runs"
SAFE_NAME="${TICKET_ID}-${SLUG}"
LOG_FILE="${RUN_DIR}/${SAFE_NAME}.log"
PID_FILE="${RUN_DIR}/${SAFE_NAME}.pid"
LAST_FILE="${RUN_DIR}/${SAFE_NAME}.last.txt"
PROMPT_FILE="${RUN_DIR}/${SAFE_NAME}.prompt.txt"
CONTEXT_FILE="${RUN_DIR}/${SAFE_NAME}.context.txt"
TODO_FILE="${RUN_DIR}/${SAFE_NAME}.todo.md"
TOOL_STATE_FILE="${RUN_DIR}/${SAFE_NAME}.tool-state.env"
CONTEXT_PACK_FILE="${RUN_DIR}/${SAFE_NAME}.context.pack.txt"
MAX_CONCURRENT_AGENTS="${MAX_CONCURRENT_AGENTS:-3}"
MODEL_SIMPLE="${AGENT_MODEL_SIMPLE:-gpt-5}"
MODEL_STANDARD="${AGENT_MODEL_STANDARD:-gpt-5}"
MODEL_COMPLEX="${AGENT_MODEL_COMPLEX:-gpt-5}"
REASONING_EFFORT_SIMPLE="${AGENT_REASONING_EFFORT_SIMPLE:-low}"
REASONING_EFFORT_STANDARD="${AGENT_REASONING_EFFORT_STANDARD:-medium}"
REASONING_EFFORT_COMPLEX="${AGENT_REASONING_EFFORT_COMPLEX:-high}"
REASONING_SUMMARY_MODE="${AGENT_REASONING_SUMMARY_MODE:-concise}"
AGENT_EXEC_MODE="${AGENT_EXEC_MODE:-guarded}"
USAGE_GUARD="${REPO_ROOT}/scripts/agents/usage-guard.sh"
DAEMON_LAUNCHER="${REPO_ROOT}/scripts/agents/launch-agent-daemon.py"
NOTIFY_SCRIPT="${REPO_ROOT}/scripts/agents/notify-orchestrator.sh"
TOOL_STATE_SCRIPT="${REPO_ROOT}/scripts/agents/tool-state-machine.sh"
CONTEXT_PACK_SCRIPT="${REPO_ROOT}/scripts/agents/context-pack.sh"
SKIP_WORKTREE_BOOTSTRAP="${SKIP_WORKTREE_BOOTSTRAP:-0}"

hash_file() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
    return 0
  fi
  sha256sum "${file}" | awk '{print $1}'
}

if [ ! -f "${REPO_ROOT}/${TASK_BRIEF}" ] && [ ! -f "${TASK_BRIEF}" ]; then
  echo "Task brief not found: ${TASK_BRIEF}"
  exit 1
fi

if [ -f "${TASK_BRIEF}" ]; then
  TASK_PATH="${TASK_BRIEF}"
else
  TASK_PATH="${REPO_ROOT}/${TASK_BRIEF}"
fi

if ! rg -q "^## Required Context" "${TASK_PATH}"; then
  echo "Task brief is missing '## Required Context': ${TASK_PATH}"
  exit 1
fi

TASK_STAGE="$(awk '
  /^## Lifecycle$/ {in_lifecycle=1; next}
  /^## / {if (in_lifecycle) exit}
  in_lifecycle && /^- Stage: `[^`]+`/ {
    line=$0
    sub(/^- Stage: `/, "", line)
    sub(/`$/, "", line)
    print line
    exit
  }
' "${TASK_PATH}")"

case "${TASK_STAGE}" in
  TODO|DOING) ;;
  BLOCKED)
    echo "Task stage is BLOCKED. Do not start: ${TASK_PATH}"
    exit 1
    ;;
  DONE)
    echo "Task stage is DONE. Do not start: ${TASK_PATH}"
    exit 1
    ;;
  *)
    echo "Task has invalid or missing Lifecycle stage (expected TODO|DOING|BLOCKED|DONE): ${TASK_PATH}"
    exit 1
    ;;
esac

MODEL_TIER="simple"
if rg -q "^## Model Tier" "${TASK_PATH}"; then
  parsed_tier="$(awk '
    /^## Model Tier$/ {in_tier=1; next}
    /^## / {if (in_tier) exit}
    in_tier && /^- `[^`]+`/ {
      line=$0
      sub(/^- `/, "", line)
      sub(/`$/, "", line)
      print line
      exit
    }
  ' "${TASK_PATH}")"
  if [ -n "${parsed_tier}" ]; then
    MODEL_TIER="${parsed_tier}"
  fi
fi

case "${MODEL_TIER}" in
  simple|standard|complex) ;;
  *)
    echo "Invalid Model Tier '${MODEL_TIER}' in task brief: ${TASK_PATH}"
    echo "Allowed values: simple | standard | complex"
    exit 1
    ;;
esac

MODEL_NAME="${MODEL_SIMPLE}"
REASONING_EFFORT="${REASONING_EFFORT_SIMPLE}"
case "${MODEL_TIER}" in
  simple)
    MODEL_NAME="${MODEL_SIMPLE}"
    REASONING_EFFORT="${REASONING_EFFORT_SIMPLE}"
    ;;
  standard)
    MODEL_NAME="${MODEL_STANDARD}"
    REASONING_EFFORT="${REASONING_EFFORT_STANDARD}"
    ;;
  complex)
    MODEL_NAME="${MODEL_COMPLEX}"
    REASONING_EFFORT="${REASONING_EFFORT_COMPLEX}"
    ;;
esac

if rg -q '^- Status:\s*`BLOCKED`' "${TASK_PATH}"; then
  echo "Task is BLOCKED by dependency. Do not start: ${TASK_PATH}"
  exit 1
fi

if rg -q '^## UI Impact' "${TASK_PATH}" && rg -q '^- `Yes`' "${TASK_PATH}"; then
  if ! rg -q "docs/design-system.md" "${TASK_PATH}"; then
    echo "UI task must include docs/design-system.md in Required Context: ${TASK_PATH}"
    exit 1
  fi
  if ! rg -q "docs/frontend-standards.md" "${TASK_PATH}"; then
    echo "UI task must include docs/frontend-standards.md in Required Context: ${TASK_PATH}"
    exit 1
  fi
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found in PATH"
  exit 1
fi

case "${AGENT_EXEC_MODE}" in
  guarded|full_auto) ;;
  *)
    echo "Invalid AGENT_EXEC_MODE '${AGENT_EXEC_MODE}'. Allowed values: guarded | full_auto"
    exit 1
    ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for detached agent launch"
  exit 1
fi

if [ ! -x "${USAGE_GUARD}" ]; then
  echo "Usage guard missing or not executable: ${USAGE_GUARD}"
  echo "Run: chmod +x scripts/agents/usage-guard.sh"
  exit 1
fi

if [ ! -x "${DAEMON_LAUNCHER}" ]; then
  echo "Daemon launcher missing or not executable: ${DAEMON_LAUNCHER}"
  echo "Run: chmod +x scripts/agents/launch-agent-daemon.py"
  exit 1
fi

if [ ! -x "${NOTIFY_SCRIPT}" ]; then
  echo "Notify hook missing or not executable: ${NOTIFY_SCRIPT}"
  echo "Run: chmod +x scripts/agents/notify-orchestrator.sh"
  exit 1
fi

if [ ! -x "${TOOL_STATE_SCRIPT}" ]; then
  echo "Tool state script missing or not executable: ${TOOL_STATE_SCRIPT}"
  echo "Run: chmod +x scripts/agents/tool-state-machine.sh"
  exit 1
fi

if [ ! -x "${CONTEXT_PACK_SCRIPT}" ]; then
  echo "Context pack script missing or not executable: ${CONTEXT_PACK_SCRIPT}"
  echo "Run: chmod +x scripts/agents/context-pack.sh"
  exit 1
fi

mkdir -p "${WORKTREE_ROOT}" "${RUN_DIR}"

if ! [[ "${MAX_CONCURRENT_AGENTS}" =~ ^[0-9]+$ ]]; then
  echo "MAX_CONCURRENT_AGENTS must be an integer (got: ${MAX_CONCURRENT_AGENTS})"
  exit 1
fi

running_count=0
for pid_file in "${RUN_DIR}"/*.pid; do
  [ -f "${pid_file}" ] || continue
  pid="$(cat "${pid_file}" 2>/dev/null || true)"
  if [[ -z "${pid}" ]]; then
    rm -f "${pid_file}"
    continue
  fi
  if ps -p "${pid}" >/dev/null 2>&1; then
    running_count=$((running_count + 1))
  else
    rm -f "${pid_file}"
  fi
done

if [ "${running_count}" -ge "${MAX_CONCURRENT_AGENTS}" ]; then
  echo "Agent limit reached: ${running_count}/${MAX_CONCURRENT_AGENTS} running."
  echo "Wait for agents to complete or increase MAX_CONCURRENT_AGENTS."
  exit 1
fi

cd "${REPO_ROOT}"

EFFECTIVE_TIER="$("${USAGE_GUARD}" resolve-tier "${MODEL_TIER}")"
if [ "${EFFECTIVE_TIER}" = "BLOCKED" ]; then
  echo "Spawn blocked by usage budget policy."
  "${USAGE_GUARD}" status
  exit 1
fi

if [ "${EFFECTIVE_TIER}" != "${MODEL_TIER}" ]; then
  echo "Model tier downgraded by usage policy: ${MODEL_TIER} -> ${EFFECTIVE_TIER}"
fi

case "${EFFECTIVE_TIER}" in
  simple)
    MODEL_NAME="${MODEL_SIMPLE}"
    REASONING_EFFORT="${REASONING_EFFORT_SIMPLE}"
    ;;
  standard)
    MODEL_NAME="${MODEL_STANDARD}"
    REASONING_EFFORT="${REASONING_EFFORT_STANDARD}"
    ;;
  complex)
    MODEL_NAME="${MODEL_COMPLEX}"
    REASONING_EFFORT="${REASONING_EFFORT_COMPLEX}"
    ;;
esac

if ! can_spawn_msg="$("${USAGE_GUARD}" can-spawn "${EFFECTIVE_TIER}")"; then
  echo "${can_spawn_msg}"
  "${USAGE_GUARD}" status
  exit 1
fi

# Keep branch roots consistent.
git fetch origin main >/dev/null 2>&1 || true

if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  echo "Branch already exists: ${BRANCH}"
  exit 1
fi

if [ -d "${WORKTREE_DIR}" ]; then
  echo "Worktree already exists: ${WORKTREE_DIR}"
  exit 1
fi

git worktree add -b "${BRANCH}" "${WORKTREE_DIR}" main

if [ "${SKIP_WORKTREE_BOOTSTRAP}" != "1" ]; then
  if ! command -v corepack >/dev/null 2>&1; then
    echo "corepack is required for dependency bootstrap in worktree"
    echo "Either install/enable corepack or run with SKIP_WORKTREE_BOOTSTRAP=1"
    exit 1
  fi

  needs_install="no"
  if [ -f "${WORKTREE_DIR}/.yarnrc.yml" ] && rg -q '^nodeLinker:\s*node-modules' "${WORKTREE_DIR}/.yarnrc.yml"; then
    if [ ! -d "${WORKTREE_DIR}/node_modules" ]; then
      needs_install="yes"
    fi
  fi

  if [ "${needs_install}" = "yes" ]; then
    echo "Bootstrapping dependencies in worktree..."
    (
      cd "${WORKTREE_DIR}"
      corepack yarn install
    ) >/dev/null
    echo "Dependency bootstrap complete."
  fi
fi

AGENT_PREFIX=$(cat <<PROMPT
You are assigned to task ${TICKET_ID} (${SLUG}).

Hard requirements:
- Use minimal context only.
- Read docs/agent-runtime-rules.md first.
- Read the assigned task brief.
- Read task brief \"Required Context\" first, then read only task-scoped implementation files listed under \"In Scope\"/\"Files/Areas\" and direct imports needed to complete the task.
- Do not read broader repo docs/files outside task scope.
- Use TDD: write tests first, then implementation.
- Keep changes scoped strictly to this task brief.
- Use assigned Model Tier: ${EFFECTIVE_TIER}.
- If unsure or blocked, ask Task Lead and pause:
  - scripts/agents/ask-lead.sh ${TICKET_ID} \"<question>\" \"<recommended_option>\"
- Never perform paid actions, purchases, billing upgrades, or accept legal terms/conditions.
- Require explicit user approval before any spend or legal acceptance.
- Do not create or commit planning skill files (task_plan.md, findings.md, progress.md).
- Run lint/tests required by this repo.
- Never leave watch/test/dev processes running; tests must run in non-watch mode.
- Keep status/final responses terse and task-relevant only.
- Commit with a clean, scoped message when done.
- Read the context snapshot and plan file below, then start by reciting:
  - objective
  - allowed scope
  - first verification command
- If a retry occurs, use a different technical approach than previous attempts.
- Follow tool state machine:
  - Initial state is plan
  - Allowed transitions: plan -> implement -> verify -> finalize
  - Use scripts/agents/tool-state-machine.sh to check/advance state
  - Do not use actions not allowed for current state

Context snapshot starts below:

PROMPT
)

TASK_HASH="$(hash_file "${TASK_PATH}")"
cat > "${CONTEXT_FILE}" <<EOF
run_name=${SAFE_NAME}
ticket_id=${TICKET_ID}
slug=${SLUG}
model_tier=${EFFECTIVE_TIER}
model_name=${MODEL_NAME}
reasoning_effort=${REASONING_EFFORT}
exec_mode=${AGENT_EXEC_MODE}
task_brief_path=${TASK_PATH}
task_brief_sha256=${TASK_HASH}
runtime_rules=docs/agent-runtime-rules.md
EOF

cat > "${TODO_FILE}" <<EOF
# Run Plan (${SAFE_NAME})

## Objective
Implement only task ${TICKET_ID} (${SLUG}) per assigned task brief.

## Scope Guard
- Read only Required Context + task-scoped files/imports.
- Do not widen scope without lead approval.
- Do not perform hard-stop domain changes without escalation.

## Start Checklist
- Read docs/agent-runtime-rules.md
- Read this file fully
- Read task brief and required context
- Recite objective/scope/first command before code changes
- Confirm tool state:
  - `scripts/agents/tool-state-machine.sh get ${SAFE_NAME}`

## Verification
- Run required lint/tests in non-watch mode
- Ensure no dev/watch processes remain running
EOF

"${TOOL_STATE_SCRIPT}" init "${SAFE_NAME}" >/dev/null

"${CONTEXT_PACK_SCRIPT}" \
  --run-name "${SAFE_NAME}" \
  --output "${CONTEXT_PACK_FILE}" \
  --context-file "${CONTEXT_FILE}" \
  --todo-file "${TODO_FILE}" \
  --task-file "${TASK_PATH}" >/dev/null

{
  echo "${AGENT_PREFIX}"
  cat "${CONTEXT_PACK_FILE}"
  echo
} > "${PROMPT_FILE}"

# Reset stale run outputs for this ticket so health checks reflect current spawn only.
: > "${LOG_FILE}"
: > "${LAST_FILE}"

PID="$(
  python3 "${DAEMON_LAUNCHER}" \
    --workdir "${WORKTREE_DIR}" \
    --model "${MODEL_NAME}" \
    --run-name "${SAFE_NAME}" \
    --notify-script "${NOTIFY_SCRIPT}" \
    --reasoning-effort "${REASONING_EFFORT}" \
    --reasoning-summary "${REASONING_SUMMARY_MODE}" \
    --exec-mode "${AGENT_EXEC_MODE}" \
    --prompt-file "${PROMPT_FILE}" \
    --log-file "${LOG_FILE}" \
    --last-file "${LAST_FILE}" \
    --pid-file "${PID_FILE}"
)"
"${USAGE_GUARD}" record "${TICKET_ID}" "${SLUG}" "${EFFECTIVE_TIER}" "${MODEL_NAME}" "${PID}" || true

echo "Spawned Codex agent"
echo "- Task: ${TICKET_ID} (${SLUG})"
echo "- Model tier/model: ${EFFECTIVE_TIER}/${MODEL_NAME}"
echo "- Exec mode: ${AGENT_EXEC_MODE}"
echo "- Branch: ${BRANCH}"
echo "- Worktree: ${WORKTREE_DIR}"
echo "- PID: ${PID}"
echo "- Log: ${LOG_FILE}"
echo "- Last message: ${LAST_FILE}"
echo "- Context snapshot: ${CONTEXT_FILE}"
echo "- Run plan: ${TODO_FILE}"
echo "- Packed context: ${CONTEXT_PACK_FILE}"
echo "- Tool state: ${TOOL_STATE_FILE}"
