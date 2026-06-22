# Linear two-phase workflows: product-spec (comment) + spec-implement (blessed → Cursor → PR).

resource "sg_runbook_sop" "linear_product_spec" {
  count = local.create_linear_product_spec ? 1 : 0

  name        = local.sop_linear_product_spec_name
  approve     = true
  description = local.linear_product_spec_sop_body
}

resource "sg_runbook_sop" "linear_spec_implement" {
  count = local.create_linear_implement ? 1 : 0

  name        = local.sop_linear_spec_implement_name
  approve     = true
  description = local.linear_spec_implement_sop_body
}

resource "sg_workflow" "linear_product_spec" {
  count = local.create_linear_product_spec ? 1 : 0

  name        = local.linear_product_spec_workflow_name
  domain      = "software-engineering"
  description = "Linear product ticket → golden-template spec + engineering subgoals → Linear comment (no runner)."
  approve     = true

  metadata = {
    planner_max_tool_iterations       = "32"
    halguard_skip_subagent_task_types = "efficiency,coding"
    binding_schema_version            = "20260617.1-linear-product-spec"
  }

  triggers = [
    { field = "event_type", values = ["issue.created", "issue.updated"], type = "active", source = "linear" }
  ]

  runbook_refs = compact([
    sg_runbook_sop.orchestration.name,
    local.create_linear_product_spec ? sg_runbook_sop.linear_product_spec[0].name : "",
  ])

  required_inputs = ["linear_issue_id", "linear_issue_title"]
  optional_inputs = ["linear_issue_body", "linear_labels", "repository_url"]

  example_queries = [
    "Linear CORE-42 with needs-spec label: author product spec and post comment with engineering subgoals",
  ]

  stages = [
    { stage_id = "linear-intake", description = "Parse Linear webhook payload", required = true },
    { stage_id = "needs-spec-gate", description = "Skip when needs-spec label missing", required = false },
    { stage_id = "author-product-spec", description = "Golden template spec from ticket", required = true },
    { stage_id = "decompose-subgoals", description = "Numbered engineering subgoals", required = true },
    { stage_id = "post-linear-spec-comment", description = "Post spec comment via Linear MCP", required = true },
    { stage_id = "linear-product-spec-finish", description = "Close workflow", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "linear-intake"
      agent_ref    = sg_agent.spec_symphony_orchestrator.name
      runbook_refs = [sg_runbook_sop.orchestration.name, sg_runbook_sop.linear_product_spec[0].name]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_linear_product_spec_name],
        try(var.workflow_skill_refs["linear-product-spec::linear-intake"], []),
      )
      spawn_contracts = local.spawn_contracts_linear_product_intake
      note            = local.linear_intake_stage_note
    },
    {
      stage_id         = "needs-spec-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["linear-intake"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)needs_spec_present=false|missing_${var.linear_product_spec_label}"
        skip_to   = "linear-product-spec-finish"
        reason    = "Label ${var.linear_product_spec_label} not present — skip spec authoring"
      }
    },
    {
      stage_id         = "author-product-spec"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["needs-spec-gate"]
      runbook_refs     = [sg_runbook_sop.linear_product_spec[0].name]
      skill_refs       = concat([local.sop_linear_product_spec_name], try(var.workflow_skill_refs["linear-product-spec::author-product-spec"], []))
      spawn_contracts  = local.spawn_contracts_author_product_spec
      note             = local.author_product_spec_stage_note
    },
    {
      stage_id         = "decompose-subgoals"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["author-product-spec"]
      runbook_refs     = [sg_runbook_sop.linear_product_spec[0].name]
      skill_refs       = try(var.workflow_skill_refs["linear-product-spec::decompose-subgoals"], [])
      spawn_contracts  = local.spawn_contracts_decompose_subgoals
      note             = local.decompose_subgoals_stage_note
    },
    {
      stage_id         = "post-linear-spec-comment"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["decompose-subgoals"]
      runbook_refs     = [sg_runbook_sop.linear_product_spec[0].name]
      skill_refs       = try(var.workflow_skill_refs["linear-product-spec::post-linear-spec-comment"], [])
      spawn_contracts  = local.spawn_contracts_post_linear_spec_comment
      note             = local.post_linear_spec_comment_stage_note
    },
    {
      stage_id         = "linear-product-spec-finish"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["post-linear-spec-comment"]
      runbook_refs     = [sg_runbook_sop.linear_product_spec[0].name]
      spawn_contracts  = local.spawn_contracts_linear_product_finish
      note             = "Close: stage_summary:linear-product-spec=done."
    },
  ]
}

