#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <ticket_id> <question> <recommended_option>"
  exit 1
fi

TICKET_ID="$1"
QUESTION="$2"
RECOMMENDED="$3"
AGENT_NAME="${AGENT_NAME:-$(whoami)}"
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
## Question (${TS})
- Agent: ${AGENT_NAME}
- Task: ${TICKET_ID}
- Question: ${QUESTION}
- Recommended option: ${RECOMMENDED}
- Status: awaiting lead reply

ENTRY

echo "Posted question to ${FILE}"
