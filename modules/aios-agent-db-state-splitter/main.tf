terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # sg_remote_runner create + install commands (>= 0.1.23); spawn_contracts (>= 0.1.21).
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "db-state-splitter"

  # Normalize name_suffix: empty → "" (no suffix), non-empty → "-<suffix>"
  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name = "db-state-split-architect${local.suffix}"

  workflow_primary_name   = "db-monorepo-state-split-convergence${local.suffix}"
  workflow_secondary_name = "orphan-iac-module-authoring${local.suffix}"
  webhook_name            = "github-db-state-split-receiver${local.suffix}"

  sop_orchestration_name     = "db-state-split-orchestration-sop${local.suffix}"
  sop_shard_extraction_name  = "terraform-state-shard-extraction-sop${local.suffix}"
  sop_registry_reverse_name  = "terraform-registry-reverse-iac-sop${local.suffix}"
  sop_substate_converge_name = "terraform-substate-convergence-sop${local.suffix}"
  sop_orphan_bootstrap_name  = "orphan-iac-module-bootstrap-sop${local.suffix}"
  sop_appstack_playbook_name = "stackgen-appstack-mcp-playbook-sop${local.suffix}"
  sop_cce_iac_alignment      = "cce-iac-alignment${local.suffix}"
  policy_auto_approve_name   = "db-state-split-stackgen-mcp-auto-approve${local.suffix}"
  evidence_primary_name      = "db-monorepo-state-split-evidence${local.suffix}"
  evidence_orphan_name       = "orphan-iac-module-authoring-evidence${local.suffix}"

  # Module-identity-prefixed integration names. These ARE the MCP tool
  # prefixes the LLM sees at runtime; every literal `${local.shell_tool_prefix}_*` reference
  # in the SOPs / persona is templated below.
  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  aws_integration_name    = "${local.module_prefix}-aws${local.suffix}"

  default_remote_runner_name  = "${local.module_prefix}-runner${local.suffix}"
  resolved_remote_runner_name = trimspace(var.remote_runner_name) != "" ? trimspace(var.remote_runner_name) : local.default_remote_runner_name
  # Guild exposes runner shell tools as `<runner_name>_execute_command|series|parallel|create_files`.
  shell_tool_prefix = local.resolved_remote_runner_name
  runner_work_home  = trimspace(var.runner_work_home) != "" ? trimspace(var.runner_work_home) : "/home/runner"

  # `provision_*` must be plan-time known because it drives `count` on the
  # nested integration modules. We deliberately do NOT inspect
  # `var.*_secret_id` here — the consumer often wires those from another
  # module's output (`module.github_pat[0].secret_id`,
  # `module.aws_integration[0].secret_id`) which is only known at apply time.
  # When `existing_*_integration_name` is empty we always try to provision; the
  # inner integration module's preconditions surface a clear error if the
  # secret input is also missing.
  provision_github = trimspace(var.existing_github_integration_name) == ""
  provision_aws    = trimspace(var.existing_aws_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )

  # Runner mothership sync: vault metadata must be flat env keys (GIT_TOKEN, AWS_ACCESS_KEY_ID, …).
  create_runner_git_env_secret = var.create_remote_runner && trimspace(var.runner_git_token) != ""
  create_runner_aws_env_secret = var.create_remote_runner && (
    trimspace(var.runner_aws_access_key_id) != "" && trimspace(var.runner_aws_secret_access_key) != ""
  )
  create_runner_script_pack_env_secret = var.create_remote_runner

  runner_git_env_secret_id         = local.create_runner_git_env_secret ? sg_secret.runner_git_env[0].id : trimspace(var.runner_git_env_secret_id)
  runner_aws_env_secret_id         = local.create_runner_aws_env_secret ? sg_secret.runner_aws_env[0].id : trimspace(var.runner_aws_env_secret_id)
  runner_script_pack_env_secret_id = local.create_runner_script_pack_env_secret ? sg_secret.runner_script_pack_env[0].id : trimspace(var.runner_script_pack_env_secret_id)

  runner_typed_secret_refs_base = merge(
    trimspace(local.runner_git_env_secret_id) != "" ? { github = local.runner_git_env_secret_id } : {},
    trimspace(local.runner_aws_env_secret_id) != "" ? { aws = local.runner_aws_env_secret_id } : {},
    var.remote_runner_typed_secret_refs,
  )
  runner_typed_secret_refs = var.remote_runner_secret_sync_enabled ? local.runner_typed_secret_refs_base : {}
  runner_generic_secret_ref_ids = var.remote_runner_secret_sync_enabled ? compact(concat(
    var.remote_runner_generic_secret_ref_ids,
    trimspace(local.runner_script_pack_env_secret_id) != "" ? [local.runner_script_pack_env_secret_id] : [],
  )) : []
  runner_secrets_sync_configured = var.remote_runner_secret_sync_enabled && (
    trimspace(var.runner_git_token) != ""
    || trimspace(var.runner_git_env_secret_id) != ""
    || trimspace(var.runner_aws_access_key_id) != "" && trimspace(var.runner_aws_secret_access_key) != ""
    || trimspace(var.runner_aws_env_secret_id) != ""
    || trimspace(local.runner_script_pack_env_secret_id) != ""
    || length(var.remote_runner_typed_secret_refs) > 0
    || length(var.remote_runner_generic_secret_ref_ids) > 0
  )

  # Guild tool names are <integration_name>_<mcp_tool>; pattern suffix * bypasses HITL for all MCP tools on that integration.
  # `stackgen_mcp_integration_name` is required (variables.tf validates non-empty) so this list is always populated.
  stackgen_mcp_hitl_patterns = ["${trimspace(var.stackgen_mcp_integration_name)}_*"]

  stage_runner_script         = trimspace(file("${path.module}/scripts/stage-runner.sh"))
  allocate_manifest_script    = file("${path.module}/scripts/allocate_manifest.py")
  script_pack_version         = "20260604.7"
  script_pack_git_ref         = "main"
  script_pack_allocate_sha256 = sha256(local.allocate_manifest_script)
  script_pack_runner_sha256   = sha256(local.stage_runner_script)
  script_pack_allocate_b64    = base64encode(local.allocate_manifest_script)
  script_pack_runner_b64      = base64encode(local.stage_runner_script)

  # Exclude efficiency/mini models from the agent so create_agent sub-agents do not route to gpt-*-mini / flash for paste-heavy work.
  filtered_non_trivial_model_names = [
    for name in compact(var.model_names) : name if !can(regex("(?i)(mini|flash|nano|haiku|efficiency)", name))
  ]
  non_trivial_model_names = length(compact(var.non_trivial_model_names)) > 0 ? compact(var.non_trivial_model_names) : (
    length(local.filtered_non_trivial_model_names) > 0 ? local.filtered_non_trivial_model_names : compact(var.model_names)
  )

  ingest_bootstrap_script = trimspace(local.ingest_execute_series_body)
  ingest_bootstrap_b64    = base64encode(local.ingest_bootstrap_script)
  ingest_bootstrap_sha256 = sha256(local.ingest_bootstrap_script)
  # Single execute_command copied from spawn context — reads bootstrap from runner script-pack secret (generic vault `value` JSON).
  # Must be POSIX sh (aiden-runner uses `sh -c`); bash <<< here-strings fail with "redirection unexpected".
  ingest_bootstrap_execute_command = "printf '%s' \"$${value}\" | jq -r .DBSPLIT_INGEST_BOOTSTRAP_B64 | base64 -d | DBSPLIT_EMBEDDED=1 bash"

  runner_script_pack_env_json = jsonencode({
    DBSPLIT_SCRIPT_PACK_VERSION         = local.script_pack_version
    DBSPLIT_SCRIPT_PACK_ALLOCATE_B64    = local.script_pack_allocate_b64
    DBSPLIT_SCRIPT_PACK_RUNNER_B64      = local.script_pack_runner_b64
    DBSPLIT_SCRIPT_PACK_ALLOCATE_SHA256 = local.script_pack_allocate_sha256
    DBSPLIT_SCRIPT_PACK_RUNNER_SHA256   = local.script_pack_runner_sha256
    DBSPLIT_INGEST_BOOTSTRAP_B64        = local.ingest_bootstrap_b64
    DBSPLIT_INGEST_BOOTSTRAP_SHA256     = local.ingest_bootstrap_sha256
  })

  subagent_budget_defaults = {
    script_runner_max_llm_calls                = 40
    script_runner_max_tool_iterations          = 48
    script_runner_timeout_seconds              = 3600
    registry_codegen_max_llm_calls             = 60
    registry_codegen_max_tool_iterations       = 48
    registry_codegen_timeout_seconds           = 900
    hcl_hydrate_batch_max_llm_calls            = 60
    hcl_hydrate_batch_max_tool_iterations      = 48
    hcl_hydrate_batch_timeout_seconds          = 600
    appstack_batch_max_llm_calls               = 55
    appstack_batch_max_tool_iterations         = 48
    appstack_batch_timeout_seconds             = 720
    plan_convergence_batch_max_llm_calls       = 60
    plan_convergence_batch_max_tool_iterations = 48
    plan_convergence_batch_timeout_seconds     = 900
    mcp_shell_runner_max_llm_calls             = 35
    mcp_shell_runner_max_tool_iterations       = 45
    mcp_shell_runner_timeout_seconds           = 600
  }
  subagent_budgets = {
    for key, default in local.subagent_budget_defaults :
    key => coalesce(try(var.subagent_budgets[key], null), default)
  }

  dbsplit_script_pack_env_helpers = templatefile(
    "${path.module}/templates/dbsplit-script-pack-env.sh.tftpl",
    {
      script_pack_version         = local.script_pack_version
      script_pack_allocate_sha256 = local.script_pack_allocate_sha256
      script_pack_runner_sha256   = local.script_pack_runner_sha256
    },
  )

  template_vars = {
    module_prefix                       = local.module_prefix
    suffix                              = local.suffix
    shell_tool_prefix                   = local.shell_tool_prefix
    remote_runner_name                  = local.resolved_remote_runner_name
    github_tool_prefix                  = local.resolved_github_integration_name
    aws_tool_prefix                     = local.resolved_aws_integration_name
    stackgen_mcp_tool_prefix            = trimspace(var.stackgen_mcp_integration_name)
    max_iterations                      = var.max_convergence_iterations
    remote_runner_block                 = local.remote_runner_block
    stage_runner_script                 = local.stage_runner_script
    allocate_manifest_script            = local.allocate_manifest_script
    script_pack_version                 = local.script_pack_version
    script_pack_git_ref                 = local.script_pack_git_ref
    script_pack_allocate_sha256         = local.script_pack_allocate_sha256
    script_pack_runner_sha256           = local.script_pack_runner_sha256
    script_pack_allocate_b64            = local.script_pack_allocate_b64
    script_pack_runner_b64              = local.script_pack_runner_b64
    runner_work_home                    = local.runner_work_home
    stackgen_project_name_default       = trimspace(var.stackgen_project_name)
    default_grouping_strategy           = var.default_grouping_strategy
    default_max_resources_per_appstack  = var.default_max_resources_per_appstack
    default_iac_repository_url          = trimspace(var.default_iac_repository_url)
    default_branch                      = trimspace(var.default_branch)
    subagent_budgets                    = local.subagent_budgets
    subagent_task_type                  = var.subagent_task_type
    bulk_add_resources_max_per_call     = 100
    bulk_connect_resources_max_per_call = 100
    bulk_resources_chunk_size           = 80
    bulk_connections_chunk_size         = 50
    dbsplit_script_pack_env_helpers     = local.dbsplit_script_pack_env_helpers
  }

  stage_execute_series_paste_max_len = 16384

  # Bootstrap script body (~3k) — stored in runner_script_pack_env secret as DBSPLIT_INGEST_BOOTSTRAP_B64; runner decodes via INGEST_BOOTSTRAP_EXECUTE_COMMAND (one execute_command, no LLM paste).
  ingest_execute_series_body = templatefile(
    "${path.module}/templates/ingest-execute-series-embedded.sh.tftpl",
    local.template_vars,
  )

  iac_pr_execute_series_body = templatefile(
    "${path.module}/templates/iac-pr-execute-series-embedded.sh.tftpl",
    local.template_vars,
  )

  converge_execute_series_body = templatefile(
    "${path.module}/templates/converge-execute-series-embedded.sh.tftpl",
    local.template_vars,
  )

  rendered_persona = templatefile("${path.module}/personas/db-state-split-architect.md.tftpl", local.template_vars)

  rendered_templates = {
    for filename in fileset("${path.module}/templates", "*.md.tftpl") :
    replace(filename, ".tftpl", "") => templatefile("${path.module}/templates/${filename}", local.template_vars)
  }

  remote_runner_block = trimspace(<<-RUNNER
    **Primary execution:** all shell, `tofu`/`terraform`, `jq`, `git`, and **monolith state download** run on remote runner **`${local.resolved_remote_runner_name}`** via **`${local.shell_tool_prefix}_execute_*`** tools (never Ubuntu CLI). When `monolith_state_uri` is an HTTP/S3/GCS/Drive link, the mothership dispatches download to the runner; `stage-runner.sh download-state` materializes `$WORK_ROOT/state/terraform.tfstate` locally on the runner.%{if var.create_remote_runner~}
    Runner registered by Terraform via `sg_remote_runner`; install commands are in module outputs `remote_runner_cli_start_command` / `remote_runner_helm_install_command` — deploy aiden-runner on-prem with **outbound-only** access to mothership before running workflows.%{endif~}
    Per the **Execution Optimization Protocol** (db-state-split-orchestration-sop), multi-step work is batched into one `${local.shell_tool_prefix}_execute_series`; `${local.shell_tool_prefix}_execute_command` is for a single cohesive command; `${local.shell_tool_prefix}_execute_parallel` (or `flow_type:"parallel"` subagent batches) is the only sanctioned fan-out for independent per-group / per-shard work.
    **Runner prerequisites:** the runner image must include **`tofu`/`terraform`**, **`jq`**, **`git`**, **`awscli`** (when state is on S3). When `runner_git_token` / `runner_aws_*` or `runner_*_env_secret_id` / `remote_runner_typed_secret_refs` are set, Terraform binds **`sg_remote_runner_secrets`** so mothership sync injects **`GIT_TOKEN`** / **`AWS_*`** env on the runner (memory-only) for **`git clone`**, **`gh pr create`**, and S3 state download. Terraform also provisions **`DBSPLIT_SCRIPT_PACK_*`** on the runner (generic vault sync) — required for ingest; restart aiden-runner after `tofu apply` when `script_pack_version` changes. Otherwise mount the same keys locally (K8s Secret, `-e`). This module does not install CLIs on the runner host.
    Persist artifact paths (plan JSON, state snapshots) via `note` keys `remote_runner_artifacts`. If `${local.shell_tool_prefix}_execute_*` is unavailable (runner offline), emit **`blocked:remote_runner_shell_unavailable: "true"`** and stop — do not fall back to inline shell on the architect.
    RUNNER
  )
}

