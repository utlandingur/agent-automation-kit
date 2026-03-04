#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${ROOT}/template/scripts/agents"

[ -d "${SCRIPTS_DIR}" ] || { echo "[FAIL] missing scripts directory: ${SCRIPTS_DIR}"; exit 1; }

find_files_with_pattern() {
  local pattern="$1"
  local root="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -l "${pattern}" "${root}" || true
    return
  fi
  grep -R -l -E "${pattern}" "${root}" || true
}

file_contains_pattern() {
  local pattern="$1"
  local file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -q "${pattern}" "${file}"
    return
  fi
  grep -Eq "${pattern}" "${file}"
}

# Ensure date offsets are implemented with macOS and GNU date compatibility.
date_files="$(find_files_with_pattern "date -v-" "${SCRIPTS_DIR}")"
if [ -n "${date_files}" ]; then
  for file in ${date_files}; do
    if ! file_contains_pattern "date -d \"\$\{days\} days ago\"|date -d" "${file}"; then
      echo "[FAIL] ${file} uses BSD date offsets without GNU fallback"
      exit 1
    fi
  done
fi

# Ensure any BSD stat usage has GNU stat fallback in the same file.
stat_files="$(find_files_with_pattern "stat -f %m" "${SCRIPTS_DIR}")"
if [ -n "${stat_files}" ]; then
  for file in ${stat_files}; do
    if ! file_contains_pattern "stat -c %Y" "${file}"; then
      echo "[FAIL] ${file} uses BSD stat without GNU fallback"
      exit 1
    fi
  done
fi

echo "[PASS] Portability checks passed"
