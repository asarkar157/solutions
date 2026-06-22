terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

locals {
  module_prefix = "spec-symphony"
  suffix        = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name                         = "spec-symphony-orchestrator${local.suffix}"
  workflow_name                      = "spec-driven-feature${local.suffix}"
  github_webhook_name                = "${local.module_prefix}-github-receiver${local.suffix}"
  linear_webhook_name                = "${local.module_prefix}-linear-receiver${local.suffix}"
  linear_product_spec_webhook_name   = "${local.module_prefix}-linear-product-spec${local.suffix}"
  linear_spec_implement_webhook_name = "${local.module_prefix}-linear-spec-implement${local.suffix}"

  linear_product_spec_workflow_name   = "linear-product-spec${local.suffix}"
  linear_spec_implement_workflow_name = "linear-spec-implement${local.suffix}"

  sop_linear_product_spec_name   = "${local.module_prefix}-linear-product-spec-sop${local.suffix}"
  sop_linear_spec_implement_name = "${local.module_prefix}-linear-spec-implement-sop${local.suffix}"

  linear_integration_name    = trimspace(var.existing_linear_integration_name)
  linear_mcp_enabled         = local.linear_integration_name != ""
  create_linear_product_spec = var.enable_linear_product_spec_workflow && local.linear_mcp_enabled
  create_linear_implement    = var.enable_linear_implement_workflow && local.linear_mcp_enabled

  linear_tool_save_comment  = "${local.linear_integration_name}_save_comment"
  linear_tool_list_comments = "${local.linear_integration_name}_list_comments"

  golden_product_spec_body = file("${path.module}/templates/sdd-kit-starter/golden-product-spec.md")

  linear_product_spec_sop_body = trimspace(templatefile("${path.module}/templates/linear-product-spec-sop.md.tftpl", {
    linear_product_spec_label = var.linear_product_spec_label
    linear_implement_label    = var.linear_implement_label
    golden_product_spec_body  = local.golden_product_spec_body
    linear_tool_save_comment  = local.linear_tool_save_comment
  }))

  linear_spec_implement_sop_body = trimspace(templatefile("${path.module}/templates/linear-spec-implement-sop.md.tftpl", {
    linear_implement_label    = var.linear_implement_label
    linear_implement_engine   = var.linear_implement_engine
    linear_tool_list_comments = local.linear_tool_list_comments
  }))

  linear_stage_note_vars = {
    linear_product_spec_label    = var.linear_product_spec_label
    linear_implement_label       = var.linear_implement_label
    linear_tool_save_comment     = local.linear_tool_save_comment
    sop_linear_product_spec_name = local.sop_linear_product_spec_name
    shell_tool_prefix            = local.shell_tool_prefix
  }

  linear_intake_stage_note                 = trimspace(templatefile("${path.module}/templates/stage-notes/linear-intake.md.tftpl", local.linear_stage_note_vars))
  author_product_spec_stage_note           = trimspace(templatefile("${path.module}/templates/stage-notes/author-product-spec.md.tftpl", local.linear_stage_note_vars))
  decompose_subgoals_stage_note            = trimspace(templatefile("${path.module}/templates/stage-notes/decompose-subgoals.md.tftpl", local.linear_stage_note_vars))
  post_linear_spec_comment_stage_note      = trimspace(templatefile("${path.module}/templates/stage-notes/post-linear-spec-comment.md.tftpl", local.linear_stage_note_vars))
  fetch_spec_context_stage_note            = trimspace(templatefile("${path.module}/templates/stage-notes/fetch-spec-context.md.tftpl", merge(local.linear_stage_note_vars, { linear_tool_list_comments = local.linear_tool_list_comments })))
  materialize_spec_stage_note              = trimspace(templatefile("${path.module}/templates/stage-notes/materialize-spec.md.tftpl", local.linear_stage_note_vars))
  post_linear_implement_comment_stage_note = trimspace(templatefile("${path.module}/templates/stage-notes/post-linear-implement-comment.md.tftpl", local.linear_stage_note_vars))
  linear_intake_clone_bootstrap_stage_note = trimspace(templatefile("${path.module}/templates/stage-notes/intake-clone-bootstrap-linear.md.tftpl", merge(local.stage_note_vars, {
    sop_orchestration_name = local.sop_orchestration_name
  })))

  needs_cursor_on_runner = var.implement_engine == "cursor_cli" || (local.create_linear_implement && var.linear_implement_engine == "cursor_cli")

  legacy_linear_webhook_trigger_url = (
    var.enable_legacy_linear_factory_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.linear_receiver.token) != ""
    ) ? format(
    "%s?apiKey=%s%s",
    local.stackgen_webhook_trigger_url,
    urlencode(sg_webhook.linear_receiver.token),
    local.stackgen_webhook_org_query
  ) : null

  linear_product_spec_webhook_trigger_url = (
    local.create_linear_product_spec
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.linear_product_spec_receiver[0].token) != ""
    ) ? format(
    "%s?apiKey=%s%s",
    local.stackgen_webhook_trigger_url,
    urlencode(sg_webhook.linear_product_spec_receiver[0].token),
    local.stackgen_webhook_org_query
  ) : null

  linear_spec_implement_webhook_trigger_url = (
    local.create_linear_implement
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.linear_spec_implement_receiver[0].token) != ""
    ) ? format(
    "%s?apiKey=%s%s",
    local.stackgen_webhook_trigger_url,
    urlencode(sg_webhook.linear_spec_implement_receiver[0].token),
    local.stackgen_webhook_org_query
  ) : null

  sop_orchestration_name    = "${local.module_prefix}-orchestration-sop${local.suffix}"
  sop_github_content_change = "${local.module_prefix}-github-content-change-sop${local.suffix}"
  sop_workflow_script_pack  = "${local.module_prefix}-workflow-script-pack${local.suffix}"

  default_remote_runner_name  = "${local.module_prefix}-runner${local.suffix}"
  resolved_remote_runner_name = trimspace(var.remote_runner_name) != "" ? trimspace(var.remote_runner_name) : local.default_remote_runner_name

  shell_work_home   = trimspace(var.runner_work_home) != "" ? trimspace(var.runner_work_home) : "/home/runner"
  shell_tool_prefix = local.resolved_remote_runner_name

  stackgen_webhook_api_origin  = trimsuffix(trimspace(var.webhook_trigger_base_url), "/")
  stackgen_webhook_trigger_url = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${local.stackgen_webhook_api_origin}/guild/api/v1/webhooks/trigger"
  stackgen_webhook_org_query   = trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))

  script_pack_version = "20260617.1"
  home_brace_literal  = join("", ["$", "{HOME}"])
  clone_execute_series_body = templatefile(
    "${path.module}/templates/clone-execute-series-embedded.sh.tftpl",
    {
      shell_work_home     = local.shell_work_home
      script_pack_version = local.script_pack_version
      home_brace_literal  = local.home_brace_literal
    },
  )
  clone_execute_series_b64       = base64encode(local.clone_execute_series_body)
  clone_execute_series_one_liner = "printf '%s' '${local.clone_execute_series_b64}' | base64 -d | /bin/bash"
  specsym_pack_dir               = "${local.shell_work_home}/.spec-symphony/pack/${local.script_pack_version}"

  stage_runner_script       = trimspace(file("${path.module}/scripts/stage-runner.sh"))
  clone_pack_script         = trimspace(file("${path.module}/scripts/clone-pack.sh"))
  script_pack_runner_sha256 = sha256(local.stage_runner_script)
  script_pack_clone_sha256  = sha256(local.clone_pack_script)
  specsym_pack_ensure_shell = local.specsym_pack_ensure_shell_body

  workflow_script_pack_body = trimspace(templatefile("${path.module}/templates/workflow-script-pack.md.tftpl", {
    shell_tool_prefix   = local.shell_tool_prefix
    shell_work_home     = local.shell_work_home
    script_pack_version = local.script_pack_version
    specsym_pack_dir    = local.specsym_pack_dir
  }))

  orchestration_sop_body = trimspace(templatefile("${path.module}/templates/spec-symphony-orchestration-sop.md.tftpl", {
    sdd_framework          = var.sdd_framework
    change_type            = var.change_type
    shell_tool_prefix      = local.shell_tool_prefix
    remote_runner_name     = local.resolved_remote_runner_name
    shell_work_home        = local.shell_work_home
    specsym_pack_dir       = local.specsym_pack_dir
    script_pack_version    = local.script_pack_version
    quality_max_iterations = var.quality_max_iterations
    sop_orchestration_name = local.sop_orchestration_name
  }))

  evidence_checklist_name = "${local.module_prefix}-feature-evidence${local.suffix}"

  stage_note_vars = {
    sdd_framework = var.sdd_framework
    change_type   = var.change_type
  }

  intake_clone_bootstrap_stage_note = trimspace(templatefile("${path.module}/templates/stage-notes/intake-clone-bootstrap.md.tftpl", merge(local.stage_note_vars, {
    sop_orchestration_name = local.sop_orchestration_name
  })))
  repo_sdd_bootstrap_stage_note = trimspace(templatefile("${path.module}/templates/stage-notes/repo-sdd-bootstrap.md.tftpl", local.stage_note_vars))
  author_spec_stage_note        = trimspace(templatefile("${path.module}/templates/stage-notes/author-spec.md.tftpl", local.stage_note_vars))
  implement_stage_note          = trimspace(templatefile("${path.module}/templates/stage-notes/implement.md.tftpl", local.stage_note_vars))
  validate_and_test_stage_note  = trimspace(templatefile("${path.module}/templates/stage-notes/validate-and-test.md.tftpl", local.stage_note_vars))
  create_pr_stage_note          = trimspace(templatefile("${path.module}/templates/stage-notes/create-pr.md.tftpl", local.stage_note_vars))
  update_tracker_stage_note     = trimspace(templatefile("${path.module}/templates/stage-notes/update-tracker.md.tftpl", local.stage_note_vars))

  persona = templatefile("${path.module}/personas/spec-symphony-orchestrator.md.tftpl", {
    runner_name      = local.resolved_remote_runner_name
    specsym_pack_dir = local.specsym_pack_dir
    sdd_framework    = var.sdd_framework
    change_type      = var.change_type
  })

  power_pack_skill = {
    for stage_id, skill in var.power_pack_refs :
    stage_id => [skill]
  }

  create_runner_git_env_secret = trimspace(var.github_token) != ""
  runner_github_secret_id      = local.create_runner_git_env_secret ? sg_secret.runner_git_env[0].id : trimspace(var.github_secret_id)

  create_runner_cursor_env_secret = local.needs_cursor_on_runner && trimspace(var.cursor_api_key) != ""
  runner_cursor_secret_id         = local.create_runner_cursor_env_secret ? sg_secret.runner_cursor_env[0].id : trimspace(var.cursor_secret_id)

  integration_auto_approve_tool_patterns = compact([
    "${local.shell_tool_prefix}_*",
    local.linear_mcp_enabled && var.auto_approve_linear_tools ? "${local.linear_integration_name}_*" : "",
  ])
}

