#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/agents/ship-pr.sh \
    --commit-msg "..." \
    --pr-title "..." \
    --pr-body "..." | --pr-body-file <file> \
    [--checks "cmd"] \
    [--base staging] \
    [--allow-main] \
    [--merge-method squash|merge|rebase]

Behavior (strictly sequential):
  1) run checks (if provided)
  2) git add -A
  3) git commit
  4) git push
  5) create or reuse PR
  6) wait for required PR checks
  7) merge PR
  8) fast-forward local base branch

Notes:
- Refuses to run from main/staging.
- Refuses direct merge to main unless --allow-main is set.
- Prevents commit/push race conditions by running serially in one process.
USAGE
}

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

wait_for_required_checks() {
  local pr_number="$1"
  local timeout_secs="${2:-300}"
  local interval_secs=10
  local elapsed=0
  local output=""

  wait_for_checks_visible() {
    local mode="$1"
    local command_output=""
    elapsed=0

    while true; do
      set +e
      if [ "$mode" = "required" ]; then
        command_output="$(gh pr checks "$pr_number" --required 2>&1)"
      else
        command_output="$(gh pr checks "$pr_number" 2>&1)"
      fi
      set -e

      if [ "$mode" = "required" ] && printf '%s' "$command_output" | grep -Eqi "no required checks"; then
        return 2
      fi

      if printf '%s' "$command_output" | grep -Eqi "no checks reported"; then
        if [ "$elapsed" -ge "$timeout_secs" ]; then
          return 1
        fi
        echo "No ${mode} checks reported yet for PR #$pr_number; waiting ${interval_secs}s..."
        sleep "$interval_secs"
        elapsed=$((elapsed + interval_secs))
        continue
      fi

      output="$command_output"
      return 0
    done
  }

  if wait_for_checks_visible "required"; then
    gh pr checks "$pr_number" --watch --required || fail "Required PR checks failed for #$pr_number"
    return
  fi

  if [ "$?" -eq 2 ]; then
    echo "No required checks configured for PR #$pr_number. Falling back to all PR checks..."
  else
    echo "No required checks reported for PR #$pr_number within ${timeout_secs}s. Falling back to all PR checks..."
  fi
  if ! wait_for_checks_visible "all"; then
    fail "No PR checks reported for PR #$pr_number after ${timeout_secs}s"
  fi

  gh pr checks "$pr_number" --watch || fail "PR checks failed for #$pr_number"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

COMMIT_MSG=""
PR_TITLE=""
PR_BODY=""
PR_BODY_FILE=""
CHECKS_CMD=""
BASE_BRANCH="staging"
MERGE_METHOD="squash"
ALLOW_MAIN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --commit-msg)
      shift; COMMIT_MSG="${1:-}" ;;
    --pr-title)
      shift; PR_TITLE="${1:-}" ;;
    --pr-body)
      shift; PR_BODY="${1:-}" ;;
    --pr-body-file)
      shift; PR_BODY_FILE="${1:-}" ;;
    --checks)
      shift; CHECKS_CMD="${1:-}" ;;
    --base)
      shift; BASE_BRANCH="${1:-}" ;;
    --allow-main)
      ALLOW_MAIN=1 ;;
    --merge-method)
      shift; MERGE_METHOD="${1:-}" ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      fail "Unknown argument: $1" ;;
  esac
  shift
done

[ -n "$COMMIT_MSG" ] || fail "--commit-msg is required"
[ -n "$PR_TITLE" ] || fail "--pr-title is required"

if [ -z "$PR_BODY" ] && [ -z "$PR_BODY_FILE" ]; then
  fail "Provide --pr-body or --pr-body-file"
fi
if [ -n "$PR_BODY" ] && [ -n "$PR_BODY_FILE" ]; then
  fail "Use either --pr-body or --pr-body-file, not both"
fi

case "$MERGE_METHOD" in
  squash|merge|rebase) ;;
  *) fail "--merge-method must be squash|merge|rebase" ;;
esac

if [ "$BASE_BRANCH" = "main" ] && [ "$ALLOW_MAIN" -ne 1 ]; then
  fail "Direct main merges are blocked. Use --base staging, then promote staging->main."
fi

require_cmd git
require_cmd gh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if [ "$BASE_BRANCH" = "staging" ]; then
  scripts/agents/ensure-staging-branch.sh
fi

BRANCH="$(git branch --show-current)"
[ -n "$BRANCH" ] || fail "Not on a git branch"
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "$BASE_BRANCH" ] || [ "$BRANCH" = "staging" ]; then
  fail "Refusing to ship from protected branch '$BRANCH'. Use a feature branch."
fi

if [ -f .git/index.lock ]; then
  fail "Git index lock exists (.git/index.lock). Resolve lock and rerun."
fi

echo "[1/8] Running checks"
if [ "${SKIP_TASK_BRANCH_AUDIT:-0}" != "1" ]; then
  echo "Running task branch PR linkage audit"
  scripts/agents/check-task-branch-pr-link.sh
else
  echo "Skipping task branch PR linkage audit (SKIP_TASK_BRANCH_AUDIT=1)"
fi

if [ -n "$CHECKS_CMD" ]; then
  bash -lc "$CHECKS_CMD"
else
  echo "No checks command provided; skipping checks."
fi

echo "[2/8] Staging changes"
git add -A

if git diff --cached --quiet; then
  fail "No staged changes to commit"
fi

echo "[3/8] Creating commit"
git commit -m "$COMMIT_MSG"

echo "[4/8] Pushing branch"
git push -u origin "$BRANCH"

echo "[5/8] Creating or reusing PR"
PR_NUMBER=""
if gh pr view --head "$BRANCH" --json number >/tmp/ship_pr_view.json 2>/dev/null; then
  PR_NUMBER="$(sed -n 's/.*"number":\([0-9][0-9]*\).*/\1/p' /tmp/ship_pr_view.json | head -n1)"
else
  if [ -n "$PR_BODY_FILE" ]; then
    PR_URL="$(gh pr create --base "$BASE_BRANCH" --head "$BRANCH" --title "$PR_TITLE" --body-file "$PR_BODY_FILE")"
  else
    PR_URL="$(gh pr create --base "$BASE_BRANCH" --head "$BRANCH" --title "$PR_TITLE" --body "$PR_BODY")"
  fi
  echo "Created PR: $PR_URL"
  PR_NUMBER="$(echo "$PR_URL" | sed -n 's#.*/pull/\([0-9][0-9]*\)$#\1#p')"
fi

[ -n "$PR_NUMBER" ] || fail "Could not resolve PR number"

echo "[6/8] Waiting for required PR checks on #$PR_NUMBER"
wait_for_required_checks "$PR_NUMBER"

echo "[7/8] Merging PR #$PR_NUMBER"
MERGE_FLAG="--squash"
if [ "$MERGE_METHOD" = "merge" ]; then MERGE_FLAG="--merge"; fi
if [ "$MERGE_METHOD" = "rebase" ]; then MERGE_FLAG="--rebase"; fi
gh pr merge "$PR_NUMBER" "$MERGE_FLAG" --delete-branch

echo "[8/8] Fast-forwarding local $BASE_BRANCH"
git switch "$BASE_BRANCH"
git pull --ff-only origin "$BASE_BRANCH"

echo "[PASS] Shipped and merged PR #$PR_NUMBER"
