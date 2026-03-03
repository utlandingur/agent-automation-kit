#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="${ROOT}/docs/agent-project-profile.md"
AGENTS="${ROOT}/agents.md"
README="${ROOT}/README.md"
PACKAGE_JSON="${ROOT}/package.json"

if [[ ! -f "${PROFILE}" || ! -f "${AGENTS}" ]]; then
  echo "[FAIL] Missing required files. Run installer first." >&2
  exit 1
fi

if [[ ! -t 0 ]]; then
  echo "[FAIL] init-project-context.sh requires interactive confirmation in a TTY session." >&2
  exit 1
fi

trim() {
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

profile_field() {
  local label="$1"
  if [[ -f "${PROFILE}" ]]; then
    awk -v key="- ${label}: " 'index($0,key)==1 {print substr($0,length(key)+1); exit}' "${PROFILE}" | trim
  fi
}

first_non_empty() {
  local out=""
  for candidate in "$@"; do
    if [[ -n "${candidate}" ]]; then
      out="${candidate}"
      break
    fi
  done
  printf '%s' "${out}"
}

confirm_value() {
  local prompt="$1"
  local suggested="$2"
  local value=""
  local yn=""

  while true; do
    if [[ -n "${suggested}" ]]; then
      read -r -p "${prompt} [${suggested}]: " value
      [[ -z "${value}" ]] && value="${suggested}"
    else
      read -r -p "${prompt}: " value
    fi

    value="$(printf '%s' "${value}" | trim)"
    if [[ -z "${value}" ]]; then
      echo "Value cannot be empty."
      continue
    fi

    read -r -p "Confirm \"${value}\"? (y/n): " yn
    case "${yn}" in
      y|Y|yes|YES) printf '%s' "${value}"; return 0 ;;
      n|N|no|NO) echo "Re-enter value." ;;
      *) echo "Please enter y or n." ;;
    esac
  done
}

package_name=""
lint_from_pkg=""
test_from_pkg=""
e2e_from_pkg=""
if [[ -f "${PACKAGE_JSON}" ]] && command -v node >/dev/null 2>&1; then
  package_name="$(node -e "const p=require(process.argv[1]); console.log(p.name||'')" "${PACKAGE_JSON}" 2>/dev/null || true)"
  lint_from_pkg="$(node -e "const p=require(process.argv[1]); console.log(p.scripts&&p.scripts.lint?'yarn lint':'')" "${PACKAGE_JSON}" 2>/dev/null || true)"
  test_from_pkg="$(node -e "const p=require(process.argv[1]); console.log(p.scripts&&p.scripts.test?'yarn test':'')" "${PACKAGE_JSON}" 2>/dev/null || true)"
  e2e_from_pkg="$(node -e "const p=require(process.argv[1]); const s=p.scripts||{}; console.log(s['test:e2e']?'yarn test:e2e':(s.e2e?'yarn e2e':''))" "${PACKAGE_JSON}" 2>/dev/null || true)"
fi

readme_context=""
readme_summary_line=""
if [[ -f "${README}" ]]; then
  readme_context="$(awk 'NF && $0 !~ /^#/ {print; c++; if (c==3) exit}' "${README}")"
  readme_summary_line="$(awk 'NF && $0 !~ /^#/ {print; exit}' "${README}" | trim)"
fi