check "github_credentials" {
  assert {
    condition     = trimspace(var.github_token) != "" || trimspace(var.github_secret_id) != ""
    error_message = "Provide github_token or github_secret_id for runner git/gh auth."
  }
  assert {
    condition     = !(trimspace(var.github_token) != "" && trimspace(var.github_secret_id) != "")
    error_message = "Provide exactly one of github_token or github_secret_id."
  }
}

check "cursor_credentials" {
  assert {
    condition     = !local.needs_cursor_on_runner || trimspace(var.cursor_api_key) != "" || trimspace(var.cursor_secret_id) != ""
    error_message = "cursor_cli (spec-driven-feature or linear-spec-implement) requires cursor_api_key or cursor_secret_id for runner CURSOR_API_KEY sync."
  }
  assert {
    condition     = !(trimspace(var.cursor_api_key) != "" && trimspace(var.cursor_secret_id) != "")
    error_message = "Provide exactly one of cursor_api_key or cursor_secret_id."
  }
}

check "linear_workflows" {
  assert {
    condition     = (!var.enable_linear_product_spec_workflow && !var.enable_linear_implement_workflow) || local.linear_mcp_enabled
    error_message = "Linear workflows require existing_linear_integration_name (aios-integration-linear)."
  }
}

resource "sg_secret" "runner_git_env" {
  count = local.create_runner_git_env_secret ? 1 : 0

  name        = "${local.module_prefix}-runner-git-env${local.suffix}"
  description = "Git credentials for ${local.resolved_remote_runner_name}."
  category    = "Provider"
  subcategory = "github"
  metadata = {
    token        = var.github_token
    GIT_TOKEN    = var.github_token
    GIT_HOST     = "github.com"
    GIT_USERNAME = "x-access-token"
    GH_TOKEN     = var.github_token
    GITHUB_TOKEN = var.github_token
  }
}