# =============================================================================
# Owned integrations — GitHub (gh api) and AWS (aws_cli_* MCP). Shell / tofu /
# state download run on the attached remote runner, not Ubuntu CLI.
# =============================================================================

resource "terraform_data" "github_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_github_integration_name) != ""
      error_message = "aios-agent-db-state-splitter needs a GitHub Guild integration: provide `github_secret_id` (module provisions one) or `existing_github_integration_name`."
    }
  }
}

resource "terraform_data" "aws_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_aws_integration_name) != ""
      error_message = "aios-agent-db-state-splitter needs an AWS Guild integration: provide `aws_secret_id` (module provisions one) or `existing_aws_integration_name`."
    }
  }
}

resource "terraform_data" "runner_git_secret_input" {
  lifecycle {
    precondition {
      condition     = !(local.create_runner_git_env_secret && trimspace(var.runner_git_env_secret_id) != "")
      error_message = "Set either runner_git_token (module creates vault secret) or runner_git_env_secret_id, not both."
    }
    precondition {
      condition     = !(local.create_runner_aws_env_secret && trimspace(var.runner_aws_env_secret_id) != "")
      error_message = "Set either runner_aws_access_key_id + runner_aws_secret_access_key or runner_aws_env_secret_id, not both."
    }
  }
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by the ${local.agent_name} agent (issue/PR triage, gh api). Bound to a shared tenant-level PAT secret."
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
  description        = "AWS Guild integration owned by the ${local.agent_name} agent (read-only state inspection via aws_cli_* tools)."
}

