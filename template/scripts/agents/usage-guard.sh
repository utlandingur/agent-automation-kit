#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
USAGE_DIR="${REPO_ROOT}/.ops/usage"
USAGE_FILE="${USAGE_DIR}/agent-usage.tsv"
LIMITS_FILE="${USAGE_DIR}/limits.env"

if [ -f "${LIMITS_FILE}" ]; then
  # Load persisted limits when present.
  # shellcheck disable=SC1090
  source "${LIMITS_FILE}"
fi

LIMITS_VERIFIED="${AGENT_LIMITS_VERIFIED:-0}"
WEEKLY_BUDGET_UNITS="${AGENT_WEEKLY_BUDGET_UNITS:-0}"

MONTHLY_BUDGET_UNITS="${AGENT_MONTHLY_BUDGET_UNITS:-1200}"
DAILY_BUDGET_UNITS_RAW="${AGENT_DAILY_BUDGET_UNITS:-}"
WARN_RATIO_PCT="${AGENT_SCALEBACK_WARN_RATIO_PCT:-70}"
STRICT_RATIO_PCT="${AGENT_SCALEBACK_STRICT_RATIO_PCT:-85}"
DAILY_PAUSE_RATIO_PCT="${AGENT_DAILY_PAUSE_RATIO_PCT:-80}"
WEEKLY_PAUSE_RATIO_PCT="${AGENT_WEEKLY_PAUSE_RATIO_PCT:-${DAILY_PAUSE_RATIO_PCT}}"
ALLOW_OVER_80_PCT="${AGENT_ALLOW_OVER_80_PCT:-0}"

UNIT_SIMPLE="${AGENT_USAGE_UNITS_SIMPLE:-1}"
UNIT_STANDARD="${AGENT_USAGE_UNITS_STANDARD:-3}"
UNIT_COMPLEX="${AGENT_USAGE_UNITS_COMPLEX:-6}"
PROJECT_UPDATE_FILE="${REPO_ROOT}/docs/project-update.md"

derive_daily_budget() {
  local monthly derived
  monthly="$1"
  if [ "$monthly" -le 0 ]; then
    echo 0
    return 0
  fi
  derived=$(( monthly / 30 ))
  if [ "$derived" -lt 1 ]; then
    derived=1
  fi
  echo "$derived"
}

if [ -n "${DAILY_BUDGET_UNITS_RAW}" ]; then
  DAILY_BUDGET_UNITS="${DAILY_BUDGET_UNITS_RAW}"
  DAILY_BUDGET_SOURCE="explicit"
else
  DAILY_BUDGET_UNITS="$(derive_daily_budget "${MONTHLY_BUDGET_UNITS}")"
  DAILY_BUDGET_SOURCE="derived_from_monthly_div_30"
fi

mkdir -p "${USAGE_DIR}"
touch "${USAGE_FILE}"

today="$(date +%Y-%m-%d)"
month="$(date +%Y-%m)"

date_days_ago_ymd() {
  local days="$1"
  if date -v-"${days}"d +%Y-%m-%d >/dev/null 2>&1; then
    date -v-"${days}"d +%Y-%m-%d
    return 0
  fi
  date -d "${days} days ago" +%Y-%m-%d
}

week_start="$(date_days_ago_ymd 6)"

units_for_tier() {
  case "${1:-simple}" in
    simple) echo "${UNIT_SIMPLE}" ;;
    standard) echo "${UNIT_STANDARD}" ;;
    complex) echo "${UNIT_COMPLEX}" ;;
    *) echo "${UNIT_SIMPLE}" ;;
  esac
}

ceil_div() {
  local numerator denominator
  numerator="${1:-0}"
  denominator="${2:-1}"
  if [ "${denominator}" -le 0 ]; then
    echo 0
    return 0
  fi
  echo $(( (numerator + denominator - 1) / denominator ))
}

