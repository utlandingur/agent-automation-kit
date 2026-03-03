#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${ROOT}/template/scripts/agents"

[ -d "${SCRIPTS_DIR}" ] || { echo "[FAIL] missing scripts directory: ${SCRIPTS_DIR}"; exit 1; }

# Ensure date offsets are implemented with macOS and GNU date compatibility.
if rg -n "date -v-" "${SCRIPTS_DIR}" >/dev/null 2>&1; then
  for file in $(rg -l "date -v-" "${SCRIPTS_DIR}"); do
    if ! rg -q "date -d \"\$\{days\} days ago\"|date -d" "${file}"; then
      echo "[FAIL] ${file} uses BSD date offsets without GNU fallback"
      exit 1
    fi
  done
fi

# Ensure any BSD stat usage has GNU stat fallback in the same file.
if rg -n "stat -f %m" "${SCRIPTS_DIR}" >/dev/null 2>&1; then
  for file in $(rg -l "stat -f %m" "${SCRIPTS_DIR}"); do
    if ! rg -q "stat -c %Y" "${file}"; then
      echo "[FAIL] ${file} uses BSD stat without GNU fallback"
      exit 1
    fi
  done
fi

echo "[PASS] Portability checks passed"
