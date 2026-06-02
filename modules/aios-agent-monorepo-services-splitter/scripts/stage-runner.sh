#!/usr/bin/env bash
# Monorepo services splitter stage runner — invoke via MONOREPO_SPLIT_EMBEDDED=1 in ONE execute_series.
# Commands: clone-and-scan | write-guidance-artifacts | guidance-pr | scaffold-services | extract-pr
set -euo pipefail

SCRIPT_PACK_VERSION="20260602.14"
RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
TEXT_SANITIZE="${RUNNER_DIR}/text-sanitize.sh"

require_embedded_invocation() {
  if [ "${MONOREPO_SPLIT_EMBEDDED:-}" = "1" ]; then
    return 0
  fi
  if [ "${MONOREPO_SPLIT_ALLOW_DIRECT:-}" = "1" ]; then
    return 0
  fi
  echo "script_pack_error=invoke_via_embed_set_MONOREPO_SPLIT_EMBEDDED=1" >&2
  return 1
}

mirror_note() {
  local work_root="${1:?WORK_ROOT}"
  local key="${2:?KEY}"
  local value="${3:?VALUE}"
  local notes="${work_root}/notes.json"
  mkdir -p "$work_root"
  [ -f "$notes" ] || echo '{}' >"$notes"
  jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$notes" >"${notes}.tmp" \
    && mv "${notes}.tmp" "$notes"
}

resolve_work_root() {
  local work_root="${1:-}"
  if [ -n "$work_root" ] && [ -d "$work_root" ]; then
    printf '%s' "$work_root"
    return 0
  fi
  if [ -n "${WORK_ROOT:-}" ] && [ -d "${WORK_ROOT}" ]; then
    printf '%s' "${WORK_ROOT}"
    return 0
  fi
  echo "work_root_error=unset" >&2
  return 1
}

script_pack_files_present() {
  local scripts_dir="${1:?SCRIPTS_DIR}"
  [ -f "${scripts_dir}/boundary-scan.sh" ] \
    && [ -f "${scripts_dir}/clone-and-pr.sh" ] \
    && [ -f "${scripts_dir}/scaffold-services.sh" ] \
    && [ -f "${scripts_dir}/agents-md-scaffold.sh" ] \
    && [ -f "${scripts_dir}/runtime-deps-provision.sh" ] \
    && [ -f "${scripts_dir}/text-sanitize.sh" ] \
    && [ -f "${scripts_dir}/stage-runner.sh" ]
}

install_script_pack() {
  local work_root="${1:?WORK_ROOT}"
  local scripts_dir="${work_root}/scripts"
  local runner_dir
  runner_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  mkdir -p "${scripts_dir}"

  if [ -f "${scripts_dir}/.script_pack_version" ] \
    && [ "$(cat "${scripts_dir}/.script_pack_version")" = "${SCRIPT_PACK_VERSION}" ] \
    && script_pack_files_present "${scripts_dir}"; then
    return 0
  fi

  # Embedded bootstrap extracts the tarball into WORK_ROOT/scripts and invokes this
  # script from that directory — cp source and dest would be the same inode.
  if script_pack_files_present "${scripts_dir}" \
    && [ "$(cd "${runner_dir}" && pwd -P)" = "$(cd "${scripts_dir}" && pwd -P)" ]; then
    chmod +x "${scripts_dir}/"*.sh 2>/dev/null || true
    printf '%s\n' "$SCRIPT_PACK_VERSION" >"${scripts_dir}/.script_pack_version"
    mirror_note "$work_root" "script_pack_version" "$SCRIPT_PACK_VERSION"
    echo "script_pack_install=reused_work_root_scripts version=${SCRIPT_PACK_VERSION}"
    return 0
  fi

  if [ ! -f "${runner_dir}/boundary-scan.sh" ]; then
    echo "script_pack_error=missing_embedded_scripts set_MONOREPO_SPLIT_EMBEDDED=1" >&2
    return 1
  fi

  copy_script_pack_file() {
    local src="${1:?SRC}"
    local dest="${2:?DEST}"
    if [ "${src}" -ef "${dest}" ]; then
      return 0
    fi
    cp "${src}" "${dest}"
  }

  copy_script_pack_file "${runner_dir}/boundary-scan.sh" "${scripts_dir}/boundary-scan.sh"
  copy_script_pack_file "${runner_dir}/clone-and-pr.sh" "${scripts_dir}/clone-and-pr.sh"
  copy_script_pack_file "${runner_dir}/scaffold-services.sh" "${scripts_dir}/scaffold-services.sh"
  copy_script_pack_file "${runner_dir}/agents-md-scaffold.sh" "${scripts_dir}/agents-md-scaffold.sh"
  copy_script_pack_file "${runner_dir}/runtime-deps-provision.sh" "${scripts_dir}/runtime-deps-provision.sh"
  copy_script_pack_file "${runner_dir}/text-sanitize.sh" "${scripts_dir}/text-sanitize.sh"
  copy_script_pack_file "${runner_dir}/stage-runner.sh" "${scripts_dir}/stage-runner.sh"
  chmod +x "${scripts_dir}/"*.sh 2>/dev/null || true
  printf '%s\n' "$SCRIPT_PACK_VERSION" >"${scripts_dir}/.script_pack_version"
  mirror_note "$work_root" "script_pack_version" "$SCRIPT_PACK_VERSION"
}