effective_daily_budget() {
  local d w_per_day m_per_day project_cap eff
  d="${DAILY_BUDGET_UNITS}"
  w_per_day="$(ceil_div "${WEEKLY_BUDGET_UNITS}" 7)"
  m_per_day="$(ceil_div "${MONTHLY_BUDGET_UNITS}" 30)"
  project_cap="$(project_daily_capacity_units)"
  eff="${d}"

  if [ "${w_per_day}" -gt 0 ] && { [ "${eff}" -le 0 ] || [ "${w_per_day}" -lt "${eff}" ]; }; then
    eff="${w_per_day}"
  fi
  if [ "${m_per_day}" -gt 0 ] && { [ "${eff}" -le 0 ] || [ "${m_per_day}" -lt "${eff}" ]; }; then
    eff="${m_per_day}"
  fi
  if [ "${project_cap}" -gt 0 ] && { [ "${eff}" -le 0 ] || [ "${project_cap}" -lt "${eff}" ]; }; then
    eff="${project_cap}"
  fi

  echo "${eff}"
}

project_daily_capacity_units() {
  local line units
  if [ ! -f "${PROJECT_UPDATE_FILE}" ]; then
    echo 0
    return 0
  fi

  line="$(awk '/^- Daily capacity: `/{print; exit}' "${PROJECT_UPDATE_FILE}")"
  units="$(printf '%s' "${line}" | sed -n 's/^- Daily capacity: `\([0-9][0-9]*\) units\/day`$/\1/p')"
  if [[ "${units}" =~ ^[0-9]+$ ]]; then
    echo "${units}"
    return 0
  fi
  echo 0
}

sum_units_for_day() {
  local ledger_done_units task_done_units
  ledger_done_units="$(awk -F '\t' -v d="${today}" '$2==d {sum += $7} END {print sum+0}' "${USAGE_FILE}")"
  task_done_units="$(sum_done_task_units_for_day)"

  if [ "${task_done_units}" -gt "${ledger_done_units}" ]; then
    echo "${task_done_units}"
    return 0
  fi
  echo "${ledger_done_units}"
}

sum_done_task_units_for_day() {
  local tasks_dir total
  tasks_dir="${REPO_ROOT}/docs/tasks/done"
  total=0

  if [ ! -d "${tasks_dir}" ]; then
    echo 0
    return 0
  fi

  for f in "${tasks_dir}"/T*.md; do
    [ -f "${f}" ] || continue
    local last_updated unit_estimate
    last_updated="$(awk '/^- Last Updated: `/{gsub(/^- Last Updated: `|`$/,"",$0); print $0; exit}' "${f}")"
    [ "${last_updated}" = "${today}" ] || continue

    unit_estimate="$(awk '/^- Unit Estimate: `/{gsub(/^- Unit Estimate: `|`$/,"",$0); print $0; exit}' "${f}")"
    if [[ "${unit_estimate}" =~ ^[0-9]+$ ]]; then
      total=$(( total + unit_estimate ))
    fi
  done

  echo "${total}"
}

sum_units_for_month() {
  awk -F '\t' -v m="${month}" '$3==m {sum += $7} END {print sum+0}' "${USAGE_FILE}"
}

sum_units_for_week() {
  awk -F '\t' -v ws="${week_start}" -v td="${today}" '$2>=ws && $2<=td {sum += $7} END {print sum+0}' "${USAGE_FILE}"
}

is_truthy() {
  case "${1:-0}" in
    1|yes|true|TRUE|Yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

max_ratio_pct() {
  local day_used week_used month_used day_ratio week_ratio month_ratio max_ratio effective_day_budget
  day_used="$(sum_units_for_day)"
  week_used="$(sum_units_for_week)"
  month_used="$(sum_units_for_month)"
  effective_day_budget="$(effective_daily_budget)"

  day_ratio=0
  if [ "${effective_day_budget}" -gt 0 ]; then
    day_ratio=$(( day_used * 100 / effective_day_budget ))
  fi

  week_ratio=0
  if [ "${WEEKLY_BUDGET_UNITS}" -gt 0 ]; then
    week_ratio=$(( week_used * 100 / WEEKLY_BUDGET_UNITS ))
  fi

  month_ratio=0
  if [ "${MONTHLY_BUDGET_UNITS}" -gt 0 ]; then
    month_ratio=$(( month_used * 100 / MONTHLY_BUDGET_UNITS ))
  fi

  max_ratio="${day_ratio}"
  if [ "${week_ratio}" -gt "${max_ratio}" ]; then
    max_ratio="${week_ratio}"
  fi
  if [ "${month_ratio}" -gt "${max_ratio}" ]; then
    max_ratio="${month_ratio}"
  fi

  echo "${max_ratio}"
}

downgrade_one_step() {
  case "${1:-simple}" in
    complex) echo "standard" ;;
    standard) echo "simple" ;;
    simple) echo "simple" ;;
    *) echo "simple" ;;
  esac
}