# =============================================================================
# Policy — auto-approve StackGen Consumer MCP tools (stackgen-mcp_*)
# =============================================================================

resource "sg_policy" "db_state_split_stackgen_mcp_auto_approve" {
  name        = local.policy_auto_approve_name
  description = "Companion intervention policy for db-state-split-architect; Consumer MCP tools are auto-approved via sg_agent.auto_approve_tools (<integration>_* rules) and this intervention policy."
  type        = "intervention"
  rego_source = file("${path.module}/policies/stackgen-mcp-auto-approve.rego")
}

# =============================================================================
# Remote runner env secrets (flat metadata for mothership sync → aiden-runner)
# =============================================================================

resource "sg_secret" "runner_git_env" {
  count = local.create_runner_git_env_secret ? 1 : 0

  name        = "${local.module_prefix}-runner-git-env${local.suffix}"
  description = "Git HTTPS credentials for ${local.resolved_remote_runner_name} (GIT_TOKEN/GIT_HOST for clone + gh pr)."
  category    = "Provider"
  subcategory = "github"
  metadata = {
    token        = var.runner_git_token
    GIT_TOKEN    = var.runner_git_token
    GIT_HOST     = trimspace(var.runner_git_host) != "" ? trimspace(var.runner_git_host) : "github.com"
    GIT_USERNAME = trimspace(var.runner_git_username) != "" ? trimspace(var.runner_git_username) : "x-access-token"
    GH_TOKEN     = var.runner_git_token
    GITHUB_TOKEN = var.runner_git_token
  }
}

resource "sg_secret" "runner_aws_env" {
  count = local.create_runner_aws_env_secret ? 1 : 0

  name        = "${local.module_prefix}-runner-aws-env${local.suffix}"
  description = "AWS credentials for ${local.resolved_remote_runner_name} (S3 state download + tofu AWS provider)."
  category    = "CloudProvider"
  subcategory = "aws"
  metadata = {
    AWS_ACCESS_KEY_ID     = var.runner_aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.runner_aws_secret_access_key
    AWS_REGION            = trimspace(var.runner_aws_region)
    AWS_DEFAULT_REGION    = trimspace(var.runner_aws_region)
  }
}

resource "sg_secret" "runner_script_pack_env" {
  count = local.create_runner_script_pack_env_secret ? 1 : 0

  name        = "${local.module_prefix}-runner-script-pack-env${local.suffix}"
  description = "Terraform-baked db-state-split script pack + ingest bootstrap for ${local.resolved_remote_runner_name} (allocate_manifest.py, stage-runner.sh, DBSPLIT_INGEST_BOOTSTRAP_B64)."
  category    = "Provider"
  subcategory = "generic"
  metadata = {
    # Generic vault secrets require a single `value` key; runner sync exposes it as env `value`.
    # Ingest embed parses JSON into DBSPLIT_SCRIPT_PACK_* before materializing scripts.
    value = local.runner_script_pack_env_json
  }
}

check "iac_pr_execute_series_paste_budget" {
  assert {
    condition     = length(local.iac_pr_execute_series_body) <= local.stage_execute_series_paste_max_len
    error_message = "iac-pr execute series body length ${length(local.iac_pr_execute_series_body)} exceeds ${local.stage_execute_series_paste_max_len} — do not inline script_pack_*_b64 in spawn paste"
  }
}

check "converge_execute_series_paste_budget" {
  assert {
    condition     = length(local.converge_execute_series_body) <= local.stage_execute_series_paste_max_len
    error_message = "converge execute series body length ${length(local.converge_execute_series_body)} exceeds ${local.stage_execute_series_paste_max_len} — do not inline script_pack_*_b64 in spawn paste"
  }
}