resource "sg_secret" "runner_cursor_env" {
  count = local.create_runner_cursor_env_secret ? 1 : 0

  name        = "${local.module_prefix}-runner-cursor-env${local.suffix}"
  description = "Cursor API key for ${local.resolved_remote_runner_name} (implement_engine=cursor_cli)."
  category    = "Other"
  subcategory = "cursor"
  metadata = {
    CURSOR_API_KEY = var.cursor_api_key
  }
}

module "remote_runner" {
  count  = var.create_remote_runner ? 1 : 0
  source = "../aios-remote-runner"

  create_runner = true
  name          = local.resolved_remote_runner_name
  description   = trimspace(var.remote_runner_description) != "" ? trimspace(var.remote_runner_description) : "Remote runner for ${local.agent_name} (spec-symphony SDD factory)."
  labels        = var.remote_runner_labels

  typed_secret_refs = {
    github = local.runner_github_secret_id
  }
  generic_secret_ref_ids = compact(concat(
    local.runner_generic_secret_ref_ids,
    trimspace(local.runner_cursor_secret_id) != "" ? [local.runner_cursor_secret_id] : [],
  ))
  bind_runner_secrets           = true
  secrets_sync_interval_seconds = var.remote_runner_secrets_sync_interval_seconds
}

resource "sg_agent" "spec_symphony_orchestrator" {
  name        = local.agent_name
  persona     = local.persona
  model_names = compact(var.model_names)

  remote_runners = var.create_remote_runner && var.remote_runner_attach_to_agent ? toset([module.remote_runner[0].runner_name]) : null

  integrations = compact([
    trimspace(var.existing_linear_integration_name) != "" ? var.existing_linear_integration_name : null,
  ])

  auto_approve_tools = var.auto_approve_integration_tools ? [
    for pattern in local.integration_auto_approve_tool_patterns : {
      tool = pattern
    }
  ] : []
}

