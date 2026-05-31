terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # remote_runners on sg_agent + sg_remote_runner lookup (attach); pin matches repo-wide minimum
      # spawn_contracts on stage_bindings + workflow metadata (provider >= 0.1.21).
      version = ">= 0.1.21, < 0.2.0"
    }
  }
}

data "sg_remote_runner" "db_state_split_architect" {
  count = var.remote_runner_attach_to_agent ? 1 : 0
  name  = trimspace(var.remote_runner_name)
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
  allocate_manifest_script    = trimspace(file("${path.module}/scripts/allocate_manifest.py"))
  ubuntu_integration_home     = "/home/integration"
  script_pack_version         = "20260531.5"
  script_pack_allocate_sha256 = sha256(local.allocate_manifest_script)
  script_pack_runner_sha256   = sha256(local.stage_runner_script)

  subagent_budget_defaults = {
    script_runner_max_llm_calls                = 40
    script_runner_max_tool_iterations          = 48
    script_runner_timeout_seconds              = 900
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
    script_pack_allocate_sha256         = local.script_pack_allocate_sha256
    script_pack_runner_sha256           = local.script_pack_runner_sha256
    ubuntu_integration_home             = local.ubuntu_integration_home
    stackgen_project_name_default       = trimspace(var.stackgen_project_name)
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

  rendered_persona = templatefile("${path.module}/personas/db-state-split-architect.md.tftpl", local.template_vars)

  rendered_templates = {
    for filename in fileset("${path.module}/templates", "*.md.tftpl") :
    replace(filename, ".tftpl", "") => templatefile("${path.module}/templates/${filename}", local.template_vars)
  }

  remote_runner_block = trimspace(var.remote_runner_name) != "" ? trimspace(<<-RUNNER
    Operator supplied **remote_runner_name** = "${var.remote_runner_name}".
    When the Guild agent exposes a **remote runner** or delegated execution tool bound to that name, use it for **fan-out** `tofu plan` / heavy `terraform show -json` over many shards so the Ubuntu MCP sandbox does not time out. Persist artifact paths (plan JSON, state snapshots) via `note` keys `remote_runner_artifacts`.
    **Runner prerequisites (operator-owned):** the runner image and env must include **`tofu`/`terraform`**, **`jq`**, **`git`**, and **cloud/SDK credentials** matching `monolith_state_uri` (e.g. S3/GCS/Azure access) if state is not only local HTTP. This Terraform module only **documents** the name and optionally **attaches** it on `sg_agent` — it does not provision the runner or its secrets.
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

module "ubuntu_integration" {
  count  = local.provision_ubuntu ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = compact([var.github_secret_id, var.aws_secret_id])
  install_tools    = ["tofu", "awscli", "gh", "git", "curl"]
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

  remote_runners = length(data.sg_remote_runner.db_state_split_architect) > 0 ? toset([data.sg_remote_runner.db_state_split_architect[0].name]) : null

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
    "hcl_hydration_no_changes_per_group",
    "stackgen_appstack_membership_report_attached",
    "appstack_membership_verified_per_group",
    "multi_shard_plan_zero_diff_evidence",
  ]
  optional_items = [
    "appstack_materialization_summary",
    "orphan_secondary_handoff_link",
    "cross_group_bleed_resolution_log",
    "stackgen_plan_action_run_logs",
  ]
  scoring = {
    min_required         = 5
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
    **DAG (lean):** `ingest-and-split` (script: download + split-manifest + group shards) → `registry-and-import-codegen`, then **3-way parallel** — `hcl-hydrate-per-group` ‖ `materialize-stackgen-appstacks` ‖ `orphans-secondary-pipeline` (optional) → `multi-shard-plan-convergence` → `final-gate-and-memory`. **7 LLM stages** (was 11) — split work is one coordinator + one runner.
  EOT
  approve     = true

  metadata = {
    planner_max_tool_iterations = "40"
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
      description = "Fetch monolith state (optional IaC clone), deterministic split-manifest, per-group tfstate shards, count reconcile"
      note        = "One script series: preflight → download-state → split-manifest. Replaces legacy ingest / discover / allocate / count-reconcile stages. See db-state-split-orchestration-sop § *Script pack*."
      required    = true
    },
    {
      stage_id    = "split-input-gate"
      description = "Skip to final gate when monolith URI missing or ingest script-pack failed (unrecoverable without operator fix)"
      note        = "conditional_skip only — no LLM. Matches missing URI, three runner failures, or script_pack errors."
      required    = false
    },
    {
      stage_id    = "split-ingest-blocked-gate"
      description = "Skip to final gate when split never verified, reconcile failed, or loop emitted GO_BACK (DAG mode does not re-run ingest on GO_BACK)"
      note        = "conditional_skip only — fan-in ingest-and-split + split-loop-gate outputs."
      required    = false
    },
    {
      stage_id    = "split-loop-gate"
      description = "Loop back to ingest-and-split when count reconciliation fails (bounded; rare with deterministic split)"
      note        = "loop_stage only — no LLM."
      required    = false
    },
    {
      stage_id    = "registry-and-import-codegen"
      description = "FAST: per-group TF root scaffolding (versions.tf / providers.tf / import {} blocks), registry mapping (get_supported_resource_types → StackGen resource_type), classify orphans_bundle. Hydration runs in the next parallel layer."
      note        = "terraform-registry-reverse-iac-sop §§ Stage entry, Execution, Reverse IaC, StackGen module / template cross-check, Registry best-fit, Output. **Does NOT run `tofu plan -generate-config-out`** — that is hcl-hydrate-per-group. Feeds three parallel downstream stages (hydration + AppStacks + orphans)."
      required    = true
    },
    {
      stage_id    = "hcl-hydrate-per-group"
      description = "SLOW (parallel layer): for each group_id, tofu init + tofu plan -generate-config-out=generated.tf (Pass 1) + tofu plan -out=verify.tfplan (Pass 2), looped until plan_no_changes=true or moved to orphans_bundle with reason:'import_failed_*'. Runs concurrently with materialize-stackgen-appstacks and orphans-secondary-pipeline."
      note        = "terraform-registry-reverse-iac-sop § HCL hydration. Per-group children are fully independent — fan out parallel subagents `hcl-hydrate-runner-batch-<NN>` over disjoint group_id ranges. Emit `hcl_hydration_status:<group_id>={generated_tf_path, generated_resources, plan_no_changes, remaining_actions, attempt}`; addresses that the generator cannot read move to `orphans_bundle{reason:'import_failed_<provider_message>'}` (merge with the bundle from the prior stage)."
      required    = true
    },
    {
      stage_id    = "materialize-stackgen-appstacks"
      description = "Parallel layer: per logical group: create_appstack, bulk_add_resources_to_appstack + bulk_connect_resources_in_appstack (closed set from logical_group_manifest; singular add/connect only for needs_attention retries), verify membership (get_appstack_resources); env profile + Plan action run are OPTIONAL (only when stackgen_target_environment is supplied); stackgen_appstack_map + stackgen_appstack_membership_report. Per-group MCP fan-out via appstack-materialize-runner-batch-<NN>. Runs concurrently with hcl-hydrate-per-group and orphans-secondary-pipeline — does NOT read hydrated HCL bodies."
      note        = "stackgen-appstack-mcp-playbook-sop — **one AppStack per `group_id`** in `logical_group_manifest`, with **mandatory** step 3.5 membership verification gate. Persist `stackgen_appstack_membership:<group_id>` per group and the roll-up `stackgen_appstack_membership_report` (required evidence). If operators used `max_resources_per_appstack`, each group should already be ≤ that size; do not merge or re-bucket groups in MCP. Env profile + Plan action runs are **optional** — skipped silently when `stackgen_target_environment` is unset or when the project env is missing (recorded in `stackgen_env_profile:<group_id>` / `stackgen_plan_run:<group_id>`); they do not block the membership gate. Skip the whole stage with note if StackGen MCP not attached."
      required    = true
    },
    {
      stage_id    = "orphans-secondary-pipeline"
      description = "Parallel layer: trigger orphan-iac-module-authoring when orphans_bundle non-empty. Runs concurrently with hcl-hydrate-per-group and materialize-stackgen-appstacks."
      note        = "db-state-split-orchestration-sop § Secondary Guild pipeline. Skip cleanly when orphans_bundle empty — not a failure."
      required    = false
    },
    {
      stage_id    = "multi-shard-plan-convergence"
      description = "tofu plan each TF root + StackGen Plan action runs; emit multi_plan_zero_diff_ok for loop gate. 3-way fan-in: waits for hcl-hydrate-per-group, materialize-stackgen-appstacks, AND orphans-secondary-pipeline."
      note        = "terraform-substate-convergence-sop § Plan matrix + Loop B."
      required    = true
    },
    {
      stage_id    = "multi-shard-plan-infra-gate"
      description = "Skip plan rework loop when Ubuntu sidecar lacks tofu/terraform (infra BLOCKED — operator must fix image)"
      note        = "conditional_skip only — no LLM."
      required    = false
    },
    {
      stage_id    = "multi-shard-plan-loop-gate"
      description = "Loop back when plan matrix not zero-diff (bounded)"
      note        = "loop_stage only — no LLM."
      required    = false
    },
    {
      stage_id    = "final-gate-and-memory"
      description = "Confirm counts + zero plans; persist orphan_modularization_memory and handoff summary"
      note        = "Merge secondary workflow results if any; final notify / PR."
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
        Budget: ≤ 1 Ubuntu-CLI subagent, ≤ $1.50, ≤ 15m.
        **Step 0 — normalize inputs (mandatory before spawn):** Resolve `monolith_state_uri` from workflow inputs (`monolith_state_uri`, `tfstate_file`), nested JSON in the user message (`{"tfstate_file":"…"}` or `{"monolith_state_uri":"…"}` inside prose), or bare `s3://` / `https://` / `drive.google.com` URLs. `monolith_state_uri = inputs.monolith_state_uri // inputs.tfstate_file // parsed_json // prose_url`. `note("monolith_state_uri", resolved_uri)` when non-empty. **`iac_repository_url = inputs.iac_repository_url // inputs.iac_repo_url`** — missing repo URL → `repo_clone_path=skipped_no_iac_repository_url_provided` (non-blocking). If URI is still empty → `ask_clarifying_question` **once** for `monolith_state_uri` only; `note stage_summary:ingest-and-split=blocked:missing_input`; emit final line **`blocked:missing_monolith_state_uri: "true"`**; **do NOT spawn** `ingest-and-split-runner` (`split-input-gate` skips to final-gate).
        **Architect = coordinator only:** when URI is resolved, spawn **exactly one** `ingest-and-split-runner` (`task_type="terminal_calling"`). **`agent_name` MUST be the exact string `ingest-and-split-runner`** — never suffix variants (`ingest-and-split-split-runner`, `ingest-and-split-verify-*`, `ingest-and-split-disk-probe`, `*-direct-runner`, `*-build-seeds`). **Max 1 runner re-spawn** after failure only — second attempt must use **hardcoded absolute paths** from spawn contract context (`WORK_ROOT: …` line), never `$WORK_ROOT` / `$HOME` inside `execute_series` command strings. After **two failed runner attempts**, emit **`blocked:three_runner_attempts_failed: "true"`** and **`blocked:ingest_script_pack_failed: "true"`**; do **NOT** spawn inline python splitters. Forbidden: `*-script-prep`, `*-notes-mirror`, `*-scripts`, `*-v2`, `discover-db-anchors-script-prep`, `allocate-script-writer`. Host applies `spawn_contracts` budgets/tools — do NOT re-specify create_agent fields. **Do NOT** include `create_files` on the ingest runner. **Architect MUST NOT** call `${local.resolved_ubuntu_integration_name}_execute_*` during this stage — only `read_notes`, `note`, and `create_agent` for the runner.
        **INGEST STOP RULE (mandatory after runner success):** when runner output OR `read_notes` shows `count_reconciliation_ok: "true"` AND `logical_group_count >= 10`: (1) `read_notes` once if keys not already visible; (2) `note("stage_summary:ingest-and-split", "ok")` without overwriting runner handoff keys (`logical_group_count`, `group_state_paths`, `logical_group_manifest_path`); (3) final message MUST echo `count_reconciliation_ok: "true"`, `logical_group_count`, `script_pack_version: "${local.script_pack_version}"`, `script_pack_verify_ok: "true"`; (4) **RETURN immediately** — zero additional spawns, zero disk probes (`find`/`cat reconcile_result.json`/`ls`), zero verification subagents. Trace `d0bb9462` thrashed past success and hit max tool iterations — do NOT repeat.
        **StackGen project (mirror at ingest):** `stackgen_project_name = inputs.stackgen_project_name // "${trimspace(var.stackgen_project_name)}"` — when non-empty, `note("stackgen_project_name", …)` before spawning the runner so `materialize-stackgen-appstacks` never calls MCP with empty `project_name`.
        **Script pack (mandatory):** spawn contract context includes **INGEST_EXECUTE_SERIES** (terraform-rendered canonical bash). Runner: `read_notes monolith_state_uri` → ONE `${local.resolved_ubuntu_integration_name}_execute_series` whose body is `export MONOLITH_URI='<uri>'` then the INGEST_EXECUTE_SERIES block verbatim (uses **`ABS_WORK_ROOT=/home/integration/.{{workflow_run_id}}`** — never `/root`, never `$HOME` in tool JSON). **Never** split embed across tool calls. **Never** `bash $WORK_ROOT/scripts/stage-runner.sh` without `_embed_dbsplit_run`. See orchestration SOP § *Script pack*.
        **Success criteria:** final line MUST include `count_reconciliation_ok: "true"` or `"false"` (quoted), `script_pack_version: "${local.script_pack_version}"`, and `script_pack_verify_ok: "true"` when reconcile succeeded. If `logical_group_count` is 1 and group id is `ungrouped` with `monolith_resource_count > 5000`, emit **`script_pack_drift_possible: "true"`** (non-blocking warning — likely non-canonical inline python recovery).
        **Outputs:** `monolith_state_local_path`, `logical_group_manifest`, `group_state_paths`, `count_reconciliation_ok`, `logical_group_count`, `script_pack_version`, DB anchor inventory paths. Echo group count + shared group ids in final message. **Loop gate sentinel:** final line MUST include `count_reconciliation_ok: "true"` or `count_reconciliation_ok: "false"` (quoted strings) for `split-loop-gate`.
        `note` `stage_summary:ingest-and-split` AND mirror all handoff keys to `$HOME/.<workflow_run_id>/notes.json`. Never `load_skill` / `submit_evidence` here.
      EOT
    },
    {
      stage_id         = "split-input-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["ingest-and-split"]
      action_config = {
        condition = "output_matches_regex"
        match     = "blocked:missing_monolith_state_uri|blocked:three_runner_attempts_failed|blocked:ingest_script_pack_failed|stage_summary:ingest-and-split=blocked:|script_pack_verify_ok: \"false\"|script_pack_drift_possible: \"true\""
        skip_to   = "final-gate-and-memory"
        reason    = "Ingest input or script-pack failure — skip rework loop and downstream stages"
      }
    },
    {
      stage_id    = "split-ingest-blocked-gate"
      action_type = "conditional_skip"
      # Fan-in ingest output: conditional_skip evaluates merged predecessor text; loop_stage
      # output alone is JSON without script_pack sentinels (Guild stagerunner limitation).
      stage_depends_on = ["split-loop-gate", "ingest-and-split"]
      action_config = {
        condition = "output_matches_regex"
        match     = "script_pack_error=|script_pack_verify_ok: \"false\"|allocate_sha256_mismatch|blocked:ingest_script_pack_failed|script_pack_drift_possible: \"true\"|count_reconciliation_ok: \"false\"|\"action\":\"GO_BACK\""
        skip_to   = "final-gate-and-memory"
        reason    = "Split not verified or loop did not converge — skip registry and parallel layer"
      }
    },
    {
      stage_id    = "split-loop-gate"
      action_type = "loop_stage"
      # Fan-in ingest so exit_match sees count_reconciliation_ok (not only gate JSON wrapper).
      stage_depends_on = ["split-input-gate", "ingest-and-split"]
      action_config = {
        loop_to        = "ingest-and-split"
        max_iterations = var.max_convergence_iterations
        exit_condition = "output_contains"
        exit_match     = "count_reconciliation_ok: \"true\""
      }
    },
    {
      stage_id         = "registry-and-import-codegen"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["split-ingest-blocked-gate"]
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
        **Upstream blocked guard (step 0):** if notes contain `blocked:missing_monolith_state_uri`, `blocked:three_runner_attempts_failed`, `blocked:ingest_script_pack_failed`, or `stage_summary:ingest-and-split=blocked:` → one-line `notify({stage:'registry-and-import-codegen',error:'upstream_ingest_blocked'})` and **return**. No markdown reports, no `ask_clarifying_question`.
        **Loop-gate guard (step 1):** if stage Input JSON contains `"action":"GO_BACK"` OR `count_reconciliation_ok` is not `"true"` OR `script_pack_verify_ok` is not `"true"` OR `script_pack_drift_possible` is `"true"` → one-line `notify({stage:'registry-and-import-codegen',error:'upstream_not_ready'})` and **return** — do NOT scaffold. If `logical_group_manifest` is absent, same fast-fail (no multi-page report).
        **Stage entry contract (cold-start fast-fail):**
          - (1) `read_notes` (2) if 0 keys, `cat $HOME/.<workflow_run_id>/notes.json` (3) if both empty AND `$HOME/.<workflow_run_id>/terraform.tfstate` does not exist → `notify` once with `{stage:'registry-and-import-codegen', error:'cold_start_no_upstream'}` and **return**. Do NOT emit a long markdown report.
          - Required keys: `repo_clone_path`, `monolith_state_local_path`, `logical_group_manifest` (or legacy `shard_manifest`), `count_reconciliation_ok`, optional `grouping_strategy` / `max_resources_per_appstack`.
          - If notes are missing but the `$HOME/.<workflow_run_id>/` tree IS present, **recover silently**: rebuild paths under that tree and re-run the upstream procedure (re-clone repo, re-download `monolith_state_uri` to the same WORK_ROOT path, re-run shard extraction from `terraform-state-shard-extraction-sop`). Only `notify` after recovery fails.
          - StackGen MCP availability is **discoverable** via `search_tools` (`*_create_appstack` / `*_get_appstacks`); this stage stops at TF roots + import blocks + registry mapping — AppStack materialization and HCL hydration are downstream parallel stages.
        **Scope (FAST):** registry mapping + scaffold + import blocks ONLY. **Per-group state:** read `group_state_paths` from notes — each `groups/<group_id>/terraform.tfstate` already exists from `split-manifest`; scaffold `imports.tf` from addresses in `logical_group_manifest`, point backend/data sources at the slice path when helpful.
        **HCL-only output (hard rule):** every scaffold file under `groups/<group_id>/` MUST be HCL `.tf` — `versions.tf`, `providers.tf`, `imports.tf` (or per-cloud `imports-<provider>.tf`). **Never** write `*.tf.json` (Terraform JSON syntax), and never synthesize Terraform config via `jq` / `python -c json.dumps`. When authoring optional `*.tftest.hcl` under a group root, include **`mock_provider "aws" {}`** (and matching providers per cloud) so offline `tofu test` never needs live credentials — same rule as terraform-module-update discovery scaffolds. `terraform show -json` / `tofu show -json` output stays in `$HOME/.<workflow_run_id>/` scratch and is **not** committed alongside the per-group `.tf` files. Run `tofu fmt` on every scaffold root before declaring the stage complete.
        **Subagent discipline:** delegate to ONE `registry-and-import-codegen-runner`. Host applies `spawn_contracts`. If it does not converge, **re-plan** (split per cloud / per group batch) rather than re-running the same payload.
        Materialize `groups/<group_id>/` TF roots + import strategy (`versions.tf`, `providers.tf`, `import {}` blocks — all HCL). Run **registry mapping** via `get_supported_resource_types` per terraform-registry-reverse-iac-sop § *Registry best-fit*. Emit `registry_mapping_report` and the **initial** `orphans_bundle` (addresses with `reason: "no_supported_resource_type"`; the hydration stage will append `reason: "import_failed_*"` entries).
        Use writable `$HOME/.<workflow_run_id>` and chunked `terraform show` / shell steps per terraform-registry-reverse-iac-sop **Execution** section.
        `note` `reverse_iac_summary={files_created, imports_pending, scaffold_paths_per_group}`, `registry_mapping_report`, `orphans_bundle`, and `stage_summary:registry-and-import-codegen`. Mirror all to `$HOME/.<workflow_run_id>/notes.json`. Echo a compact per-group scaffold table (group_id → scaffold_path / addresses_imported) in the final assistant message so the three parallel downstream stages can start cleanly.
      EOT
    },
    {
      stage_id         = "hcl-hydrate-per-group"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["registry-and-import-codegen"]
      runbook_refs = [
        sg_runbook_sop.terraform_registry_reverse_iac.name,
        sg_runbook_sop.db_state_split_orchestration.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "terraform-registry-reverse-iac-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::hcl-hydrate-per-group"], [])
      )
      spawn_contracts = local.spawn_contracts_hcl_hydrate_batch
      note            = <<-EOT
        **Upstream blocked guard (step 0):** if notes contain `blocked:missing_monolith_state_uri`, `blocked:ubuntu_infra_tofu_missing`, or stage Input JSON contains `"action":"GO_BACK"` with no `logical_group_manifest` → one-line `notify({stage:'hcl-hydrate-per-group',error:'upstream_not_ready'})` and **return**. No markdown reports, no `ask_clarifying_question`.
        **Infra preflight (step 1 — mandatory):** ONE `${local.resolved_ubuntu_integration_name}_execute_command`: `command -v tofu || command -v terraform`. If both missing → `note blocked:ubuntu_infra_tofu_missing: "true"`, `note stage_summary:hcl-hydrate-per-group=blocked:ubuntu_infra_tofu_missing`, mirror to disk, **return immediately**. Do **NOT** append all resources to `orphans_bundle` for a missing binary — that is infra BLOCKED, not per-address import failure. Do **NOT** attempt apt/snap/curl installs in-agent.
        **Stage entry contract (cold-start fast-fail):** (1) `read_notes` (2) if 0 keys, `cat $HOME/.<workflow_run_id>/notes.json` (3) if both empty OR no `groups/` directory under `$HOME/.<workflow_run_id>/` → `notify` once with `{stage:'hcl-hydrate-per-group', error:'cold_start_no_upstream'}` and return.
        **Required keys after stage entry:** `logical_group_manifest`, `repo_clone_path`, `reverse_iac_summary` (with per-group scaffold paths), `registry_mapping_report`, `orphans_bundle`.
        **Parallel siblings:** this stage runs concurrently with `materialize-stackgen-appstacks` and `orphans-secondary-pipeline`. Use disjoint `note` keys: this stage owns `hcl_hydration_status:<group_id>` and may append to `orphans_bundle` with `reason:"import_failed_*"` entries. **Do not** read or write `stackgen_appstack_*` or `secondary_workflow_payload` here.
        **Subagent discipline — per-group parallel fan-out:** spawn N parallel `hcl-hydrate-runner-batch-<NN>` children (`flow_type:"parallel"`). Host applies `spawn_contracts` for `hcl-hydrate-runner-batch`. If any batch does not converge, **re-plan** (smaller batch size) rather than `-v2` retries.
        **Execution Optimization Protocol (hard rule):** inside each batch child, the per-group Pass 1 + Pass 2 + `tofu fmt` MUST be **one** `${local.resolved_ubuntu_integration_name}_execute_series` per `group_id`, not three `${local.resolved_ubuntu_integration_name}_execute_command` calls. **Across groups**, fan out via `flow_type:"parallel"` batch children (this stage's pattern) or `${local.resolved_ubuntu_integration_name}_execute_parallel` — **never** N concurrent `${local.resolved_ubuntu_integration_name}_execute_command` calls in a single turn. See db-state-split-orchestration-sop § *Execution Optimization Protocol*.
        For each `group_id` in the batch, run **Pass 1** (`tofu init -input=false -no-color && tofu plan -generate-config-out=generated.tf -input=false -lock=false -out=hydrate.tfplan`) then **Pass 2** (`tofu plan -input=false -lock=false -out=verify.tfplan`), batched together in one `execute_series`. Loop per group until `plan_no_changes=true` or surface failed addresses to `orphans_bundle{reason:"import_failed_<provider_message>"}`. **Never** leave empty-body `resource "aws_X" "Y" {}` stubs and **never** emit owner "HCL AUTHOR" — see terraform-registry-reverse-iac-sop § *HCL hydration*.
        **HCL-only output (hard rule):** `generated.tf` and any patches you apply MUST be HCL `.tf`. The `-generate-config-out=generated.tf` flag is the only sanctioned codegen path; never `-generate-config-out=*.tf.json`. Do not synthesize `*.tf.json` via `jq` / `python -c json.dumps` when an attribute is awkward — push the address to `orphans_bundle{reason:"requires_dynamic_codegen"}` instead and let `orphan-iac-module-authoring` wrap it (still HCL). `hcl_hydration_status:<group_id>.generated_tf_path` MUST end in `.tf` for the convergence + final gates to accept the group. Run `tofu fmt` on every group root after each pass.
        Persist `hcl_hydration_status:<group_id>={generated_tf_path, generated_resources, plan_no_changes, remaining_actions, attempt}` per group, and update the shared `orphans_bundle` with any new `import_failed_*` entries. Mirror all to `$HOME/.<workflow_run_id>/notes.json`.
        `note` `stage_summary:hcl-hydrate-per-group` with per-group `plan_no_changes` counts, orphan additions during hydration, and the parallel batch fan-out summary. Echo the same in the final assistant message.
      EOT
    },
    {
      stage_id         = "materialize-stackgen-appstacks"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["registry-and-import-codegen"]
      runbook_refs = [
        sg_runbook_sop.stackgen_appstack_mcp_playbook.name,
        sg_runbook_sop.db_state_split_orchestration.name,
      ]
      skill_refs = concat(
        ["stackgen-appstack-mcp-playbook-sop", "db-state-split-orchestration-sop", "terraform-registry-reverse-iac-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::materialize-stackgen-appstacks"], [])
      )
      spawn_contracts = local.spawn_contracts_appstack_batch
      note            = <<-EOT
        **Upstream blocked guard (step 0):** if notes contain `blocked:missing_monolith_state_uri` or no `logical_group_manifest` and stage Input JSON contains `"action":"GO_BACK"` → one-line `notify({stage:'materialize-stackgen-appstacks',error:'upstream_not_ready'})` and **return**. No markdown reports, no `ask_clarifying_question`.
        **Stage entry contract (cold-start fast-fail):** (1) `read_notes` (2) if 0 keys, `cat $HOME/.<workflow_run_id>/notes.json` (3) if both empty → `notify` once with `{stage:'materialize-stackgen-appstacks', error:'cold_start_no_upstream'}` and return. Don't use `ask_clarifying_question` to recover prior-stage state — that's a fast-fail case.
        **Required keys after stage entry:** `logical_group_manifest`, `repo_clone_path`, `reverse_iac_summary`, `registry_mapping_report`, `orphans_bundle`, **`stackgen_project_name`** (required when MCP attached — from ingest notes or workflow input; module default `${trimspace(var.stackgen_project_name) != "" ? trimspace(var.stackgen_project_name) : "(unset — call me)"}`), optional `stackgen_target_environment`, optional `stackgen_environments_required`. Detect StackGen MCP via `search_tools` for `*_create_appstack` / `*_get_appstacks`. **Before any MCP call:** confirm `stackgen_project_name` is non-empty; if empty, call `me` once and `note` the resolved UUID — never call `get_appstacks` with empty `project_name`.
        **Subagent discipline:** spawn parallel `appstack-materialize-runner-batch-<NN>` when group count > 1. Host applies `spawn_contracts`. Target 8–16 batches for large manifests; halve concurrency on MCP 429. Atomicity is per group — never split one group's MCP flow across subagents.
        If StackGen MCP is attached: for **each** `group_id` assigned to this agent (lead only when group count = 1; otherwise each batch child for its slice), run the **state → AppStack** flow from **`stackgen-appstack-mcp-playbook-sop`** in this exact order:
          1) `create_appstack` (record `stackgen_appstack_map[group_id]` immediately).
          2) Build `identifier_for_address:<group_id>` from `group.resource_addresses` (deterministic snake_case sanitizer; resources without a mapped `resource_type` go to `orphans_bundle` — never silently dropped).
          3) **`bulk_add_resources_to_appstack`** — build `resources[]` from `identifier_for_address` + registry mapping (+ `configuration` when known). Chunk ≤ 80 items per call (server max 100). Fix all validation errors from one failed bulk in a single follow-up call; use singular `add_resource_to_appstack` only for `needs_attention` indices. Closed set — never addresses outside the group.
          3.5) **MANDATORY membership verification gate.** Call `get_appstack_resources(appstack_id)` once and write `stackgen_appstack_membership:<group_id>` JSON with `expected_identifiers`, `actual_identifiers`, `missing`, `unexpected`, `cross_group_bleed`, `ok`. Reconcile (bulk-add or singular re-add missing, delete unexpected non-bleed entries) until `ok=true`. Cross-group bleed → log to `stackgen_mcp_errors` and escalate; do not auto-fix by deleting from another group's stack.
          4) **`bulk_connect_resources_in_appstack`** — `connections[]` with `source_identifier` / `target_identifier` from step 3; chunk ≤ 50 per call (server max 100). Singular `connect_resources` only for `needs_attention` edges. Same `appstack_id` only.
          5) **Env profile is OPTIONAL** (project envs cannot be created via MCP). If `stackgen_target_environment` is unset → skip and `note` `stackgen_env_profile:<group_id>={skipped:"no_target_env_input"}`. If set, `get_env_profiles` then `create_env_profile` / `update_env_profile`. On `environment '<env>' not found in project settings` (or any 4xx tied to env existence) → soft-fail: append `stackgen_mcp_errors{reason:"env_not_in_project_settings"}` and `note stackgen_env_profile:<group_id>={skipped:"env_missing_in_project_settings", env}`. Only escalate via a single `notify` when `stackgen_environments_required="true"`; never block other groups.
          6) **StackGen Plan is OPTIONAL.** Skip when step 5 was skipped/soft-failed → `note stackgen_plan_run:<group_id>={skipped:"no_env_profile"}` and rely on Ubuntu `tofu plan` for parity. Otherwise `create_appstack_action_run` (Plan) and capture `get_action_run_logs`.
        After all groups, write **`stackgen_appstack_membership_report`** roll-up JSON (groups_total / groups_ok / groups_failed + per_group). The stage is **not complete** while any group is `ok=false` — but a **soft-failed env / Plan does not** make a group `ok=false`; membership is the gate, env/Plan is bonus evidence.
        This stage runs **in the 3-way parallel layer** alongside `hcl-hydrate-per-group` and `orphans-secondary-pipeline`. **Read only** notes from `registry-and-import-codegen` (`registry_mapping_report`, `reverse_iac_summary`, `orphans_bundle`, `logical_group_manifest`) and the monolith state attributes — do **NOT** wait on or read `hcl_hydration_status:*` (hydration is a peer, not an upstream). MCP **`bulk_add_resources_to_appstack`** only needs `identifier` + `resource_type` (+ optional `configuration`); hydrated HCL bodies live in the sibling stage. Prefer disjoint `note` keys from the orphan branch (`secondary_workflow_payload`, `stage_summary:orphans-secondary-pipeline`).
        MCP efficiency: one `get_appstacks` pass per wave → `note` `stackgen_appstack_list_cache`; `get_appstack_resources` once per `appstack_id` per reconcile pass — not before every bulk-add; prefer bulk_add + bulk_connect over per-address singular tools (integrations bulk MCP, deployed 2026-05-30).
        Do **not** re-bucket by Terraform type at MCP time (e.g. "all aws_iam_*" into one stack) — `logical_group_manifest` is authoritative.
        If MCP not attached: `note` stackgen_appstack_map=`skipped: no_mcp` and stackgen_appstack_membership_report=`skipped: no_mcp`.
        Optional workflow input `cloud_discovery_id` is a **correlation id** only — the default StackGen **user** MCP does not expose discovery-import tools; do not plan on `create_appstack_from_discovered_resources` unless a **different** MCP integration documents it.
        `note` `stage_summary:materialize-stackgen-appstacks` (include groups_ok / groups_failed, parallel batch fan-out summary, and counts of env/Plan skips) AND append to `$HOME/.<workflow_run_id>/notes.json`. Echo `stackgen_appstack_map` and the membership-report summary in the final assistant message.
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
        **Stage entry contract (cold-start fast-fail):** (1) `read_notes` (2) if 0 keys, `cat $HOME/.<workflow_run_id>/notes.json` (3) if both empty → `notify` once with `{stage:'orphans-secondary-pipeline', error:'cold_start_no_upstream'}` and return. Don't use `ask_clarifying_question` to recover prior-stage state — that's a fast-fail case.
        **Required keys after stage entry:** `orphans_bundle`, `logical_group_manifest`, `iac_repository_url`.
        3-way parallel layer with `hcl-hydrate-per-group` and `materialize-stackgen-appstacks`. Do not assume AppStacks already exist; read only registry-and-import-codegen notes (`orphans_bundle`, `logical_group_manifest`, `registry_mapping_report`). Note: hydration may append late-discovered `import_failed_*` entries to `orphans_bundle` concurrently; if your secondary workflow consumes it, snapshot the bundle at stage entry and document the snapshot timestamp.
        If `orphans_bundle` empty → `note` `stage_summary:orphans-secondary-pipeline={skipped:'empty_orphans_bundle'}` and return cleanly (this is **🟢 INFO**, not a failure). Else build `secondary_workflow_payload` and start workflow **orphan-iac-module-authoring** (same org) or notify operators with JSON.
        Mirror `stage_summary:orphans-secondary-pipeline` to `$HOME/.<workflow_run_id>/notes.json` and echo the outcome (`skipped` or `started:<workflow_run_id>`) in the final assistant message.
      EOT
    },
    {
      stage_id         = "multi-shard-plan-convergence"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["hcl-hydrate-per-group", "materialize-stackgen-appstacks", "orphans-secondary-pipeline"]
      runbook_refs = [
        sg_runbook_sop.terraform_substate_convergence.name,
        sg_runbook_sop.db_state_split_orchestration.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "terraform-substate-convergence-sop", "terraform-registry-reverse-iac-sop", "stackgen-appstack-mcp-playbook-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::multi-shard-plan-convergence"], [])
      )
      spawn_contracts = local.spawn_contracts_plan_convergence
      note            = <<-EOT
        **Upstream blocked guard (step 0):** if notes contain `blocked:missing_monolith_state_uri` or no `logical_group_manifest` and stage Input JSON contains `"action":"GO_BACK"` → one-line `notify({stage:'multi-shard-plan-convergence',error:'upstream_not_ready'})` and **return**. No markdown reports, no `ask_clarifying_question`.
        **Stage entry contract (cold-start fast-fail):** (1) `read_notes` (2) if 0 keys, `cat $HOME/.<workflow_run_id>/notes.json` (3) if BOTH empty AND no `$HOME/.<workflow_run_id>/groups/` directory exists → this is a vacuous cold-start. **Do NOT** emit a multi-table "all SKIPPED" markdown report. `notify` once with `{stage:'multi-shard-plan-convergence', error:'cold_start_no_upstream'}` and return. Don't substitute `ask_clarifying_question` for the fast-fail path — production DAGs showed it waiting ~5 min per call for prior-stage state the operator can't supply.
        **Required keys after stage entry:** `logical_group_manifest`, `repo_clone_path`, `hcl_hydration_status:<group_id>` (per group), `stackgen_appstack_map`, `stackgen_appstack_membership:<group_id>` (per group), `stackgen_env_profile:<group_id>` (per group), `stackgen_plan_run:<group_id>` (per group).
        **Subagent discipline:** delegate to ONE `multi-shard-plan-runner` or parallel `multi-shard-plan-runner-batch-<NN>`. Host applies `spawn_contracts`. If any batch does not converge, **re-plan** decomposition rather than re-running the same payload.
        **Execution Optimization Protocol (hard rule):** inside each shard, `tofu init` + `tofu plan` + plan-summary `jq` MUST be **one** `${local.resolved_ubuntu_integration_name}_execute_series` per shard. **Across shards**, fan out via `${local.resolved_ubuntu_integration_name}_execute_parallel` or `flow_type:"parallel"` `multi-shard-plan-runner-batch-<NN>` children — **never** N concurrent `${local.resolved_ubuntu_integration_name}_execute_command` calls in a single turn. `${local.resolved_ubuntu_integration_name}_execute_command` is reserved for a single cohesive command. See db-state-split-orchestration-sop § *Execution Optimization Protocol*.
        **HCL hydration pre-check first** (Loop B-hcl). For every `group_id`, `hcl_hydration_status:<group_id>.plan_no_changes` must be `true`. If any group is `false` or missing, check `failure_reason` — when it contains `tofu_not_installed` or notes contain `blocked:ubuntu_infra_tofu_missing`, emit **`blocked:ubuntu_infra_tofu_missing: "true"`** in the final message (infra gate skips the rework loop). Otherwise return execution to `hcl-hydrate-per-group` for stub/import fixes — **do not** raise an operator-facing 🔴 "HCL AUTHOR" item.
        **Membership pre-check second** (Loop B-membership). For every `group_id`, read `stackgen_appstack_membership:<group_id>` and confirm `ok=true`, `expected_count==actual_count`, and `cross_group_bleed==[]`. Any failure → re-enter **stackgen-appstack-mcp-playbook-sop** step 3.5 for that group.
        Run TF plan matrix per `logical_group_manifest`. **StackGen Plan is OPTIONAL:** for groups whose `stackgen_env_profile:<group_id>` is `{skipped:...}` or `stackgen_plan_run:<group_id>` is already `{skipped:...}`, skip `create_appstack_action_run` and rely on Ubuntu `tofu plan` parity. For the rest (membership ok and env profile present), run **`create_appstack_action_run`** (Plan) per AppStack and collect **`get_action_run`** / **`get_action_run_logs`**. If any drift, Loop B then re-plan until pass or iteration cap. Treat any new `env_not_in_project_settings` here as a soft skip (same semantics as the materialization stage).
        One shard (or small batch) per `execute_series` with bounded `timeout_seconds` per step; avoid one shell invocation that plans all shards sequentially past integration ceilings (~300s). Prefer remote runner fan-out when configured.
        Set **`multi_plan_zero_diff_ok: "true"`** or **`multi_plan_zero_diff_ok: "false"`** (exact quoted strings) for **`multi-shard-plan-loop-gate`**. `note` `stage_summary:multi-shard-plan-convergence` with skip counts and a *per-iteration blocking-items report* using db-state-split-orchestration-sop § *Iteration report — blocker classification* (env-missing → 🟢 INFO; empty-body stubs → 🟡 self-fixable, never 🔴). Mirror `multi_plan_zero_diff_ok` to `$HOME/.<workflow_run_id>/notes.json` and echo the sentinel line in the final assistant message.
      EOT
    },
    {
      stage_id         = "multi-shard-plan-infra-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["multi-shard-plan-convergence"]
      action_config = {
        condition = "output_matches_regex"
        match     = "blocked:ubuntu_infra_tofu_missing|tofu_not_installed|failure_reason.*tofu_not_installed|hcl_hydration_status.*tofu_not_installed"
        skip_to   = "final-gate-and-memory"
        reason    = "Ubuntu sidecar missing tofu/terraform — skip unproductive plan rework loop"
      }
    },
    {
      stage_id    = "multi-shard-plan-loop-gate"
      action_type = "loop_stage"
      # Fan-in convergence output so exit_match sees multi_plan_zero_diff_ok after infra gate pass-through.
      stage_depends_on = ["multi-shard-plan-infra-gate", "multi-shard-plan-convergence"]
      action_config = {
        loop_to        = "hcl-hydrate-per-group"
        max_iterations = var.max_convergence_iterations
        exit_condition = "output_contains"
        exit_match     = "multi_plan_zero_diff_ok: \"true\""
      }
    },
    {
      stage_id         = "final-gate-and-memory"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["multi-shard-plan-loop-gate"]
      runbook_refs = [
        sg_runbook_sop.db_state_split_orchestration.name,
        sg_runbook_sop.orphan_iac_module_bootstrap.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "orphan-iac-module-bootstrap-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::final-gate-and-memory"], [])
      )
      note = <<-EOT
        **Skipped-from-ingest guard (step 0):** if notes contain `blocked:missing_monolith_state_uri`, `blocked:three_runner_attempts_failed`, `blocked:ingest_script_pack_failed`, `blocked:ubuntu_infra_tofu_missing`, or matching `stage_summary:ingest-and-split=blocked:` / `stage_summary:hcl-hydrate-per-group=blocked:ubuntu_infra_tofu_missing` → `notify({stage:'final-gate-and-memory',status:'blocked:<reason>'})`, `note stage_summary:final-gate-and-memory=blocked:<reason>`, and **return** (evidence gate correctly fails — no vacuous success).
        **Loop-gate guard (step 1):** if predecessor/stage Input JSON contains `"action":"GO_BACK"` AND `blocked:ubuntu_infra_tofu_missing` is **not** set → **blocked** (`stage_summary:final-gate-and-memory=blocked:loop_not_finished`). When **`blocked:ubuntu_infra_tofu_missing`** is set, report operator action (install tofu on Ubuntu integration / redeploy image) — do NOT expect GO_BACK to converge. If `multi_plan_zero_diff_ok` is not `"true"` and infra is OK, fail with `blocked:plan_not_converged`.
        **Stage entry contract (cold-start fast-fail):** (1) `read_notes` (2) if 0 keys, `cat $HOME/.<workflow_run_id>/notes.json` (3) if BOTH empty → this is a vacuous cold-start. **Do NOT** emit a multi-table "all SKIPPED" markdown report. `notify` once with `{stage:'final-gate-and-memory', error:'cold_start_no_upstream'}` and **exit with error status** so the evidence checklist correctly fails. Don't use `ask_clarifying_question` to recover the run — there is nothing the operator can supply at this point that earlier stages didn't already.
        **Required keys after stage entry:** `count_reconciliation_ok`, `multi_plan_zero_diff_ok`, `hcl_hydration_status:<group_id>` (per group), `stackgen_appstack_membership_report`, `stackgen_env_profile:<group_id>` / `stackgen_plan_run:<group_id>` (per group), `orphan_modularization_memory`, all `stage_summary:*`.
        **Evidence gate (mandatory before success):** verify that the workflow's `evidence_checklist_ref` (`db-monorepo-state-split-evidence`) has a successful `submit_evidence` call for **every** required item: `monolith_resource_count_recorded`, `aggregate_shard_count_matches_monolith`, `hcl_hydration_no_changes_per_group`, `stackgen_appstack_membership_report_attached`, `appstack_membership_verified_per_group`, `multi_shard_plan_zero_diff_evidence`. If any are missing or `count_reconciliation_ok != "true"` or `multi_plan_zero_diff_ok != "true"`, **this stage MUST fail** with `notify({status:'evidence_missing', missing_items:[…]})`. Do NOT return "vacuous gate complete" — that produced silent no-op runs in production (trace 019e20308ea374c8bbc134d5c0ef0860).
        Verify `count_reconciliation_ok`, `multi_plan_zero_diff_ok`, **all `hcl_hydration_status:<group_id>.plan_no_changes==true`**, and **`stackgen_appstack_membership_report.summary.groups_failed == 0`** (when StackGen MCP was used). Env-profile / StackGen-Plan skips are **not** failures.
        Final `notify` / PR comment with tables (per-group expected vs actual counts, hydration outcome, missing/unexpected highlights) + PR links. Apply db-state-split-orchestration-sop § *Iteration report — blocker classification* to any remaining items: env-missing → 🟢 INFO ("optional — operator may register the env in StackGen Project Settings to also see StackGen-side Plan logs"); never emit 🔴 ADMIN for the env unless `stackgen_environments_required="true"` AND `stackgen_target_environment` was supplied. Never emit owner "HCL AUTHOR".
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
