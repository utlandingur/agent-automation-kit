#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <ticket_id> <decision_and_next_action>"
  exit 1
fi

TICKET_ID="$1"
DECISION="$2"
LEAD_NAME="${LEAD_NAME:-$(whoami)}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${ROOT}/.ops/coordination"
FILE="${DIR}/${TICKET_ID}.md"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p "${DIR}"

if [ ! -f "${FILE}" ]; then
  cat >"${FILE}" <<HEADER
# Coordination Thread: ${TICKET_ID}

HEADER
fi

cat >>"${FILE}" <<ENTRY
## Lead Reply (${TS})
- Lead: ${LEAD_NAME}
- Task: ${TICKET_ID}
- Decision: ${DECISION}
- Status: resolved

ENTRY

echo "Posted lead reply to ${FILE}"