ensure_repo_cloned() {
  local work_root="${1:?WORK_ROOT}"
  local notes="${work_root}/notes.json"
  local repo_url default_branch

  if [ -d "$work_root/repo/.git" ]; then
    return 0
  fi

  repo_url="$(jq -r '.github_repo_url // empty' "$notes" 2>/dev/null || true)"
  default_branch="$(jq -r '.default_branch // empty' "$notes" 2>/dev/null || true)"
  [ -n "$default_branch" ] || default_branch="${DEFAULT_BRANCH:-main}"

  if [ -z "$repo_url" ]; then
    echo "scaffold_error=missing_github_repo_url" >&2
    mirror_note "$work_root" "scaffold_validation_error" "missing_github_repo_url"
    exit 1
  fi

  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" clone \
    "$work_root" "$repo_url" "$default_branch"
}

resolve_catalog_path() {
  local work_root="${1:?WORK_ROOT}"
  local notes="${work_root}/notes.json"
  local catalog_path="${work_root}/service-catalog.yaml"
  local plan_path repo_plan

  if [ -f "$work_root/service-catalog.yaml" ]; then
    printf '%s' "$work_root/service-catalog.yaml"
    return 0
  fi

  plan_path="$(jq -r '.plan_artifact_path // empty' "$notes" 2>/dev/null || true)"
  if [ -n "$plan_path" ] && [ -f "$work_root/$plan_path" ]; then
    catalog_path="$work_root/$plan_path"
    cp "$catalog_path" "$work_root/service-catalog.yaml"
    mirror_note "$work_root" "plan_catalog_resolved" "work_root"
    printf '%s' "$catalog_path"
    return 0
  fi

  if [ -n "$plan_path" ] && [ -f "$work_root/repo/$plan_path" ]; then
    repo_plan="$work_root/repo/$plan_path"
    cp "$repo_plan" "$work_root/service-catalog.yaml"
    mirror_note "$work_root" "plan_catalog_resolved" "repo_path"
    printf '%s' "$work_root/service-catalog.yaml"
    return 0
  fi

  if [ -f "$work_root/repo/docs/architecture/service-catalog.yaml" ]; then
    cp "$work_root/repo/docs/architecture/service-catalog.yaml" "$work_root/service-catalog.yaml"
    mirror_note "$work_root" "plan_catalog_resolved" "docs_architecture"
    printf '%s' "$work_root/service-catalog.yaml"
    return 0
  fi

  printf '%s' "$catalog_path"
}

sanitize_text_artifact() {
  local path="${1:?PATH}"
  [ -f "$path" ] || return 0
  [ -f "$TEXT_SANITIZE" ] || return 0
  bash "$TEXT_SANITIZE" file "$path"
}

is_placeholder_service_catalog() {
  local catalog="${1:?CATALOG}"
  [ -f "$catalog" ] || return 1
  grep -qE 'name:[[:space:]]*example-service' "$catalog" 2>/dev/null
}

merge_analyst_artifacts_into_repo() {
  local work_root="${1:?WORK_ROOT}"
  local repo_dir="${2:?REPO_DIR}"
  local arch="$repo_dir/docs/architecture"
  mkdir -p "$arch"

  local src dst name
  for src in \
    "$work_root/service-catalog.yaml" \
    "$work_root/migration-phases.md" \
    "$work_root/bounded-context-map.mermaid" \
    "$work_root/docs/architecture/service-catalog.yaml" \
    "$work_root/docs/architecture/migration-phases.md" \
    "$work_root/docs/architecture/bounded-context-map.mermaid"; do
    [ -f "$src" ] || continue
    name="$(basename "$src")"
    dst="$arch/$name"
    cp "$src" "$dst"
    sanitize_text_artifact "$dst"
    mirror_note "$work_root" "merged_artifact_$(basename "$src" .yaml)" "$dst"
  done
}

