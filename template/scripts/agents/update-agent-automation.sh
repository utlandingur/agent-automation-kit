#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="${1:-${AGENT_AUTOMATION_KIT_SOURCE:-${AGENT_AUTOMATION_KIT_DIR:-}}}"
REF="${AGENT_AUTOMATION_KIT_REF:-}"
TMP_DIR=""
SOURCE_DESC="${SOURCE}"
EXTRA_FLAGS=()

if [[ $# -ge 2 ]]; then
  if [[ "${2}" == --* ]]; then
    EXTRA_FLAGS=("${@:2}")
  else
    REF="${2}"
    if [[ $# -ge 3 ]]; then
      EXTRA_FLAGS=("${@:3}")
    fi
  fi
fi

if [[ -z "${SOURCE}" ]]; then
  cat >&2 <<'EOF'
[FAIL] Missing core kit source.
Usage:
  scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git [ref]
  scripts/agents/update-agent-automation.sh /absolute/path/to/local/clone [ref]
or set env:
  AGENT_AUTOMATION_KIT_SOURCE=https://github.com/<org>/agent-automation-kit.git
  AGENT_AUTOMATION_KIT_REF=<branch-or-tag>   # optional

Note:
  Local paths are used only to discover their 'origin' remote.
  Updates are always cloned from remote (GitHub/origin), never from local files.
EOF
  exit 1
fi

cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}
trap cleanup EXIT

require_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "[FAIL] git is required for repository-based updates" >&2
    exit 1
  fi
}

clone_repo() {
  local repo_url="$1"
  local ref="$2"
  require_git
  TMP_DIR="$(mktemp -d)"
  if [[ -n "${ref}" ]]; then
    git clone --depth 1 --branch "${ref}" "${repo_url}" "${TMP_DIR}" >/dev/null
  else
    git clone --depth 1 "${repo_url}" "${TMP_DIR}" >/dev/null
  fi
  CORE_KIT_DIR="${TMP_DIR}"
}

if [[ -d "${SOURCE}" ]]; then
  if [[ -d "${SOURCE}/.git" ]]; then
    ORIGIN_URL="$(git -C "${SOURCE}" remote get-url origin 2>/dev/null || true)"
    if [[ -n "${ORIGIN_URL}" ]]; then
      clone_repo "${ORIGIN_URL}" "${REF}"
      SOURCE_DESC="${ORIGIN_URL}${REF:+@${REF}}"
    else
      echo "[FAIL] Local source has no 'origin' remote: ${SOURCE}" >&2
      exit 1
    fi
  else
    echo "[FAIL] Local source is not a git repo: ${SOURCE}" >&2
    exit 1
  fi
else
  clone_repo "${SOURCE}" "${REF}"
  SOURCE_DESC="${SOURCE}${REF:+@${REF}}"
fi

INSTALLER="${CORE_KIT_DIR}/bin/install.js"
if [[ ! -f "${INSTALLER}" ]]; then
  echo "[FAIL] Installer not found at ${INSTALLER}" >&2
  exit 1
fi

echo "Updating agent automation from ${SOURCE_DESC} into ${ROOT}"
node "${INSTALLER}" "${ROOT}" --update "${EXTRA_FLAGS[@]}"
echo "[PASS] Agent automation update complete"
