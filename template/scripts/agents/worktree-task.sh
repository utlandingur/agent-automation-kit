#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $0 create <ticket_id> <slug> [base_ref]
  $0 remove <ticket_id> <slug> [--force] [--delete-branch]
  $0 path <ticket_id> <slug>
  $0 branch <ticket_id> <slug>
  $0 list

Defaults:
  base_ref: main
  worktree_root: AGENT_WORKTREE_ROOT or <repo-parent>/agent-worktrees
USAGE
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

COMMAND="$1"
shift

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_WORKTREE_ROOT="$(cd "${REPO_ROOT}/.." && pwd)/agent-worktrees"
WORKTREE_ROOT="${AGENT_WORKTREE_ROOT:-${DEFAULT_WORKTREE_ROOT}}"

branch_name() {
  local ticket_id="$1"
  local slug="$2"
  printf "codex/%s-%s" "${ticket_id}" "${slug}"
}

worktree_dir() {
  local ticket_id="$1"
  local slug="$2"
  printf "%s/%s-%s" "${WORKTREE_ROOT}" "${ticket_id}" "${slug}"
}

require_args() {
  local count="$1"
  shift
  if [ "$#" -lt "${count}" ]; then
    usage
    exit 1
  fi
}

case "${COMMAND}" in
  create)
    require_args 2 "$@"
    TICKET_ID="$1"
    SLUG="$2"
    BASE_REF="${3:-main}"
    BRANCH="$(branch_name "${TICKET_ID}" "${SLUG}")"
    TARGET_DIR="$(worktree_dir "${TICKET_ID}" "${SLUG}")"

    mkdir -p "${WORKTREE_ROOT}"
    cd "${REPO_ROOT}"

    if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
      echo "Branch already exists: ${BRANCH}"
      exit 1
    fi

    if [ -d "${TARGET_DIR}" ]; then
      echo "Worktree already exists: ${TARGET_DIR}"
      exit 1
    fi

    git fetch origin "${BASE_REF}" >/dev/null 2>&1 || true
    git worktree add -b "${BRANCH}" "${TARGET_DIR}" "${BASE_REF}"
    ;;

  remove)
    require_args 2 "$@"
    TICKET_ID="$1"
    SLUG="$2"
    shift 2

    FORCE=0
    DELETE_BRANCH=0
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --force)
          FORCE=1
          ;;
        --delete-branch)
          DELETE_BRANCH=1
          ;;
        *)
          echo "Unknown option: $1"
          usage
          exit 1
          ;;
      esac
      shift
    done

    BRANCH="$(branch_name "${TICKET_ID}" "${SLUG}")"
    TARGET_DIR="$(worktree_dir "${TICKET_ID}" "${SLUG}")"
    cd "${REPO_ROOT}"

    if [ -d "${TARGET_DIR}" ]; then
      if [ "${FORCE}" = "1" ]; then
        git worktree remove --force "${TARGET_DIR}"
      else
        git worktree remove "${TARGET_DIR}"
      fi
    else
      echo "Worktree not found: ${TARGET_DIR}"
      exit 1
    fi

    if [ "${DELETE_BRANCH}" = "1" ] && git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
      git branch -D "${BRANCH}" >/dev/null
    fi
    ;;

  path)
    require_args 2 "$@"
    echo "$(worktree_dir "$1" "$2")"
    ;;

  branch)
    require_args 2 "$@"
    echo "$(branch_name "$1" "$2")"
    ;;

  list)
    cd "${REPO_ROOT}"
    git worktree list
    ;;

  --help|-h|help)
    usage
    ;;

  *)
    echo "Unknown command: ${COMMAND}"
    usage
    exit 1
    ;;
esac
