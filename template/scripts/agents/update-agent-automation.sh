#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="${1:-${AGENT_AUTOMATION_KIT_SOURCE:-${AGENT_AUTOMATION_KIT_DIR:-}}}"
REF="${AGENT_AUTOMATION_KIT_REF:-}"
ALLOW_UNPINNED="${AGENT_AUTOMATION_ALLOW_UNPINNED:-0}"
TMP_DIR=""
CORE_KIT_DIR=""
SOURCE_DESC="${SOURCE}"
EXTRA_FLAGS=()

is_truthy() {
  case "${1:-0}" in
    1|yes|true|TRUE|Yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

is_commit_sha() {
  [[ "${1:-}" =~ ^[0-9a-fA-F]{40}$ ]]
}

usage_fail() {
  cat >&2 <<'EOF_USAGE'
[FAIL] Missing required source/ref for core kit update.
Usage:
  scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git <ref>
  scripts/agents/update-agent-automation.sh /absolute/path/to/local/clone <ref>
or set env:
  AGENT_AUTOMATION_KIT_SOURCE=https://github.com/<org>/agent-automation-kit.git
  AGENT_AUTOMATION_KIT_REF=<tag-or-commit-sha>

Security defaults:
- Ref is required.
- Use immutable refs (commit SHA strongly preferred).
- Branch refs are blocked by default. Override only with:
  AGENT_AUTOMATION_ALLOW_UNPINNED=1
EOF_USAGE
  exit 1
}

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

if [[ -z "${SOURCE}" || -z "${REF}" ]]; then
  usage_fail
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

resolve_source_repo_url() {
  local source="$1"
  if [[ -d "${source}" ]]; then
    if [[ ! -d "${source}/.git" ]]; then
      echo "[FAIL] Local source is not a git repo: ${source}" >&2
      exit 1
    fi
    local origin_url
    origin_url="$(git -C "${source}" remote get-url origin 2>/dev/null || true)"
    if [[ -z "${origin_url}" ]]; then
      echo "[FAIL] Local source has no 'origin' remote: ${source}" >&2
      exit 1
    fi
    printf '%s' "${origin_url}"
    return 0
  fi

  printf '%s' "${source}"
}

enforce_ref_policy() {
  local repo_url="$1"
  local ref="$2"

  if is_commit_sha "${ref}"; then
    return 0
  fi

  if git ls-remote --exit-code --tags --refs "${repo_url}" "refs/tags/${ref}" >/dev/null 2>&1; then
    return 0
  fi

  if is_truthy "${ALLOW_UNPINNED}"; then
    echo "[WARN] Using unpinned ref '${ref}'. Prefer commit SHA or tag for safer updates." >&2
    return 0
  fi

  echo "[FAIL] Ref '${ref}' is not an immutable commit SHA or tag." >&2
  echo "Set AGENT_AUTOMATION_ALLOW_UNPINNED=1 only when branch-based updates are explicitly required." >&2
  exit 1
}

clone_repo_at_ref() {
  local repo_url="$1"
  local ref="$2"

  require_git
  TMP_DIR="$(mktemp -d)"

  if is_commit_sha "${ref}"; then
    git init -q "${TMP_DIR}"
    git -C "${TMP_DIR}" remote add origin "${repo_url}"
    git -C "${TMP_DIR}" fetch --depth 1 origin "${ref}" >/dev/null
    git -C "${TMP_DIR}" checkout --detach -q FETCH_HEAD
  else
    git clone --depth 1 --branch "${ref}" "${repo_url}" "${TMP_DIR}" >/dev/null
  fi

  CORE_KIT_DIR="${TMP_DIR}"
}

SOURCE_URL="$(resolve_source_repo_url "${SOURCE}")"
enforce_ref_policy "${SOURCE_URL}" "${REF}"
clone_repo_at_ref "${SOURCE_URL}" "${REF}"

RESOLVED_COMMIT="$(git -C "${CORE_KIT_DIR}" rev-parse HEAD)"
if is_commit_sha "${REF}" && [[ "${RESOLVED_COMMIT}" != "${REF}" ]]; then
  echo "[FAIL] Resolved commit '${RESOLVED_COMMIT}' does not match requested '${REF}'" >&2
  exit 1
fi

SOURCE_DESC="${SOURCE_URL}@${REF}#${RESOLVED_COMMIT}"

INSTALLER="${CORE_KIT_DIR}/bin/install.js"
if [[ ! -f "${INSTALLER}" ]]; then
  echo "[FAIL] Installer not found at ${INSTALLER}" >&2
  exit 1
fi

echo "Updating agent automation from ${SOURCE_DESC} into ${ROOT}"
node "${INSTALLER}" "${ROOT}" --update "${EXTRA_FLAGS[@]}"
echo "[PASS] Agent automation update complete"