# =============================================================================
# Remote runner (required — primary shell / tofu / state-download execution)
# =============================================================================

module "remote_runner" {
  source = "../aios-remote-runner"

  create_runner = var.create_remote_runner
  name          = local.resolved_remote_runner_name
  description   = trimspace(var.remote_runner_description) != "" ? trimspace(var.remote_runner_description) : "Remote runner for ${local.agent_name} (tofu plan, state download, git clone behind the customer firewall)."
  labels        = var.remote_runner_labels

  bind_runner_secrets           = local.runner_secrets_sync_configured
  typed_secret_refs             = local.runner_typed_secret_refs
  generic_secret_ref_ids        = local.runner_generic_secret_ref_ids
  secrets_sync_interval_seconds = var.remote_runner_secrets_sync_interval_seconds
}

# =============================================================================
# Agent — DB / monorepo state split architect
# =============================================================================

resource "sg_agent" "db_state_split_architect" {
  name        = local.agent_name
  persona     = local.rendered_persona
  model_names = local.non_trivial_model_names

  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }

  # Guild-native HITL bypass rules (replaces MCP wildcards in hitl.always_allowed).
  auto_approve_tools = [
    for pattern in local.stackgen_mcp_hitl_patterns : {
      tool = pattern
    }
  ]

  remote_runners = var.remote_runner_attach_to_agent ? toset([module.remote_runner.runner_name]) : null

  integrations = compact([
    local.resolved_github_integration_name,
    local.resolved_aws_integration_name,
    trimspace(var.stackgen_mcp_integration_name),
  ])
}

