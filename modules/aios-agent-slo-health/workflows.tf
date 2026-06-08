# =============================================================================
# Workflow 1 — slo-health-review
# =============================================================================

resource "sg_workflow" "slo_health_review" {
  name        = local.workflow_review_name
  domain      = "observability-slo"
  description = trimspace(file("${path.module}/templates/workflow-slo-health-review.md"))
  approve     = true

  required_inputs = []
  optional_inputs = ["scope"]

  example_queries = [
    "What is our error budget posture this week?",
    "Are any SLOs at risk of exhausting their budget?",
    "Show config drift between our OpenSLO repo and Grafana alerts.",
    "Summarize SLO health for payments-api.",
  ]

  stages = concat(
    [
      { stage_id = "fetch-openslo-specs", description = "Load OpenSLO YAML catalog from GitHub.", required = true },
    ],
    var.enable_slo_drift_in_review ? [
      { stage_id = "scan-grafana-config", description = "Snapshot Grafana dashboards and alert rules.", required = true },
    ] : [],
    var.enable_slo_drift_in_review ? [
      { stage_id = "detect-config-drift", description = "Compare Git OpenSLO to Grafana config; emit slo_drift_report.", required = true },
    ] : [],
    [
      { stage_id = "query-slo-metrics", description = "Query SLI and burn metrics via Grafana PromQL.", required = true },
      { stage_id = "assess-error-budget", description = "Classify error budget posture per SLO.", required = true },
      { stage_id = "compose-digest", description = "Render weekly digest with posture and drift sections.", required = true },
    ],
    local.webhook_notify_enabled ? [
      { stage_id = "notify-webhook", description = "POST slo_posture and slo_drift_report JSON to configured webhook.", required = false },
    ] : [],
    local.slack_notify_enabled ? [
      { stage_id = "notify-slack", description = "Post digest to Slack.", required = false },
    ] : [],
  )

  stage_bindings = concat(
    [
      {
        stage_id     = "fetch-openslo-specs"
        agent_ref    = sg_agent.slo_health.name
        runbook_refs = [sg_runbook_sop.fetch_openslo_specs.name]
        skill_refs   = try(var.workflow_skill_refs["${local.workflow_review_name}::fetch-openslo-specs"], [])
        note         = local.openslo_authoritative_config_note
      },
    ],
    var.enable_slo_drift_in_review ? [
      {
        stage_id     = "scan-grafana-config"
        agent_ref    = sg_agent.slo_health.name
        runbook_refs = [sg_runbook_sop.scan_grafana_config.name]
        skill_refs   = try(var.workflow_skill_refs["${local.workflow_review_name}::scan-grafana-config"], [])
      },
    ] : [],
    var.enable_slo_drift_in_review ? [
      {
        stage_id         = "detect-config-drift"
        agent_ref        = sg_agent.slo_health.name
        stage_depends_on = ["fetch-openslo-specs", "scan-grafana-config"]
        runbook_refs     = [sg_runbook_sop.detect_config_drift.name]
        skill_refs       = try(var.workflow_skill_refs["${local.workflow_review_name}::detect-config-drift"], [])
      },
    ] : [],
    [
      {
        stage_id         = "query-slo-metrics"
        agent_ref        = sg_agent.slo_health.name
        stage_depends_on = local.review_query_depends_on
        runbook_refs     = [sg_runbook_sop.query_slo_metrics.name]
        skill_refs       = try(var.workflow_skill_refs["${local.workflow_review_name}::query-slo-metrics"], [])
        note             = var.enable_slo_drift_in_review ? "Runs parallel with detect-config-drift after fetch-openslo-specs completes (needs catalog only)." : ""
      },
      {
        stage_id         = "assess-error-budget"
        agent_ref        = sg_agent.slo_health.name
        stage_depends_on = ["query-slo-metrics"]
        runbook_refs     = [sg_runbook_sop.assess_error_budget.name]
        skill_refs       = try(var.workflow_skill_refs["${local.workflow_review_name}::assess-error-budget"], [])
      },
      {
        stage_id         = "compose-digest"
        agent_ref        = sg_agent.slo_health.name
        stage_depends_on = local.review_compose_depends_on
        runbook_refs     = [sg_runbook_sop.compose_slo_digest.name]
        skill_refs       = try(var.workflow_skill_refs["${local.workflow_review_name}::compose-digest"], [])
        note             = var.enable_slo_drift_reconcile_workflow ? "When actionable drift exists, suggest slo-drift-reconcile workflow." : ""
      },
    ],
    local.webhook_notify_enabled ? [{
      stage_id         = "notify-webhook"
      action_type      = "webhook"
      stage_depends_on = ["compose-digest"]
      action_config = {
        url             = var.slo_report_webhook_url
        method          = "POST"
        timeout_seconds = 10
      }
    }] : [],
    local.slack_notify_enabled ? [{
      stage_id         = "notify-slack"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = concat(["compose-digest"], local.webhook_notify_enabled ? ["notify-webhook"] : [])
      skill_refs       = try(var.workflow_skill_refs["${local.workflow_review_name}::notify-slack"], [])
      note             = "Post digest_markdown to Slack."
    }] : [],
  )
}

