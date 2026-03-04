#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="${ROOT}/.ops/agent-runs"
USAGE_DIR="${ROOT}/.ops/usage"
OUT_DIR="${ROOT}/.ops/evals/traces"
INCLUDE_PROMPTS=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --include-prompts)
      INCLUDE_PROMPTS=1
      ;;
    -h|--help)
      cat <<'EOF_HELP'
Usage: scripts/agents/export-agent-traces.sh [--include-prompts]

Creates a timestamped trace bundle under .ops/evals/traces/ with:
- agent run logs
- last-message files
- usage logs (if present)
- manifest with file hashes

By default prompt files are excluded to reduce accidental sensitive-context leakage.
Use --include-prompts only when required and approved.
EOF_HELP
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

mkdir -p "${OUT_DIR}"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
staging_dir="${OUT_DIR}/trace-export-${timestamp}"
bundle_file="${OUT_DIR}/trace-export-${timestamp}.tar.gz"
manifest_file="${staging_dir}/MANIFEST.txt"

mkdir -p "${staging_dir}"

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [ -e "${src}" ]; then
    mkdir -p "$(dirname "${dst}")"
    cp "${src}" "${dst}"
  fi
}

if [ -d "${RUN_DIR}" ]; then
  for file in "${RUN_DIR}"/*.log "${RUN_DIR}"/*.last.txt "${RUN_DIR}"/*.pid; do
    [ -f "${file}" ] || continue
    copy_if_exists "${file}" "${staging_dir}/agent-runs/$(basename "${file}")"
  done

  if [ "${INCLUDE_PROMPTS}" -eq 1 ]; then
    for file in "${RUN_DIR}"/*.prompt.txt; do
      [ -f "${file}" ] || continue
      copy_if_exists "${file}" "${staging_dir}/agent-runs/$(basename "${file}")"
    done
  fi
fi

if [ -d "${USAGE_DIR}" ]; then
  for file in "${USAGE_DIR}"/*.tsv "${USAGE_DIR}"/*.env; do
    [ -f "${file}" ] || continue
    copy_if_exists "${file}" "${staging_dir}/usage/$(basename "${file}")"
  done
fi

hash_file() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
    return 0
  fi
  sha256sum "${file}" | awk '{print $1}'
}

{
  echo "generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "include_prompts=${INCLUDE_PROMPTS}"
  echo ""
  find "${staging_dir}" -type f ! -name 'MANIFEST.txt' | sort | while read -r file; do
    rel="${file#${staging_dir}/}"
    echo "${rel} $(hash_file "${file}")"
  done
} > "${manifest_file}"

tar -C "${OUT_DIR}" -czf "${bundle_file}" "$(basename "${staging_dir}")"
rm -rf "${staging_dir}"

echo "[PASS] Trace bundle written: ${bundle_file}"