resource "sg_agent_budget" "db_state_split_architect" {
  agent_name  = sg_agent.db_state_split_architect.name
  limit_usd   = 25
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "db_state_split_architect_dangerous_ops" {
  agent_name = sg_agent.db_state_split_architect.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "db_state_split_architect_stackgen_mcp_auto_approve" {
  agent_name = sg_agent.db_state_split_architect.name
  policy_id  = sg_policy.db_state_split_stackgen_mcp_auto_approve.id
  enabled    = true
}

# =============================================================================
# Runbooks (Guild skills)
# =============================================================================

resource "sg_runbook_sop" "db_state_split_orchestration" {
  name        = local.sop_orchestration_name
  approve     = true
  description = trimspace(local.rendered_templates["db-state-split-orchestration.md"])
}

resource "sg_runbook_sop" "terraform_state_shard_extraction" {
  name        = local.sop_shard_extraction_name
  approve     = true
  description = trimspace(local.rendered_templates["terraform-state-shard-extraction.md"])
}

resource "sg_runbook_sop" "terraform_registry_reverse_iac" {
  name        = local.sop_registry_reverse_name
  approve     = true
  description = trimspace(local.rendered_templates["terraform-registry-reverse-iac.md"])
}

resource "sg_runbook_sop" "terraform_substate_convergence" {
  name        = local.sop_substate_converge_name
  approve     = true
  description = trimspace(local.rendered_templates["terraform-substate-convergence.md"])
}

resource "sg_runbook_sop" "orphan_iac_module_bootstrap" {
  name        = local.sop_orphan_bootstrap_name
  approve     = true
  description = trimspace(local.rendered_templates["orphan-iac-module-bootstrap.md"])
}

resource "sg_runbook_sop" "stackgen_appstack_mcp_playbook" {
  name        = local.sop_appstack_playbook_name
  approve     = true
  description = trimspace(local.rendered_templates["stackgen-appstack-mcp-playbook.md"])
}

resource "sg_runbook_sop" "cce_iac_alignment" {
  count       = var.enable_cce ? 1 : 0
  name        = local.sop_cce_iac_alignment
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cce-iac-alignment.md.tftpl", {}))
}

# =============================================================================
# Evidence checklists — proof-of-work for primary vs orphan workflows
# =============================================================================

resource "sg_evidence_checklist" "db_monorepo_state_split_evidence" {
  name        = local.evidence_primary_name
  description = "Proof-of-work for monorepo state split: counts reconciled, shard manifests, plan matrix, HCL hydration converged per group, AppStack membership verified per group, and handoff artifacts."
  approve     = true
  required_items = [
    "monolith_resource_count_recorded",
    "aggregate_shard_count_matches_monolith",
    "iac_pr_url_recorded",
  ]
  optional_items = [
    "hcl_hydration_no_changes_per_group",
    "stackgen_appstack_membership_report_attached",
    "appstack_membership_verified_per_group",
    "multi_shard_plan_zero_diff_evidence",
    "appstack_materialization_summary",
    "orphan_secondary_handoff_link",
    "cross_group_bleed_resolution_log",
    "stackgen_plan_action_run_logs",
  ]
  scoring = {
    min_required         = 3
    confidence_threshold = 0.8
  }
  metadata = {
    playbook                   = "db-monorepo-state-split-convergence"
    membership_note_key_prefix = "stackgen_appstack_membership:"
    membership_report_note_key = "stackgen_appstack_membership_report"
    membership_runbook         = "stackgen-appstack-mcp-playbook-sop"
    membership_runbook_section = "step 3.5 — Membership verification gate"
    hcl_hydration_note_prefix  = "hcl_hydration_status:"
    hcl_hydration_runbook      = "terraform-registry-reverse-iac-sop"
    hcl_hydration_section      = "HCL hydration (mandatory — no human \"HCL author\" handoff)"
  }
}

resource "sg_evidence_checklist" "orphan_iac_module_authoring_evidence" {
  name        = local.evidence_orphan_name
  description = "Proof-of-work for orphan module pipeline: bundle classified, module scaffold validated, memory and PR handoff."
  approve     = true
  required_items = [
    "orphans_bundle_classification_summary",
    "module_fmt_validate_plan_evidence",
    "modularization_memory_or_pr_link",
  ]
  optional_items = ["test_results_or_ci_link"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.7
  }
  metadata = { playbook = "orphan-iac-module-authoring" }
}

# =============================================================================
# Primary workflow — monorepo state → per-DB TF states + convergence loops
# =============================================================================

resource "sg_workflow" "db_monorepo_state_split_convergence" {
  name        = local.workflow_primary_name
  domain      = "infrastructure-as-code"
  description = <<-EOT
    Splits a monolithic Terraform/OpenTofu state across **AWS, Azure, and GCP** into **logical resource groups**
    (tags, module paths, grouping policy, or **connectivity-first** graphs), optional **per-group TF states**, **StackGen AppStacks** (via MCP when configured),
    reverse-engineered IaC, registry mapping, orphan secondary workflow, and loops until counts match and plans converge.
    Cross-stage scratch paths use `$HOME/.<workflow_run_id>/` — copy `workflow_run_id` from the stagerunner `[Workflow execution]` header (same contract as terraform-module-update).
    Optional **`grouping_strategy`** + **`max_resources_per_appstack`** cap large type buckets into smaller connected shards.
    **HCL is fully agent-authored, and only HCL:** the reverse-IaC stage runs `tofu plan -generate-config-out=generated.tf` to materialize resource bodies from import blocks; every committed file under `groups/<group_id>/` is `.tf` (HCL), never `*.tf.json`. Empty-body `main.tf` stubs are never handed off to a human; addresses the generator cannot read (provider auth / deleted) move to `orphans_bundle` automatically.
    **Git access** for `git clone iac_repository_url` runs on the **remote runner** with env-mounted credentials (`GIT_TOKEN` / `GIT_HOST` / `GIT_USERNAME` or `GIT_SSH_PRIVATE_KEY` + `GIT_SSH_KNOWN_HOSTS`). See module README "Operator prerequisites → Git connectivity".
    **Execution Optimization Protocol (hard rule):** multi-step shell work batches into one `${local.shell_tool_prefix}_execute_series`; `${local.shell_tool_prefix}_execute_command` is for a single cohesive command only; independent per-group / per-shard fan-out uses `${local.shell_tool_prefix}_execute_parallel` or `flow_type:"parallel"` subagent batches — never N concurrent `execute_command` calls in a single turn. See orchestration SOP § *Execution Optimization Protocol*.
    Env profile + StackGen Plan action runs are **optional**: pass **`stackgen_target_environment`** (an existing project env) only if you want them — leave it unset to skip those steps and rely on remote-runner `tofu plan` parity. **`stackgen_environments_required="true"`** turns "env not in project settings" into a single operator notify; default is silent skip.
    **DAG (lean v2 — 5 LLM stages):** `ingest-and-split` → `ingest-blocked-gate` → `registry-and-import-codegen` (script: scaffold + IaC PR + parallel artifacts) → **3-way parallel** — `shell-converge-matrix` ‖ `materialize-appstacks-coordinator` ‖ `orphans-secondary-pipeline` → `final-gate-and-memory`. HCL hydrate + plan matrix are script-driven in `shell-converge-matrix`.
  EOT
  approve     = true

  metadata = {
    planner_max_tool_iterations = "12"
  }

  required_inputs = ["monolith_state_uri"]
  optional_inputs = [
    "tfstate_file",
    "iac_repository_url",
    "iac_repo_url",
    "default_branch",
    "state_encryption_hint",
    "remote_runner_name",
    "max_convergence_iterations",
    "registry_catalog_url",
    "grouping_policy_json",
    "grouping_strategy",
    "max_resources_per_appstack",
    "stackgen_project_name",
    "stackgen_target_environment",
    "stackgen_environments_required",
    "cloud_discovery_id",
  ]
  evidence_checklist_ref = sg_evidence_checklist.db_monorepo_state_split_evidence.name

  example_queries = [
    "Split monorepo tfstate s3://acme-tf/prod/terraform.tfstate: group by tag Application, one AppStack per tag value for AWS + Azure resources",
    "Brownfield infra-live: logical groups by module.networking vs module.data — GCP and AWS — then create_appstack per group",
    "Use grouping_policy_json to merge all azurerm_* with tag env=prod into one StackGen appstack and empty-plan each",
    "Connectivity-first: grouping_strategy=connectivity_capped, max_resources_per_appstack=80 — shard state into connected subgraphs with at most 80 resources per AppStack",
    "Zero-diff default for large states: grouping_strategy=tag_seeded_connectivity_capped, max_resources_per_appstack=120 — tag-seeded dependency components capped for per-group tofu plan",
    "AppStacks only (no Plan): leave stackgen_target_environment empty so env profile + create_appstack_action_run are skipped — fall back to remote-runner tofu plan parity",
  ]

  triggers = [
    { field = "intent", values = ["db-state-split", "db-monorepo-tfstate-split", "split-db-state", "logical-state-split", "appstack-from-tfstate"], type = "passive" },
  ]

  runbook_refs = [
    sg_runbook_sop.db_state_split_orchestration.name,
    sg_runbook_sop.terraform_state_shard_extraction.name,
    sg_runbook_sop.terraform_registry_reverse_iac.name,
    sg_runbook_sop.stackgen_appstack_mcp_playbook.name,
    sg_runbook_sop.terraform_substate_convergence.name,
    sg_runbook_sop.orphan_iac_module_bootstrap.name,
  ]

  stages = [
    {
      stage_id    = "ingest-and-split"
      description = "Fetch monolith state, deterministic split-manifest, per-group tfstate shards, count reconcile"
      note        = "One script series: preflight → download-state → split-manifest. See db-state-split-orchestration-sop § *Script pack*."
      required    = true
    },
    {
      stage_id    = "ingest-blocked-gate"
      description = "Skip to final gate when ingest failed (missing URI, script-pack error, reconcile false)"
      note        = "conditional_skip only — no LLM, no GO_BACK loop gates."
      required    = false
    },
    {
      stage_id    = "registry-and-import-codegen"
      description = "Script-first: registry scaffold + prepare-parallel-artifacts + IaC PR"
      note        = "Runs iac-pr-pipeline (scaffold, batch_payloads.json, clone, cp sync, gh pr). Does NOT run tofu hydrate — that is shell-converge-matrix."
      required    = true
    },
    {
      stage_id    = "shell-converge-matrix"
      description = "Script-first: hydrate-and-plan-matrix over sample groups (tofu init + generate-config-out + verify plan)"
      note        = "Parallel layer. ONE shell-converge-matrix-runner execute_series. Emits hcl_hydration_status:* and multi_plan_zero_diff_ok."
      required    = true
    },
    {
      stage_id    = "materialize-appstacks-coordinator"
      description = "Parallel layer: spawn 4× appstack-materialize-runner-batch-<NN> in one turn using batch_payloads.json"
      note        = "Coordinator only — max 1 create_agent fan-out message with flow_type parallel. Reads pre-built batch_payloads.json from registry stage."
      required    = true
    },
    {
      stage_id    = "orphans-secondary-pipeline"
      description = "Parallel layer: trigger orphan-iac-module-authoring when orphans_bundle non-empty"
      note        = "Skip cleanly when orphans_bundle empty. Max 2 tool turns (read_notes + note/notify)."
      required    = false
    },
    {
      stage_id    = "final-gate-and-memory"
      description = "Confirm counts + zero plans; persist orphan_modularization_memory and handoff summary"
      note        = "Merge secondary workflow results if any; final notify / PR / submit_evidence."
      required    = true
    },
  ]

  stage_bindings = [
    {
      stage_id  = "ingest-and-split"
      agent_ref = sg_agent.db_state_split_architect.name
      runbook_refs = [
        sg_runbook_sop.db_state_split_orchestration.name,
        sg_runbook_sop.terraform_state_shard_extraction.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "terraform-state-shard-extraction-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::ingest-and-split"], []),
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::ingest-monolith"], []),
      )
      spawn_contracts = local.spawn_contracts_ingest_and_split
      note            = <<-EOT
        DBSPLIT_ALLOCATE_SHA256=${local.script_pack_allocate_sha256}
        Budget: ≤ 1 remote-runner script subagent, ≤ $1.50, ≤ 60m (script_runner_timeout_seconds=${local.subagent_budgets.script_runner_timeout_seconds}).
        **Step 0 — normalize inputs (mandatory before spawn):** Resolve `monolith_state_uri` from workflow inputs (`monolith_state_uri`, `tfstate_file`), nested JSON in the user message (`{"tfstate_file":"…"}` or `{"monolith_state_uri":"…"}` inside prose), or bare `s3://` / `https://` / `drive.google.com` URLs. `monolith_state_uri = inputs.monolith_state_uri // inputs.tfstate_file // parsed_json // prose_url`. `note("monolith_state_uri", resolved_uri)` when non-empty. **`iac_repository_url = inputs.iac_repository_url // inputs.iac_repo_url // "$${default_iac_repository_url}"`** — missing repo URL → `repo_clone_path=skipped_no_iac_repository_url_provided` (blocks IaC push / final-gate). **`default_branch = inputs.default_branch // "$${default_branch}"`** — mirror when non-empty. If monolith URI is still empty → `ask_clarifying_question` **once** for `monolith_state_uri` only; `note stage_summary:ingest-and-split=blocked:missing_input`; emit final line **`blocked:missing_monolith_state_uri: "true"`**; **do NOT spawn** `ingest-and-split-runner` (`ingest-blocked-gate` skips to final-gate).
        **Architect = coordinator only:** when URI is resolved, spawn **exactly one** `ingest-and-split-runner` (`task_type="${var.subagent_task_type}"`). **`create_agent` goal MUST be the spawn_contract goal verbatim** — never paste this stage note into `goal` and never author a custom multi-step goal (trace `88b0393c`: truncated goal dropped ingest bootstrap; trace **019e905a51fc**: custom goal used `create_files` + `${local.resolved_github_integration_name}_*` / `${local.resolved_aws_integration_name}_*` instead of `${local.shell_tool_prefix}_execute_*`; trace **ea8f5ab7**: `terminal_calling` + execute_series paste corrupted JSON). **`agent_name` MUST be the exact string `ingest-and-split-runner`** — never suffix variants. **`tool_names` on create_agent MUST match spawn_contract** — only `${local.shell_tool_prefix}_execute_command`, `note`, `read_notes`; never `execute_series`, never `create_files`, never MCP integration execute_* tools. **Max 1 runner re-spawn** after failure only. After **two failed runner attempts**, emit **`blocked:three_runner_attempts_failed: "true"`** and **`blocked:ingest_script_pack_failed: "true"`**; do **NOT** spawn inline python splitters. Host applies `spawn_contracts` budgets/tools — do NOT re-specify create_agent fields. **Architect MUST NOT** call `${local.shell_tool_prefix}_execute_*` during this stage — only `read_notes`, `note`, and `create_agent` for the runner.
        **INGEST FAIL signature (trace f23d78e0 / ffc0a822 / 019e9036 / ea8f5ab7):** heredoc paste, **`create_files`** with giant B64, LLM-authored base64 in `execute_command`, or **`execute_series`** JSON paste → **base64: invalid input** / shell syntax errors. Runner MUST use **two `execute_command` calls only:** spawn_monolith_uri pre-write, then paste **`INGEST_BOOTSTRAP_EXECUTE_COMMAND`** verbatim (decodes bootstrap from runner script-pack secret) — **`timeout_seconds=${local.subagent_budgets.script_runner_timeout_seconds}`** (never 60). Trace **8c7ea4ad:** bootstrap **< 60s** + missing handoff → **`MONOLITH_URI_unset`** or skipped **spawn_monolith_uri** pre-write.
        **INGEST RETRY (max 1 re-spawn):** Re-spawn with **identical spawn_contract goal** — same two execute_command steps; never create_files, heredoc, or LLM-authored script body. Missing `script_pack_version` after bootstrap **< 120s** → wrong tool order or timeout too low.
        **INGEST STOP RULE (mandatory after runner success):** apply ONLY when `read_notes` shows `count_reconciliation_ok: "true"` AND `logical_group_count >= 10` AND non-empty `logical_group_manifest_path`. Runner must `note()` handoff keys from **`$WORK_ROOT/notes.json`** or **`$WORK_ROOT/.work/ingest-handoff.txt`** — **NOT** from execute_command stdout (trace `88b0393c`: stdout truncated → empty keys). Then: (1) `note("stage_summary:ingest-and-split", "ok")` without overwriting handoff keys; (2) final message echoing reconcile keys; (3) **RETURN immediately** — zero additional spawns.
        **StackGen project (mirror at ingest):** `stackgen_project_name = inputs.stackgen_project_name // "${trimspace(var.stackgen_project_name)}"` — when non-empty, `note("stackgen_project_name", …)` before spawning the runner so `materialize-appstacks-coordinator` never calls MCP with empty `project_name`.
        **Script pack (mandatory):** ingest bootstrap in **`runner_script_pack_env`** secret as **`DBSPLIT_INGEST_BOOTSTRAP_B64`** (sha **${local.ingest_bootstrap_sha256}**, pack **${local.script_pack_version}**). Spawn context delivers **`INGEST_BOOTSTRAP_EXECUTE_COMMAND`** — runner pastes into second `execute_command` after spawn_monolith_uri. See orchestration SOP § *Script pack*.
        **Success criteria:** final line MUST include `count_reconciliation_ok: "true"` or `"false"` (quoted), `script_pack_version: "${local.script_pack_version}"`, and `script_pack_verify_ok: "true"` when reconcile succeeded. If `logical_group_count` is 1 and group id is `ungrouped` with `monolith_resource_count > 5000`, emit **`script_pack_drift_possible: "true"`** (non-blocking warning — likely non-canonical inline python recovery).
        **Outputs:** `monolith_state_local_path`, `logical_group_manifest`, `group_state_paths`, `count_reconciliation_ok`, `logical_group_count`, `script_pack_version`, DB anchor inventory paths. Echo group count + shared group ids in final message. Final line MUST include `count_reconciliation_ok: "true"` or `count_reconciliation_ok: "false"` (quoted strings).
        `note` `stage_summary:ingest-and-split` AND mirror all handoff keys to `$HOME/.<workflow_run_id>/notes.json`. Never `load_skill` / `submit_evidence` here.
      EOT
    },
    {
      stage_id         = "ingest-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["ingest-and-split"]
      action_config = {
        condition = "output_matches_regex"
        match     = "blocked:missing_monolith_state_uri|blocked:three_runner_attempts_failed|blocked:ingest_script_pack_failed|stage_summary:ingest-and-split=blocked:|script_pack_verify_ok: \"false\"|script_pack_drift_possible: \"true\"|count_reconciliation_ok: \"false\"|script_pack_error="
        skip_to   = "final-gate-and-memory"
        reason    = "Ingest or reconcile failure — skip registry and parallel layer"
      }
    },
    {
      stage_id         = "registry-and-import-codegen"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["ingest-blocked-gate"]
      runbook_refs = [
        sg_runbook_sop.terraform_registry_reverse_iac.name,
        sg_runbook_sop.db_state_split_orchestration.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "terraform-registry-reverse-iac-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::registry-and-import-codegen"], [])
      )
      spawn_contracts = local.spawn_contracts_registry_codegen
      note            = <<-EOT
        **Upstream blocked guard (step 0):** if notes contain `blocked:missing_monolith_state_uri`, `blocked:three_runner_attempts_failed`, `blocked:ingest_script_pack_failed`, `count_reconciliation_ok` not `"true"`, or `stage_summary:ingest-and-split=blocked:` → one-line `notify({stage:'registry-and-import-codegen',error:'upstream_ingest_blocked'})` and **return** (no remediation prose).
        **Script-first IaC PR (mandatory):** spawn **exactly one** `registry-and-import-codegen-runner`. Architect MUST NOT call `${local.shell_tool_prefix}_execute_*` — only `read_notes`, `note`, and `create_agent`.
        **ONE execute_series:** paste IAC_PR_EXECUTE_SERIES verbatim. Pipeline: registry scaffold → prepare-parallel-artifacts → clone → cp sync groups → gh pr create.
        After runner: `note()` stdout keys including `batch_payloads_path`, `pr_url`, `large_state_sample_group_ids`. Final message echoes `pr_url=` (may be empty on pr_blocker) and `stage_summary:registry-and-import-codegen`.
        Forbidden: LLM-per-group scaffold, inline python, `create_files`, second execute_series, `*-probe`, `*-disk-mirror`.
      EOT
    },
    {
      stage_id         = "shell-converge-matrix"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["registry-and-import-codegen"]
      runbook_refs = [
        sg_runbook_sop.terraform_registry_reverse_iac.name,
        sg_runbook_sop.terraform_substate_convergence.name,
        sg_runbook_sop.db_state_split_orchestration.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "terraform-registry-reverse-iac-sop", "terraform-substate-convergence-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::shell-converge-matrix"], []),
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::hcl-hydrate-per-group"], []),
      )
      spawn_contracts = local.spawn_contracts_shell_converge
      note            = <<-EOT
        **Upstream blocked guard (step 0):** if notes contain ingest blocked sentinels (`blocked:ingest_script_pack_failed`, `blocked:three_runner_attempts_failed`, `count_reconciliation_ok` not `"true"`) → one-line `notify({stage:'shell-converge-matrix',error:'upstream_ingest_blocked'})` and **return**.
        **Coordinator-only (max 2 create_agent calls):** (1) spawn **exactly one** `shell-converge-matrix-runner` with CONVERGE_EXECUTE_SERIES verbatim — runs `hydrate-and-plan-matrix` over `sample_group_ids.json`. (2) **RETURN** — no probes, no batch re-spawns.
        **Forbidden agent names:** `*-probe`, `*-disk-mirror`, `*-extract-*`, `*-v2`, `hcl-hydrate-runner-batch-*` (script owns hydration).
        After runner: parse stdout for `multi_plan_zero_diff_ok: "true"|"false"`, `hydrate_ok_groups=`, mirror `hcl_hydration_status:*` keys from notes/disk. `note stage_summary:shell-converge-matrix`.
        Runs **in parallel** with `materialize-appstacks-coordinator` and `orphans-secondary-pipeline`.
      EOT
    },
    {
      stage_id         = "materialize-appstacks-coordinator"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["registry-and-import-codegen"]
      runbook_refs = compact(concat(
        [
          sg_runbook_sop.stackgen_appstack_mcp_playbook.name,
          sg_runbook_sop.db_state_split_orchestration.name,
        ],
        var.enable_cce ? [sg_runbook_sop.cce_iac_alignment[0].name] : [],
      ))
      skill_refs = concat(
        ["stackgen-appstack-mcp-playbook-sop", "db-state-split-orchestration-sop"],
        var.enable_cce ? [local.sop_cce_iac_alignment] : [],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::materialize-appstacks-coordinator"], []),
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::materialize-stackgen-appstacks"], []),
      )
      spawn_contracts = local.spawn_contracts_appstack_batch
      note            = <<-EOT
        **Coordinator-only (max 1 create_agent fan-out):** `read_notes` → confirm `batch_payloads_path` + `large_state_sample_group_ids` exist (registry stage wrote them). Spawn **exactly 4** parallel children in **one message**: `appstack-materialize-runner-batch-01` … `batch-04` with `flow_type:"parallel"`, each assigned disjoint slices from `batch_payloads.json`. **RETURN immediately** after spawn — do NOT run MCP on the lead.
        **Forbidden:** `*-extract-payloads`, `*-read-payloads`, `*-prep`, `*-probe`, lead `${local.shell_tool_prefix}_execute_*`.
        Batch children follow stackgen-appstack-mcp-playbook-sop (create → bulk_add → membership gate → bulk_connect). Lead merges `stackgen_appstack_membership_report` at **final-gate-and-memory** (read notes only — not in this stage).
        If MCP not attached: `note stackgen_appstack_map=skipped: no_mcp` and return.
        **Final message format (mandatory):** Title **`## materialize-appstacks-coordinator — Fan-out started (async)`** — NOT "stage complete" for AppStack materialize. State that **4 batch runners are executing** create/bulk_add/membership/connect in parallel. `note("stage_summary:materialize-appstacks-coordinator", "spawned")`. **Do not** claim AppStacks exist yet on the lead. **Do not** use a closing line that reads like workflow closure (avoid sole headline **"Next step: final-gate"**); instead: *"Batch runners in flight; **final-gate-and-memory** will publish the accomplishment report when parallel branches finish."*
      EOT
    },
    {
      stage_id         = "orphans-secondary-pipeline"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["registry-and-import-codegen"]
      runbook_refs = [
        sg_runbook_sop.db_state_split_orchestration.name,
        sg_runbook_sop.orphan_iac_module_bootstrap.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "orphan-iac-module-bootstrap-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::orphans-secondary-pipeline"], [])
      )
      note = <<-EOT
        **Max 2 tool turns:** `read_notes` (+ disk mirror fallback) → if `orphans_bundle` empty → `note stage_summary:orphans-secondary-pipeline=skipped:empty_orphans_bundle` and **return**. Else build `secondary_workflow_payload` and notify/start orphan workflow.
        **Forbidden:** `*-entry-probe`, `*-disk-mirror`, `*-bundle-snapshot` subagents.
        Runs in parallel with `shell-converge-matrix` and `materialize-appstacks-coordinator`.
      EOT
    },
    {
      stage_id         = "final-gate-and-memory"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["shell-converge-matrix", "materialize-appstacks-coordinator", "orphans-secondary-pipeline"]
      runbook_refs = [
        sg_runbook_sop.db_state_split_orchestration.name,
        sg_runbook_sop.orphan_iac_module_bootstrap.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "orphan-iac-module-bootstrap-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::final-gate-and-memory"], [])
      )
      note = <<-EOT
        **Blocked guards (step 0):** if notes contain `blocked:missing_monolith_state_uri`, `blocked:three_runner_attempts_failed`, `blocked:ingest_script_pack_failed`, `blocked:remote_runner_shell_unavailable`, `blocked:remote_runner_tofu_missing`, or ingest/registry blocked summaries → `notify` + `stage_summary:final-gate-and-memory=blocked:<reason>` and **return**.
        **Convergence guard (step 1):** if `multi_plan_zero_diff_ok` is not `"true"` → `blocked:plan_not_converged`. When `pr_blocker` is `git_credentials_missing`, `notify` must tell the operator to wire `runner_git_token` / `runner_git_env_secret_id` on the remote runner (see README) — IaC PR is optional for count/AppStack convergence but required for final evidence `pr_url`. If `pr_url` missing and `pr_blocker` set → include in notify (operator may open PR from `working_branch`).
        **Evidence gate:** `submit_evidence` for required checklist items. When `large_state_sample_mode=true`, partial AppStack/hydration evidence is acceptable with `"partial": true`.
        Final `notify` with PR URL + per-group tables. Never emit owner "HCL AUTHOR".
        `note` `stage_summary:final-gate-and-memory` and mirror to `$HOME/.<workflow_run_id>/notes.json`.
        **Final message format (mandatory — operator/UI rollup):** Title **`## final-gate-and-memory — COMPLETE`**. Include **Evidence Gate — PASSED** table, **Convergence Guards** table, **per-group summary** (group, AppStack ID, resources, membership ok), `pr_url`, and **`stage_summary:final-gate-and-memory=ok`**. This message is the authoritative accomplishment summary (not the materialize coordinator spawn message).
      EOT
    },
  ]
}