# =============================================================================
# Workflow 2 — slo-definition-bootstrap
# =============================================================================

resource "sg_workflow" "slo_definition_bootstrap" {
  count       = var.enable_slo_bootstrap_workflow ? 1 : 0
  name        = local.workflow_bootstrap_name
  domain      = "observability-slo"
  description = trimspace(file("${path.module}/templates/workflow-slo-definition-bootstrap.md"))
  approve     = true

  required_inputs = []
  optional_inputs = ["scope", "confirm_pr", "allow_slo_overwrite"]

  example_queries = [
    "Run slo-definition-bootstrap with confirm_pr=true to discover SLOs from Grafana and open a PR.",
    "Bootstrap OpenSLO YAML for the payments team dashboards.",
  ]

  stages = concat(
    [
      { stage_id = "fetch-existing-catalog", description = "Load Git catalog and catalog_gaps.", required = true },
      { stage_id = "scan-grafana-signals", description = "Discover golden-signal PromQL from Grafana.", required = true },
      { stage_id = "propose-slo-candidates", description = "Map signals to OpenSLO proposals.", required = true },
      { stage_id = "validate-promql", description = "Validate proposals with query_metric.", required = true },
      { stage_id = "no-valid-proposals-gate", description = "Skip PR path when zero validated proposals.", required = false },
      { stage_id = "draft-openslo-yaml", description = "Write draft YAML under WORK_ROOT/openslo-drafts/.", required = true },
      { stage_id = "preview-proposals", description = "Human preview; require confirm_pr.", required = true },
      { stage_id = "confirm-pr-gate", description = "Proceed to PR only when confirm_pr=true.", required = true },
      { stage_id = "open-slo-pr", description = "Spawn open-slo-pr-runner to open GitHub PR.", required = true },
      { stage_id = "notify-pr-opened", description = "Notify Slack/webhook with PR link.", required = false },
    ],
  )

  stage_bindings = [
    {
      stage_id     = "fetch-existing-catalog"
      agent_ref    = sg_agent.slo_health.name
      runbook_refs = [sg_runbook_sop.fetch_existing_catalog[0].name]
      note         = local.bootstrap_stage_inline_note
    },
    {
      stage_id     = "scan-grafana-signals"
      agent_ref    = sg_agent.slo_health.name
      runbook_refs = [sg_runbook_sop.scan_grafana_signals[0].name]
      note         = local.bootstrap_stage_inline_note
    },
    {
      stage_id         = "propose-slo-candidates"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = ["fetch-existing-catalog", "scan-grafana-signals"]
      runbook_refs     = [sg_runbook_sop.propose_slo_candidates[0].name]
    },
    {
      stage_id         = "validate-promql"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = ["propose-slo-candidates"]
      runbook_refs     = [sg_runbook_sop.validate_promql[0].name]
      spawn_contracts  = var.enable_parallel_validate_batches ? local.spawn_contracts_validate_parallel : []
      note             = var.enable_parallel_validate_batches ? "Parallel validate batches enabled (max ${var.max_parallel_batches}). Coordinator splits slo_proposals round-robin; one flow_type parallel create_agent fan-out only." : "Inline sequential PromQL validation."
    },
    {
      stage_id         = "no-valid-proposals-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["validate-promql"]
      action_config = {
        condition = "output_matches_regex"
        match     = "validated_count[^\\n]{0,20}0|slo_proposals_validated[^\\n]*\\[\\s*\\]"
        skip_to   = "notify-pr-opened"
        reason    = "No validated SLO proposals"
      }
    },
    {
      stage_id         = "draft-openslo-yaml"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = ["no-valid-proposals-gate"]
      runbook_refs     = [sg_runbook_sop.draft_openslo_yaml[0].name]
      spawn_contracts  = local.spawn_contracts_draft
      note             = "Write slo_proposals_validated.json to WORK_ROOT before spawn. Use spawn contracts only — FORBIDDEN create_files with empty payload."
    },
    {
      stage_id         = "preview-proposals"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = ["draft-openslo-yaml"]
      runbook_refs     = [sg_runbook_sop.preview_proposals[0].name]
    },
    {
      stage_id         = "confirm-pr-gate"
      action_type      = "navigation_gate"
      stage_depends_on = ["preview-proposals"]
      action_config = {
        max_goback_count    = 0
        navigation_prompt   = "If workflow input confirm_pr=true, proceed to open-slo-pr. Otherwise stop with awaiting_confirm."
        allowed_transitions = jsonencode(["open-slo-pr"])
      }
    },
    {
      stage_id         = "open-slo-pr"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = ["confirm-pr-gate"]
      runbook_refs     = [sg_runbook_sop.open_slo_pr[0].name]
      spawn_contracts  = local.spawn_contracts_open_slo_pr
      note             = local.openslo_authoritative_config_note
    },
    {
      stage_id         = "notify-pr-opened"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = ["open-slo-pr", "no-valid-proposals-gate"]
      runbook_refs     = [sg_runbook_sop.notify_pr_opened[0].name]
    },
  ]
}