cmd_clone_and_scan() {
  local work_root="${1:?WORK_ROOT}"
  local repo_url="${2:?REPO_URL}"
  local default_branch="${3:-main}"
  local workflow_run_id="${4:-unknown}"

  install_script_pack "$work_root"
  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" clone \
    "$work_root" "$repo_url" "$default_branch"

  local repo_dir="$work_root/repo"
  MONOREPO_SPLIT_ALLOW_DIRECT=1 SCRIPT_PACK_VERSION="$SCRIPT_PACK_VERSION" \
    bash "${work_root}/scripts/boundary-scan.sh" scan "$work_root" "$repo_dir"

  if [ -f "${work_root}/scripts/runtime-deps-provision.sh" ]; then
    MONOREPO_SPLIT_ALLOW_DIRECT=1 SCRIPT_PACK_VERSION="$SCRIPT_PACK_VERSION" \
      bash "${work_root}/scripts/runtime-deps-provision.sh" provision "$work_root" "$repo_dir" \
      "${work_root}/boundary_scan.json"
    MONOREPO_SPLIT_ALLOW_DIRECT=1 SCRIPT_PACK_VERSION="$SCRIPT_PACK_VERSION" \
      bash "${work_root}/scripts/runtime-deps-provision.sh" baseline-tests "$work_root" "$repo_dir" \
      "${work_root}/boundary_scan.json"
  fi

  mirror_note "$work_root" "github_repo_url" "$repo_url"
  mirror_note "$work_root" "workflow_run_id" "$workflow_run_id"

  local scan_summary
  scan_summary="$(jq -r '.boundary_scan_summary // empty' "${work_root}/notes.json" 2>/dev/null || true)"
  if [ -n "$scan_summary" ]; then
    echo "boundary_scan_summary=${scan_summary}"
  fi
  echo "stage_summary:clone-and-boundary-scan=ok"
  echo "script_pack_version=${SCRIPT_PACK_VERSION}"
}

cmd_write_guidance_artifacts() {
  local work_root="${1:?WORK_ROOT}"
  local repo_dir="${2:-$work_root/repo}"
  local scan_path="${work_root}/boundary_scan.json"

  mkdir -p "$repo_dir/docs/architecture"
  merge_analyst_artifacts_into_repo "$work_root" "$repo_dir"

  local summary="$repo_dir/docs/architecture/monorepo-split-analysis.md"
  local phases="$repo_dir/docs/architecture/migration-phases.md"
  local catalog="$repo_dir/docs/architecture/service-catalog.yaml"
  local matrix="$repo_dir/docs/architecture/coupling-matrix.json"
  local mermaid="$repo_dir/docs/architecture/bounded-context-map.mermaid"

  if [ -f "$scan_path" ]; then
    cp "$scan_path" "$matrix"
  elif [ ! -f "$matrix" ]; then
    echo '{"modules":[]}' >"$matrix"
  fi

  if [ ! -f "$summary" ]; then
    cat >"$summary" <<'EOF'
# Monorepo split analysis

Guild-generated guidance for decomposing this monorepo into independently deployable services.

See `bounded-context-map.mermaid`, `coupling-matrix.json`, `migration-phases.md`, and `service-catalog.yaml`.
EOF
  fi

  if [ ! -f "$phases" ]; then
    cat >"$phases" <<'EOF'
# Migration phases (strangler fig)

1. **Facade / API gateway** — route traffic to new service boundaries without moving data yet.
2. **Contract-first** — extract OpenAPI/proto; publish consumer contracts before code moves.
3. **Extract implementations** — move packages per bounded context; keep shared DB until outbox/events exist.
4. **Data decomposition** — split schemas with dual-write or outbox; retire shared tables last.
EOF
  fi

  if [ ! -f "$catalog" ]; then
    cat >"$catalog" <<'EOF'
# Proposed microservices — refine with domain analyst output
services:
  - name: example-service
    path: services/example-service
    apis: []
    data_ownership: TBD
    rationale: Placeholder until analyst catalog is merged
EOF
  fi

  if [ ! -f "$mermaid" ]; then
    cat >"$mermaid" <<'EOF'
flowchart LR
  subgraph Monolith
    Core[Core packages]
    Shared[Shared libraries]
  end
  subgraph Targets
    S1[Service A]
    S2[Service B]
  end
  Core --> S1
  Core --> S2
  Shared -.-> S1
  Shared -.-> S2
EOF
  fi

  local agents_md="$repo_dir/AGENTS.md"
  local notes="${work_root}/notes.json"
  if [ -f "$scan_path" ] && [ -f "${work_root}/scripts/agents-md-scaffold.sh" ]; then
    MONOREPO_SPLIT_ALLOW_DIRECT=1 SCRIPT_PACK_VERSION="$SCRIPT_PACK_VERSION" \
      bash "${work_root}/scripts/agents-md-scaffold.sh" scaffold "$repo_dir" "$scan_path" "$agents_md"
    mirror_note "$work_root" "agents_md_source" "boundary_scan_scaffold"
  fi
  if [ -f "$agents_md" ]; then
    sanitize_text_artifact "$agents_md"
    mirror_note "$work_root" "agents_md_path" "$agents_md"
    mirror_note "$work_root" "agents_md_produced" "true"
  fi

  for doc in "$summary" "$phases" "$catalog" "$mermaid"; do
    sanitize_text_artifact "$doc"
  done

  mirror_note "$work_root" "guidance_artifacts_path" "$repo_dir/docs/architecture"
  echo "guidance_artifacts_written=true"
}

