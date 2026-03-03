#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKG_REF="${1:-agent-automation-kit@latest}"

if ! command -v npx >/dev/null 2>&1; then
  echo "[FAIL] npx is required" >&2
  exit 1
fi

echo "Updating agent automation from ${PKG_REF} into ${ROOT}"
npx --yes --package "${PKG_REF}" agent-automation-update "${ROOT}"
echo "[PASS] Agent automation update complete"