resolve_tier() {
  local requested ratio
  requested="${1:-simple}"
  ratio="$(max_ratio_pct)"

  if [ "${ratio}" -ge 100 ]; then
    echo "BLOCKED"
    return 0
  fi

  if [ "${ratio}" -ge "${STRICT_RATIO_PCT}" ]; then
    echo "simple"
    return 0
  fi

  if [ "${ratio}" -ge "${WARN_RATIO_PCT}" ]; then
    downgrade_one_step "${requested}"
    return 0
  fi

  case "${requested}" in
    simple|standard|complex) echo "${requested}" ;;
    *) echo "simple" ;;
  esac
}

check_can_spawn() {
  local tier units day_used week_used month_used day_total week_total month_total day_ratio_after week_ratio_after effective_day_budget
  if ! is_truthy "${LIMITS_VERIFIED}"; then
    echo "Limits are not verified. Set AGENT_LIMITS_VERIFIED=1 and provide AGENT_DAILY_BUDGET_UNITS/AGENT_WEEKLY_BUDGET_UNITS/AGENT_MONTHLY_BUDGET_UNITS."
    return 1
  fi
  tier="${1:-simple}"
  units="$(units_for_tier "${tier}")"
  day_used="$(sum_units_for_day)"
  week_used="$(sum_units_for_week)"
  month_used="$(sum_units_for_month)"
  day_total=$(( day_used + units ))
  week_total=$(( week_used + units ))
  month_total=$(( month_used + units ))
  effective_day_budget="$(effective_daily_budget)"
  day_ratio_after=0
  week_ratio_after=0
  if [ "${effective_day_budget}" -gt 0 ]; then
    day_ratio_after=$(( day_total * 100 / effective_day_budget ))
  fi
  if [ "${WEEKLY_BUDGET_UNITS}" -gt 0 ]; then
    week_ratio_after=$(( week_total * 100 / WEEKLY_BUDGET_UNITS ))
  fi

  if [ "${effective_day_budget}" -gt 0 ] && [ "${day_ratio_after}" -gt "${DAILY_PAUSE_RATIO_PCT}" ]; then
    if [ "${ALLOW_OVER_80_PCT}" != "1" ] && [ "${ALLOW_OVER_80_PCT}" != "yes" ] && [ "${ALLOW_OVER_80_PCT}" != "true" ]; then
      echo "Effective daily usage (daily/weekly/monthly paced) would exceed ${DAILY_PAUSE_RATIO_PCT}% (${day_ratio_after}%). Pause required unless user explicitly approves override."
      return 1
    fi
  fi

  if [ "${WEEKLY_BUDGET_UNITS}" -gt 0 ] && [ "${week_ratio_after}" -gt "${WEEKLY_PAUSE_RATIO_PCT}" ]; then
    if [ "${ALLOW_OVER_80_PCT}" != "1" ] && [ "${ALLOW_OVER_80_PCT}" != "yes" ] && [ "${ALLOW_OVER_80_PCT}" != "true" ]; then
      echo "Weekly usage would exceed ${WEEKLY_PAUSE_RATIO_PCT}% (${week_ratio_after}%). Pause required unless user explicitly approves override."
      return 1
    fi
  fi

  if [ "${effective_day_budget}" -gt 0 ] && [ "${day_total}" -gt "${effective_day_budget}" ]; then
    echo "Effective daily budget exceeded (${day_total}/${effective_day_budget} units; min of daily/weekly/7/monthly/30)."
    return 1
  fi

  if [ "${WEEKLY_BUDGET_UNITS}" -gt 0 ] && [ "${week_total}" -gt "${WEEKLY_BUDGET_UNITS}" ]; then
    echo "Weekly budget exceeded (${week_total}/${WEEKLY_BUDGET_UNITS} units)."
    return 1
  fi

  if [ "${MONTHLY_BUDGET_UNITS}" -gt 0 ] && [ "${month_total}" -gt "${MONTHLY_BUDGET_UNITS}" ]; then
    echo "Monthly budget exceeded (${month_total}/${MONTHLY_BUDGET_UNITS} units)."
    return 1
  fi

  echo "OK"
}

