terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # remote_runners on sg_agent + sg_remote_runner lookup (attach); pin matches repo-wide minimum
      version = ">= 0.1.13, < 0.2.0"
    }
  }
}

data "sg_remote_runner" "db_state_split_architect" {
  count = var.remote_runner_attach_to_agent ? 1 : 0
  name  = trimspace(var.remote_runner_name)
}

locals {
  # Guild tool names are <integration_name>_<mcp_tool>; pattern suffix * bypasses HITL for all MCP tools on that integration.
  stackgen_mcp_hitl_patterns = trimspace(var.stackgen_mcp_integration_name) != "" ? ["${trimspace(var.stackgen_mcp_integration_name)}_*"] : []

  remote_runner_block = trimspace(var.remote_runner_name) != "" ? trimspace(<<-RUNNER
    Operator supplied **remote_runner_name** = "${var.remote_runner_name}".
    When the Guild agent exposes a **remote runner** or delegated execution tool bound to that name, use it for **fan-out** `tofu plan` / heavy `terraform show -json` over many shards so the Ubuntu MCP sandbox does not time out. Persist artifact paths (plan JSON, state snapshots) via `note` keys `remote_runner_artifacts`.
    **Runner prerequisites (operator-owned):** the runner image and env must include **`tofu`/`terraform`**, **`jq`**, **`git`**, and **cloud/SDK credentials** matching `monolith_state_uri` (e.g. S3/GCS/Azure access) if state is not only local HTTP. This Terraform module only **documents** the name and optionally **attaches** it on `sg_agent` — it does not provision the runner or its secrets.
    If no such tool is available, fall back to Ubuntu CLI and **serialize** plans if needed.
    RUNNER
    ) : trimspace(<<-RUNNER
    No `remote_runner_name` was set on the module. Run **all** shell, `tofu`/`terraform`, `jq`, `git`, and state pulls via **Ubuntu CLI** (`ubuntu-cli_execute_command|series|parallel`) subagents only.
    The **Ubuntu CLI integration** must still have whatever credentials the backend needs for `monolith_state_uri` (IAM keys, workload identity, `gcloud`/`az` login, etc.); this module does not inject cloud provider integrations beyond what Guild binds to that integration.
    RUNNER
  )
}

# =============================================================================
# Policy — auto-approve StackGen Consumer MCP tools (stackgen-mcp_*)
# =============================================================================

resource "sg_policy" "db_state_split_stackgen_mcp_auto_approve" {
  name        = "db-state-split-stackgen-mcp-auto-approve"
  description = "Companion intervention policy for db-state-split-architect; when stackgen_mcp_integration_name is set, hitl.always_allowed includes <integration>_* so Consumer MCP tools skip HITL."
  type        = "intervention"
  rego_source = file("${path.module}/policies/stackgen-mcp-auto-approve.rego")
}

# =============================================================================
# Agent — DB / monorepo state split architect
# =============================================================================