# =============================================================================
# Secondary workflow — orphan resources → new module + memory
# =============================================================================

resource "sg_workflow" "orphan_iac_module_authoring" {
  name        = local.workflow_secondary_name
  domain      = "infrastructure-as-code"
  description = <<-EOT
    Guild pipeline that materializes Terraform modules from orphan resource bundles produced by
    db-monorepo-state-split-convergence, validates them, and records modularization memory for reuse.
  EOT
  approve     = true

  metadata = {
    planner_max_tool_iterations = "40"
  }

  required_inputs        = ["orphans_bundle", "parent_repository_url"]
  optional_inputs        = ["base_branch", "proposed_module_name_prefix"]
  evidence_checklist_ref = sg_evidence_checklist.orphan_iac_module_authoring_evidence.name

  example_queries = [
    "Orphans from state split: [...addresses...] — scaffold a shared networking module",
    "Take orphans_bundle JSON and publish modules/orphan-wrap under parent repo",
  ]

  triggers = [
    { field = "intent", values = ["orphan-iac-module-authoring", "db-split-orphan-modules"], type = "passive" },
  ]

  runbook_refs = [
    sg_runbook_sop.orphan_iac_module_bootstrap.name,
    sg_runbook_sop.db_state_split_orchestration.name,
  ]

  stages = [
    {
      stage_id    = "orphan-intake-classify"
      description = "Parse orphans_bundle; classify and name proposed modules"
      required    = true
    },
    {
      stage_id    = "scaffold-validate-module"
      description = "Author module tree, fmt/init/validate/plan, tests"
      required    = true
    },
    {
      stage_id    = "memory-and-handoff"
      description = "Write orphan_modularization_memory; PR or notify primary workflow"
      required    = true
    },
  ]

  stage_bindings = [
    {
      stage_id  = "orphan-intake-classify"
      agent_ref = sg_agent.db_state_split_architect.name
      runbook_refs = [
        sg_runbook_sop.orphan_iac_module_bootstrap.name,
        sg_runbook_sop.db_state_split_orchestration.name,
      ]
      skill_refs = concat(
        ["orphan-iac-module-bootstrap-sop", "db-state-split-orchestration-sop"],
        try(var.secondary_workflow_skill_refs["orphan-iac-module-authoring::orphan-intake-classify"], [])
      )
      note = "read_notes for orphans_bundle; emit classification markdown; note stage_summary."
    },
    {
      stage_id         = "scaffold-validate-module"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["orphan-intake-classify"]
      runbook_refs     = [sg_runbook_sop.orphan_iac_module_bootstrap.name]
      skill_refs = concat(
        ["orphan-iac-module-bootstrap-sop"],
        try(var.secondary_workflow_skill_refs["orphan-iac-module-authoring::scaffold-validate-module"], [])
      )
      note = "Remote runner CLI subagent: scaffold under a writable `$HOME/.<workflow_run_id>` tree if needed; run fmt/init/validate/plan in bounded steps (see orphan-iac-module-bootstrap-sop); persist paths via notes."
    },
    {
      stage_id         = "memory-and-handoff"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["scaffold-validate-module"]
      runbook_refs     = [sg_runbook_sop.orphan_iac_module_bootstrap.name]
      skill_refs = concat(
        ["orphan-iac-module-bootstrap-sop"],
        try(var.secondary_workflow_skill_refs["orphan-iac-module-authoring::memory-and-handoff"], [])
      )
      note = "Append orphan_modularization_memory; open PR or notify with summary for primary workflow consumer."
    },
  ]
}

# =============================================================================
# Optional GitHub webhook → primary workflow
# =============================================================================

resource "sg_webhook" "github_db_state_split" {
  count = var.enable_github_webhook ? 1 : 0

  name        = local.webhook_name
  target_type = "workflow"
  target_name = sg_workflow.db_monorepo_state_split_convergence.name
  action      = "GitHub issue or PR about splitting monorepo Terraform state into logical groups and StackGen AppStacks (multi-cloud); triage and run db-monorepo-state-split-convergence with repository_url and state URI from the body."
  enabled     = true
}
