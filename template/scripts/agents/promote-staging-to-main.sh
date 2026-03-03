#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/agents/promote-staging-to-main.sh \
    [--title "Promote staging to main"] \
    [--body "..."] \
    [--body-file <file>] \
    [--merge-method squash|rebase]

Behavior:
  1) sync local staging and main
  2) create or reuse PR: staging -> main
  3) wait for required PR checks
  4) merge PR (default squash)
  5) fast-forward local main
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

TITLE="promote(staging): sync validated staging into main"
BODY=""
BODY_FILE=""
MERGE_METHOD="squash"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --title)
      shift; TITLE="${1:-}" ;;
    --body)
      shift; BODY="${1:-}" ;;
    --body-file)
      shift; BODY_FILE="${1:-}" ;;
    --merge-method)
      shift; MERGE_METHOD="${1:-}" ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      fail "Unknown argument: $1" ;;
  esac
  shift
done

case "$MERGE_METHOD" in
  squash|rebase) ;;
  *) fail "--merge-method must be squash|rebase" ;;
esac

if [ -n "$BODY" ] && [ -n "$BODY_FILE" ]; then
  fail "Use either --body or --body-file, not both"
fi

require_cmd git
require_cmd gh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

scripts/agents/ensure-staging-branch.sh

if [ -n "$(git status --porcelain)" ]; then
  fail "Working tree is dirty. Commit/stash changes before promotion."
fi

if [ "${SKIP_TASK_BRANCH_AUDIT:-0}" != "1" ]; then
  echo "[0/5] Running task branch PR linkage audit"
  scripts/agents/check-task-branch-pr-link.sh
else
  echo "[0/5] Skipping task branch PR linkage audit (SKIP_TASK_BRANCH_AUDIT=1)"
fi

echo "[1/5] Syncing local staging and main"
git fetch origin
git switch staging
git pull --ff-only origin staging
git switch main
git pull --ff-only origin main

echo "[2/5] Creating or reusing staging->main PR"
PR_NUMBER=""
if gh pr view --base main --head staging --json number >/tmp/promote_pr_view.json 2>/dev/null; then
  PR_NUMBER="$(sed -n 's/.*"number":\([0-9][0-9]*\).*/\1/p' /tmp/promote_pr_view.json | head -n1)"
else
  if [ -n "$BODY_FILE" ]; then
    PR_URL="$(gh pr create --base main --head staging --title "$TITLE" --body-file "$BODY_FILE")"
  elif [ -n "$BODY" ]; then
    PR_URL="$(gh pr create --base main --head staging --title "$TITLE" --body "$BODY")"
  else
    PR_URL="$(gh pr create --base main --head staging --title "$TITLE" --body "Promote validated changes from staging to main after required checks pass.")"
  fi
  echo "Created PR: $PR_URL"
  PR_NUMBER="$(echo "$PR_URL" | sed -n 's#.*/pull/\([0-9][0-9]*\)$#\1#p')"
fi

[ -n "$PR_NUMBER" ] || fail "Could not resolve PR number"

echo "[3/5] Waiting for required PR checks on #$PR_NUMBER"
wait_for_required_checks "$PR_NUMBER"

echo "[4/5] Merging PR #$PR_NUMBER"
MERGE_FLAG="--squash"
if [ "$MERGE_METHOD" = "rebase" ]; then MERGE_FLAG="--rebase"; fi
gh pr merge "$PR_NUMBER" "$MERGE_FLAG"

echo "[5/5] Fast-forwarding local main"
git switch main
git pull --ff-only origin main

echo "[PASS] Promoted staging to main via PR #$PR_NUMBER"