existing_agents_purpose="$(awk 'index($0,"Purpose: ")==1 {print substr($0,10); exit}' "${AGENTS}" | trim)"
existing_input="$(profile_field "Input")"
existing_processing="$(profile_field "Processing")"
existing_output="$(profile_field "Output")"
existing_priorities="$(profile_field "Priorities")"
existing_patterns="$(awk 'index($0,"- Patterns: ")==1 {print substr($0,13); exit}' "${PROFILE}" | trim)"
existing_references="$(awk 'index($0,"- References: ")==1 {print substr($0,15); exit}' "${PROFILE}" | trim)"
existing_architecture="$(awk 'index($0,"- ")==1 && seen==1 {print substr($0,3); exit} /^## Architecture Guardrails$/ {seen=1}' "${PROFILE}" | trim)"
existing_lint="$(awk 'index($0,"- lint: `")==1 {sub(/^- lint: `/,""); sub(/`$/,""); print; exit}' "${PROFILE}" | trim)"
existing_test="$(awk 'index($0,"- unit tests: `")==1 {sub(/^- unit tests: `/,""); sub(/`$/,""); print; exit}' "${PROFILE}" | trim)"
existing_e2e="$(awk 'index($0,"- e2e tests: `")==1 {sub(/^- e2e tests: `/,""); sub(/`$/,""); print; exit}' "${PROFILE}" | trim)"

echo "Detected project context (for suggestions):"
if [[ -n "${package_name}" ]]; then
  echo "- package.json name: ${package_name}"
fi
if [[ -n "${readme_context}" ]]; then
  echo "- README summary:"
  printf '%s\n' "${readme_context}" | sed 's/^/  - /'
fi
echo "- Existing profile/agents values will be used as first suggestions when present."
echo

default_purpose="$(first_non_empty "${existing_agents_purpose}" "${readme_summary_line}" "Ship ${package_name:-this project} reliably with strict contracts and clean collaboration.")"
default_input="$(first_non_empty "${existing_input}" "User or system input")"
default_processing="$(first_non_empty "${existing_processing}" "Core application/business logic")"
default_output="$(first_non_empty "${existing_output}" "User-facing output and side effects")"
default_priorities="$(first_non_empty "${existing_priorities}" "Reliability, clarity, and maintainability")"
default_patterns="$(first_non_empty "${existing_patterns}" "Use existing design system/components before inventing new patterns")"
default_references="$(first_non_empty "${existing_references}" "docs/design-system.md, docs/frontend-standards.md")"
default_architecture="$(first_non_empty "${existing_architecture}" "Keep modules small, explicit contracts, and test coverage for behavior changes")"
default_lint="$(first_non_empty "${existing_lint}" "${lint_from_pkg}" "yarn lint")"
default_test="$(first_non_empty "${existing_test}" "${test_from_pkg}" "yarn test")"
default_e2e="$(first_non_empty "${existing_e2e}" "${e2e_from_pkg}" "N/A")"

PROJECT_PURPOSE="$(confirm_value "Project purpose statement" "${default_purpose}")"
SCOPE_INPUT="$(confirm_value "Product input scope" "${default_input}")"
SCOPE_PROCESSING="$(confirm_value "Product processing scope" "${default_processing}")"
SCOPE_OUTPUT="$(confirm_value "Product output scope" "${default_output}")"
SCOPE_PRIORITIES="$(confirm_value "Top priorities" "${default_priorities}")"
DESIGN_PATTERNS="$(confirm_value "Design pattern baseline" "${default_patterns}")"
DESIGN_REFERENCES="$(confirm_value "Design references docs (comma-separated or N/A)" "${default_references}")"
ARCHITECTURE_GUARDRAILS="$(confirm_value "Architecture guardrails" "${default_architecture}")"
LINT_CMD="$(confirm_value "Lint command" "${default_lint}")"
TEST_CMD="$(confirm_value "Unit test command" "${default_test}")"
E2E_CMD="$(confirm_value "E2E test command (or N/A)" "${default_e2e}")"

escape_hash() {
  printf '%s' "$1" | sed 's/#/\\#/g'
}

PROJECT_PURPOSE_ESC="$(escape_hash "${PROJECT_PURPOSE}")"
SCOPE_INPUT_ESC="$(escape_hash "${SCOPE_INPUT}")"
SCOPE_PROCESSING_ESC="$(escape_hash "${SCOPE_PROCESSING}")"
SCOPE_OUTPUT_ESC="$(escape_hash "${SCOPE_OUTPUT}")"
SCOPE_PRIORITIES_ESC="$(escape_hash "${SCOPE_PRIORITIES}")"
LINT_CMD_ESC="$(escape_hash "${LINT_CMD}")"
TEST_CMD_ESC="$(escape_hash "${TEST_CMD}")"

perl -0pi -e "s#Purpose: .*#Purpose: ${PROJECT_PURPOSE_ESC}#m" "${AGENTS}"
perl -0pi -e "s#- Input:.*#- Input: ${SCOPE_INPUT_ESC}#m; s#- Processing:.*#- Processing: ${SCOPE_PROCESSING_ESC}#m; s#- Output:.*#- Output: ${SCOPE_OUTPUT_ESC}#m; s#- Priorities:.*#- Priorities: ${SCOPE_PRIORITIES_ESC}#m" "${AGENTS}"
perl -0pi -e "s@(## Validation Required\\n)- [^\\n]*\\n- [^\\n]*@\$1- `${LINT_CMD_ESC}`\\n- `${TEST_CMD_ESC}`@s" "${AGENTS}"

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

echo "[PASS] Project context initialized with explicit confirmations."
echo "Updated:"
echo "  - ${AGENTS}"
echo "  - ${PROFILE}"
echo
echo "Note: Safe updates preserve local edits by default. Changed project-specific files are not auto-overwritten during update mode."