cmd_guidance_pr() {
  local work_root="${1:?WORK_ROOT}"
  local workflow_run_id="${2:-split}"
  local default_branch="${3:-main}"

  install_script_pack "$work_root"
  ensure_repo_cloned "$work_root"
  local repo_dir="$work_root/repo"
  local branch="guild/split-analysis-${workflow_run_id}"

  cmd_write_guidance_artifacts "$work_root" "$repo_dir"

  local catalog_path="$repo_dir/docs/architecture/service-catalog.yaml"
  if is_placeholder_service_catalog "$catalog_path"; then
    mirror_note "$work_root" "pr_blocker" "placeholder_service_catalog"
    mirror_note "$work_root" "guidance_pr_blocker" "Run synthesize-split-plan before guidance PR — service-catalog.yaml is still the example placeholder"
    echo "guidance_pr_blocker=placeholder_service_catalog" >&2
    exit 1
  fi

  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" create-branch \
    "$work_root" "$branch"
  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" commit-and-push \
    "$work_root" "docs: monorepo split analysis (${workflow_run_id})"
  local pr_body
  pr_body="$(MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" render-pr-body \
    "$work_root" "guidance")"
  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" open-pr \
    "$work_root" "Monorepo split analysis" "$pr_body" "$default_branch"

  mirror_note "$work_root" "guidance_pr_url" "$(jq -r '.pr_url // empty' "$work_root/notes.json")"
  echo "stage_summary:open-guidance-pr=ok"
}

cmd_scaffold_services() {
  local work_root="${1:?WORK_ROOT}"

  install_script_pack "$work_root"
  ensure_repo_cloned "$work_root"
  merge_analyst_artifacts_into_repo "$work_root" "$work_root/repo"

  local catalog_path
  catalog_path="$(resolve_catalog_path "$work_root")"
  if [ ! -f "$catalog_path" ]; then
    mirror_note "$work_root" "scaffold_layout_validated" "false"
    mirror_note "$work_root" "scaffold_validation_error" "missing_catalog"
    echo "scaffold_error=missing_catalog" >&2
    exit 1
  fi

  MONOREPO_SPLIT_ALLOW_DIRECT=1 SCRIPT_PACK_VERSION="$SCRIPT_PACK_VERSION" \
    bash "${work_root}/scripts/scaffold-services.sh" scaffold \
    "$work_root" "$work_root/repo" "$catalog_path"
  echo "stage_summary:scaffold-service-layout=ok"
}

cmd_extract_pr() {
  local work_root="${1:?WORK_ROOT}"
  local workflow_run_id="${2:-extract}"
  local default_branch="${3:-main}"

  install_script_pack "$work_root"
  ensure_repo_cloned "$work_root"

  local validated
  validated="$(jq -r '.scaffold_layout_validated // empty' "$work_root/notes.json" 2>/dev/null || true)"
  if [ "$validated" != "true" ]; then
    mirror_note "$work_root" "pr_blocker" "scaffold_not_validated"
    echo "extract_pr_blocker=scaffold_not_validated" >&2
    exit 1
  fi

  local branch="guild/split-extract-${workflow_run_id}"

  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" create-branch \
    "$work_root" "$branch"
  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" commit-and-push \
    "$work_root" "feat: scaffold service layout (${workflow_run_id})"
  local pr_body
  pr_body="$(MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" render-pr-body \
    "$work_root" "extract")"
  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" open-pr \
    "$work_root" "Monorepo service extraction scaffold" "$pr_body" "$default_branch"

  mirror_note "$work_root" "extract_pr_url" "$(jq -r '.pr_url // empty' "$work_root/notes.json")"
  echo "stage_summary:open-extract-pr=ok"
}

main() {
  require_embedded_invocation
  local cmd="${1:?command}"
  shift
  case "$cmd" in
    clone-and-scan) cmd_clone_and_scan "$@" ;;
    write-guidance-artifacts) cmd_write_guidance_artifacts "$@" ;;
    guidance-pr) cmd_guidance_pr "$@" ;;
    scaffold-services) cmd_scaffold_services "$@" ;;
    extract-pr) cmd_extract_pr "$@" ;;
    *)
      echo "unknown_command=${cmd}" >&2
      exit 1
      ;;
  esac
}

main "$@"
