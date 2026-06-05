#!/usr/bin/env bash
# Monorepo services splitter stage runner — invoke via MONOREPO_SPLIT_EMBEDDED=1 in ONE execute_series.
# Commands: clone-and-scan | synthesize-plan | agents-md-scaffold | fetch-repo-context |
#   merge-enrichment | write-guidance-artifacts | guidance-pr | scaffold-services | extract-pr
set -euo pipefail

SCRIPT_PACK_VERSION="20260604.7"
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
    && [ -f "${scripts_dir}/monorepo-cce-scan.sh" ] \
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
  if [ -f "${runner_dir}/monorepo-cce-scan.sh" ]; then
    copy_script_pack_file "${runner_dir}/monorepo-cce-scan.sh" "${scripts_dir}/monorepo-cce-scan.sh"
  fi
  if [ -f "${runner_dir}/cce-cloud-scan.sh" ]; then
    copy_script_pack_file "${runner_dir}/cce-cloud-scan.sh" "${scripts_dir}/cce-cloud-scan.sh"
  fi
  copy_script_pack_file "${runner_dir}/text-sanitize.sh" "${scripts_dir}/text-sanitize.sh"
  copy_script_pack_file "${runner_dir}/stage-runner.sh" "${scripts_dir}/stage-runner.sh"
  for extra in build-coupling-matrix.sh detect-repo-archetype.sh synthesize-split-plan.sh \
    fetch-repo-context.sh materialize-analyst-artifacts.sh validate-and-merge-enrichment.sh \
    sync-workflow-notes.sh; do
    if [ -f "${runner_dir}/${extra}" ]; then
      copy_script_pack_file "${runner_dir}/${extra}" "${scripts_dir}/${extra}"
    fi
  done
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

is_mechanical_service_catalog() {
  local catalog="${1:?CATALOG}"
  [ -f "$catalog" ] || return 0
  local total mechanical
  total="$(grep -cE '^- name:' "$catalog" 2>/dev/null || echo 0)"
  mechanical="$(grep -c 'Group centered on' "$catalog" 2>/dev/null || echo 0)"
  if [ "$total" -eq 0 ]; then
    return 0
  fi
  if [ "$mechanical" -ge "$total" ]; then
    return 0
  fi
  return 1
}

prepare_guidance_notes_and_artifacts() {
  local work_root="${1:?WORK_ROOT}"

  if [ -f "${work_root}/scripts/sync-workflow-notes.sh" ]; then
    MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/sync-workflow-notes.sh" sync "$work_root" || true
  fi
  if [ -f "${work_root}/scripts/materialize-analyst-artifacts.sh" ]; then
    MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/materialize-analyst-artifacts.sh" materialize "$work_root" || true
  fi
}

