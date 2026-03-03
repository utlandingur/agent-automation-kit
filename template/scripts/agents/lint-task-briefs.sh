#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASK_DIR="${ROOT}/docs/tasks"

fail() {
  echo "[FAIL] $1"
  exit 1
}

required_sections=(
  "## Task ID"
  "## Slug"
  "## Lifecycle"
  "## Roles"
  "## User Story"
  "## Goal Alignment"
  "## Dependencies"
  "## UI Impact"
  "## Model Tier"
  "## Required Context"
  "## In Scope"
  "## Out of Scope"
  "## Acceptance Criteria"
  "## Required Tests (TDD)"
)

task_files=()
while IFS= read -r f; do
  task_files+=("$f")
done < <(find "${TASK_DIR}" -mindepth 2 -maxdepth 2 -type f -name 'T*.md' | sort)

[ "${#task_files[@]}" -gt 0 ] || fail "No task files found under docs/tasks/<lane>/T*.md"

for f in "${task_files[@]}"; do
  base="$(basename "$f")"
  lane="$(basename "$(dirname "$f")")"

  for s in "${required_sections[@]}"; do
    rg -Fq "${s}" "$f" || fail "${base}: missing section '${s}'"
  done

  stage="$(awk '
    /^## Lifecycle$/ {in_lifecycle=1; next}
    /^## / {if (in_lifecycle) exit}
    in_lifecycle && /^- Stage: `[^`]+`/ {
      line=$0
      sub(/^- Stage: `/, "", line)
      sub(/`$/, "", line)
      print line
      exit
    }
  ' "$f")"

  case "${stage}" in
    TODO|DOING|BLOCKED|DONE) ;;
    *)
      fail "${base}: invalid Lifecycle stage '${stage}' (expected TODO|DOING|BLOCKED|DONE)"
      ;;
  esac

  expected_stage=""
  case "${lane}" in
    todo) expected_stage="TODO" ;;
    doing) expected_stage="DOING" ;;
    blocked) expected_stage="BLOCKED" ;;
    done) expected_stage="DONE" ;;
    *)
      fail "${base}: invalid lane folder '${lane}' (expected todo|doing|blocked|done)"
      ;;
  esac

  [ "${stage}" = "${expected_stage}" ] || fail "${base}: lane '${lane}' conflicts with stage '${stage}'"

  unit_estimate="$(awk '
    /^## Lifecycle$/ {in_lifecycle=1; next}
    /^## / {if (in_lifecycle) exit}
    in_lifecycle && /^- Unit Estimate: `[0-9]+`/ {
      line=$0
      sub(/^- Unit Estimate: `/, "", line)
      sub(/`$/, "", line)
      print line
      exit
    }
  ' "$f")"
  [[ "${unit_estimate}" =~ ^[0-9]+$ ]] || fail "${base}: missing valid Unit Estimate in Lifecycle"

  rg -q '^- Status:\s*`(READY|BLOCKED)`' "$f" || fail "${base}: missing valid Dependencies status"
  rg -q '^- `(simple|standard|complex)`' "$f" || fail "${base}: missing valid Model Tier (simple|standard|complex)"

  dep_status="$(awk '
    /^## Dependencies$/ {in_deps=1; next}
    /^## / {if (in_deps) exit}
    in_deps && /^- Status: `[^`]+`/ {
      line=$0
      sub(/^- Status: `/, "", line)
      sub(/`$/, "", line)
      print line
      exit
    }
  ' "$f")"

  case "${stage}" in
    BLOCKED)
      [ "${dep_status}" = "BLOCKED" ] || fail "${base}: BLOCKED stage must have Dependencies status BLOCKED"
      ;;
    TODO|DOING|DONE)
      [ "${dep_status}" = "READY" ] || fail "${base}: ${stage} stage must have Dependencies status READY"
      ;;
  esac

  model_tier="$(awk '
    /^## Model Tier$/ {in_tier=1; next}
    /^## / {if (in_tier) exit}
    in_tier && /^- `[^`]+`/ {
      line=$0
      sub(/^- `/, "", line)
      sub(/`$/, "", line)
      print line
      exit
    }
  ' "$f")"
  expected_units=1
  case "${model_tier}" in
    simple) expected_units=1 ;;
    standard) expected_units=3 ;;
    complex) expected_units=6 ;;
  esac
  [ "${unit_estimate}" -eq "${expected_units}" ] || fail "${base}: Unit Estimate (${unit_estimate}) must match Model Tier (${model_tier}=>${expected_units})"

  is_ui="no"
  if rg -q "^## UI Impact$" "$f" && rg -q '^- `Yes`' "$f"; then
    is_ui="yes"
  fi

  rg -q "docs/agent-runtime-rules.md" "$f" || fail "${base}: Required Context must include docs/agent-runtime-rules.md"

  if [ "$is_ui" = "yes" ]; then
    rg -q "docs/design-system.md" "$f" || fail "${base}: UI task missing docs/design-system.md"
    rg -q "docs/frontend-standards.md" "$f" || fail "${base}: UI task missing docs/frontend-standards.md"
  fi

  # Encourage compact context windows.
  context_lines=$(awk '
    /^## Required Context$/ {in_ctx=1; next}
    /^## / {if (in_ctx) exit}
    in_ctx && /^- / {count++}
    END {print count+0}
  ' "$f")

  if [ "$is_ui" = "yes" ] && [ "$context_lines" -gt 6 ]; then
    fail "${base}: UI task context too large (${context_lines} entries > 6)"
  fi

  if [ "$is_ui" = "no" ] && [ "$context_lines" -gt 4 ]; then
    fail "${base}: non-UI task context too large (${context_lines} entries > 4)"
  fi

  has_skills_section=0
  if rg -q '^## Recommended Skills \(Optional\)$' "$f"; then
    has_skills_section=1
  fi

  if [ "$has_skills_section" -eq 1 ]; then
    skill_lines=$(awk '
      /^## Recommended Skills \(Optional\)$/ {in_skills=1; next}
      /^## / {if (in_skills) exit}
      in_skills && /^- / {count++}
      END {print count+0}
    ' "$f")

    if [ "$skill_lines" -gt 3 ]; then
      fail "${base}: Recommended Skills exceeds max 3 entries (${skill_lines})"
    fi

    while IFS= read -r skill_line; do
      skill_path="${skill_line#- }"
      # Ignore template explanatory lines and blank markers.
      if [[ "$skill_path" =~ ^List\ up\ to ]] || [[ "$skill_path" =~ ^Use\ repo-local ]] || [[ "$skill_path" =~ ^Example: ]] || [[ "$skill_path" =~ ^$ ]]; then
        continue
      fi
      if ! printf '%s\n' "$skill_path" | rg -q '^`docs/skills/external/[^`]+`$'; then
        fail "${base}: Recommended Skills entry must be repo-local path under docs/skills/external (got: ${skill_line})"
      fi
    done < <(awk '
      /^## Recommended Skills \(Optional\)$/ {in_skills=1; next}
      /^## / {if (in_skills) exit}
      in_skills && /^- / {print}
    ' "$f")
  fi

  if [ "${stage}" = "DONE" ]; then
    rg -q '^## Completion Record$' "$f" || fail "${base}: DONE tasks must include '## Completion Record'"
    rg -q '^- Acceptance Criteria:\s*`PASS`' "$f" || fail "${base}: DONE task must mark Acceptance Criteria PASS"
    rg -q '^- Required Tests:\s*`PASS`' "$f" || fail "${base}: DONE task must mark Required Tests PASS"
    rg -q '^- Evidence:\s*`[^`]+`' "$f" || fail "${base}: DONE task must include Completion Record evidence"
    rg -q '^- Completion Evidence:\s*`[^`]+`' "$f" || fail "${base}: DONE task must include Lifecycle completion evidence"
    if rg -q '^- Completion Evidence:\s*`N/A`' "$f"; then
      fail "${base}: DONE task cannot have Lifecycle completion evidence N/A"
    fi
  fi
done

echo "[PASS] task brief lint passed"
