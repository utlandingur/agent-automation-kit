#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "[FAIL] Remote 'origin' is not configured" >&2
  exit 1
fi

if git ls-remote --exit-code --heads origin staging >/dev/null 2>&1; then
  echo "[PASS] origin/staging exists"
  exit 0
fi

echo "[INFO] origin/staging is missing; recreating from origin/main"
git fetch origin main

if git show-ref --verify --quiet refs/heads/staging; then
  git branch -f staging origin/main
else
  git branch staging origin/main
fi

git push -u origin staging
echo "[PASS] Recreated origin/staging from origin/main"
