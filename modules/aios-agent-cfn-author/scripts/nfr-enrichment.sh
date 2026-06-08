#!/usr/bin/env bash
# nfr-enrichment.sh — derive NFR fields from requirements_spec intent prose (stdin: spec path).
set -euo pipefail

SPEC="${1:-}"
if [[ -z "${SPEC}" || ! -f "${SPEC}" ]]; then
  exit 0
fi

intent="$(jq -r '.intent // ""' "${SPEC}")"
combined="$(jq -r '[.intent, .target_rps, .sla_availability, .p99_latency_ms] | map(select(. != null and . != "")) | join(" ")' "${SPEC}" 2>/dev/null || echo "${intent}")"

target_rps="$(jq -r '.target_rps // empty' "${SPEC}")"
sla_availability="$(jq -r '.sla_availability // empty' "${SPEC}")"
p99_latency_ms="$(jq -r '.p99_latency_ms // empty' "${SPEC}")"
workload_class="$(jq -r '.workload_class // empty' "${SPEC}")"

if [[ -z "${target_rps}" ]]; then
  if echo "${combined}" | grep -qiE '1[,.]?000[,.]?000.*rps|1000000.*rps|1m rps|1 million rps'; then
    target_rps="1000000"
  else
    target_rps="$(echo "${combined}" | grep -oEi '[0-9][0-9,]*[[:space:]]*rps' | head -1 | grep -oE '[0-9][0-9,]*' | tr -d ',' || true)"
  fi
fi

if [[ -z "${sla_availability}" ]]; then
  sla_availability="$(echo "${combined}" | grep -oE '99\.[0-9]+%' | head -1 || true)"
fi

if [[ -z "${p99_latency_ms}" ]]; then
  p99_latency_ms="$(echo "${combined}" | sed -nE 's/.*[Pp]99[^0-9]{0,24}[<=> ]+([0-9]+)[[:space:]]*[Mm][Ss].*/\1/p' | head -1 || true)"
fi

if [[ -z "${workload_class}" && -n "${target_rps}" ]]; then
  threshold="${CFN_AUTHOR_HIGH_RPS_THRESHOLD:-100000}"
  if [[ "${target_rps}" -ge "${threshold}" ]] 2>/dev/null; then
    workload_class="high-throughput-web"
  fi
fi

jq \
  --arg target_rps "${target_rps:-}" \
  --arg sla_availability "${sla_availability:-}" \
  --arg p99_latency_ms "${p99_latency_ms:-}" \
  --arg workload_class "${workload_class:-}" \
  '
  . as $in
  | ($in + {
      target_rps: (if ($target_rps|length) > 0 then ($target_rps|tonumber? // $target_rps) else $in.target_rps end),
      sla_availability: (if ($sla_availability|length) > 0 then $sla_availability else $in.sla_availability end),
      p99_latency_ms: (if ($p99_latency_ms|length) > 0 then ($p99_latency_ms|tonumber? // $p99_latency_ms) else $in.p99_latency_ms end),
      workload_class: (if ($workload_class|length) > 0 then $workload_class else $in.workload_class end)
    })
  | with_entries(select(.value != null and .value != ""))
  ' "${SPEC}"