resource "sg_workflow" "linear_spec_implement" {
  count = local.create_linear_implement ? 1 : 0

  name        = local.linear_spec_implement_workflow_name
  domain      = "software-engineering"
  description = "Linear spec-blessed → clone → materialize spec → Cursor implement → validate → PR → Linear comment."
  approve     = true

  metadata = {
    planner_max_tool_iterations       = "40"
    terminal_calling_halguard_mode    = "paste_only_minimal_planner"
    halguard_skip_subagent_task_types = "terminal_calling,efficiency"
    binding_schema_version            = "20260618.1-linear-spec-implement"
  }

  evidence_checklist_ref = sg_evidence_checklist.spec_driven_feature_evidence.name

  triggers = [
    { field = "event_type", values = ["issue.updated", "issue.created"], type = "active", source = "linear" }
  ]

  runbook_refs = compact([
    sg_runbook_sop.orchestration.name,
    sg_runbook_sop.workflow_script_pack.name,
    sg_runbook_sop.github_content_change.name,
    sg_runbook_sop.linear_spec_implement[0].name,
  ])

  required_inputs = ["linear_issue_id", "repository_url"]
  optional_inputs = ["linear_issue_body", "linear_labels", "engineering_subgoals"]

  example_queries = [
    "Linear CORE-42 with spec-blessed label: implement engineering subgoals and open PR",
  ]

  stages = [
    { stage_id = "linear-intake", description = "Parse Linear webhook + repo link", required = true },
    { stage_id = "blessed-gate", description = "Skip when spec-blessed label missing", required = false },
    { stage_id = "fetch-spec-context", description = "Load spec comment from Linear", required = true },
    { stage_id = "fetch-spec-blocked-gate", description = "Skip on missing spec comment", required = false },
    { stage_id = "intake-clone-bootstrap", description = "Clone linked GitHub repo", required = true },
    { stage_id = "intake-blocked-gate", description = "Skip on clone failure", required = false },
    { stage_id = "repo-sdd-bootstrap", description = "SDD Kit bootstrap", required = true },
    { stage_id = "materialize-spec", description = "Write specs/ from Linear comment", required = true },
    { stage_id = "implement", description = "Cursor/shell implement subgoals", required = true },
    { stage_id = "implement-blocked-gate", description = "Skip on plan-only implement", required = false },
    { stage_id = "validate-and-test", description = "Validate + ci-spec-linkage", required = true },
    { stage_id = "validate-loop-gate", description = "Loop on NEEDS_REVISION", required = false },
    { stage_id = "spec-evidence-gate", description = "Evidence before PR", required = false },
    { stage_id = "create-pr", description = "Commit, push, open PR", required = true },
    { stage_id = "post-linear-implement-comment", description = "Linear MCP status comment", required = true },
    { stage_id = "linear-implement-finish", description = "Close workflow", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "linear-intake"
      agent_ref    = sg_agent.spec_symphony_orchestrator.name
      runbook_refs = [sg_runbook_sop.orchestration.name, sg_runbook_sop.linear_spec_implement[0].name]
      skill_refs = concat(
        [local.sop_orchestration_name, local.sop_linear_spec_implement_name],
        try(var.workflow_skill_refs["linear-spec-implement::linear-intake"], []),
      )
      spawn_contracts = local.spawn_contracts_linear_implement_intake
      note            = local.linear_intake_stage_note
    },
    {
      stage_id         = "blessed-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["linear-intake"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)spec_blessed_present=false|missing_${var.linear_implement_label}"
        skip_to   = "linear-implement-finish"
        reason    = "Label ${var.linear_implement_label} not present — skip implement factory"
      }
    },
    {
      stage_id         = "fetch-spec-context"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["blessed-gate"]
      runbook_refs     = [sg_runbook_sop.linear_spec_implement[0].name]
      skill_refs       = try(var.workflow_skill_refs["linear-spec-implement::fetch-spec-context"], [])
      spawn_contracts  = local.spawn_contracts_fetch_spec_context
      note             = local.fetch_spec_context_stage_note
    },
    {
      stage_id         = "fetch-spec-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["fetch-spec-context"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)fetch_spec_blocker=|spec_comment_found=false"
        skip_to   = "linear-implement-finish"
        reason    = "Blessed spec comment not found on Linear issue"
      }
    },
    {
      stage_id         = "intake-clone-bootstrap"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["fetch-spec-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.orchestration.name, sg_runbook_sop.workflow_script_pack.name]
      skill_refs       = concat([local.sop_orchestration_name], try(var.workflow_skill_refs["linear-spec-implement::intake-clone-bootstrap"], []))
      spawn_contracts  = local.spawn_contracts_intake_clone
      note             = local.linear_intake_clone_bootstrap_stage_note
    },
    {
      stage_id         = "intake-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["intake-clone-bootstrap"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)stage_summary:intake-clone-bootstrap[=:\"\\s]+blocked:|clone_blocker=|context canceled|runner_unavailable|repo_clone_path=$"
        skip_to   = "post-linear-implement-comment"
        reason    = "Clone failed — notify Linear with blocker"
      }
    },
    {
      stage_id         = "repo-sdd-bootstrap"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["intake-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.orchestration.name]
      skill_refs       = concat([local.sop_orchestration_name], try(var.workflow_skill_refs["linear-spec-implement::repo-sdd-bootstrap"], []))
      spawn_contracts  = local.spawn_contracts_repo_bootstrap
      note             = local.repo_sdd_bootstrap_stage_note
    },
    {
      stage_id         = "materialize-spec"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["repo-sdd-bootstrap"]
      runbook_refs     = [sg_runbook_sop.linear_spec_implement[0].name]
      skill_refs       = try(var.workflow_skill_refs["linear-spec-implement::materialize-spec"], [])
      spawn_contracts  = local.spawn_contracts_materialize_spec
      note             = local.materialize_spec_stage_note
    },
    {
      stage_id         = "implement"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["materialize-spec"]
      runbook_refs     = [sg_runbook_sop.orchestration.name, sg_runbook_sop.linear_spec_implement[0].name]
      skill_refs       = concat([local.sop_orchestration_name], try(var.workflow_skill_refs["linear-spec-implement::implement"], []))
      spawn_contracts  = local.linear_implement_spawn_contracts
      note             = local.implement_stage_note
    },
    {
      stage_id         = "implement-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["implement"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)implement_blocker=|implement_edit_verified=(false|missing)|stage_summary:implement[=:\"\\s]+blocked:"
        skip_to   = "post-linear-implement-comment"
        reason    = "Implement blocked — notify Linear"
      }
    },
    {
      stage_id         = "validate-and-test"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["implement-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.orchestration.name]
      skill_refs       = concat([local.sop_orchestration_name], try(var.workflow_skill_refs["linear-spec-implement::validate-and-test"], []))
      spawn_contracts  = local.spawn_contracts_validate
      note             = local.validate_and_test_stage_note
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
          "spec_linkage_recorded from materialize-spec or validate stdout",
          "engineering_subgoals referenced in implement notes",
          "module_quality_summary is PASS or BLOCKED with reason",
        ])
      }
    },
    {
      stage_id         = "create-pr"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["spec-evidence-gate"]
      runbook_refs     = [sg_runbook_sop.orchestration.name, sg_runbook_sop.github_content_change.name]
      skill_refs       = concat([local.sop_orchestration_name], try(var.workflow_skill_refs["linear-spec-implement::create-pr"], []))
      spawn_contracts  = local.spawn_contracts_create_pr
      note             = local.create_pr_stage_note
    },
    {
      stage_id         = "post-linear-implement-comment"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["create-pr"]
      runbook_refs     = [sg_runbook_sop.linear_spec_implement[0].name]
      skill_refs       = try(var.workflow_skill_refs["linear-spec-implement::post-linear-implement-comment"], [])
      spawn_contracts  = local.spawn_contracts_post_linear_implement_comment
      note             = local.post_linear_implement_comment_stage_note
    },
    {
      stage_id         = "linear-implement-finish"
      agent_ref        = sg_agent.spec_symphony_orchestrator.name
      stage_depends_on = ["post-linear-implement-comment"]
      spawn_contracts  = local.spawn_contracts_linear_implement_finish
      note             = "Close: stage_summary:linear-spec-implement=done."
    },
  ]
}
