terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # sg_remote_runner create + install commands (>= 0.1.23); spawn_contracts (>= 0.1.21).
      version = ">= 0.1.25, < 0.2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

locals {
  module_prefix = "cdk-bot"
  suffix        = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name    = "cdk-module-manager${local.suffix}"
  workflow_name = "cdk-app-update${local.suffix}"
  webhook_name  = "${local.module_prefix}-github-receiver${local.suffix}"

  sop_orchestration_name       = "${local.module_prefix}-orchestration-sop${local.suffix}"
  sop_install_validate_test    = "${local.module_prefix}-install-validate-test-sop${local.suffix}"
  sop_github_content_change    = "${local.module_prefix}-github-content-change-sop${local.suffix}"
  sop_discovery_modules_layout = "${local.module_prefix}-cdk-catalog-layout-sop${local.suffix}"
  discovery_modules_enabled    = length(var.discovery_modules_repository_full_names) > 0

  default_remote_runner_name  = "${local.module_prefix}-runner${local.suffix}"
  resolved_remote_runner_name = trimspace(var.remote_runner_name) != "" ? trimspace(var.remote_runner_name) : local.default_remote_runner_name

  shell_work_home = trimspace(var.runner_work_home) != "" ? trimspace(var.runner_work_home) : "/home/runner"
  # Public StackGen ingress (ai.dev.stackgen.com) mounts Guild at /guild — not /api/v1/... at origin root.
  stackgen_webhook_api_origin  = trimsuffix(trimspace(var.webhook_trigger_base_url), "/")
  stackgen_webhook_trigger_url = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${local.stackgen_webhook_api_origin}/guild/api/v1/webhooks/trigger"
  stackgen_webhook_org_query   = trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  script_pack_version          = "20260617.1"
  cdkbot_pack_dir              = "${local.shell_work_home}/.cdk-bot/pack/${local.script_pack_version}"
  discovery_modules_template_vars = {
    discovery_repositories_list = join(", ", [for r in var.discovery_modules_repository_full_names : "\"${r}\""])
    discovery_issue_label       = trimspace(var.discovery_modules_issue_label)
    sop_discovery_layout_name   = local.sop_discovery_modules_layout
    sop_install_validate_test   = local.sop_install_validate_test
    cdkbot_pack_dir             = local.cdkbot_pack_dir
  }
  discovery_modules_orchestration_addon = local.discovery_modules_enabled ? trimspace(templatefile("${path.module}/templates/cdk-catalog-orchestration-addon.md.tftpl", local.discovery_modules_template_vars)) : ""
  discovery_modules_layout_sop_body     = local.discovery_modules_enabled ? trimspace(templatefile("${path.module}/templates/cdk-catalog-layout-sop.md.tftpl", local.discovery_modules_template_vars)) : ""
  sop_module_quality                    = "${local.module_prefix}-module-quality-sop${local.suffix}"
  sop_workflow_script_pack              = "${local.module_prefix}-workflow-script-pack${local.suffix}"
  workflow_script_names = [
    "stage-runner.sh",
    "bootstrap-gh-git.sh",
    "mirror-note.sh",
    "clone-and-notes.sh",
    "resolve-module-paths.sh",
    "discovery-exists-check.sh",
    "validate-cdk.sh",
    "detect-cdk-language.sh",
    "ensure-cdk-toolchain.sh",
    "ensure-shell-tool.sh",
    "bootstrap-deps.sh",
    "catalog-scaffold.sh",
    "commit-and-pr.sh",
    "progress-comment.sh",
  ]
  workflow_scripts = {
    for name in local.workflow_script_names :
    name => trimspace(file("${path.module}/scripts/${name}"))
  }
  stage_runner_script = trimspace(file("${path.module}/scripts/stage-runner.sh"))
  clone_pack_script   = trimspace(file("${path.module}/scripts/clone-pack.sh"))
  # Pack ensure: tarball from mothership generic secret sync (remote runner).
  # Docker image may still bake scripts as bootstrap fallback; script changes do not require image rebuild.
  cdkbot_pack_ensure_shell  = local.cdkbot_pack_ensure_shell_body
  script_pack_runner_sha256 = sha256(local.stage_runner_script)
  script_pack_clone_sha256  = sha256(local.clone_pack_script)
  clone_execute_series_body = templatefile(
    "${path.module}/templates/clone-execute-series-embedded.sh.tftpl",
    {
      shell_work_home     = local.shell_work_home
      script_pack_version = local.script_pack_version
    },
  )
  validate_execute_series_body = templatefile(
    "${path.module}/templates/validate-execute-series-embedded.sh.tftpl",
    {
      shell_work_home           = local.shell_work_home
      script_pack_version       = local.script_pack_version
      script_pack_runner_b64    = base64encode(local.stage_runner_script)
      script_pack_runner_sha256 = local.script_pack_runner_sha256
    },
  )
  commit_pr_execute_series_body = templatefile(
    "${path.module}/templates/commit-pr-execute-series-embedded.sh.tftpl",
    {
      shell_work_home     = local.shell_work_home
      script_pack_version = local.script_pack_version
    },
  )
  progress_comment_execute_series_body = templatefile(
    "${path.module}/templates/progress-comment-execute-series-embedded.sh.tftpl",
    {
      module_prefix = local.module_prefix
    },
  )
  discovery_scaffold_execute_series_body = templatefile(
    "${path.module}/templates/catalog-scaffold-execute-series-embedded.sh.tftpl",
    {
      shell_work_home           = local.shell_work_home
      script_pack_version       = local.script_pack_version
      script_pack_runner_b64    = base64encode(local.stage_runner_script)
      script_pack_runner_sha256 = local.script_pack_runner_sha256
    },
  )
  discovery_scaffold_execute_series_b64       = base64encode(local.discovery_scaffold_execute_series_body)
  discovery_scaffold_execute_series_one_liner = "printf '%s' '${local.discovery_scaffold_execute_series_b64}' | base64 -d | /bin/bash"
  clone_execute_series_b64                    = base64encode(local.clone_execute_series_body)
  clone_execute_series_one_liner              = "printf '%s' '${local.clone_execute_series_b64}' | base64 -d | /bin/bash"
  validate_execute_series_b64                 = base64encode(local.validate_execute_series_body)
  validate_execute_series_one_liner           = "printf '%s' '${local.validate_execute_series_b64}' | base64 -d | /bin/bash"
  workflow_script_pack_body = trimspace(templatefile("${path.module}/templates/workflow-script-pack.md.tftpl", {
    shell_tool_prefix   = local.shell_tool_prefix
    shell_work_home     = local.shell_work_home
    script_pack_version = local.script_pack_version
    cdkbot_pack_dir     = local.cdkbot_pack_dir
  }))

  create_runner_git_env_secret = trimspace(var.github_token) != ""
  runner_github_secret_id      = local.create_runner_git_env_secret ? sg_secret.runner_git_env[0].id : trimspace(var.github_secret_id)

  shell_tool_prefix = local.resolved_remote_runner_name

  # Dev UX: skip HITL on shell runner tool calls.
  integration_auto_approve_tool_patterns = compact([
    local.shell_tool_prefix != "" ? "${local.shell_tool_prefix}_*" : "",
  ])

  aws_integration_name = "${local.module_prefix}-aws${local.suffix}"
  resolved_aws_integration_name = var.enable_aws_validation ? coalesce(
    trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : null,
    try(module.aws_integration[0].integration_name, null),
    "",
  ) : ""

  module_quality_sop_body = trimspace(templatefile("${path.module}/templates/module-quality-sop.md.tftpl", {
    module_quality_max_iterations = var.module_quality_max_iterations
    sop_install_validate_test     = local.sop_install_validate_test
    shell_tool_prefix             = local.shell_tool_prefix
  }))
  install_validate_test_sop_body = trimspace(templatefile("${path.module}/templates/cdk-install-validate-test-sop.md.tftpl", {
    shell_tool_prefix  = local.shell_tool_prefix
    cdkbot_pack_dir    = local.cdkbot_pack_dir
    shell_work_home    = local.shell_work_home
    sop_module_quality = local.sop_module_quality
  }))
  github_content_change_sop_body = trimspace(templatefile("${path.module}/templates/cdk-github-content-change-sop.md.tftpl", {
    shell_tool_prefix            = local.shell_tool_prefix
    sop_discovery_modules_layout = local.sop_discovery_modules_layout
  }))
  subagent_budget_defaults = {
    runner_max_llm_calls      = 8
    runner_timeout_seconds    = 300
    validate_max_llm_calls    = 12
    validate_timeout_seconds  = 600
    implement_max_llm_calls   = 20
    implement_timeout_seconds = 900
    github_max_llm_calls      = 12
    github_timeout_seconds    = 90
  }
  subagent_budgets = {
    for key, default in local.subagent_budget_defaults :
    key => coalesce(try(var.subagent_budgets[key], null), default)
  }
  create_pr_runner_max_llm_calls       = local.subagent_budgets.runner_max_llm_calls + local.subagent_budgets.github_max_llm_calls
  discovery_scaffold_timeout_seconds   = local.subagent_budgets.runner_timeout_seconds + 300
  spawn_contracts_progress_conditional = var.enable_progress_issue_comment ? [local.spawn_contract_progress_comment] : []
  orchestration_sop_template_vars = {
    module_prefix                      = local.module_prefix
    shell_tool_prefix                  = local.shell_tool_prefix
    shell_work_home                    = local.shell_work_home
    cdkbot_pack_dir                    = local.cdkbot_pack_dir
    remote_runner_name                 = local.resolved_remote_runner_name
    discovery_modules_issue_label      = trimspace(var.discovery_modules_issue_label)
    sop_discovery_modules_layout       = local.sop_discovery_modules_layout
    sop_install_validate_test          = local.sop_install_validate_test
    subagent_budgets                   = local.subagent_budgets
    discovery_scaffold_timeout_seconds = local.discovery_scaffold_timeout_seconds
    create_pr_runner_max_llm_calls     = local.create_pr_runner_max_llm_calls
  }
  cdk_bot_orchestration_extensions_body = trimspace(templatefile("${path.module}/templates/cdk-bot-orchestration-extensions.md.tftpl", local.orchestration_sop_template_vars))
  cdk_bot_orchestration_sop_body = join("\n\n", compact([
    trimspace(templatefile("${path.module}/templates/cdk-bot-orchestration-sop.md.tftpl", local.orchestration_sop_template_vars)),
    local.cdk_bot_orchestration_extensions_body,
  ]))
  evidence_checklist_name = "${local.module_prefix}-module-update-evidence${local.suffix}"

  # Compact stage-binding notes: authoritative rules stay in runbook_refs / skills /
  # orchestration SOP — not duplicated inline (avoids persona token blow-up and Guild WM
  # Postgres key overflow when the full stage goal is persisted as session state).
  stage_note_common_vars = {
    script_pack_runner_sha256            = local.script_pack_runner_sha256
    script_pack_clone_sha256             = local.script_pack_clone_sha256
    script_pack_version                  = local.script_pack_version
    enable_progress_issue_comment        = var.enable_progress_issue_comment ? "true" : "false"
    sop_orchestration_name               = local.sop_orchestration_name
    shell_work_home                      = local.shell_work_home
    shell_tool_prefix                    = local.shell_tool_prefix
    cdkbot_pack_dir                      = local.cdkbot_pack_dir
    evidence_checklist_name              = local.evidence_checklist_name
    draft_pr_on_max_iterations_exhausted = var.draft_pr_on_max_iterations_exhausted ? "true" : "false"
    sop_install_validate_test            = local.sop_install_validate_test
    sop_module_quality                   = local.sop_module_quality
    sop_github_content_change            = local.sop_github_content_change
    module_quality_max_iterations        = var.module_quality_max_iterations
  }
  clone_stage_note = trimspace(templatefile(
    "${path.module}/templates/stage-notes/clone.md.tftpl",
    merge(local.stage_note_common_vars, {
      sop_discovery_layout = local.sop_discovery_modules_layout
    }),
  ))
  edit_stage_note = trimspace(templatefile(
    "${path.module}/templates/stage-notes/edit.md.tftpl",
    local.stage_note_common_vars,
  ))
  validate_stage_note = trimspace(templatefile(
    "${path.module}/templates/stage-notes/validate.md.tftpl",
    local.stage_note_common_vars,
  ))

  persona = templatefile("${path.module}/personas/cdk-module-manager.md.tftpl", {
    module_prefix                 = local.module_prefix
    cdkbot_pack_dir               = local.cdkbot_pack_dir
    shell_tool_prefix             = local.shell_tool_prefix
    remote_runner_name            = local.resolved_remote_runner_name
    discovery_modules_enabled     = local.discovery_modules_enabled
    sop_discovery_modules_layout  = local.sop_discovery_modules_layout
    discovery_repositories_list   = join(", ", var.discovery_modules_repository_full_names)
    discovery_modules_issue_label = trimspace(var.discovery_modules_issue_label)
    module_quality_max_iterations = var.module_quality_max_iterations
    subagent_budgets              = local.subagent_budgets
  })
}

