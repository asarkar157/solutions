#!/usr/bin/env bash
# =============================================================================
# scripts/demo.sh — SE demo launcher
# =============================================================================
# Subcommands:
#   list                List available scenarios with their pitch line.
#   doctor              Pre-flight: check tooling + required env vars.
#   apply  <scenario>   tofu init && apply in examples/scenarios/<scenario>.
#   reset  <scenario>   tofu destroy then re-apply (between back-to-back demos).
#
# Prefers OpenTofu (`tofu`); falls back to HashiCorp Terraform (`terraform`).
# Same scenarios; either CLI works.
#
# Environment variables read (mapped to TF_VAR_* automatically):
#   STACKGEN_URL          → TF_VAR_stackgen_url            (required)
#   STACKGEN_TOKEN        → TF_VAR_stackgen_token          (required)
#   STACKGEN_PROJECT_ID   → TF_VAR_stackgen_project_id     (optional)
#   OPENAI_API_KEY        → TF_VAR_openai_api_key          (one of these required)
#   ANTHROPIC_API_KEY     → TF_VAR_anthropic_api_key
#   GEMINI_API_KEY        → TF_VAR_gemini_api_key
#   AWS_ROLE_ARN          → TF_VAR_aws_role_arn            (per-scenario; aws-sre-demo + finops-weekly)
#   AWS_REGION            → TF_VAR_aws_region              (optional)
#   SLACK_BOT_TOKEN       → TF_VAR_slack_bot_token         (per-scenario)
#   GITHUB_TOKEN          → TF_VAR_github_token            (pipeline-insights + repo-to-iac)
#   GRAFANA_SERVER        → TF_VAR_grafana_server          (incident-triage)
#   GRAFANA_TOKEN         → TF_VAR_grafana_token           (incident-triage)
#   GITHUB_REPO_URL       → TF_VAR_github_repo_url         (repo-to-iac)
#
# The script will not auto-export anything that is already set as TF_VAR_*.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENARIOS_DIR="${ROOT}/examples/scenarios"

# ----- ANSI helpers ----------------------------------------------------------
if [[ -t 1 ]]; then
  C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'; C_RED=$'\e[31m'; C_YEL=$'\e[33m'
  C_GRN=$'\e[32m'; C_CYA=$'\e[36m'; C_RST=$'\e[0m'
else
  C_BOLD=''; C_DIM=''; C_RED=''; C_YEL=''; C_GRN=''; C_CYA=''; C_RST=''
fi

info()  { printf '%s\n' "${C_CYA}==>${C_RST} $*" >&2; }
warn()  { printf '%s\n' "${C_YEL}warn:${C_RST} $*" >&2; }
err()   { printf '%s\n' "${C_RED}error:${C_RST} $*" >&2; }
ok()    { printf '%s\n' "${C_GRN}ok:${C_RST} $*" >&2; }

# ----- TF binary discovery ---------------------------------------------------
pick_tf() {
  if command -v tofu >/dev/null 2>&1; then
    echo tofu
  elif command -v terraform >/dev/null 2>&1; then
    echo terraform
  else
    err "neither 'tofu' (OpenTofu) nor 'terraform' is on your PATH. Install OpenTofu (preferred) or HashiCorp Terraform."
    exit 1
  fi
}

# ----- Scenario inventory ----------------------------------------------------
# Adding a scenario? Append a row below and ship the matching folder under
# examples/scenarios/<name>/. The pitch line shows up in `demo list`.
scenario_pitch() {
  case "${1:-}" in
    aws-sre-demo)       echo "Can your thing actually fix an AWS incident? (foundation + policies + AWS + Slack + agent-aws-sre)";;
    finops-weekly)      echo "We are drowning in cloud spend. (cost optimizer + resource janitor + weekly Slack summary)";;
    pipeline-insights)  echo "Our CI is a mess; what do you actually see? (read-only GitHub pipeline + release intelligence)";;
    incident-triage)    echo "We get 200 Grafana alerts a day. (Grafana -> cloud-routed RCA -> Slack)";;
    repo-to-iac)        echo "Take a legacy repo and make IaC out of it. (GitHub URL -> StackGen MCP -> generated IaC)";;
    monorepo-services-split) echo "Monolith codebase split guidance + optional extract scaffold. (GitHub clone -> boundary scan -> guidance PR)";;
    clean-tenant-reset) echo "Wipe to a known baseline between demos. (foundation + policies only)";;
    *)                  return 1;;
  esac
}

