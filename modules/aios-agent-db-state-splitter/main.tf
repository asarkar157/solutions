terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # sg_remote_runner (>= 0.1.23); sg_agent plan stability + workflow metadata (>= 0.1.23).
      version = ">= 0.1.23, < 0.2.0"
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
  # prefixes the LLM sees at runtime; every literal `${local.resolved_ubuntu_integration_name}_*` reference
  # in the SOPs / persona is templated below.
  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  ubuntu_integration_name = "${local.module_prefix}-ubuntu${local.suffix}"
  aws_integration_name    = "${local.module_prefix}-aws${local.suffix}"

  # `provision_*` must be plan-time known because it drives `count` on the
  # nested integration modules. We deliberately do NOT inspect
  # `var.*_secret_id` here — the consumer often wires those from another
  # module's output (`module.github_pat[0].secret_id`,
  # `module.aws_integration[0].secret_id`) which is only known at apply time.
  # When `existing_*_integration_name` is empty we always try to provision; the
  # inner integration module's preconditions surface a clear error if the
  # secret input is also missing.
  provision_github = trimspace(var.existing_github_integration_name) == ""
  provision_ubuntu = trimspace(var.existing_ubuntu_integration_name) == ""
  provision_aws    = trimspace(var.existing_aws_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_ubuntu_integration_name = trimspace(var.existing_ubuntu_integration_name) != "" ? var.existing_ubuntu_integration_name : (
    local.provision_ubuntu ? module.ubuntu_integration[0].integration_name : ""
  )
  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )

  # Guild tool names are <integration_name>_<mcp_tool>; pattern suffix * bypasses HITL for all MCP tools on that integration.
  # `stackgen_mcp_integration_name` is required (variables.tf validates non-empty) so this list is always populated.
  stackgen_mcp_hitl_patterns = ["${trimspace(var.stackgen_mcp_integration_name)}_*"]

  stage_runner_script         = trimspace(file("${path.module}/scripts/stage-runner.sh"))
  allocate_manifest_script    = file("${path.module}/scripts/allocate_manifest.py")
  ubuntu_integration_home     = "/home/integration"
  script_pack_version         = "20260531.32"
  script_pack_git_ref         = "main"
  script_pack_allocate_sha256 = sha256(local.allocate_manifest_script)
  script_pack_runner_sha256   = sha256(local.stage_runner_script)
  script_pack_allocate_b64    = base64encode(local.allocate_manifest_script)
  script_pack_runner_b64      = base64encode(local.stage_runner_script)

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

  template_vars = {
    module_prefix                       = local.module_prefix
    suffix                              = local.suffix
    ubuntu_tool_prefix                  = local.resolved_ubuntu_integration_name
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
    ubuntu_integration_home             = local.ubuntu_integration_home
    stackgen_project_name_default       = trimspace(var.stackgen_project_name)
    default_grouping_strategy           = var.default_grouping_strategy
    default_max_resources_per_appstack  = var.default_max_resources_per_appstack
    default_iac_repository_url          = trimspace(var.default_iac_repository_url)
    default_branch                      = trimspace(var.default_branch)
    subagent_budgets                    = local.subagent_budgets
    bulk_add_resources_max_per_call     = 100
    bulk_connect_resources_max_per_call = 100
    bulk_resources_chunk_size           = 80
    bulk_connections_chunk_size         = 50
  }

  ingest_execute_series_body = templatefile(
    "${path.module}/templates/ingest-execute-series-embedded.sh.tftpl",
    local.template_vars,
  )
  # Bootstrap embed (~4.3k) — delivered via create_files + short decode command (avoids printf quote/truncation in execute_series).
  ingest_execute_series_b64            = base64encode(local.ingest_execute_series_body)
  ingest_execute_series_decode_command = "base64 -d /home/integration/.{{workflow_run_id}}/.work/ingest-embed.b64 | /bin/bash"

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

  remote_runner_block = trimspace(var.remote_runner_name) != "" ? trimspace(<<-RUNNER
    Operator supplied **remote_runner_name** = "${var.remote_runner_name}"%{if var.create_remote_runner~} (registered by Terraform via `sg_remote_runner`; install commands are in root module outputs `remote_runner_cli_start_command` / `remote_runner_helm_install_command` — deploy aiden-runner on-prem with **outbound-only** access to mothership before running workflows)%{endif~}.
    When the Guild agent exposes a **remote runner** or delegated execution tool bound to that name, use it for **fan-out** `tofu plan` / heavy `terraform show -json` over many shards so the Ubuntu MCP sandbox does not time out. Persist artifact paths (plan JSON, state snapshots) via `note` keys `remote_runner_artifacts`.
    **Runner prerequisites (operator-owned):** the runner image and env must include **`tofu`/`terraform`**, **`jq`**, **`git`**, and **cloud/SDK credentials** matching `monolith_state_uri` (e.g. S3/GCS/Azure access) if state is not only local HTTP. This Terraform module registers or looks up the runner and optionally **attaches** it on `sg_agent` — it does not install CLIs or cloud secrets on the runner host.
    If no such tool is available, fall back to Ubuntu CLI and **serialize** plans if needed.
    RUNNER
    ) : trimspace(<<-RUNNER
    No `remote_runner_name` was set on the module. Run **all** shell, `tofu`/`terraform`, `jq`, `git`, and state pulls via **Ubuntu CLI** subagents only. Per the **Execution Optimization Protocol** (db-state-split-orchestration-sop), multi-step work is batched into one `${local.resolved_ubuntu_integration_name}_execute_series`; `${local.resolved_ubuntu_integration_name}_execute_command` is reserved for a single cohesive command; `${local.resolved_ubuntu_integration_name}_execute_parallel` (or `flow_type:"parallel"` subagent batches) is the only sanctioned fan-out for independent per-group / per-shard work.
    The **Ubuntu CLI integration** must still have whatever credentials the backend needs for `monolith_state_uri` (IAM keys, workload identity, `gcloud`/`az` login, etc.); this module does not inject cloud provider integrations beyond what Guild binds to that integration.
    RUNNER
  )
}

