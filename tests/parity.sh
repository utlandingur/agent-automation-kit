#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKG_ROOT="${ROOT}/agent-automation"
TEMPLATE_SCRIPTS="${PKG_ROOT}/template/scripts/agents"
KIT_SCRIPTS="${ROOT}/agent-kit/payload/scripts/agents"
SOURCE_SCRIPTS="${ROOT}/scripts/agents"

for dir in "${TEMPLATE_SCRIPTS}" "${KIT_SCRIPTS}" "${SOURCE_SCRIPTS}"; do
  [ -d "${dir}" ] || { echo "[FAIL] missing directory: ${dir}"; exit 1; }
done

tmp_dir="$(mktemp -d /tmp/agent-automation-parity.XXXXXX)"
trap 'rm -rf "${tmp_dir}"' EXIT

find "${SOURCE_SCRIPTS}" -maxdepth 1 -type f -print | sed "s#^${SOURCE_SCRIPTS}/##" | sort >"${tmp_dir}/source.txt"
find "${TEMPLATE_SCRIPTS}" -maxdepth 1 -type f -print | sed "s#^${TEMPLATE_SCRIPTS}/##" | sort >"${tmp_dir}/template.txt"
find "${KIT_SCRIPTS}" -maxdepth 1 -type f -print | sed "s#^${KIT_SCRIPTS}/##" | sort >"${tmp_dir}/kit.txt"

if ! diff -u "${tmp_dir}/source.txt" "${tmp_dir}/template.txt"; then
  echo "[FAIL] agent-automation template scripts diverge from scripts/agents"
  exit 1
fi

if ! diff -u "${tmp_dir}/source.txt" "${tmp_dir}/kit.txt"; then
  echo "[FAIL] agent-kit payload scripts diverge from scripts/agents"
  exit 1
fi

echo "[PASS] Script parity checks passed"