# =============================================================================
# Workflow 3 — slo-drift-reconcile
# =============================================================================

resource "sg_workflow" "slo_drift_reconcile" {
  count       = var.enable_slo_drift_reconcile_workflow ? 1 : 0
  name        = local.workflow_drift_name
  domain      = "observability-slo"
  description = trimspace(file("${path.module}/templates/workflow-slo-drift-reconcile.md"))
  approve     = true

  required_inputs = []
  optional_inputs = ["confirm_pr", "scope"]

  example_queries = [
    "Fix SLO config drift between Git and Grafana with a PR.",
    "Reconcile OpenSLO YAML with our on-call alert rules.",
  ]

  stages = [
    { stage_id = "fetch-catalog-and-grafana", description = "Combined Git + Grafana snapshot.", required = true },
    { stage_id = "classify-drift-items", description = "Classify drift with recommended actions.", required = true },
    { stage_id = "draft-reconcile-yaml", description = "Draft YAML patches for Git-side fixes.", required = true },
    { stage_id = "preview-drift-fixes", description = "Preview changes; require confirm_pr.", required = true },
    { stage_id = "confirm-drift-pr-gate", description = "Gate before PR when confirm_pr required.", required = true },
    { stage_id = "open-drift-pr", description = "Open reconcile PR via open-slo-pr-runner.", required = true },
    { stage_id = "notify-drift-pr", description = "Notify Slack with PR link.", required = false },
  ]

  stage_bindings = [
    {
      stage_id     = "fetch-catalog-and-grafana"
      agent_ref    = sg_agent.slo_health.name
      runbook_refs = [sg_runbook_sop.fetch_catalog_and_grafana[0].name]
      note         = local.bootstrap_stage_inline_note
    },
    {
      stage_id         = "classify-drift-items"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = ["fetch-catalog-and-grafana"]
      runbook_refs     = [sg_runbook_sop.classify_drift_items[0].name]
    },
    {
      stage_id         = "draft-reconcile-yaml"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = ["classify-drift-items"]
      runbook_refs     = [sg_runbook_sop.draft_reconcile_yaml[0].name]
    },
    {
      stage_id         = "preview-drift-fixes"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = ["draft-reconcile-yaml"]
      runbook_refs     = [sg_runbook_sop.preview_drift_fixes[0].name]
    },
    {
      stage_id         = "confirm-drift-pr-gate"
      action_type      = "navigation_gate"
      stage_depends_on = ["preview-drift-fixes"]
      action_config = {
        max_goback_count    = 0
        navigation_prompt   = "When confirm_pr=true proceed to open-drift-pr; else stop."
        allowed_transitions = jsonencode(["open-drift-pr"])
      }
    },
    {
      stage_id         = "open-drift-pr"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = ["confirm-drift-pr-gate"]
      runbook_refs     = [sg_runbook_sop.open_drift_pr[0].name]
      spawn_contracts  = local.spawn_contracts_open_slo_pr
    },
    {
      stage_id         = "notify-drift-pr"
      agent_ref        = sg_agent.slo_health.name
      stage_depends_on = ["open-drift-pr"]
      runbook_refs     = [sg_runbook_sop.notify_drift_pr[0].name]
    },
  ]
}

# =============================================================================
# Schedule + ingress webhooks
# =============================================================================

module "weekly_slo_review_schedule" {
  count  = var.enable_weekly_schedule ? 1 : 0
  source = "../aios-agent-schedules"

  target_type = "workflow"
  target_name = sg_workflow.slo_health_review.name

  schedules = [
    {
      name       = "weekly-slo-health-review${local.suffix}"
      expression = var.weekly_schedule_cron
      action     = "Run the full slo-health-review workflow: fetch OpenSLO from Git, scan Grafana for config drift, query error budgets, compose digest, then notify webhook and Slack."
      enabled    = true
    },
  ]
}

resource "sg_webhook" "slo_bootstrap_ingress" {
  count       = var.enable_slo_bootstrap_workflow && var.enable_slo_bootstrap_webhook ? 1 : 0
  name        = local.webhook_bootstrap_name
  target_type = "workflow"
  target_name = sg_workflow.slo_definition_bootstrap[0].name
  action      = "Remote slo-definition-bootstrap trigger. Parse scope (service/dashboard UID) and confirm_pr from JSON body, then discover SLOs from Grafana and open PR when confirmed."
  enabled     = true
}

resource "sg_webhook" "slo_drift_ingress" {
  count       = var.enable_slo_drift_reconcile_workflow && var.enable_slo_drift_reconcile_webhook ? 1 : 0
  name        = local.webhook_drift_name
  target_type = "workflow"
  target_name = sg_workflow.slo_drift_reconcile[0].name
  action      = "Remote slo-drift-reconcile trigger. Parse confirm_pr and optional scope, classify drift between Git OpenSLO and Grafana, open reconcile PR when confirmed."
  enabled     = true
}