# =============================================================================
# Owned integrations — provisioned when the consumer hasn't supplied an
# existing one to share. Ubuntu gets both `github_secret_id` and `aws_secret_id`
# attached as `secret_ref_ids` so `git clone`, `gh`, and `tofu` against AWS
# state backends all work inside the sandbox without explicit token capture.
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

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by the ${local.agent_name} agent (issue/PR triage, gh api). Bound to a shared tenant-level PAT secret."
}

module "cce_scripts" {
  count  = var.enable_cce ? 1 : 0
  source = "../aios-cce-scripts"
}

module "ubuntu_integration" {
  count  = local.provision_ubuntu ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = compact([var.github_secret_id, var.aws_secret_id])
  install_tools = concat(
    ["tofu", "terraform", "awscli", "gh", "git", "curl", "jq", "gdown"],
    var.enable_cce ? ["cce"] : [],
  )
  env_vars = var.enable_cce ? {
    CCE_PACK_VERSION = module.cce_scripts[0].cce_pack_version
    CCE_PACK_DIR     = module.cce_scripts[0].cce_pack_dir
    CCE_PACK_B64     = module.cce_scripts[0].cce_pack_tarball_b64
    CCE_USE_CASE     = "iac-alignment"
  } : {}
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
# Remote runner (optional create or lookup)
# =============================================================================

module "remote_runner" {
  count  = trimspace(var.remote_runner_name) != "" ? 1 : 0
  source = "../aios-remote-runner"

  create_runner = var.create_remote_runner
  name          = trimspace(var.remote_runner_name)
  description   = trimspace(var.remote_runner_description) != "" ? trimspace(var.remote_runner_description) : "Remote runner for ${local.agent_name} (fan-out tofu plan / state inspection behind the customer firewall)."
  labels        = var.remote_runner_labels
}

# =============================================================================
# Agent — DB / monorepo state split architect
# =============================================================================

resource "sg_agent" "db_state_split_architect" {
  name        = local.agent_name
  persona     = local.rendered_persona
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }

  # Guild-native HITL bypass rules (replaces MCP wildcards in hitl.always_allowed).
  auto_approve_tools = [
    for pattern in local.stackgen_mcp_hitl_patterns : {
      tool = pattern
    }
  ]

  remote_runners = var.remote_runner_attach_to_agent && length(module.remote_runner) > 0 ? toset([module.remote_runner[0].runner_name]) : null

