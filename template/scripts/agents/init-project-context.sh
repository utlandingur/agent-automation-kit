#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="${ROOT}/docs/agent-project-profile.md"
AGENTS="${ROOT}/agents.md"

if [[ ! -f "${PROFILE}" || ! -f "${AGENTS}" ]]; then
  echo "[FAIL] Missing required files. Run installer first." >&2
  exit 1
fi

read_with_default() {
  local prompt="$1"
  local default="$2"
  local value
  read -r -p "${prompt} [${default}]: " value
  if [[ -z "${value}" ]]; then
    value="${default}"
  fi
  printf '%s' "${value}"
}

PROJECT_PURPOSE="$(read_with_default "Project purpose statement" "Ship this product reliably with strict contracts and clean collaboration.")"
SCOPE_INPUT="$(read_with_default "Product input scope" "User or system input")"
SCOPE_PROCESSING="$(read_with_default "Product processing scope" "Core application/business logic")"
SCOPE_OUTPUT="$(read_with_default "Product output scope" "User-facing output and side effects")"
SCOPE_PRIORITIES="$(read_with_default "Top priorities" "Reliability, clarity, and maintainability")"
DESIGN_PATTERNS="$(read_with_default "Design pattern baseline" "Use existing design system/components before inventing new patterns")"
DESIGN_REFERENCES="$(read_with_default "Design references docs (comma-separated or N/A)" "docs/design-system.md, docs/frontend-standards.md")"
ARCHITECTURE_GUARDRAILS="$(read_with_default "Architecture guardrails" "Keep modules small, explicit contracts, and test coverage for behavior changes")"
LINT_CMD="$(read_with_default "Lint command" "yarn lint")"
TEST_CMD="$(read_with_default "Unit test command" "yarn test")"
E2E_CMD="$(read_with_default "E2E test command (or N/A)" "yarn test:e2e")"

perl -0pi -e "s#Purpose: .*#Purpose: ${PROJECT_PURPOSE//#/\\#}#m" "${AGENTS}"
perl -0pi -e "s#- Input:.*#- Input: ${SCOPE_INPUT//#/\\#}#m; s#- Processing:.*#- Processing: ${SCOPE_PROCESSING//#/\\#}#m; s#- Output:.*#- Output: ${SCOPE_OUTPUT//#/\\#}#m; s#- Priorities:.*#- Priorities: ${SCOPE_PRIORITIES//#/\\#}#m" "${AGENTS}"
perl -0pi -e "s#- `<LINT_COMMAND>`#- `${LINT_CMD//#/\\#}`#m; s#- `<UNIT_TEST_COMMAND>`#- `${TEST_CMD//#/\\#}`#m" "${AGENTS}"

cat > "${PROFILE}" <<EOF
# Agent Project Profile

## Product Scope
- Input: ${SCOPE_INPUT}
- Processing: ${SCOPE_PROCESSING}
- Output: ${SCOPE_OUTPUT}
- Priorities: ${SCOPE_PRIORITIES}

## Design Pattern Baseline
- Patterns: ${DESIGN_PATTERNS}
- References: ${DESIGN_REFERENCES}

## Architecture Guardrails
- ${ARCHITECTURE_GUARDRAILS}

## Non-Negotiable Contracts
- 

## Hard-Stop Domains
- 

## Validation Commands
- lint: \`${LINT_CMD}\`
- unit tests: \`${TEST_CMD}\`
- e2e tests: \`${E2E_CMD}\`

## Branch and PR Rules
- 

## Security/Privacy Notes
- 
EOF

echo "[PASS] Project context initialized."
echo "Updated:"
echo "  - ${AGENTS}"
echo "  - ${PROFILE}"
echo
echo "Note: Safe updates preserve local edits by default. Changed project-specific files are not auto-overwritten during update mode."
