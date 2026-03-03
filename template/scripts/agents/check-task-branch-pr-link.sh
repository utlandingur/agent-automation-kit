#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

require_cmd git
require_cmd gh
require_cmd jq

git fetch origin --prune >/dev/null 2>&1

TASK_BRANCHES=()
while IFS= read -r branch; do
  [ -n "$branch" ] && TASK_BRANCHES+=("$branch")
done <<EOF
$(git for-each-ref 'refs/remotes/origin/codex/T*' --format='%(refname:short)' \
  | sed 's#^origin/##' \
  | sort)
EOF

if [ "${#TASK_BRANCHES[@]}" -eq 0 ]; then
  echo "[PASS] No remote codex/T* branches found."
  exit 0
fi

PRS_JSON="$(gh pr list --state all --limit 1000 --json headRefName,state,mergedAt,number,url)"

violations=()

for branch in "${TASK_BRANCHES[@]}"; do
  summary="$(
    jq -r --arg head "$branch" '
      map(select(.headRefName == $head)) as $rows
      | if ($rows | length) == 0 then
          "MISSING_PR"
        elif ($rows | any(.state == "OPEN")) then
          "OPEN_PR"
        elif ($rows | any(.mergedAt != null)) then
          "MERGED_PR"
        else
          "CLOSED_UNMERGED_PR"
        end
    ' <<<"$PRS_JSON"
  )"

  case "$summary" in
    OPEN_PR|MERGED_PR)
      ;;
    MISSING_PR)
      violations+=("$branch :: no PR found")
      ;;
    CLOSED_UNMERGED_PR)
      violations+=("$branch :: only closed-unmerged PRs found")
      ;;
    *)
      violations+=("$branch :: unknown state ($summary)")
      ;;
  esac
done

if [ "${#violations[@]}" -gt 0 ]; then
  echo "[FAIL] Found task branches without a valid PR/merge record:"
  printf ' - %s\n' "${violations[@]}"
  echo "Action: merge via PR, or delete stale branches from origin."
  exit 1
fi

echo "[PASS] All codex/T* branches map to an open or merged PR."