record_usage() {
  if [ "$#" -ne 5 ]; then
    echo "Usage: $0 record <ticket_id> <slug> <tier> <model> <pid>"
    exit 1
  fi
  local ticket slug tier model pid units now_epoch
  ticket="$1"
  slug="$2"
  tier="$3"
  model="$4"
  pid="$5"
  units="$(units_for_tier "${tier}")"
  now_epoch="$(date +%s)"
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "${now_epoch}" "${today}" "${month}" "${ticket}" "${slug}" "${tier}" "${units}" "${model}" "${pid}" >> "${USAGE_FILE}"
}

show_status() {
  local day_used week_used month_used ratio day_rem week_rem month_rem eff_day eff_day_rem
  local ledger_day_used task_done_units project_cap
  ledger_day_used="$(awk -F '\t' -v d="${today}" '$2==d {sum += $7} END {print sum+0}' "${USAGE_FILE}")"
  task_done_units="$(sum_done_task_units_for_day)"
  project_cap="$(project_daily_capacity_units)"
  day_used="$(sum_units_for_day)"
  week_used="$(sum_units_for_week)"
  month_used="$(sum_units_for_month)"
  eff_day="$(effective_daily_budget)"
  ratio="$(max_ratio_pct)"
  day_rem=$(( eff_day - day_used ))
  week_rem=$(( WEEKLY_BUDGET_UNITS - week_used ))
  month_rem=$(( MONTHLY_BUDGET_UNITS - month_used ))
  eff_day_rem=$(( eff_day - day_used ))

  echo "Usage status"
  echo "- Date: ${today}"
  echo "- Week window: ${week_start}..${today}"
  echo "- Month: ${month}"
  if is_truthy "${LIMITS_VERIFIED}"; then
    if [ -f "${LIMITS_FILE}" ]; then
      echo "- Limits: VERIFIED (source: ${LIMITS_FILE})"
    else
      echo "- Limits: VERIFIED (source: AGENT_*_BUDGET_UNITS)"
    fi
  else
    echo "- Limits: UNVERIFIED (spawns blocked)"
  fi
  echo "- Effective daily units: ${day_used}/${eff_day} (remaining ${day_rem})"
  echo "- Daily units sources: ledger=${ledger_day_used}, done_tasks_today=${task_done_units}"
  if [ "${project_cap}" -gt 0 ]; then
    echo "- Project daily capacity: ${project_cap} units/day (from docs/project-update.md)"
  fi
  echo "- Daily budget source: ${DAILY_BUDGET_SOURCE}"
  echo "- Monthly units: ${month_used}/${MONTHLY_BUDGET_UNITS} (remaining ${month_rem})"
  echo "- Scaleback ratio: ${ratio}% (warn ${WARN_RATIO_PCT}%, strict ${STRICT_RATIO_PCT}%)"
  echo "- Daily pause threshold: ${DAILY_PAUSE_RATIO_PCT}% (override: AGENT_ALLOW_OVER_80_PCT=1)"
  echo "- Weekly pause threshold: ${WEEKLY_PAUSE_RATIO_PCT}% (override: AGENT_ALLOW_OVER_80_PCT=1)"
  echo "- Unit weights: simple=${UNIT_SIMPLE}, standard=${UNIT_STANDARD}, complex=${UNIT_COMPLEX}"
  if ! is_truthy "${LIMITS_VERIFIED}"; then
    echo "- Action: spawn blocked until limits are verified and set"
  elif [ "${ratio}" -ge 100 ]; then
    echo "- Action: spawning blocked (budget exhausted)"
  elif [ "${ratio}" -ge "${STRICT_RATIO_PCT}" ]; then
    echo "- Action: force simple tier"
  elif [ "${ratio}" -ge "${WARN_RATIO_PCT}" ]; then
    echo "- Action: downgrade one tier on spawn"
  else
    echo "- Action: normal tier routing"
  fi
}

