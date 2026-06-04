# Pre-deploy IAM review workflow — PR-only entitlement delta + GitHub comment.
# Requires enable_cce = true (CCE pack on Ubuntu integration).

locals {
  workflow_iam_gate_name = "pre-deploy-iam-review${local.suffix}"
  sop_iam_gate_cce_delta = "${local.module_prefix}-cce-iam-pr-delta${local.suffix}"
  sop_iam_gate_comment   = "${local.module_prefix}-iam-gate-pr-comment${local.suffix}"
  webhook_iam_gate_name  = "${local.module_prefix}-iam-gate-receiver${local.suffix}"

  iam_gate_enabled = var.enable_cce && var.enable_iam_gate_workflow

  iam_gate_allowed_ops_json = jsonencode(var.iam_gate_allowed_operations)

  iam_gate_ingest_rego = trimspace(templatefile("${path.module}/templates/iam-gate-ingest.rego.tftpl", {}))
}

resource "sg_runbook_sop" "iam_gate_cce_delta" {
  count       = local.iam_gate_enabled ? 1 : 0
  name        = local.sop_iam_gate_cce_delta
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/iam-gate-cce-pr-delta.md.tftpl", {}))
}

resource "sg_runbook_sop" "iam_gate_pr_comment" {
  count   = local.iam_gate_enabled ? 1 : 0
  name    = local.sop_iam_gate_comment
  approve = true
  description = trimspace(templatefile("${path.module}/templates/iam-gate-pr-comment.md.tftpl", {
    allowlist_enabled = length(var.iam_gate_allowed_operations) > 0
    allowed_ops_json  = local.iam_gate_allowed_ops_json
  }))
}

resource "sg_workflow" "pre_deploy_iam_review" {
  count       = local.iam_gate_enabled ? 1 : 0
  name        = local.workflow_iam_gate_name
  domain      = "security"
  description = "PR-only CCE entitlement delta (pre-deploy-iam-review + change-control). Posts file:line evidence on new cloud API call sites; optional Rego allowlist gate."
  approve     = true

  triggers = [
    { field = "event_type", values = ["pull_request.opened", "pull_request.synchronize"], type = "active", integration = "github" },
  ]

  required_inputs = ["repository"]
  optional_inputs = ["pull_request_number", "head_ref", "base_ref", "default_branch"]

  example_queries = [
    "Review IAM impact of this PR before merge",
    "What new AWS API calls does this pull request introduce?",
  ]

  stages = [
    { stage_id = "iam-gate-ingest-filter", description = "Rego allowlist gate for new cloud operations (when configured).", required = true },
    { stage_id = "clone-pr-and-cce-delta", description = "Clone PR head and run CCE pre-deploy-iam-review delta.", required = true },
    { stage_id = "iam-gate-skip-clean", description = "Skip LLM reviewer when no new entitlements.", required = false },
    { stage_id = "iam-reviewer-comment", description = "Post markdown table of new entitlements on the PR.", required = true },
    { stage_id = "notify-clean-pr", description = "Confirm no new cloud entitlements on PR.", required = false },
  ]

  stage_bindings = [
    {
      stage_id    = "iam-gate-ingest-filter"
      action_type = "policy_check"
      action_config = {
        inline_rego = local.iam_gate_ingest_rego
      }
    },
    {
      stage_id         = "clone-pr-and-cce-delta"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["iam-gate-ingest-filter"]
      runbook_refs     = [sg_runbook_sop.iam_gate_cce_delta[0].name]
      skill_refs       = concat([local.sop_iam_gate_cce_delta], try(var.workflow_skill_refs["${local.workflow_iam_gate_name}::clone-pr-and-cce-delta"], []))
      note             = "Ubuntu: cce-pr-delta.sh writes note keys + cce_pr_comment.md; do not paste full delta JSON."
    },
    {
      stage_id         = "iam-gate-skip-clean"
      action_type      = "conditional_skip"
      stage_depends_on = ["clone-pr-and-cce-delta"]
      action_config = {
        condition = "regex"
        match     = "cce_new_entitlement_count=0"
        skip_to   = "notify-clean-pr"
        reason    = "No new cloud entitlements — skip IAM reviewer LLM"
      }
    },
    {
      stage_id         = "iam-reviewer-comment"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["iam-gate-skip-clean"]
      runbook_refs     = [sg_runbook_sop.iam_gate_pr_comment[0].name]
      skill_refs       = concat([local.sop_iam_gate_comment], try(var.workflow_skill_refs["${local.workflow_iam_gate_name}::iam-reviewer-comment"], []))
      note             = "Post cce_pr_comment_path via GitHub; add IAM hints only if missing. Never load full cce_pr_delta.json."
    },
    {
      stage_id         = "notify-clean-pr"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["iam-gate-skip-clean"]
      skill_refs       = try(var.workflow_skill_refs["${local.workflow_iam_gate_name}::notify-clean-pr"], [])
      note             = "Post brief PR comment: no new cloud API call sites detected by CCE vs base branch."
    },
  ]
}

resource "sg_webhook" "github_iam_gate" {
  count       = local.iam_gate_enabled ? 1 : 0
  name        = local.webhook_iam_gate_name
  target_type = "workflow"
  target_name = sg_workflow.pre_deploy_iam_review[0].name
  action      = "A GitHub pull request was opened or updated. Run CCE pre-deploy-iam-review delta against the PR head, apply optional Rego allowlist gate, and post file:line entitlement evidence on the PR."
  enabled     = true
}