write_workflow_progress() {
  local repo_dir="${1:?REPO_DIR}"
  local stage_name="${2:?STAGE}"
  local workflow_run_id="${3:?WORKFLOW_RUN_ID}"
  local progress="${repo_dir}/docs/architecture/WORKFLOW_PROGRESS.md"
  mkdir -p "$(dirname "$progress")"

  if [ ! -f "$progress" ]; then
    cat >"$progress" <<EOF
# Monorepo split workflow progress

Guild updates **this same pull request** with one commit per completed stage so reviewers can follow progress.

- **Workflow run:** \`${workflow_run_id}\`
- **Branch:** \`guild/split-analysis-${workflow_run_id}\`

| Stage | Status | Commit prefix |
|-------|--------|---------------|
EOF
  fi

  if ! grep -Fq "| ${stage_name} |" "$progress" 2>/dev/null; then
    echo "| ${stage_name} | complete | \`docs(monorepo-split): [stage:${stage_name}]\` |" >>"$progress"
  fi
}

apply_analyst_artifacts_over_deterministic() {
  local work_root="${1:?WORK_ROOT}"
  local arch="${work_root}/docs/architecture"
  mkdir -p "$arch"

  local llm_patch catalog_src
  llm_patch="$(jq -r '.llm_patch_applied // .llm_plan_review_complete // "false"' "${work_root}/notes.json" 2>/dev/null || echo "false")"
  catalog_src="${work_root}/service-catalog.yaml"
  if [ ! -f "$catalog_src" ]; then
    return 0
  fi
  if [ "$llm_patch" != "true" ] && is_mechanical_service_catalog "$catalog_src"; then
    return 0
  fi
  if is_mechanical_service_catalog "$catalog_src"; then
    return 0
  fi

  cp "$catalog_src" "${arch}/service-catalog.yaml"
  sanitize_text_artifact "${arch}/service-catalog.yaml"
  mirror_note "$work_root" "plan_source" "analyst_catalog"
  if [ -f "${work_root}/migration-phases.md" ]; then
    cp "${work_root}/migration-phases.md" "${arch}/migration-phases.md"
    sanitize_text_artifact "${arch}/migration-phases.md"
  fi
  if [ -f "${work_root}/bounded-context-map.mermaid" ]; then
    cp "${work_root}/bounded-context-map.mermaid" "${arch}/bounded-context-map.mermaid"
    sanitize_text_artifact "${arch}/bounded-context-map.mermaid"
  fi
  echo "analyst_catalog_applied_over_deterministic=true"
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
    "$work_root/docs/architecture/bounded-context-map.mermaid" \
    "$work_root/docs/architecture/coupling-matrix.json" \
    "$work_root/docs/architecture/testing-strategy.md" \
    "$work_root/docs/architecture/README.md" \
    "$work_root/docs/architecture/for-developers.md" \
    "$work_root/docs/architecture/for-tech-leads.md" \
    "$work_root/docs/architecture/for-architects.md" \
    "$work_root/docs/architecture/glossary.md" \
    "$work_root/coupling-matrix.json"; do
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

  local scan_summary cce_summary_note
  scan_summary="$(jq -r '.boundary_scan_summary // empty' "${work_root}/notes.json" 2>/dev/null || true)"
  cce_summary_note="$(jq -r '.cce_summary // empty' "${work_root}/notes.json" 2>/dev/null || true)"
  if [ -n "$scan_summary" ]; then
    echo "boundary_scan_summary=${scan_summary}"
  fi
  if [ -n "$cce_summary_note" ]; then
    echo "cce_summary=${cce_summary_note}"
  fi
  echo "stage_summary:clone-and-boundary-scan=ok"
  echo "script_pack_version=${SCRIPT_PACK_VERSION}"
}

cmd_synthesize_plan() {
  local work_root="${1:?WORK_ROOT}"
  install_script_pack "$work_root"
  export MAX_RECOMMENDED_SERVICES="${MAX_RECOMMENDED_SERVICES:-12}"
  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/synthesize-split-plan.sh" synthesize "$work_root"
  echo "synthesize_plan_ok=true"
}

cmd_agents_md_scaffold() {
  local work_root="${1:?WORK_ROOT}"
  install_script_pack "$work_root"
  ensure_repo_cloned "$work_root"
  local repo_dir="$work_root/repo"
  local scan_path="${work_root}/boundary_scan.json"
  local agents_md="$repo_dir/AGENTS.md"
  if [ ! -f "$scan_path" ]; then
    echo "agents_md_scaffold_ok=false"
    echo "agents_md_scaffold_error=missing_boundary_scan"
    exit 1
  fi
  MONOREPO_SPLIT_ALLOW_DIRECT=1 SCRIPT_PACK_VERSION="$SCRIPT_PACK_VERSION" \
    bash "${work_root}/scripts/agents-md-scaffold.sh" scaffold "$repo_dir" "$scan_path" "$agents_md"
  if [ -f "${work_root}/agents-md-analyst-sections.md" ]; then
    {
      echo ""
      echo "## Analyst context (Guild)"
      cat "${work_root}/agents-md-analyst-sections.md"
    } >>"$agents_md"
  fi
  sanitize_text_artifact "$agents_md"
  mirror_note "$work_root" "agents_md_path" "$agents_md"
  mirror_note "$work_root" "agents_md_produced" "true"
  echo "agents_md_scaffold_ok=true"
  echo "stage_summary:agents-md-scaffold=ok"
}

cmd_fetch_repo_context() {
  local work_root="${1:?WORK_ROOT}"
  install_script_pack "$work_root"
  ensure_repo_cloned "$work_root"
  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/fetch-repo-context.sh" fetch \
    "$work_root" "$work_root/repo"
}

cmd_merge_enrichment() {
  local work_root="${1:?WORK_ROOT}"
  install_script_pack "$work_root"
  prepare_guidance_notes_and_artifacts "$work_root"
  apply_analyst_artifacts_over_deterministic "$work_root"
  if [ -f "${work_root}/scripts/validate-and-merge-enrichment.sh" ]; then
    MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/validate-and-merge-enrichment.sh" merge "$work_root"
  fi
  echo "stage_summary:merge-enrichment=ok"
}

cmd_write_guidance_artifacts() {
  local work_root="${1:?WORK_ROOT}"
  local repo_dir="${2:-$work_root/repo}"
  local scan_path="${work_root}/boundary_scan.json"
  local notes="${work_root}/notes.json"
  local deterministic
  deterministic="$(jq -r '.deterministic_plan_produced // "false"' "$notes" 2>/dev/null || echo "false")"

  mkdir -p "$repo_dir/docs/architecture"
  prepare_guidance_notes_and_artifacts "$work_root"
  apply_analyst_artifacts_over_deterministic "$work_root"
  if [ -f "${work_root}/scripts/validate-and-merge-enrichment.sh" ]; then
    MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/validate-and-merge-enrichment.sh" merge "$work_root" || true
  fi
  merge_analyst_artifacts_into_repo "$work_root" "$repo_dir"

  local summary="$repo_dir/docs/architecture/monorepo-split-analysis.md"
  local phases="$repo_dir/docs/architecture/migration-phases.md"
  local catalog="$repo_dir/docs/architecture/service-catalog.yaml"
  local matrix="$repo_dir/docs/architecture/coupling-matrix.json"
  local mermaid="$repo_dir/docs/architecture/bounded-context-map.mermaid"

  if [ -f "${work_root}/coupling-matrix.json" ]; then
    cp "${work_root}/coupling-matrix.json" "$matrix"
  elif [ -f "${work_root}/docs/architecture/coupling-matrix.json" ]; then
    cp "${work_root}/docs/architecture/coupling-matrix.json" "$matrix"
  elif [ ! -f "$matrix" ]; then
    echo '{"modules":[]}' >"$matrix"
  fi

  if [ -f "${work_root}/.work/cce/monorepo-cce-result.json" ]; then
    cp "${work_root}/.work/cce/monorepo-cce-result.json" "$repo_dir/docs/architecture/cce-monorepo-scan.json"
  fi
  if [ -f "${work_root}/.work/cce/merged-recipes.json" ]; then
    cp "${work_root}/.work/cce/merged-recipes.json" "$repo_dir/docs/architecture/cce-merged-recipes.json"
  fi
  if [ -f "${work_root}/.work/cce/targeted-summary.json" ]; then
    cp "${work_root}/.work/cce/targeted-summary.json" "$repo_dir/docs/architecture/cce-targeted-scan.json"
  fi

  if [ "$deterministic" != "true" ]; then
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
      mirror_note "$work_root" "guidance_artifacts_blocker" "missing_service_catalog_run_synthesize_plan"
      echo "guidance_artifacts_blocker=missing_service_catalog" >&2
      exit 1
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
  fi

  local agents_md="$repo_dir/AGENTS.md"
  if [ ! -f "$agents_md" ] && [ -f "$scan_path" ] && [ -f "${work_root}/scripts/agents-md-scaffold.sh" ]; then
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

cmd_incremental_guidance_commit() {
  local work_root="${1:?WORK_ROOT}"
  local workflow_run_id="${2:?WORKFLOW_RUN_ID}"
  local default_branch="${3:-main}"
  local stage_name="${4:?STAGE_NAME}"

  install_script_pack "$work_root"
  ensure_repo_cloned "$work_root"
  local repo_dir="$work_root/repo"
  local branch="guild/split-analysis-${workflow_run_id}"

  if [ "$stage_name" = "parallel-plan-prep" ]; then
    cmd_write_guidance_artifacts "$work_root" "$repo_dir"
  fi
  if [ "$stage_name" = "llm-plan-review" ]; then
    prepare_guidance_notes_and_artifacts "$work_root"
    apply_analyst_artifacts_over_deterministic "$work_root"
    cmd_write_guidance_artifacts "$work_root" "$repo_dir"
    merge_analyst_artifacts_into_repo "$work_root" "$repo_dir"
  fi
  if [ "$stage_name" = "llm-os-enrichment" ]; then
    prepare_guidance_notes_and_artifacts "$work_root"
    apply_analyst_artifacts_over_deterministic "$work_root"
    cmd_merge_enrichment "$work_root" || true
    merge_analyst_artifacts_into_repo "$work_root" "$repo_dir"
  fi

  write_workflow_progress "$repo_dir" "$stage_name" "$workflow_run_id"

  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" ensure-branch \
    "$work_root" "$branch"
  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" commit-and-push \
    "$work_root" "docs(monorepo-split): [stage:${stage_name}] workflow ${workflow_run_id}"

  local pr_url
  pr_url="$(jq -r '.guidance_pr_url // .pr_url // empty' "$work_root/notes.json" 2>/dev/null || true)"
  if [ "$stage_name" = "parallel-plan-prep" ] && [ -z "$pr_url" ]; then
    local pr_body
    pr_body="$(MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" render-pr-body \
      "$work_root" "guidance")"
    MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" open-pr \
      "$work_root" "WIP: Monorepo split analysis (${workflow_run_id})" "$pr_body" "$default_branch" "draft"
    pr_url="$(jq -r '.guidance_pr_url // .pr_url // empty' "$work_root/notes.json" 2>/dev/null || true)"
  fi

  mirror_note "$work_root" "guidance_pr_url" "$pr_url"
  mirror_note "$work_root" "guidance_pr_last_commit_stage" "$stage_name"
  mirror_note "$work_root" "incremental_guidance_commit_ok" "true"
  echo "incremental_guidance_commit_stage=${stage_name}"
  echo "guidance_pr_url=${pr_url}"
  echo "stage_summary:incremental-guidance-commit-${stage_name}=ok"
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
  local plan_ok llm_patch
  plan_ok="$(jq -r '.plan_ok // .deterministic_plan_produced // "false"' "$work_root/notes.json" 2>/dev/null || echo "false")"
  llm_patch="$(jq -r '.llm_patch_applied // .llm_plan_review_complete // "false"' "$work_root/notes.json" 2>/dev/null || echo "false")"
  if [ "$llm_patch" = "true" ] || [ -f "${work_root}/service-catalog.yaml" ]; then
    prepare_guidance_notes_and_artifacts "$work_root"
    apply_analyst_artifacts_over_deterministic "$work_root"
    merge_analyst_artifacts_into_repo "$work_root" "$repo_dir"
    if [ -f "$work_root/service-catalog.yaml" ]; then
      cp "$work_root/service-catalog.yaml" "$catalog_path"
      plan_ok="true"
      mirror_note "$work_root" "plan_ok" "true"
      mirror_note "$work_root" "plan_source" "llm_plan_review"
    fi
  fi
  if [ "$plan_ok" != "true" ] && [ ! -f "$catalog_path" ]; then
    mirror_note "$work_root" "pr_blocker" "plan_not_ready"
    mirror_note "$work_root" "guidance_pr_blocker" "Run parallel-plan-prep (synthesize-split-plan) before guidance PR"
    echo "guidance_pr_blocker=plan_not_ready" >&2
    exit 1
  fi
  if is_placeholder_service_catalog "$catalog_path"; then
    mirror_note "$work_root" "pr_blocker" "placeholder_service_catalog"
    mirror_note "$work_root" "guidance_pr_blocker" "Run synthesize-split-plan before guidance PR — service-catalog.yaml is still the example placeholder"
    echo "guidance_pr_blocker=placeholder_service_catalog" >&2
    exit 1
  fi

  write_workflow_progress "$repo_dir" "final" "$workflow_run_id"

  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" ensure-branch \
    "$work_root" "$branch"
  MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" commit-and-push \
    "$work_root" "docs(monorepo-split): [stage:final] monorepo split analysis (${workflow_run_id})"
  local pr_body
  pr_body="$(MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" render-pr-body \
    "$work_root" "guidance")"
  local pr_url
  pr_url="$(jq -r '.guidance_pr_url // .pr_url // empty' "$work_root/notes.json" 2>/dev/null || true)"
  if [ -z "$pr_url" ]; then
    MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" open-pr \
      "$work_root" "Monorepo split analysis (${workflow_run_id})" "$pr_body" "$default_branch"
    pr_url="$(jq -r '.pr_url // empty' "$work_root/notes.json" 2>/dev/null || true)"
  fi
  if [ -n "$pr_url" ]; then
    MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" update-pr-body \
      "$work_root" "$pr_body" || true
    MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/clone-and-pr.sh" update-pr-title \
      "$work_root" "Monorepo split analysis (${workflow_run_id})" || true
  fi

  mirror_note "$work_root" "guidance_pr_url" "$pr_url"
  mirror_note "$work_root" "guidance_pr_last_commit_stage" "final"
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

cmd_targeted_cce_scan() {
  local work_root="${1:?WORK_ROOT}"
  local notes="${work_root}/notes.json"
  local spec custom_lens

  install_script_pack "$work_root"
  ensure_repo_cloned "$work_root"

  spec="$(jq -c '.cce_rescan_spec // empty' "$notes" 2>/dev/null || true)"
  if [ -z "$spec" ] || [ "$spec" = "null" ]; then
    echo "targeted_cce_skipped=true reason=missing_cce_rescan_spec"
    mirror_note "$work_root" "targeted_cce_status" "skipped"
    return 0
  fi

  custom_lens="$(jq -r '.cce_custom_lens_yaml // empty' "$notes" 2>/dev/null || true)"
  if [ -n "$custom_lens" ]; then
    export CCE_CUSTOM_LENS_YAML="$custom_lens"
  fi

  local repo_dir="$work_root/repo"
  local result
  result="$(MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "${work_root}/scripts/monorepo-cce-scan.sh" targeted \
    "$repo_dir" "$work_root" "$spec" 2>"${work_root}/.work/targeted-cce.err" || true)"

  if ! echo "$result" | jq -e '.scan_status == "ok"' >/dev/null 2>&1; then
    mirror_note "$work_root" "targeted_cce_status" "failed"
    echo "targeted_cce_error=scan_failed" >&2
    exit 1
  fi

  local existing_cce_summary targeted_summary cce_summary
  existing_cce_summary="$(jq -c '.cce_summary // {}' "$notes" 2>/dev/null || echo '{}')"
  targeted_summary="$(cat "${work_root}/.work/cce/targeted-summary.json" 2>/dev/null || echo '{}')"
  cce_summary="$(jq -n \
    --argjson base "$existing_cce_summary" \
    --argjson targeted "$targeted_summary" \
    '$base + { targeted_cce: $targeted, targeted_cce_status: "ok" }')"

  mirror_note "$work_root" "cce_summary" "$cce_summary"
  mirror_note "$work_root" "targeted_cce_status" "ok"
  echo "stage_summary:targeted-cce-rescan=ok"
  echo "targeted_cce_summary=${cce_summary}"
}

main() {
  require_embedded_invocation
  local cmd="${1:?command}"
  shift
  case "$cmd" in
    clone-and-scan) cmd_clone_and_scan "$@" ;;
    synthesize-plan) cmd_synthesize_plan "$@" ;;
    agents-md-scaffold) cmd_agents_md_scaffold "$@" ;;
    fetch-repo-context) cmd_fetch_repo_context "$@" ;;
    merge-enrichment) cmd_merge_enrichment "$@" ;;
    write-guidance-artifacts) cmd_write_guidance_artifacts "$@" ;;
    incremental-guidance-commit) cmd_incremental_guidance_commit "$@" ;;
    guidance-pr) cmd_guidance_pr "$@" ;;
    scaffold-services) cmd_scaffold_services "$@" ;;
    extract-pr) cmd_extract_pr "$@" ;;
    targeted-cce-scan) cmd_targeted_cce_scan "$@" ;;
    *)
      echo "unknown_command=${cmd}" >&2
      exit 1
      ;;
  esac
}

main "$@"
