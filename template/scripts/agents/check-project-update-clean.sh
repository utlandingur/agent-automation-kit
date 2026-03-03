#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

scripts/agents/update-project-update.sh >/dev/null

if ! git diff --quiet -- docs/project-update.md; then
  echo "[FAIL] docs/project-update.md is stale. Run scripts/agents/update-project-update.sh and commit the result."
  git --no-pager diff -- docs/project-update.md
  exit 1
fi

echo "[PASS] docs/project-update.md is up to date"