resource "sg_agent_budget" "spec_symphony_orchestrator" {
  agent_name  = sg_agent.spec_symphony_orchestrator.name
  limit_usd   = 15
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "spec_symphony_dangerous_ops" {
  agent_name = sg_agent.spec_symphony_orchestrator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "spec_symphony_spec_traceability" {
  count = try(var.policy_create_flags.spec_traceability, true) ? 1 : 0

  agent_name = sg_agent.spec_symphony_orchestrator.name
  policy_id  = var.policy_ids.spec_traceability
  enabled    = true
}

resource "sg_runbook_sop" "orchestration" {
  name        = local.sop_orchestration_name
  approve     = true
  description = local.orchestration_sop_body
}

resource "sg_runbook_sop" "workflow_script_pack" {
  name        = local.sop_workflow_script_pack
  approve     = true
  description = local.workflow_script_pack_body
}

resource "sg_runbook_sop" "github_content_change" {
  name        = local.sop_github_content_change
  approve     = true
  description = <<-EOT
    GitHub PR and issue comment patterns for spec-symphony.
    PR body must link specs/ or openspec/changes/ folder.
    Use gh pr create and gh issue comment on the remote runner.
  EOT
}

resource "sg_evidence_checklist" "spec_driven_feature_evidence" {
  name        = local.evidence_checklist_name
  description = "Proof-of-work for spec-driven-feature: clone, SDD bootstrap, implement, validate, PR, CI status."
  approve     = true
  required_items = [
    "trigger_payload_recorded",
    "repo_clone_materialized",
    "sdd_framework_documented",
    "spec_linkage_recorded",
    "spec_artifacts_committed",
    "constitution_present",
    "validation_summary_recorded",
    "quality_checks_pass_or_blocked",
    "pr_url_or_blocker_documented",
    "ci_status_recorded",
  ]
  optional_items = [
    "archive_specs_evidence",
    "tracker_update_evidence",
  ]
  scoring = {
    min_required         = 8
    confidence_threshold = 0.75
  }
  metadata = {
    playbook = "spec-driven-feature"
  }
}

resource "sg_workflow" "spec_driven_feature" {
  name        = local.workflow_name
  domain      = "software-engineering"
  description = <<-EOT
    Spec-driven feature factory (lean): intake → bootstrap → author-spec → implement → validate → evidence gate → create-pr → update-tracker.
    Remote runner only. Spec Kit / OpenSpec via sdd_framework. implement_engine=${var.implement_engine}.
  EOT
  approve     = true

  metadata = {
    planner_max_tool_iterations       = "40"
    terminal_calling_halguard_mode    = "paste_only_minimal_planner"
    halguard_skip_subagent_task_types = "terminal_calling"
    binding_schema_version            = "20260616.8-enforcement"
  }

  evidence_checklist_ref = sg_evidence_checklist.spec_driven_feature_evidence.name

  triggers = [
    { field = "event_type", values = ["issue.created", "issue.reopened", "pull_request.opened"], type = "active", source = "github" }
  ]

  runbook_refs = [
    sg_runbook_sop.orchestration.name,
    sg_runbook_sop.workflow_script_pack.name,
    sg_runbook_sop.github_content_change.name,
  ]

  required_inputs = ["repository_url", "issue_or_pr_number"]
  optional_inputs = ["requested_change", "sdd_framework", "change_type"]

  example_queries = [
    "Linear issue CORE-101: implement feature per OpenSpec change proposal",
    "GitHub issue #42 on a TypeScript service: bootstrap Spec Kit and open PR with spec linkage",
  ]

  stages = [
    { stage_id = "intake-clone-bootstrap", description = "Parse webhook, clone repo", required = true },
    { stage_id = "intake-blocked-gate", description = "Skip to create-pr on clone failure", required = false },
    { stage_id = "repo-sdd-bootstrap", description = "Initialize SDD framework + SDD Kit starter", required = true },
    { stage_id = "author-spec", description = "Author spec/plan/tasks from thin ticket", required = true },
    { stage_id = "author-blocked-gate", description = "Skip to create-pr when spec authoring fails", required = false },
    { stage_id = "implement", description = "Implement per spec/tasks", required = true },
    { stage_id = "implement-blocked-gate", description = "Skip to create-pr on plan-only implement", required = false },
    { stage_id = "validate-and-test", description = "Local validate + CI poll", required = true },
    { stage_id = "validate-loop-gate", description = "Loop to implement on NEEDS_REVISION", required = false },
    { stage_id = "spec-evidence-gate", description = "Verify spec linkage evidence before PR", required = false },
    { stage_id = "create-pr", description = "Commit, push, open PR", required = true },
    { stage_id = "update-tracker", description = "OpenSpec archive + tracker update", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "intake-clone-bootstrap"
      agent_ref    = sg_agent.spec_symphony_orchestrator.name
      runbook_refs = [sg_runbook_sop.orchestration.name]
      skill_refs = concat(
        [local.sop_orchestration_name],
        try(var.workflow_skill_refs["spec-driven-feature::intake-clone-bootstrap"], []),
        try(local.power_pack_skill["intake-clone-bootstrap"], []),
      )
      spawn_contracts = local.spawn_contracts_intake_clone
      note            = local.intake_clone_bootstrap_stage_note
    },
    {
      stage_id         = "intake-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["intake-clone-bootstrap"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)stage_summary:intake-clone-bootstrap[=:\"\\s]+blocked:|\"notes\":\\{\\}|context canceled|adaptive loop interrupted|remote runner (offline|unavailable)|runner_unavailable|clone_blocker=(auth|auth_or_network|network|branch|placeholder_url|runner_unavailable|missing_clone_params|malformed_work_root)|specsym_pack_error=|script_pack_error=|shell_runner_incompatible|base64: invalid input|clone-pack\\.sh: not found|does not allow spawning approved sub-agents|repo_clone_path=$|repo_clone_path=.*/\\}|repo_clone_path=.*//home/runner"
        skip_to   = "create-pr"
        reason    = "Clone/auth/runner failed at intake — skip implement/validate; create-pr posts blocker comment"
      }
    },
    {
      stage_id         = "repo-sdd-bootstrap"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["intake-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.orchestration.name]
      skill_refs = concat(
        [local.sop_orchestration_name],
        try(var.workflow_skill_refs["spec-driven-feature::repo-sdd-bootstrap"], []),
        try(local.power_pack_skill["repo-sdd-bootstrap"], []),
      )
      spawn_contracts = local.spawn_contracts_repo_bootstrap
      note            = local.repo_sdd_bootstrap_stage_note
    },
    {
      stage_id         = "author-spec"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["repo-sdd-bootstrap"]
      runbook_refs     = [sg_runbook_sop.orchestration.name]
      skill_refs = concat(
        [local.sop_orchestration_name],
        try(var.workflow_skill_refs["spec-driven-feature::author-spec"], []),
        try(local.power_pack_skill["author-spec"], []),
      )
      spawn_contracts = concat(
        var.implement_engine != "cursor_cli" ? local.spawn_contracts_author_spec : [],
        var.implement_engine == "cursor_cli" ? local.spawn_contracts_author_spec_cursor : [],
      )
      note = local.author_spec_stage_note
    },
    {
      stage_id         = "author-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["author-spec"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)author_spec_blocker=|author_spec_status=blocked|spec_tasks_path=$|missing_spec_artifacts|stage_summary:author-spec[=:\"\\s]+blocked:"
        skip_to   = "create-pr"
        reason    = "Spec authoring failed or tasks.md missing — skip implement/validate; create-pr posts blocker comment"
      }
    },
    {
      stage_id         = "implement"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["author-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.orchestration.name]
      skill_refs = concat(
        [local.sop_orchestration_name],
        try(var.workflow_skill_refs["spec-driven-feature::implement"], []),
        try(local.power_pack_skill["implement"], []),
      )
      spawn_contracts = concat(
        var.implement_engine != "cursor_cli" ? local.spawn_contracts_implement : [],
        var.implement_engine == "cursor_cli" ? local.spawn_contracts_implement_cursor : [],
      )
      note = local.implement_stage_note
    },
    {
      stage_id         = "implement-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["implement"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)implement_blocker=|implement_plan_only|implement_edit_verified=(false|missing)|missing implement markers|author_spec_blocker=|spec_tasks_path=$|specs/[^\\s]+ missing|openspec/changes/[^\\s]+ missing|stage_summary:implement[=:\"\\s]+blocked:|does not allow spawning approved sub-agents|no tool access in this interface|tool registry|### Phase [1-4]: (ANALYZE|PLAN|EXECUTE|SYNTHESIZE)|Repository Path Issue|extraneous characters|malformed_work_root|repo_clone_path=.*/\\}|repo_clone_path=.*//home/runner|repo_clone_path=$|\"notes\":\\{\\}"
        skip_to   = "create-pr"
        reason    = "Implement blocked or plan-only — skip validate loop; create-pr posts blocker comment"
      }
    },
    {
      stage_id         = "validate-and-test"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["implement-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.orchestration.name]
      skill_refs = concat(
        [local.sop_orchestration_name],
        try(var.workflow_skill_refs["spec-driven-feature::validate-and-test"], []),
        try(local.power_pack_skill["validate-and-test"], []),
      )
      spawn_contracts = local.spawn_contracts_validate
      note            = local.validate_and_test_stage_note
    },
    {
      stage_id         = "validate-loop-gate"
      action_type      = "loop_stage"
      stage_depends_on = ["validate-and-test"]
      action_config = {
        loop_to        = "implement"
        max_iterations = var.quality_max_iterations
        exit_condition = "output_matches_regex"
        exit_match     = "(?m)module_quality_summary[=:][^\\n]{0,32}(PASS|BLOCKED)"
      }
    },
    {
      stage_id         = "spec-evidence-gate"
      action_type      = "evidence_gate"
      stage_depends_on = ["validate-loop-gate"]
      action_config = {
        confirmation_items = jsonencode([
          "spec_linkage_recorded is documented in workflow notes or validate stdout",
          "spec_artifacts_committed: specs/ or openspec/changes/ paths are referenced",
          "constitution_present or SDD Kit bootstrap completed",
          "module_quality_summary is PASS or BLOCKED with documented reason",
        ])
      }
    },
    {
      stage_id         = "create-pr"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["spec-evidence-gate"]
      runbook_refs = [
        sg_runbook_sop.orchestration.name,
        sg_runbook_sop.github_content_change.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_github_content_change],
        try(var.workflow_skill_refs["spec-driven-feature::create-pr"], []),
        try(local.power_pack_skill["create-pr"], []),
      )
      spawn_contracts = local.spawn_contracts_create_pr
      note            = local.create_pr_stage_note
    },
    {
      stage_id         = "update-tracker"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["create-pr"]
      runbook_refs     = [sg_runbook_sop.orchestration.name, sg_runbook_sop.github_content_change.name]
      skill_refs = concat(
        [local.sop_orchestration_name],
        try(var.workflow_skill_refs["spec-driven-feature::update-tracker"], []),
        try(local.power_pack_skill["update-tracker"], []),
      )
      spawn_contracts = concat(
        local.spawn_contracts_archive,
        local.spawn_contracts_update_tracker,
      )
      note = local.update_tracker_stage_note
    },
  ]
}