list_scenarios() {
  printf '%s\n' "${C_BOLD}Available scenarios${C_RST} (run with: make demo SCENARIO=<name>)"
  printf '\n'
  local entry
  for entry in "${SCENARIOS_DIR}"/*/; do
    [[ -d "${entry}" ]] || continue
    local name
    name="$(basename "${entry}")"
    local pitch
    if pitch="$(scenario_pitch "${name}")"; then
      printf '  %s%-22s%s %s\n' "${C_CYA}" "${name}" "${C_RST}" "${pitch}"
    else
      printf '  %s%-22s%s %s(no pitch registered in scripts/demo.sh)%s\n' "${C_CYA}" "${name}" "${C_RST}" "${C_DIM}" "${C_RST}"
    fi
  done
}

# ----- TF_VAR_* auto-mapping -------------------------------------------------
map_env() {
  local from="$1" to="$2"
  if [[ -z "${!to:-}" && -n "${!from:-}" ]]; then
    export "${to}=${!from}"
  fi
}

apply_env_mapping() {
  map_env STACKGEN_URL TF_VAR_stackgen_url
  map_env STACKGEN_TOKEN TF_VAR_stackgen_token
  map_env STACKGEN_PROJECT_ID TF_VAR_stackgen_project_id
  map_env OPENAI_API_KEY TF_VAR_openai_api_key
  map_env ANTHROPIC_API_KEY TF_VAR_anthropic_api_key
  map_env GEMINI_API_KEY TF_VAR_gemini_api_key
  map_env AWS_ROLE_ARN TF_VAR_aws_role_arn
  map_env AWS_REGION TF_VAR_aws_region
  map_env SLACK_BOT_TOKEN TF_VAR_slack_bot_token
  map_env GITHUB_TOKEN TF_VAR_github_token
  map_env GRAFANA_SERVER TF_VAR_grafana_server
  map_env GRAFANA_TOKEN TF_VAR_grafana_token
  map_env GITHUB_REPO_URL TF_VAR_github_repo_url
}

# ----- doctor ----------------------------------------------------------------
check_var() {
  local name="$1" required="$2" label="$3"
  if [[ -n "${!name:-}" ]]; then
    ok "${label} is set"
    return 0
  fi
  if [[ "${required}" == "required" ]]; then
    err "${label} is NOT set (export \$${name}, or pass via tfvars)"
    return 1
  fi
  warn "${label} is not set (optional)"
  return 0
}

doctor() {
  local scenario="${1:-}"
  local fail=0

  info "Checking tooling"
  if command -v tofu >/dev/null 2>&1; then ok "tofu: $(tofu version | head -1)"
  elif command -v terraform >/dev/null 2>&1; then ok "terraform: $(terraform version | head -1)"
  else err "neither tofu nor terraform on PATH"; fail=1
  fi

  info "Checking StackGen credentials"
  check_var STACKGEN_URL required "STACKGEN_URL" || fail=1
  check_var STACKGEN_TOKEN required "STACKGEN_TOKEN" || fail=1

  info "Checking LLM keys (at least one required)"
  if [[ -z "${OPENAI_API_KEY:-}" && -z "${ANTHROPIC_API_KEY:-}" && -z "${GEMINI_API_KEY:-}" ]]; then
    err "no LLM key set; need at least one of OPENAI_API_KEY / ANTHROPIC_API_KEY / GEMINI_API_KEY"
    fail=1
  else
    [[ -n "${OPENAI_API_KEY:-}" ]] && ok "OPENAI_API_KEY is set"
    [[ -n "${ANTHROPIC_API_KEY:-}" ]] && ok "ANTHROPIC_API_KEY is set"
    [[ -n "${GEMINI_API_KEY:-}" ]] && ok "GEMINI_API_KEY is set"
  fi

  case "${scenario}" in
    aws-sre-demo|finops-weekly)
      info "Checking AWS connection"
      check_var AWS_ROLE_ARN required "AWS_ROLE_ARN" || fail=1
      ;;
  esac
  case "${scenario}" in
    finops-weekly)
      info "Checking Slack (required for ${scenario})"
      check_var SLACK_BOT_TOKEN required "SLACK_BOT_TOKEN" || fail=1
      ;;
    aws-sre-demo|pipeline-insights|incident-triage)
      info "Checking Slack (optional for ${scenario})"
      check_var SLACK_BOT_TOKEN optional "SLACK_BOT_TOKEN" || true
      ;;
  esac
  case "${scenario}" in
    pipeline-insights|repo-to-iac|monorepo-services-split)
      info "Checking GitHub"
      check_var GITHUB_TOKEN required "GITHUB_TOKEN" || fail=1
      ;;
  esac
  case "${scenario}" in
    incident-triage)
      info "Checking Grafana"
      check_var GRAFANA_SERVER required "GRAFANA_SERVER" || fail=1
      check_var GRAFANA_TOKEN required "GRAFANA_TOKEN" || fail=1
      ;;
    repo-to-iac|monorepo-services-split)
      info "Checking GitHub repo URL"
      check_var GITHUB_REPO_URL required "GITHUB_REPO_URL" || fail=1
      ;;
  esac

  if [[ "${fail}" -ne 0 ]]; then
    err "doctor: prerequisites missing — set the variables above and re-run."
    exit 1
  fi
  ok "doctor: all checks passed"
}

# ----- apply / reset ---------------------------------------------------------
require_scenario_dir() {
  local scenario="${1:-}"
  if [[ -z "${scenario}" ]]; then
    err "usage: $(basename "$0") ${2:-apply} <scenario>"
    list_scenarios
    exit 2
  fi
  local dir="${SCENARIOS_DIR}/${scenario}"
  if [[ ! -d "${dir}" ]]; then
    err "no such scenario: ${scenario}"
    list_scenarios
    exit 2
  fi
  echo "${dir}"
}

apply() {
  local scenario="$1"
  local dir
  dir="$(require_scenario_dir "${scenario}" apply)"
  apply_env_mapping
  doctor "${scenario}"
  local tf
  tf="$(pick_tf)"
  info "${tf} init in ${dir}"
  (cd "${dir}" && "${tf}" init -input=false -upgrade)
  info "${tf} apply in ${dir}"
  (cd "${dir}" && "${tf}" apply -input=false -auto-approve)
  info "${tf} output in ${dir}"
  (cd "${dir}" && "${tf}" output)
}

reset() {
  local scenario="$1"
  local dir
  dir="$(require_scenario_dir "${scenario}" reset)"
  apply_env_mapping
  local tf
  tf="$(pick_tf)"
  info "${tf} destroy in ${dir}"
  (cd "${dir}" && "${tf}" init -input=false -upgrade)
  (cd "${dir}" && "${tf}" destroy -input=false -auto-approve)
  apply "${scenario}"
}

# ----- entrypoint ------------------------------------------------------------
sub="${1:-}"
case "${sub}" in
  list)
    list_scenarios
    ;;
  doctor)
    apply_env_mapping
    doctor "${2:-}"
    ;;
  apply)
    apply "${2:-}"
    ;;
  reset)
    reset "${2:-}"
    ;;
  ""|-h|--help|help)
    printf '%sscripts/demo.sh — SE demo launcher%s\n\n' "${C_BOLD}" "${C_RST}"
    printf '  list                  Show available scenarios\n'
    printf '  doctor [scenario]     Pre-flight check (tools + env vars; scenario-specific when given)\n'
    printf '  apply <scenario>      tofu init && apply against examples/scenarios/<scenario>\n'
    printf '  reset <scenario>      tofu destroy then re-apply (between back-to-back demos)\n\n'
    printf 'Set credentials as environment variables (see top of this file for the full list):\n'
    printf '  STACKGEN_URL, STACKGEN_TOKEN, OPENAI_API_KEY (or ANTHROPIC / GEMINI),\n'
    printf '  AWS_ROLE_ARN, SLACK_BOT_TOKEN, GITHUB_TOKEN, GRAFANA_SERVER, GRAFANA_TOKEN, ...\n\n'
    printf 'Typical usage from the repo root:\n'
    printf '  make demo-list\n'
    printf '  make demo-doctor SCENARIO=aws-sre-demo\n'
    printf '  make demo        SCENARIO=aws-sre-demo\n'
    printf '  make demo-reset  SCENARIO=aws-sre-demo\n'
    ;;
  *)
    err "unknown subcommand: ${sub}"
    exit 2
    ;;
esac