calibrate_limits_from_observed() {
  if [ "$#" -lt 2 ]; then
    echo "Usage: $0 calibrate <daily_used_pct> <weekly_used_pct> [monthly_used_pct]"
    exit 1
  fi

  local observed_daily_pct observed_weekly_pct observed_monthly_pct
  local day_used week_used month_used
  local daily_budget weekly_budget monthly_budget
  local monthly_by_week

  observed_daily_pct="$1"
  observed_weekly_pct="$2"
  observed_monthly_pct="${3:-}"

  day_used="$(sum_units_for_day)"
  week_used="$(sum_units_for_week)"
  month_used="$(sum_units_for_month)"

  if [ "${observed_daily_pct}" -le 0 ] || [ "${observed_weekly_pct}" -le 0 ]; then
    echo "Observed daily/weekly percentages must be > 0."
    exit 1
  fi

  daily_budget="$(ceil_div $(( day_used * 100 )) "${observed_daily_pct}")"
  weekly_budget="$(ceil_div $(( week_used * 100 )) "${observed_weekly_pct}")"
  if [ "${daily_budget}" -lt 1 ]; then daily_budget=1; fi
  if [ "${weekly_budget}" -lt 1 ]; then weekly_budget=1; fi

  if [ -n "${observed_monthly_pct}" ] && [ "${observed_monthly_pct}" -gt 0 ]; then
    monthly_budget="$(ceil_div $(( month_used * 100 )) "${observed_monthly_pct}")"
    if [ "${monthly_budget}" -lt 1 ]; then monthly_budget=1; fi
  else
    monthly_by_week="$(ceil_div $(( weekly_budget * 435 )) 100)"
    monthly_budget="${monthly_by_week}"
    if [ "${monthly_budget}" -lt "${weekly_budget}" ]; then
      monthly_budget="${weekly_budget}"
    fi
  fi

  cat > "${LIMITS_FILE}" <<EOF
AGENT_LIMITS_VERIFIED=1
AGENT_DAILY_BUDGET_UNITS=${daily_budget}
AGENT_WEEKLY_BUDGET_UNITS=${weekly_budget}
AGENT_MONTHLY_BUDGET_UNITS=${monthly_budget}
EOF

  echo "Calibrated limits written to ${LIMITS_FILE}"
  echo "- Observed usage: daily=${observed_daily_pct}% weekly=${observed_weekly_pct}%${observed_monthly_pct:+ monthly=${observed_monthly_pct}%}"
  echo "- Current units seen: day=${day_used} week=${week_used} month=${month_used}"
  echo "- New budgets: daily=${daily_budget} weekly=${weekly_budget} monthly=${monthly_budget}"
}

command="${1:-status}"
case "${command}" in
  status)
    show_status
    ;;
  resolve-tier)
    resolve_tier "${2:-simple}"
    ;;
  can-spawn)
    check_can_spawn "${2:-simple}"
    ;;
  calibrate)
    shift
    calibrate_limits_from_observed "$@"
    ;;
  record)
    shift
    record_usage "$@"
    ;;
  *)
    echo "Usage:"
    echo "  $0 status"
    echo "  $0 resolve-tier <simple|standard|complex>"
    echo "  $0 can-spawn <simple|standard|complex>"
    echo "  $0 calibrate <daily_used_pct> <weekly_used_pct> [monthly_used_pct]"
    echo "  $0 record <ticket_id> <slug> <tier> <model> <pid>"
    exit 1
    ;;
esac