check "github_credentials" {
  assert {
    condition     = trimspace(var.github_token) != "" || trimspace(var.github_secret_id) != ""
    error_message = "Provide github_token (module creates runner env secret) or github_secret_id (pre-existing sg_secret with GIT_TOKEN/GH_TOKEN for runner sync)."
  }
  assert {
    condition     = !(trimspace(var.github_token) != "" && trimspace(var.github_secret_id) != "")
    error_message = "Provide exactly one of github_token or github_secret_id."
  }
}

# Flat env secret for aiden-runner mothership sync (GIT_TOKEN, GH_TOKEN, …).
resource "sg_secret" "runner_git_env" {
  count = local.create_runner_git_env_secret ? 1 : 0

  name        = "${local.module_prefix}-runner-git-env${local.suffix}"
  description = "Git HTTPS credentials for ${local.resolved_remote_runner_name} (clone, gh api, issue/PR comments)."
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

module "aws_integration" {
  count  = var.enable_aws_validation && trimspace(var.existing_aws_integration_name) == "" && trimspace(var.aws_role_arn) != "" ? 1 : 0
  source = "../aios-integration-aws"

  integration_name = local.aws_integration_name
  aws_role_arn     = var.aws_role_arn
  aws_region       = var.aws_region
  description      = "AWS integration for ${local.agent_name} optional CDK validate (lookups / cdk diff)."
}

module "remote_runner" {
  source = "../aios-remote-runner"

  create_runner = var.create_remote_runner
  name          = local.resolved_remote_runner_name
  description   = trimspace(var.remote_runner_description) != "" ? trimspace(var.remote_runner_description) : "Remote runner for ${local.agent_name} (CDK clone/validate/synth on aiden-runner)."
  labels        = var.remote_runner_labels

  typed_secret_refs = {
    github = local.runner_github_secret_id
  }
  generic_secret_ref_ids        = local.runner_generic_secret_ref_ids
  bind_runner_secrets           = true
  secrets_sync_interval_seconds = var.remote_runner_secrets_sync_interval_seconds
}

# ============================================================================
# CDK Module Manager agent
# ============================================================================

resource "sg_agent" "cdk_module_manager" {
  name        = local.agent_name
  persona     = local.persona
  model_names = compact(var.model_names)

  remote_runners = var.remote_runner_attach_to_agent ? toset([module.remote_runner.runner_name]) : null

  integrations = compact([
    local.resolved_aws_integration_name != "" ? local.resolved_aws_integration_name : null,
  ])

  auto_approve_tools = var.auto_approve_integration_tools ? [
    for pattern in local.integration_auto_approve_tool_patterns : {
      tool = pattern
    }
  ] : []
}

resource "sg_agent_budget" "cdk_module_manager" {
  agent_name = sg_agent.cdk_module_manager.name
  # Prior runs exhausted a $10 budget before validate/notify; per-stage subagent
  # caps keep cost predictable — $15/day leaves headroom for quality-loop retries.
  limit_usd   = 15
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "cdk_module_manager_dangerous_ops" {
  agent_name = sg_agent.cdk_module_manager.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# ============================================================================
# CDK install, validate, and test SOP (remote runner skill)
# ============================================================================

resource "sg_runbook_sop" "cdk_install_validate_test" {
  name        = local.sop_install_validate_test
  approve     = true
  description = local.install_validate_test_sop_body
}

# ============================================================================
# GitHub content change SOP (remote runner — comments + auth; PR via commit-pr)
# ============================================================================

resource "sg_runbook_sop" "github_content_change" {
  name        = local.sop_github_content_change
  approve     = true
  description = local.github_content_change_sop_body
}

# ============================================================================
# CDK Bot Orchestration SOP (meta-skill: spawn contracts, stage graph, budgets)
# ============================================================================
resource "sg_runbook_sop" "discovery_modules_layout" {
  count       = local.discovery_modules_enabled ? 1 : 0
  name        = local.sop_discovery_modules_layout
  approve     = true
  description = local.discovery_modules_layout_sop_body
}

resource "sg_runbook_sop" "module_quality" {
  name        = local.sop_module_quality
  approve     = true
  description = local.module_quality_sop_body
}

resource "sg_runbook_sop" "workflow_script_pack" {
  name        = local.sop_workflow_script_pack
  approve     = true
  description = local.workflow_script_pack_body
}

resource "sg_runbook_sop" "cdk_bot_orchestration" {
  name    = local.sop_orchestration_name
  approve = true
  description = join("\n\n", compact([
    local.discovery_modules_orchestration_addon,
    local.cdk_bot_orchestration_sop_body,
  ]))
}

# =============================================================================
# Evidence checklist — proof-of-work for cdk-app-update
# =============================================================================

resource "sg_evidence_checklist" "cdk_app_update_evidence" {
  name        = local.evidence_checklist_name
  description = "Proof-of-work for GitHub-driven CDK app update: trigger captured, clone ok, CDK implemented, six-check validate PASS, draft PR opened or blocker documented."
  approve     = true
  required_items = [
    "trigger_payload_recorded",
    "repo_clone_materialized",
    "module_paths_or_blocker_documented",
    "validation_summary_recorded",
    "quality_checks_pass_or_blocked",
    "pr_url_or_blocker_documented",
    "quality_check_lint_pass",
    "quality_check_typecheck_pass",
    "quality_check_synth_pass",
    "quality_check_cfn_lint_pass",
    "quality_check_test_pass",
    "quality_check_nag_pass",
  ]
  optional_items = [
    "pr_url_or_pr_deferred",
  ]
  scoring = {
    min_required         = 12
    confidence_threshold = 0.8
  }
  metadata = {
    playbook = "cdk-app-update"
  }
}

resource "sg_workflow" "cdk_app_update" {
  name        = local.workflow_name
  domain      = "infrastructure-as-code"
  description = <<-EOT
    GitHub issue/PR-driven AWS CDK workflow (3 agent stages): `clone` → `implement-cdk` (edit) → `validate` (quality loop back to implement-cdk).
    Automation: `clone-blocked-gate` skips to `validate` on clone failure; `implement-blocked-gate` skips to `validate` on implement blockers; `validate-loop-gate` loops `validate` → `implement-cdk` on NEEDS_REVISION (bounded).
    Cross-stage state uses planner `note` + stage closing message echo (orchestration SOP §3a–§3b). Shell work uses ONE `execute_series` with embedded stage-runner (script-pack §3h).
  EOT
  approve     = true

  metadata = {
    planner_max_tool_iterations       = "40"
    planner_min_tool_calls            = "1"
    terminal_calling_halguard_mode    = "paste_only_minimal_planner"
    halguard_skip_subagent_task_types = "terminal_calling"
  }

  evidence_checklist_ref = sg_evidence_checklist.cdk_app_update_evidence.name

  triggers = [
    { field = "event_type", values = ["issue.created", "issue.reopened", "pull_request.opened"], type = "active", source = "github" }
  ]

  runbook_refs = concat(
    [
      sg_runbook_sop.cdk_bot_orchestration.name,
      sg_runbook_sop.workflow_script_pack.name,
      sg_runbook_sop.cdk_install_validate_test.name,
      sg_runbook_sop.github_content_change.name,
      sg_runbook_sop.module_quality.name,
    ],
    local.discovery_modules_enabled ? [sg_runbook_sop.discovery_modules_layout[0].name] : [],
  )

  required_inputs = ["repository_url", "issue_or_pr_number"]
  optional_inputs = ["requested_change"]

  example_queries = [
    "A developer opened an issue on a CDK TypeScript app asking to switch an S3 bucket from SSE-S3 to KMS encryption",
    "Analyze issue #45 on a Python CDK repo and implement the requested construct change with tests",
    "Issue #12 on a discovery-modules catalog repo: scaffold the missing module template and run validate"
  ]

  stages = [
    {
      stage_id    = "clone"
      description = "Validate trigger payload, discovery label gate, fetch issue context, and clone the repo"
      note        = "Stage 1: check info + clone to `$WORK_ROOT/repo` when missing."
      required    = true
    },
    {
      stage_id    = "clone-blocked-gate"
      description = "Skip to validate when clone/auth failed in clone stage (notify-only path)"
      note        = "conditional_skip only — no LLM."
      required    = false
    },
    {
      stage_id    = "implement-cdk"
      description = "Edit: interpret the requirement and implement CDK app or catalog-module changes in the cloned repo"
      note        = "Stage 2 (edit): resolve paths, CDK app edit or catalog scaffold; commit + draft PR."
      required    = true
    },
    {
      stage_id    = "implement-blocked-gate"
      description = "Skip to validate when implement produced blockers (avoid rework loop on hard failures)"
      note        = "conditional_skip only — no LLM."
      required    = false
    },
    {
      stage_id    = "validate"
      description = "Run CDK quality checks on the open PR branch; loop on NEEDS_REVISION; notify on close"
      note        = "Stage 3: validate-only (PR opened in edit); comment/notify on close."
      required    = true
    },
    {
      stage_id    = "validate-loop-gate"
      description = "Loop back to implement-cdk (edit) when validate reported NEEDS_REVISION (bounded)"
      note        = "loop_stage only — no LLM."
      required    = false
    }
  ]

  stage_bindings = [
    {
      stage_id     = "clone"
      agent_ref    = sg_agent.cdk_module_manager.name
      runbook_refs = [sg_runbook_sop.cdk_bot_orchestration.name]
      skill_refs = concat(
        [local.sop_orchestration_name],
        try(var.workflow_skill_refs["cdk-app-update::clone"], []),
      )
      spawn_contracts = concat(local.spawn_contracts_check_info_and_clone, local.spawn_contracts_progress_conditional)
      note            = local.clone_stage_note
    },
    {
      stage_id         = "clone-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["clone"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)stage_summary:clone[=:\"\\s]+blocked:|stage_summary:intake-clone-bootstrap[=:\"\\s]+blocked:|\"notes\":\\{\\}|intake_plan_only|### Phase 1: ANALYZE|environment enumeration|command blocked: environment|blocked environment enumeration|shell_runner_incompatible|clone_blocker=(auth|auth_or_network|network|404|branch|placeholder_url|missing_clone_params|repo_not_found_or_auth|missing_script_pack|wrong_shell_dollar_escape|shell_runner_incompatible|unexpanded_shell_var)|chdir .+\\.wf-[^:]+: no such file or directory|base64: invalid input|omitted for brevity|unexpected EOF while looking for matching|syntax error|parse error near|Syntax error:.*unexpected|_embed_cdkbot_run.*command not found|script_pack_error=|cdkbot_pack_error=|scaffold_error=|missing_stage_runner|exit 127|command not found|clone-pack\\.sh: not found|Syntax error.*unexpected|example/example|repo_clone_path=$"
        skip_to   = "validate"
        reason    = "Clone/auth failed — skip edit; validate stage posts blocker comment and exits"
      }
    },
    {
      stage_id         = "implement-cdk"
      agent_ref        = sg_agent.cdk_module_manager.name
      stage_depends_on = ["clone-blocked-gate"]
      runbook_refs = [
        sg_runbook_sop.cdk_bot_orchestration.name,
        sg_runbook_sop.cdk_install_validate_test.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_install_validate_test],
        local.discovery_modules_enabled ? [local.sop_discovery_modules_layout] : [],
        try(var.workflow_skill_refs["cdk-app-update::implement-cdk"], []),
      )
      spawn_contracts = concat(local.spawn_contracts_implement_module, local.spawn_contracts_commit_pr, local.spawn_contracts_progress_conditional)
      note            = local.edit_stage_note
    },
    {
      stage_id         = "implement-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["implement-cdk"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)stage_summary:implement-cdk[=:\"\\s]+blocked:|implement_blocker=|implement_plan_only|missing implement markers|missing pr_url"
        skip_to   = "validate"
        reason    = "Implement blocked — validate posts notify; do not loop back to edit"
      }
    },
    {
      stage_id         = "validate"
      agent_ref        = sg_agent.cdk_module_manager.name
      stage_depends_on = ["implement-blocked-gate"]
      runbook_refs = [
        sg_runbook_sop.cdk_bot_orchestration.name,
        sg_runbook_sop.cdk_install_validate_test.name,
        sg_runbook_sop.module_quality.name,
        sg_runbook_sop.github_content_change.name,
      ]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_install_validate_test, local.sop_module_quality, local.sop_github_content_change],
        local.discovery_modules_enabled ? [local.sop_discovery_modules_layout] : [],
        try(var.workflow_skill_refs["cdk-app-update::validate"], []),
      )
      spawn_contracts = concat(
        local.spawn_contracts_validate,
        local.spawn_contracts_validate_followup,
        local.spawn_contracts_progress_conditional,
      )
      note = local.validate_stage_note
    },
    {
      stage_id         = "validate-loop-gate"
      action_type      = "loop_stage"
      stage_depends_on = ["validate"]
      action_config = {
        loop_to        = "implement-cdk"
        max_iterations = var.module_quality_max_iterations
        exit_condition = "output_matches_regex"
        exit_match     = "(?m)module_quality_summary[^\\n]{0,48}(PASS|BLOCKED)|stage_summary:validate[=:\"\\s]+blocked:|stage_summary:implement-cdk[=:\"\\s]+blocked:|implement_blocker="
      }
    }
  ]
}


# ============================================================================
# Webhook Ingress for GitHub
# ============================================================================

resource "sg_webhook" "github_pr_issue" {
  name        = local.webhook_name
  target_type = "workflow"
  target_name = sg_workflow.cdk_app_update.name
  action      = "A GitHub issue or PR was opened on an AWS CDK application or CDK catalog module repository. Triage the payload, clone the repo, implement the requested CDK change, run lint/typecheck/synth/cfn-lint/tests/cdk-nag, and open a draft PR when all checks pass."
  enabled     = true
}