  integrations = compact([
    local.resolved_github_integration_name,
    local.resolved_ubuntu_integration_name,
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
    **Git access** for `git clone iac_repository_url` runs inside the Ubuntu container with env-mounted credentials (`GIT_TOKEN` / `GIT_HOST` / `GIT_USERNAME` or `GIT_SSH_PRIVATE_KEY` + `GIT_SSH_KNOWN_HOSTS`) — same `sg_secret` → `secret_ref_ids` pattern as AWS creds. See module README "Operator prerequisites → Git connectivity".
    **Execution Optimization Protocol (hard rule):** multi-step shell work batches into one `${local.resolved_ubuntu_integration_name}_execute_series`; `${local.resolved_ubuntu_integration_name}_execute_command` is for a single cohesive command only; independent per-group / per-shard fan-out uses `${local.resolved_ubuntu_integration_name}_execute_parallel` or `flow_type:"parallel"` subagent batches — never N concurrent `execute_command` calls in a single turn. See orchestration SOP § *Execution Optimization Protocol*.
    Env profile + StackGen Plan action runs are **optional**: pass **`stackgen_target_environment`** (an existing project env) only if you want them — leave it unset to skip those steps and rely on Ubuntu `tofu plan` parity. **`stackgen_environments_required="true"`** turns "env not in project settings" into a single operator notify; default is silent skip.
    **DAG (lean v2 — 5 LLM stages):** `ingest-and-split` → `ingest-blocked-gate` → `registry-and-import-codegen` (script: scaffold + IaC PR + parallel artifacts) → **3-way parallel** — `shell-converge-matrix` ‖ `materialize-appstacks-coordinator` ‖ `orphans-secondary-pipeline` → `final-gate-and-memory`. HCL hydrate + plan matrix are script-driven in `shell-converge-matrix`.
  EOT
  approve     = true

  metadata = {
    planner_max_tool_iterations = 12
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
    "AppStacks only (no Plan): leave stackgen_target_environment empty so env profile + create_appstack_action_run are skipped — fall back to Ubuntu tofu plan parity",
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
        Budget: ≤ 1 Ubuntu-CLI subagent, ≤ $1.50, ≤ 60m (script_runner_timeout_seconds=${local.subagent_budgets.script_runner_timeout_seconds}).
        **Step 0 — normalize inputs (mandatory before spawn):** Resolve `monolith_state_uri` from workflow inputs (`monolith_state_uri`, `tfstate_file`), nested JSON in the user message (`{"tfstate_file":"…"}` or `{"monolith_state_uri":"…"}` inside prose), or bare `s3://` / `https://` / `drive.google.com` URLs. `monolith_state_uri = inputs.monolith_state_uri // inputs.tfstate_file // parsed_json // prose_url`. `note("monolith_state_uri", resolved_uri)` when non-empty. **`iac_repository_url = inputs.iac_repository_url // inputs.iac_repo_url // "$${default_iac_repository_url}"`** — missing repo URL → `repo_clone_path=skipped_no_iac_repository_url_provided` (blocks IaC push / final-gate). **`default_branch = inputs.default_branch // "$${default_branch}"`** — mirror when non-empty. If monolith URI is still empty → `ask_clarifying_question` **once** for `monolith_state_uri` only; `note stage_summary:ingest-and-split=blocked:missing_input`; emit final line **`blocked:missing_monolith_state_uri: "true"`**; **do NOT spawn** `ingest-and-split-runner` (`ingest-blocked-gate` skips to final-gate).
        **Architect = coordinator only:** when URI is resolved, spawn **exactly one** `ingest-and-split-runner` (`task_type="terminal_calling"`). **`create_agent` goal MUST be the spawn_contract goal verbatim** — never paste this stage note into `goal` (trace `88b0393c`: truncated goal dropped INGEST_EXECUTE_SERIES). **`agent_name` MUST be the exact string `ingest-and-split-runner`** — never suffix variants. **Max 1 runner re-spawn** after failure only. After **two failed runner attempts**, emit **`blocked:three_runner_attempts_failed: "true"`** and **`blocked:ingest_script_pack_failed: "true"`**; do **NOT** spawn inline python splitters. Host applies `spawn_contracts` budgets/tools — do NOT re-specify create_agent fields. **Architect MUST NOT** call `${local.resolved_ubuntu_integration_name}_execute_*` during this stage — only `read_notes`, `note`, and `create_agent` for the runner.
        **INGEST FAIL signature (trace f23d78e0 / ffc0a822):** heredoc paste or **`printf '%s' '<b64>'`** wrapping of INGEST_EXECUTE_SERIES into `execute_series` → shell **quoting EOF** / truncated pipe. Runner MUST use **`create_files`** (INGEST_EXECUTE_SERIES_B64) then **`execute_series`** with **INGEST_EXECUTE_SERIES_DECODE_COMMAND** only — **`timeout_seconds=${local.subagent_budgets.script_runner_timeout_seconds}`** (never 60). Trace **8c7ea4ad:** series **< 60s** + missing handoff → **`MONOLITH_URI_unset`** or skipped **spawn_monolith_uri** pre-write.
        **INGEST RETRY (max 1 re-spawn):** Re-spawn with **identical spawn_contract goal** — create_files + decode command only, never heredoc or printf-wrapped B64. Missing `script_pack_version` after series **< 120s** → wrong tool order or timeout too low.
        **INGEST STOP RULE (mandatory after runner success):** apply ONLY when `read_notes` shows `count_reconciliation_ok: "true"` AND `logical_group_count >= 10` AND non-empty `logical_group_manifest_path`. Runner must `note()` handoff keys from **`$WORK_ROOT/notes.json`** or **`$WORK_ROOT/.work/ingest-handoff.txt`** — **NOT** from execute_series stdout (trace `88b0393c`: stdout truncated → empty keys). Then: (1) `note("stage_summary:ingest-and-split", "ok")` without overwriting handoff keys; (2) final message echoing reconcile keys; (3) **RETURN immediately** — zero additional spawns.
        **StackGen project (mirror at ingest):** `stackgen_project_name = inputs.stackgen_project_name // "${trimspace(var.stackgen_project_name)}"` — when non-empty, `note("stackgen_project_name", …)` before spawning the runner so `materialize-appstacks-coordinator` never calls MCP with empty `project_name`.
        **Script pack (mandatory):** spawn context **`INGEST_EXECUTE_SERIES_B64`** + **`INGEST_EXECUTE_SERIES_DECODE_COMMAND`** (pack **${local.script_pack_version}**). Runner: spawn_monolith_uri → **create_files** ingest-embed.b64 → **execute_series** decode. Embed **git sparse-clones** `appcd-dev/aios-modules` at **`${local.script_pack_git_ref}`** via Ubuntu **GIT_TOKEN** (push pack to GitHub before ingest or sha256 verify fails). **NEVER** paste spawn B64 chunks (PII-redacted). See orchestration SOP § *Script pack*.
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
        **Upstream blocked guard (step 0):** if notes contain `blocked:missing_monolith_state_uri`, `blocked:three_runner_attempts_failed`, `blocked:ingest_script_pack_failed`, `count_reconciliation_ok` not `"true"`, or `stage_summary:ingest-and-split=blocked:` → one-line `notify({stage:'registry-and-import-codegen',error:'upstream_ingest_blocked'})` and **return**.
        **Script-first IaC PR (mandatory):** spawn **exactly one** `registry-and-import-codegen-runner`. Architect MUST NOT call `${local.resolved_ubuntu_integration_name}_execute_*` — only `read_notes`, `note`, and `create_agent`.
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
        **Forbidden:** `*-extract-payloads`, `*-read-payloads`, `*-prep`, `*-probe`, lead `${local.resolved_ubuntu_integration_name}_execute_*`.
        Batch children follow stackgen-appstack-mcp-playbook-sop (create → bulk_add → membership gate → bulk_connect). Lead merges `stackgen_appstack_membership_report` after children complete (read notes only — no execute).
        If MCP not attached: `note stackgen_appstack_map=skipped: no_mcp` and return.
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
        **Blocked guards (step 0):** if notes contain `blocked:missing_monolith_state_uri`, `blocked:three_runner_attempts_failed`, `blocked:ingest_script_pack_failed`, `blocked:ubuntu_infra_tofu_missing`, or ingest/registry blocked summaries → `notify` + `stage_summary:final-gate-and-memory=blocked:<reason>` and **return**.
        **Convergence guard (step 1):** if `multi_plan_zero_diff_ok` is not `"true"` → `blocked:plan_not_converged`. If `pr_url` missing and `pr_blocker` set → include in notify (operator may open PR from `working_branch`).
        **Evidence gate:** `submit_evidence` for required checklist items. When `large_state_sample_mode=true`, partial AppStack/hydration evidence is acceptable with `"partial": true`.
        Final `notify` with PR URL + per-group tables. Never emit owner "HCL AUTHOR".
        `note` `stage_summary:final-gate-and-memory` and mirror to `$HOME/.<workflow_run_id>/notes.json`.
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
    planner_max_tool_iterations = 40
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
      note = "Ubuntu CLI subagent: scaffold under a writable `$HOME/.<workflow_run_id>` tree if needed; run fmt/init/validate/plan in bounded steps (see orphan-iac-module-bootstrap-sop); persist paths via notes."
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