resource "sg_agent" "db_state_split_architect" {
  name        = "db-state-split-architect"
  persona     = file("${path.module}/personas/db-state-split-architect.md")
  model_names = compact([var.model_names.claude_sonnet, var.model_names.gpt4o])

  hitl = {
    # Provider: tool names or patterns — e.g. stackgen-mcp_* matches every tool with prefix stackgen-mcp_
    # when `stackgen_mcp_integration_name` is `stackgen-mcp`.
    always_allowed = concat(["web_search", "note", "read_notes"], local.stackgen_mcp_hitl_patterns)
  }

  remote_runners = length(data.sg_remote_runner.db_state_split_architect) > 0 ? toset([data.sg_remote_runner.db_state_split_architect[0].name]) : null

  integrations = compact([
    var.integration_names.github,
    var.integration_names.ubuntu_cli,
    trimspace(var.stackgen_mcp_integration_name) != "" ? trimspace(var.stackgen_mcp_integration_name) : null,
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
  name    = "db-state-split-orchestration-sop"
  approve = true
  description = trimspace(templatefile("${path.module}/templates/db-state-split-orchestration.md.tftpl", {
    max_iterations      = var.max_convergence_iterations
    remote_runner_block = local.remote_runner_block
  }))
}

resource "sg_runbook_sop" "terraform_state_shard_extraction" {
  name        = "terraform-state-shard-extraction-sop"
  approve     = true
  description = trimspace(file("${path.module}/templates/terraform-state-shard-extraction.md"))
}

resource "sg_runbook_sop" "terraform_registry_reverse_iac" {
  name        = "terraform-registry-reverse-iac-sop"
  approve     = true
  description = trimspace(file("${path.module}/templates/terraform-registry-reverse-iac.md"))
}

resource "sg_runbook_sop" "terraform_substate_convergence" {
  name        = "terraform-substate-convergence-sop"
  approve     = true
  description = trimspace(file("${path.module}/templates/terraform-substate-convergence.md"))
}

resource "sg_runbook_sop" "orphan_iac_module_bootstrap" {
  name        = "orphan-iac-module-bootstrap-sop"
  approve     = true
  description = trimspace(file("${path.module}/templates/orphan-iac-module-bootstrap.md"))
}

resource "sg_runbook_sop" "stackgen_appstack_mcp_playbook" {
  name        = "stackgen-appstack-mcp-playbook-sop"
  approve     = true
  description = trimspace(file("${path.module}/templates/stackgen-appstack-mcp-playbook.md"))
}

# =============================================================================
# Evidence checklists — proof-of-work for primary vs orphan workflows
# =============================================================================

resource "sg_evidence_checklist" "db_monorepo_state_split_evidence" {
  name        = "db-monorepo-state-split-evidence"
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
  name        = "orphan-iac-module-authoring-evidence"
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
  name        = "db-monorepo-state-split-convergence"
  domain      = "infrastructure-as-code"
  description = <<-EOT
    Splits a monolithic Terraform/OpenTofu state across **AWS, Azure, and GCP** into **logical resource groups**
    (tags, module paths, grouping policy, or **connectivity-first** graphs), optional **per-group TF states**, **StackGen AppStacks** (via MCP when configured),
    reverse-engineered IaC, registry mapping, orphan secondary workflow, and loops until counts match and plans converge.
    Optional **`grouping_strategy`** + **`max_resources_per_appstack`** cap large type buckets into smaller connected shards.
    **HCL is fully agent-authored:** the reverse-IaC stage runs `tofu plan -generate-config-out=generated.tf` to materialize resource bodies from import blocks; empty-body `main.tf` stubs are never handed off to a human. Addresses the generator cannot read (provider auth / deleted) move to `orphans_bundle` automatically.
    Env profile + StackGen Plan action runs are **optional**: pass **`stackgen_target_environment`** (an existing project env) only if you want them — leave it unset to skip those steps and rely on Ubuntu `tofu plan` parity. **`stackgen_environments_required="true"`** turns "env not in project settings" into a single operator notify; default is silent skip.
    **DAG:** after reverse IaC, **AppStack materialization** and **orphan secondary handoff** run **in parallel**; **multi-shard plan convergence** waits for both (fan-in).
  EOT
  approve     = true

  required_inputs = ["monolith_state_uri", "iac_repository_url"]
  optional_inputs = [
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
      stage_id    = "ingest-monolith"
      description = "Clone IaC repo, fetch monolith state to a writable directory (prefer /tmp/...), record monolith_resource_count"
      note        = "Ubuntu CLI: preflight writable dir (mktemp under /tmp); git clone, backend pull or aws s3 cp state, tofu/terraform state list | wc -l style count; persist monolith_state_local_path. On read-only filesystem errors, re-home clone + state under /tmp (see db-state-split-orchestration-sop) and note the actual paths. Do not use /workspace as default."
      required    = true
    },
    {
      stage_id    = "discover-db-anchors"
      description = "Multi-cloud: parse state; apply grouping_policy_json; emit logical_group_seeds and db_anchor_inventory (stage id retained)"
      note        = "terraform-state-shard-extraction-sop §2–3 — anchors + tag/module clustering, **or** §7–8 when workflow inputs `grouping_strategy` / `max_resources_per_appstack` request connectivity-capped grouping. `read_notes` for those keys from workflow inputs."
      required    = true
    },
    {
      stage_id    = "allocate-related-resources"
      description = "Build dependency closures; write logical_group_manifest (mirror shard_manifest) and per-group counts"
      note        = "Shard-extraction §4–6 (policy mode) **or** §7–8 (connectivity / cap). Never place aws_* and azurerm_* in the same group. If `max_resources_per_appstack` is set, **no** `group_id` may list more than that many managed resource addresses after allocation — split oversized components per SOP."
      required    = true
    },
    {
      stage_id    = "count-reconcile-loop"
      description = "Verify aggregate_group_resource_count == monolith_resource_count; if not, iterate allocation"
      note        = "terraform-substate-convergence-sop § Count check. If false, increment convergence_iteration and return to discover-db-anchors (within iteration budget)."
      required    = true
    },
    {
      stage_id    = "reverse-engineer-and-registry-map"
      description = "Generate import/moved IaC per logical group; registry + StackGen type mapping; orphans_bundle"
      note        = "terraform-registry-reverse-iac-sop. Feeds AppStacks and orphan pipeline."
      required    = true
    },
    {
      stage_id    = "materialize-stackgen-appstacks"
      description = "Per logical group: create_appstack, add_resource_to_appstack (closed set from logical_group_manifest), verify membership (get_appstack_resources), connect_resources; env profile + Plan action run are OPTIONAL (only when stackgen_target_environment is supplied); stackgen_appstack_map + stackgen_appstack_membership_report"
      note        = "stackgen-appstack-mcp-playbook-sop — **one AppStack per `group_id`** in `logical_group_manifest`, with **mandatory** step 3.5 membership verification gate. Persist `stackgen_appstack_membership:<group_id>` per group and the roll-up `stackgen_appstack_membership_report` (required evidence). If operators used `max_resources_per_appstack`, each group should already be ≤ that size; do not merge or re-bucket groups in MCP. Env profile + Plan action runs are **optional** — skipped silently when `stackgen_target_environment` is unset or when the project env is missing (recorded in `stackgen_env_profile:<group_id>` / `stackgen_plan_run:<group_id>`); they do not block the membership gate. Skip the whole stage with note if StackGen MCP not attached."
      required    = true
    },
    {
      stage_id    = "orphans-secondary-pipeline"
      description = "Trigger orphan-iac-module-authoring with secondary_workflow_payload when orphans_bundle non-empty (may run in parallel with AppStack materialization)"
      note        = "db-state-split-orchestration-sop § Secondary Guild pipeline. Runs same DAG layer as materialize-stackgen-appstacks after reverse-engineer; use disjoint note keys vs MCP stage."
      required    = true
    },
    {
      stage_id    = "multi-shard-plan-convergence"
      description = "tofu plan each TF root + StackGen Plan action runs; loop until all empty (fan-in: waits for AppStack materialization and orphan-secondary stage)"
      note        = "terraform-substate-convergence-sop § Plan matrix + Loop B."
      required    = true
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
      stage_id     = "ingest-monolith"
      agent_ref    = sg_agent.db_state_split_architect.name
      runbook_refs = [sg_runbook_sop.db_state_split_orchestration.name]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "terraform-state-shard-extraction-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::ingest-monolith"], [])
      )
      note = <<-EOT
        Budget: ≤ 2 Ubuntu-CLI subagents, ≤ $2, ≤ 6m.
        0) First Ubuntu action: `mktemp -d` (or `mkdir -p`) under `/tmp`, verify write with `touch`, then `note` `repo_clone_path` / `monolith_state_local_path` under that tree. Avoid `/workspace` unless proven writable.
        1) read_notes; clone IAC to `repo_clone_path` if missing — if clone/update fails (read-only filesystem, permission denied), use a fresh directory under `/tmp` (e.g. `/tmp/db-state-split-<id>/repo`), then `note` the real `repo_clone_path`. If workflow inputs include `grouping_policy_json`, `note` it under key `grouping_policy_json`.
        2) Download state from `monolith_state_uri` → `monolith_state_local_path` (same `/tmp` tree if needed); compute `monolith_resource_count`.
        3) note `stage_summary:ingest-monolith`.
      EOT
    },
    {
      stage_id         = "discover-db-anchors"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["ingest-monolith"]
      runbook_refs     = [sg_runbook_sop.terraform_state_shard_extraction.name]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "terraform-state-shard-extraction-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::discover-db-anchors"], [])
      )
      note = <<-EOT
        **Stage entry:** `read_notes` for `monolith_state_local_path`, `repo_clone_path`, `monolith_resource_count`, optional `grouping_policy_json` / `grouping_strategy` / `max_resources_per_appstack`. Do not ask the operator — recover under `/tmp/db-state-split-<workflow_id>/` if a path is missing (see db-state-split-orchestration-sop **Stage entry protocol**).
        One Ubuntu-CLI subagent: apply grouping policy + multi-vendor seeds; write `logical_group_seeds` and `db_anchor_inventory`.
        Prefer **`ubuntu-cli_create_files`** + **`ubuntu-cli_execute_series`** for heavy `jq` (see terraform-state-shard-extraction-sop) instead of embedding long programs in **`create_agent`** goals.
        note `stage_summary:discover-db-anchors`.
      EOT
    },
    {
      stage_id         = "allocate-related-resources"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["discover-db-anchors"]
      runbook_refs     = [sg_runbook_sop.terraform_state_shard_extraction.name]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "terraform-state-shard-extraction-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::allocate-related-resources"], [])
      )
      note = <<-EOT
        **Stage entry:** `read_notes` for `logical_group_seeds`, `db_anchor_inventory`, `monolith_state_local_path`, `repo_clone_path`. Do not ask the operator.
        Build `logical_group_manifest` and mirror `shard_manifest`. Emit `per_group_resource_counts`. If shared ambiguity, document under `logical_group_manifest.notes`.
        note `stage_summary:allocate-related-resources`.
      EOT
    },
    {
      stage_id         = "count-reconcile-loop"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["allocate-related-resources"]
      runbook_refs = [
        sg_runbook_sop.db_state_split_orchestration.name,
        sg_runbook_sop.terraform_substate_convergence.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "terraform-substate-convergence-sop", "terraform-state-shard-extraction-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::count-reconcile-loop"], [])
      )
      note = <<-EOT
        Enforce count equality. If false, loop back (re-invoke allocation subagent) until `max_convergence_iterations` from module — read orchestration SOP Loop A.
        Verify **no duplicate addresses** across groups, no **unallocated** managed instances, and that **`data.*`** / **deposed** handling matches how `monolith_resource_count` was computed (terraform-state-shard-extraction-sop).
        note `count_reconciliation_ok` and `stage_summary:count-reconcile-loop`.
      EOT
    },
    {
      stage_id         = "reverse-engineer-and-registry-map"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["count-reconcile-loop"]
      runbook_refs = [
        sg_runbook_sop.terraform_registry_reverse_iac.name,
        sg_runbook_sop.db_state_split_orchestration.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "terraform-registry-reverse-iac-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::reverse-engineer-and-registry-map"], [])
      )
      note = <<-EOT
        **Stage entry (do not ask the operator):**
          - `read_notes` for `repo_clone_path`, `monolith_state_local_path`, `logical_group_manifest` (or legacy `shard_manifest`), `count_reconciliation_ok`, optional `grouping_strategy` / `max_resources_per_appstack`.
          - If a required key is missing, **recover** before asking: rebuild paths under `/tmp/db-state-split-<workflow_id>/` and re-run the upstream procedure (re-clone repo, re-download `monolith_state_uri` to the same `/tmp` path, re-run shard extraction from `terraform-state-shard-extraction-sop`). Only `notify` after recovery fails — see db-state-split-orchestration-sop **Stage entry protocol**.
          - StackGen MCP availability is **discoverable** via `search_tools` (`*_create_appstack` / `*_get_appstacks`); this stage is **TF roots + import/moved + registry mapping + HCL hydration** — AppStack materialization happens in the next stage `materialize-stackgen-appstacks`. Do not ask the operator whether MCP is attached.
        Materialize `groups/<group_id>/` TF roots + import strategy; emit `registry_mapping_report` and `orphans_bundle`.
        **HCL hydration is part of THIS stage** (not a downstream human task). For each group, after writing `import {}` blocks, run `tofu init -input=false` then `tofu plan -generate-config-out=generated.tf -input=false -lock=false` (Pass 1) and `tofu plan -out=verify.tfplan -input=false -lock=false` (Pass 2). Persist `hcl_hydration_status:<group_id>={generated_tf_path,generated_resources,plan_no_changes,remaining_actions,attempt}`. Loop in-stage until `plan_no_changes=true` or surface failed addresses to `orphans_bundle{reason:"import_failed_*"}`. **Never** leave empty-body `resource "aws_X" "Y" {}` stubs and **never** emit owner "HCL AUTHOR" — see terraform-registry-reverse-iac-sop § *HCL hydration*.
        Use writable `/tmp/...` and chunked `terraform show` / shell steps per terraform-registry-reverse-iac-sop **Execution** section.
        note `stage_summary:reverse-engineer-and-registry-map` (include per-group `plan_no_changes` counts and orphan additions).
      EOT
    },
    {
      stage_id         = "materialize-stackgen-appstacks"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["reverse-engineer-and-registry-map"]
      runbook_refs = [
        sg_runbook_sop.stackgen_appstack_mcp_playbook.name,
        sg_runbook_sop.db_state_split_orchestration.name,
      ]
      skill_refs = concat(
        ["stackgen-appstack-mcp-playbook-sop", "db-state-split-orchestration-sop", "terraform-registry-reverse-iac-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::materialize-stackgen-appstacks"], [])
      )
      note = <<-EOT
        **Stage entry:** `read_notes` for `logical_group_manifest`, `repo_clone_path`, `reverse_iac_summary`, `registry_mapping_report`, `orphans_bundle`, optional `stackgen_project_name`, optional `stackgen_target_environment`, optional `stackgen_environments_required`. Detect StackGen MCP via `search_tools` for `*_create_appstack` / `*_get_appstacks`. Resolve project UUID by calling `me` when `stackgen_project_name` is absent. Do not ask the operator.
        If StackGen MCP is attached: for **each** `group_id` in `logical_group_manifest`, run the **state → AppStack** flow from **`stackgen-appstack-mcp-playbook-sop`** in this exact order:
          1) `create_appstack` (record `stackgen_appstack_map[group_id]` immediately).
          2) Build `identifier_for_address:<group_id>` from `group.resource_addresses` (deterministic snake_case sanitizer; resources without a mapped `resource_type` go to `orphans_bundle` — never silently dropped).
          3) `add_resource_to_appstack` for every address in the group (closed set — never anything outside it).
          3.5) **MANDATORY membership verification gate.** Call `get_appstack_resources(appstack_id)` once and write `stackgen_appstack_membership:<group_id>` JSON with `expected_identifiers`, `actual_identifiers`, `missing`, `unexpected`, `cross_group_bleed`, `ok`. Reconcile (re-add missing, delete unexpected non-bleed entries) until `ok=true`. Cross-group bleed → log to `stackgen_mcp_errors` and escalate; do not auto-fix by deleting from another group's stack.
          4) `connect_resources` (within the same `appstack_id` only).
          5) **Env profile is OPTIONAL** (project envs cannot be created via MCP). If `stackgen_target_environment` is unset → skip and `note` `stackgen_env_profile:<group_id>={skipped:"no_target_env_input"}`. If set, `get_env_profiles` then `create_env_profile` / `update_env_profile`. On `environment '<env>' not found in project settings` (or any 4xx tied to env existence) → soft-fail: append `stackgen_mcp_errors{reason:"env_not_in_project_settings"}` and `note stackgen_env_profile:<group_id>={skipped:"env_missing_in_project_settings", env}`. Only escalate via a single `notify` when `stackgen_environments_required="true"`; never block other groups.
          6) **StackGen Plan is OPTIONAL.** Skip when step 5 was skipped/soft-failed → `note stackgen_plan_run:<group_id>={skipped:"no_env_profile"}` and rely on Ubuntu `tofu plan` for parity. Otherwise `create_appstack_action_run` (Plan) and capture `get_action_run_logs`.
        After all groups, write **`stackgen_appstack_membership_report`** roll-up JSON (groups_total / groups_ok / groups_failed + per_group). The stage is **not complete** while any group is `ok=false` — but a **soft-failed env / Plan does not** make a group `ok=false`; membership is the gate, env/Plan is bonus evidence.
        This stage may run **concurrently** with `orphans-secondary-pipeline` — use only reverse/registry notes; do not rely on orphan-stage outputs. Prefer disjoint `note` keys from the orphan branch (`secondary_workflow_payload`, `stage_summary:orphans-secondary-pipeline`).
        MCP efficiency (from production DAGs): one `get_appstacks` pass per wave → `note` `stackgen_appstack_list_cache`; call `get_appstack_resources` once per `appstack_id` per reconcile pass — not before every `add_resource_to_appstack`.
        Do **not** re-bucket by Terraform type at MCP time (e.g. "all aws_iam_*" into one stack) — `logical_group_manifest` is authoritative.
        If MCP not attached: `note` stackgen_appstack_map=`skipped: no_mcp` and stackgen_appstack_membership_report=`skipped: no_mcp`.
        Optional workflow input `cloud_discovery_id` is a **correlation id** only — the default StackGen **user** MCP does not expose discovery-import tools; do not plan on `create_appstack_from_discovered_resources` unless a **different** MCP integration documents it.
        note `stage_summary:materialize-stackgen-appstacks` (include groups_ok / groups_failed and counts of env/Plan skips).
      EOT
    },
    {
      stage_id         = "orphans-secondary-pipeline"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["reverse-engineer-and-registry-map"]
      runbook_refs = [
        sg_runbook_sop.db_state_split_orchestration.name,
        sg_runbook_sop.orphan_iac_module_bootstrap.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "orphan-iac-module-bootstrap-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::orphans-secondary-pipeline"], [])
      )
      note = <<-EOT
        **Stage entry:** `read_notes` for `orphans_bundle`, `logical_group_manifest`, `iac_repository_url`. Do not ask the operator.
        Same DAG layer as `materialize-stackgen-appstacks` — do not assume AppStacks already exist; read only reverse/registry notes (`orphans_bundle`, `logical_group_manifest`).
        If `orphans_bundle` empty → note skip. Else build `secondary_workflow_payload` and start workflow **orphan-iac-module-authoring** (same org) or notify operators with JSON.
        note `stage_summary:orphans-secondary-pipeline`.
      EOT
    },
    {
      stage_id         = "multi-shard-plan-convergence"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["materialize-stackgen-appstacks", "orphans-secondary-pipeline"]
      runbook_refs = [
        sg_runbook_sop.terraform_substate_convergence.name,
        sg_runbook_sop.db_state_split_orchestration.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "terraform-substate-convergence-sop", "terraform-registry-reverse-iac-sop", "stackgen-appstack-mcp-playbook-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::multi-shard-plan-convergence"], [])
      )
      note = <<-EOT
        **Stage entry:** `read_notes` for `logical_group_manifest`, `repo_clone_path`, `hcl_hydration_status:<group_id>` (per group), `stackgen_appstack_map`, `stackgen_appstack_membership:<group_id>` (per group), `stackgen_env_profile:<group_id>` (per group), `stackgen_plan_run:<group_id>` (per group). Do not ask the operator.
        **HCL hydration pre-check first** (Loop B-hcl). For every `group_id`, `hcl_hydration_status:<group_id>.plan_no_changes` must be `true`. If any group is `false` or missing, **return execution to `reverse-engineer-and-registry-map`** for that group's hydration sub-loop; **do not** raise an operator-facing 🔴 "HCL AUTHOR" item — the workflow owns HCL via `tofu plan -generate-config-out=` (terraform-registry-reverse-iac-sop § *HCL hydration*).
        **Membership pre-check second** (Loop B-membership). For every `group_id`, read `stackgen_appstack_membership:<group_id>` and confirm `ok=true`, `expected_count==actual_count`, and `cross_group_bleed==[]`. Any failure → re-enter **stackgen-appstack-mcp-playbook-sop** step 3.5 for that group.
        Run TF plan matrix per `logical_group_manifest`. **StackGen Plan is OPTIONAL:** for groups whose `stackgen_env_profile:<group_id>` is `{skipped:...}` or `stackgen_plan_run:<group_id>` is already `{skipped:...}`, skip `create_appstack_action_run` and rely on Ubuntu `tofu plan` parity. For the rest (membership ok and env profile present), run **`create_appstack_action_run`** (Plan) per AppStack and collect **`get_action_run`** / **`get_action_run_logs`**. If any drift, Loop B then re-plan until pass or iteration cap. Treat any new `env_not_in_project_settings` here as a soft skip (same semantics as the materialization stage).
        One shard (or small batch) per Ubuntu command with bounded `timeout_seconds`; avoid one shell invocation that plans all shards sequentially past integration ceilings (~300s). Prefer remote runner fan-out when configured.
        Set `multi_plan_zero_diff_ok` based on **all per-group TF roots** plus **only the StackGen Plans that actually ran** (skipped Plans do not block the gate). note `stage_summary:multi-shard-plan-convergence` with skip counts and a *per-iteration blocking-items report* using db-state-split-orchestration-sop § *Iteration report — blocker classification* (env-missing → 🟢 INFO; empty-body stubs → 🟡 self-fixable, never 🔴).
      EOT
    },
    {
      stage_id         = "final-gate-and-memory"
      agent_ref        = sg_agent.db_state_split_architect.name
      stage_depends_on = ["multi-shard-plan-convergence"]
      runbook_refs = [
        sg_runbook_sop.db_state_split_orchestration.name,
        sg_runbook_sop.orphan_iac_module_bootstrap.name,
      ]
      skill_refs = concat(
        ["db-state-split-orchestration-sop", "orphan-iac-module-bootstrap-sop"],
        try(var.workflow_skill_refs["db-monorepo-state-split-convergence::final-gate-and-memory"], [])
      )
      note = <<-EOT
        **Stage entry:** `read_notes` for `count_reconciliation_ok`, `multi_plan_zero_diff_ok`, `hcl_hydration_status:<group_id>` (per group), `stackgen_appstack_membership_report`, `stackgen_env_profile:<group_id>` / `stackgen_plan_run:<group_id>` (per group), `orphan_modularization_memory`, all `stage_summary:*`. Do not ask the operator for any of these — the upstream stages already wrote them.
        Verify `count_reconciliation_ok`, `multi_plan_zero_diff_ok`, **all `hcl_hydration_status:<group_id>.plan_no_changes==true`**, and **`stackgen_appstack_membership_report.summary.groups_failed == 0`** (when StackGen MCP was used). Env-profile / StackGen-Plan skips are **not** failures.
        Final `notify` / PR comment with tables (per-group expected vs actual counts, hydration outcome, missing/unexpected highlights) + PR links. Apply db-state-split-orchestration-sop § *Iteration report — blocker classification* to any remaining items: env-missing → 🟢 INFO ("optional — operator may register the env in StackGen Project Settings to also see StackGen-side Plan logs"); never emit 🔴 ADMIN for the env unless `stackgen_environments_required="true"` AND `stackgen_target_environment` was supplied. Never emit owner "HCL AUTHOR".
        note `stage_summary:final-gate-and-memory`.
      EOT
    },
  ]
}

# =============================================================================
# Secondary workflow — orphan resources → new module + memory
# =============================================================================

resource "sg_workflow" "orphan_iac_module_authoring" {
  name        = "orphan-iac-module-authoring"
  domain      = "infrastructure-as-code"
  description = <<-EOT
    Guild pipeline that materializes Terraform modules from orphan resource bundles produced by
    db-monorepo-state-split-convergence, validates them, and records modularization memory for reuse.
  EOT
  approve     = true

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
      note = "Ubuntu CLI subagent: scaffold under a writable `/tmp/...` tree if needed; run fmt/init/validate/plan in bounded steps (see orphan-iac-module-bootstrap-sop); persist paths via notes."
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

  name        = "github-db-state-split-receiver"
  target_type = "workflow"
  target_name = sg_workflow.db_monorepo_state_split_convergence.name
  action      = "GitHub issue or PR about splitting monorepo Terraform state into logical groups and StackGen AppStacks (multi-cloud); triage and run db-monorepo-state-split-convergence with repository_url and state URI from the body."
  enabled     = true
}
