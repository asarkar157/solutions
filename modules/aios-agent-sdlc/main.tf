terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.18, < 0.2.0" }
  }
}

locals {
  module_prefix = "sdlc"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_cloud_infra_name          = "cloud-infrastructure-engineer${local.suffix}"
  agent_k8s_ops_name              = "kubernetes-operator${local.suffix}"
  agent_github_scm_name           = "github-scm-manager${local.suffix}"
  agent_qa_testing_name           = "qa-test-engineer${local.suffix}"
  agent_docs_writer_name          = "documentation-writer${local.suffix}"
  agent_ui_frontend_name          = "ui-frontend-developer${local.suffix}"
  agent_linear_pm_name            = "project-manager${local.suffix}"
  agent_datadog_alert_triage_name = "datadog-alert-analyst${local.suffix}"
  agent_github_pr_reminder_name   = "pr-review-reminder${local.suffix}"

  workflow_release_name          = "release-pipeline${local.suffix}"
  workflow_developer_intake_name = "developer-request-intake${local.suffix}"
  sop_stackgen_mcp_iac_name      = "stackgen-mcp-iac${local.suffix}"
  evidence_dev_intake_name       = "sdlc-developer-request-intake-evidence${local.suffix}"

  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  slack_integration_name  = "${local.module_prefix}-slack${local.suffix}"
  aws_integration_name    = "${local.module_prefix}-aws${local.suffix}"
  gcp_integration_name    = "${local.module_prefix}-gcp${local.suffix}"

  provision_github = trimspace(var.github_secret_id) != "" && trimspace(var.existing_github_integration_name) == ""
  provision_slack  = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""
  provision_aws    = trimspace(var.aws_secret_id) != "" && trimspace(var.existing_aws_integration_name) == ""
  provision_gcp    = trimspace(var.gcp_secret_id) != "" && trimspace(var.existing_gcp_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_gcp_integration_name = trimspace(var.existing_gcp_integration_name) != "" ? var.existing_gcp_integration_name : (
    local.provision_gcp ? module.gcp_integration[0].integration_name : ""
  )
  resolved_stackgen_mcp_integration_name = trimspace(var.stackgen_mcp_integration_name)
  resolved_linear_mcp_integration_name   = trimspace(var.linear_mcp_integration_name)

  release_notification_webhook_enabled = trimspace(var.release_notification_webhook_url) != ""
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
}

module "gcp_integration" {
  count  = local.provision_gcp ? 1 : 0
  source = "../aios-integration-gcp"

  integration_name   = local.gcp_integration_name
  existing_secret_id = var.gcp_secret_id
}

# ============================================================================
# SDLC Domain Module
# ============================================================================
# Contains SDLC agents (cloud-infra, k8s-ops, GitHub, QA, docs, UI, linear,
# Datadog triage, PR reminder) and the release-pipeline workflow with its
# execution plan. Cross-domain references (SRE agents, runbooks) are passed
# via input variables.

# ============================================================================
# SDLC Agents
# ============================================================================

resource "sg_agent" "cloud_infra" {
  name        = local.agent_cloud_infra_name
  persona     = file("${path.module}/personas/cloud-infra.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = ["run_shell"]
  }

  integrations = compact([
    local.resolved_aws_integration_name,
    local.resolved_stackgen_mcp_integration_name,
    local.resolved_gcp_integration_name,
    local.resolved_slack_integration_name,
  ])
}

resource "sg_agent" "k8s_ops" {
  name        = local.agent_k8s_ops_name
  persona     = file("${path.module}/personas/k8s-ops.md")
  model_names = compact(var.model_names)
}

resource "sg_agent" "github_scm" {
  name        = local.agent_github_scm_name
  persona     = file("${path.module}/personas/github-scm.md")
  model_names = compact(var.model_names)

  integrations = compact([local.resolved_github_integration_name])
}

resource "sg_agent" "qa_testing" {
  name        = local.agent_qa_testing_name
  persona     = file("${path.module}/personas/qa-testing.md")
  model_names = compact(var.model_names)
}

resource "sg_agent" "docs_writer" {
  name        = local.agent_docs_writer_name
  persona     = file("${path.module}/personas/docs-writer.md")
  model_names = compact(var.model_names)
}

resource "sg_agent" "ui_frontend" {
  name        = local.agent_ui_frontend_name
  persona     = file("${path.module}/personas/ui-frontend.md")
  model_names = compact(var.model_names)
}

resource "sg_agent" "linear_pm" {
  name        = local.agent_linear_pm_name
  persona     = file("${path.module}/personas/linear-pm.md")
  model_names = compact(var.model_names)

  integrations = local.resolved_linear_mcp_integration_name != "" ? [local.resolved_linear_mcp_integration_name] : []
}

resource "sg_agent" "datadog_alert_triage" {
  name        = local.agent_datadog_alert_triage_name
  persona     = file("${path.module}/personas/datadog-alert-triage.md")
  model_names = compact(var.model_names)
}

resource "sg_agent" "github_pr_reminder" {
  name        = local.agent_github_pr_reminder_name
  persona     = file("${path.module}/personas/github-pr-reminder.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = ["run_shell"]
  }
}

# ============================================================================
# SDLC Agent Budgets
# ============================================================================
# Tier 1 ($20/day): cloud-infra — runs shell commands against AWS, expensive
#   model calls for infrastructure analysis and multi-step operations.
# Tier 2 ($15/day): k8s-ops, datadog-alert-triage — moderate usage for
#   cluster operations and alert classification with tool chains.
# Tier 3 ($10/day): github-scm, qa-testing, ui-frontend — standard
#   development-assistance usage.
# Tier 4 ($5/day): docs-writer, linear-pm, pr-reminder — lightweight
#   text generation or periodic automated tasks.

resource "sg_agent_budget" "cloud_infra" {
  agent_name  = sg_agent.cloud_infra.name
  limit_usd   = 20
  period_type = "daily"
}

resource "sg_agent_budget" "k8s_ops" {
  agent_name  = sg_agent.k8s_ops.name
  limit_usd   = 15
  period_type = "daily"
}

resource "sg_agent_budget" "datadog_alert_triage" {
  agent_name  = sg_agent.datadog_alert_triage.name
  limit_usd   = 15
  period_type = "daily"
}

resource "sg_agent_budget" "github_scm" {
  agent_name  = sg_agent.github_scm.name
  limit_usd   = 10
  period_type = "daily"
}

resource "sg_agent_budget" "qa_testing" {
  agent_name  = sg_agent.qa_testing.name
  limit_usd   = 10
  period_type = "daily"
}

resource "sg_agent_budget" "ui_frontend" {
  agent_name  = sg_agent.ui_frontend.name
  limit_usd   = 10
  period_type = "daily"
}

resource "sg_agent_budget" "docs_writer" {
  agent_name  = sg_agent.docs_writer.name
  limit_usd   = 5
  period_type = "daily"
}

resource "sg_agent_budget" "linear_pm" {
  agent_name  = sg_agent.linear_pm.name
  limit_usd   = 5
  period_type = "daily"
}

resource "sg_agent_budget" "github_pr_reminder" {
  agent_name  = sg_agent.github_pr_reminder.name
  limit_usd   = 5
  period_type = "daily"
}

# ============================================================================
# StackGen platform MCP — runbook (tool-aligned with Consumer MCP surface)
# ============================================================================

resource "sg_runbook_sop" "stackgen_mcp_iac" {
  name        = local.sop_stackgen_mcp_iac_name
  approve     = true
  description = trimspace(file("${path.module}/templates/stackgen-mcp-iac.md"))
}

# ============================================================================
# SDLC Policy Attachments
# ============================================================================

# --- cloud_infra ---
resource "sg_agent_policy_attachment" "cloud_infra_dangerous_ops" {
  agent_name = sg_agent.cloud_infra.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "cloud_infra_mutations" {
  count      = var.policy_ids.infra_mutations != "" ? 1 : 0
  agent_name = sg_agent.cloud_infra.name
  policy_id  = var.policy_ids.infra_mutations
  enabled    = true
}

# --- k8s_ops ---
resource "sg_agent_policy_attachment" "k8s_ops_dangerous_ops" {
  agent_name = sg_agent.k8s_ops.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "k8s_ops_production" {
  count      = var.policy_ids.k8s_production != "" ? 1 : 0
  agent_name = sg_agent.k8s_ops.name
  policy_id  = var.policy_ids.k8s_production
  enabled    = true
}

# --- github_scm ---
resource "sg_agent_policy_attachment" "github_scm_dangerous_ops" {
  agent_name = sg_agent.github_scm.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "github_scm_protected" {
  count      = var.policy_ids.github_protected != "" ? 1 : 0
  agent_name = sg_agent.github_scm.name
  policy_id  = var.policy_ids.github_protected
  enabled    = true
}

# --- qa_testing ---
resource "sg_agent_policy_attachment" "qa_testing_dangerous_ops" {
  agent_name = sg_agent.qa_testing.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# --- docs_writer ---
resource "sg_agent_policy_attachment" "docs_writer_dangerous_ops" {
  agent_name = sg_agent.docs_writer.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# --- ui_frontend ---
resource "sg_agent_policy_attachment" "ui_frontend_dangerous_ops" {
  agent_name = sg_agent.ui_frontend.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# --- linear_pm ---
resource "sg_agent_policy_attachment" "linear_pm_dangerous_ops" {
  agent_name = sg_agent.linear_pm.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# --- datadog_alert_triage ---
resource "sg_agent_policy_attachment" "datadog_alert_triage_dangerous_ops" {
  agent_name = sg_agent.datadog_alert_triage.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "datadog_alert_triage_policy" {
  count      = var.policy_ids.datadog_alert_triage != "" ? 1 : 0
  agent_name = sg_agent.datadog_alert_triage.name
  policy_id  = var.policy_ids.datadog_alert_triage
  enabled    = true
}

# --- github_pr_reminder ---
resource "sg_agent_policy_attachment" "github_pr_reminder_dangerous_ops" {
  agent_name = sg_agent.github_pr_reminder.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "github_pr_reminder_org_restriction" {
  count      = var.policy_ids.github_org_restriction != "" ? 1 : 0
  agent_name = sg_agent.github_pr_reminder.name
  policy_id  = var.policy_ids.github_org_restriction
  enabled    = true
}

# ============================================================================
# Release Pipeline Workflow
# ============================================================================

resource "sg_workflow" "release_pipeline" {
  name        = local.workflow_release_name
  domain      = "release-pipeline"
  description = trimspace(templatefile("${path.module}/templates/workflow-release-pipeline.md", {}))
  # Guild `approve`: auto-approve the workflow *definition* draft after apply (provider sg_workflow).
  # This is not production deploy approval — deploy-production still follows canary + HITL in stage notes.
  approve = true

  triggers = []

  required_inputs = ["service_name", "git_ref"]
  optional_inputs = ["target_environment", "skip_security_scan"]

  runbook_refs = compact([
    var.sre_runbook_names.deployment_rollback,
    var.sre_runbook_names.ssl_cert_renewal,
  ])

  evidence_checklist_ref = trimspace(var.sre_evidence_checklist_names.change_validation) != "" ? trimspace(var.sre_evidence_checklist_names.change_validation) : null

  example_queries = [
    "Deploy payment-service v2.4.1 to production",
    "Ship the latest build of checkout-api from the release/3.0 branch",
    "Run the full release pipeline for user-profile-service at commit abc123",
    "Promote the staging build of order-service to prod",
    "We need to push the hotfix on notification-worker to production ASAP",
    "Start a canary deployment for the new search-service version",
  ]

  stages = concat(
    [
      {
        stage_id    = "build"
        description = "Build the container image from the specified Git ref using Kaniko in-cluster and push to the ECR registry"
        note        = "K8s-ops agent triggers a Kaniko build pod in the CI namespace, tags the image with the Git SHA and semver, and pushes to the ECR repo."
        required    = true
      },
      {
        stage_id    = "security-scan"
        description = "Scan the built container image for OS and library vulnerabilities using Trivy and Snyk"
        note        = "Fail the pipeline if any CVE with CVSS ≥ 9.0 (critical) is detected. Runs in parallel with integration-tests."
        required    = true
      },
      {
        stage_id    = "integration-tests"
        description = "Spin up an ephemeral preview environment with the new image and run the integration test suite"
        note        = "Create a temporary Kubernetes namespace, deploy the service with its dependencies via Helm, execute the integration test suite. Runs in parallel with security-scan."
        required    = true
      },
      {
        stage_id    = "deploy-staging"
        description = "Deploy the validated image to the staging environment via ArgoCD and verify rollout health"
        note        = "Sync the ArgoCD application with the new image tag, wait for rollout completion, and verify all pods pass readiness and liveness probes."
        required    = true
      },
      {
        stage_id    = "smoke-tests"
        description = "Run critical-path smoke tests against staging — covering authentication, checkout, and API health endpoints"
        note        = "Execute the smoke test suite hitting the staging ingress. Fail if any critical user journey returns a non-2xx response or latency exceeds the SLO threshold. On success, include a line exactly `smoke_test_summary: PASS_ALL` (with optional short commentary on other lines) so the smoke-test gate can match deterministically."
        required    = true
      },
      {
        stage_id    = "smoke-test-gate"
        description = "Evaluate smoke test results — if output includes the PASS_ALL sentinel or other anchored success patterns, skip manual staging verification."
        required    = false
      },
      {
        stage_id    = "deploy-production"
        description = "Promote the staging-validated image to production with a 10% canary rollout, then full promotion after human approval"
        note        = "Route 10% of production traffic to the canary pods for 15 minutes while monitoring error rate and latency. Auto-rollback if error rate exceeds baseline during the canary window."
        required    = true
      },
      {
        stage_id    = "canary-gate"
        description = "LLM evaluates canary metrics and decides: promote to full rollout, or rollback and re-deploy staging."
        required    = false
      },
    ],
    local.release_notification_webhook_enabled ? [{
      stage_id    = "notify-release-status"
      description = "POST the final deployment outcome (success / rollback) to the configured webhook endpoint \u2014 zero LLM cost, sub-second delivery."
      required    = false
    }] : [],
  )
  stage_bindings = concat(
    [
      {
        stage_id   = "build"
        agent_ref  = sg_agent.k8s_ops.name
        note       = "K8s-ops agent manages Kaniko build pods, ECR image tagging, and registry authentication."
        skill_refs = concat(["sdlc-kaniko-ecr-build"], try(var.workflow_skill_refs["release-pipeline::build"], []))
      },
      {
        stage_id         = "security-scan"
        agent_ref        = var.sre_agent_names.sre_risk_posture
        stage_depends_on = ["build"]
        note             = "SRE risk-posture agent runs Trivy and Snyk scans against the newly built image."
        skill_refs       = concat(["sdlc-container-security-scan"], try(var.workflow_skill_refs["release-pipeline::security-scan"], []))
      },
      {
        stage_id         = "integration-tests"
        agent_ref        = sg_agent.qa_testing.name
        stage_depends_on = ["build"]
        note             = "QA agent provisions an ephemeral Kubernetes namespace and runs the integration suite."
        skill_refs       = concat(["sdlc-ephemeral-integration-tests"], try(var.workflow_skill_refs["release-pipeline::integration-tests"], []))
      },
      {
        stage_id         = "deploy-staging"
        agent_ref        = sg_agent.k8s_ops.name
        stage_depends_on = ["security-scan", "integration-tests"]
        runbook_refs     = [var.sre_runbook_names.deployment_rollback]
        note             = "K8s-ops agent syncs ArgoCD and triggers rollback runbook if health checks fail."
        skill_refs       = concat(["sdlc-argocd-staging-rollout"], try(var.workflow_skill_refs["release-pipeline::deploy-staging"], []))
      },
      {
        stage_id         = "smoke-tests"
        agent_ref        = sg_agent.qa_testing.name
        stage_depends_on = ["deploy-staging"]
        note             = "QA agent runs the smoke test suite against the staging environment. On full success, include `smoke_test_summary: PASS_ALL` on its own line for deterministic fast-path matching."
        skill_refs       = concat(["sdlc-staging-smoke-tests"], try(var.workflow_skill_refs["release-pipeline::smoke-tests"], []))
      },
      # conditional_skip: Regex match on smoke test pass rate.
      # If 100% critical paths pass, skip manual staging verification and go straight to deploy-production.
      {
        stage_id         = "smoke-test-gate"
        action_type      = "conditional_skip"
        stage_depends_on = ["smoke-tests"]
        action_config = {
          condition = "output_matches_regex"
          match     = "(?m)^\\s*smoke_test_summary:\\s*PASS_ALL\\s*$|(?i)(?:^|[^0-9])100%\\s+(?:pass|passed)\\b|(?i)\\bpass\\s*rate\\s*:\\s*100%\\b|(?i)(?:^|\\n)\\s*critical[- ]path(?:es)?\\s*:\\s*(?:all\\s+passed|0\\s+failed)\\b|(?i)(?:^|\\n)\\s*0\\s+failures?\\b"
          skip_to   = "deploy-production"
          reason    = "All critical-path smoke tests passed — skipping manual staging verification"
        }
      },
      {
        stage_id         = "deploy-production"
        agent_ref        = sg_agent.k8s_ops.name
        stage_depends_on = ["smoke-test-gate"]
        runbook_refs     = [var.sre_runbook_names.deployment_rollback, var.sre_runbook_names.ssl_cert_renewal]
        note             = "K8s-ops agent performs canary deployment. Rollback and TLS renewal runbooks attached."
        skill_refs       = concat(["sdlc-canary-production-promote"], try(var.workflow_skill_refs["release-pipeline::deploy-production"], []))
      },
      # navigation_gate: LLM evaluates canary health metrics after production deploy.
      # Roll back to deploy-staging when unhealthy; when healthy, proceed to notify-release-status (if configured) or finish.
      {
        stage_id         = "canary-gate"
        action_type      = "navigation_gate"
        stage_depends_on = ["deploy-production"]
        action_config = merge(
          {
            max_goback_count = 1
            navigation_prompt = local.release_notification_webhook_enabled ? (
              "Evaluate canary metrics from the deploy-production output. If error rate exceeds 1% or p99 latency exceeds SLO, go back to deploy-staging for rollback. If metrics are healthy, choose target_stage notify-release-status so stakeholders receive the final status webhook."
              ) : (
              "Evaluate canary metrics from the deploy-production output. If error rate exceeds 1% or p99 latency exceeds SLO, go back to deploy-staging for rollback. If metrics are healthy and there is no release notification stage, choose action FINISH with an empty target_stage to complete the workflow successfully. Do not target notify-release-status when it is not part of this workflow."
            )
          },
          local.release_notification_webhook_enabled ? { allowed_transitions = jsonencode(["deploy-staging", "notify-release-status"]) } : { allowed_transitions = jsonencode(["deploy-staging"]) },
        )
      },
    ],
    local.release_notification_webhook_enabled ? [{
      stage_id         = "notify-release-status"
      action_type      = "webhook"
      stage_depends_on = ["canary-gate"]
      action_config = {
        url             = var.release_notification_webhook_url
        method          = "POST"
        timeout_seconds = 10
      }
    }] : [],
  )
}

# ============================================================================
# Developer intake — proof-of-work (local checklist; release pipeline may use SRE checklist by name)
# ============================================================================

resource "sg_evidence_checklist" "developer_request_intake_evidence" {
  name        = local.evidence_dev_intake_name
  description = "Proof-of-work for developer platform requests: classification, tracking issue, policy evaluation, and execution evidence before closing."
  approve     = true
  required_items = [
    "request_classification_recorded",
    "jira_tracking_issue_linked",
    "policy_evaluation_outcome_documented",
  ]
  optional_items = ["mcp_or_shell_action_log_summary"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.7
  }
  metadata = { playbook = "developer-request-intake" }
}

# ============================================================================
# Developer Request Intake Workflow
# ============================================================================

resource "sg_workflow" "developer_request_intake" {
  name        = local.workflow_developer_intake_name
  domain      = "developer-services"
  description = trimspace(templatefile("${path.module}/templates/workflow-developer-request-intake.md", {}))
  # Guild `approve`: auto-approve the workflow *definition* draft after apply (provider sg_workflow).
  approve = true

  triggers = [
    { field = "channel", values = ["jira", "slack", "web"], type = "passive" },
    { field = "event_type", values = ["issue.created", "issue.commented"], type = "active", source = "jira" },
    { field = "event_type", values = ["app_mention", "message"], type = "active", source = "slack" },
  ]

  required_inputs        = ["request_summary"]
  optional_inputs        = ["requester_email", "team", "priority", "jira_project_key", "environment"]
  evidence_checklist_ref = sg_evidence_checklist.developer_request_intake_evidence.name

  runbook_refs = compact([
    sg_runbook_sop.stackgen_mcp_iac.name,
    var.sre_runbook_names.deployment_rollback,
  ])

  example_queries = [
    "I need a new staging environment for the payments team",
    "Can you grant read access to the production RDS cluster for the analytics team?",
    "Please spin up a dev namespace for the new checkout-v2 service",
    "We need a new S3 bucket with encryption enabled for the data pipeline project",
    "Create a new appStack from the platform template and add an encrypted S3 resource",
    "Request a VPN certificate for the new contractor starting Monday",
    "Set up CI/CD for the new microservice repo appcd-dev/order-processor",
    "Our team needs access to the Datadog APM dashboard for the search service",
  ]

  stages = [
    {
      stage_id    = "analyze-request"
      description = "Parse the incoming request to determine intent, scope, affected services, and required approvals"
      note        = "Classify by type (greenfield appStack vs brownfield change vs cloud-only/AWS access). Decide whether work is driven by StackGen MCP (stackgen-mcp_get_appstacks, get_supported_resource_types, …) or AWS CLI via run_shell. Extract project/appstack IDs and parameters."
      required    = true
    },
    {
      stage_id    = "create-tracking-issue"
      description = "Create a Jira issue to track the request through completion"
      note        = "Open a Jira issue with summary, priority, labels, and a link back to the original request source."
      required    = true
    },
    {
      stage_id    = "check-policy"
      description = "Evaluate the request against Rego governance policies stored in the GitHub policy repository"
      note        = "Pull applicable Rego policies and evaluate request parameters. On final denial, include a line exactly `policy_outcome: DENIED` in the summary; on approval use `policy_outcome: APPROVED` so downstream gates can branch safely."
      required    = true
    },
    {
      stage_id    = "policy-enforcement-gate"
      description = "Evaluate check-policy output: when the summary contains the whole-line sentinel `policy_outcome: DENIED`, skip provisioning and close the tracking issue with denial context; otherwise continue to process-request."
      required    = false
    },
    {
      stage_id    = "process-request"
      description = "Execute the approved request: provision infrastructure, grant access, configure services, or set up environments"
      note        = "Prefer StackGen MCP tools on the integration: follow **`stackgen-mcp-iac`** and **`stackgen-mcp-consumer-tool-catalog-sop`** (user MCP: AppStacks, TF blocks on stacks, env profiles, action runs + logs, snapshots, `get_current_violations`). Use `stackgen-mcp_create_appstack`, `add_resource_to_appstack`, `connect_resources`, `update_resource`, `create_appstack_action_run`, `get_action_run_logs`, `create_snapshot` as needed. Use run_shell + AWS CLI where MCP does not cover the operation; follow **`stackgen-mcp-iac`** and SRE rollback runbook when applicable."
      required    = true
    },
    {
      stage_id    = "evidence-collection-gate"
      description = "Verify that sufficient evidence has been collected from process-request before closing the ticket."
      required    = false
    },
    {
      stage_id    = "close-tracking-issue"
      description = "Update the Jira issue with a summary of actions taken, attach evidence, and transition to Done"
      note        = "Add structured comment, attach outputs, transition to Done, and notify requester via original channel."
      required    = true
    },
  ]

  stage_bindings = [
    {
      stage_id   = "analyze-request"
      agent_ref  = sg_agent.linear_pm.name
      note       = "Linear/PM agent classifies the request and determines processing path."
      skill_refs = concat(["sdlc-request-intake-classification"], try(var.workflow_skill_refs["developer-request-intake::analyze-request"], []))
    },
    {
      stage_id         = "create-tracking-issue"
      agent_ref        = sg_agent.linear_pm.name
      stage_depends_on = ["analyze-request"]
      note             = "Linear/PM agent creates the Jira tracking issue with context from analysis."
      skill_refs       = concat(["sdlc-jira-tracking"], try(var.workflow_skill_refs["developer-request-intake::create-tracking-issue"], []))
    },
    {
      stage_id         = "check-policy"
      agent_ref        = sg_agent.github_scm.name
      stage_depends_on = ["create-tracking-issue"]
      note             = "GitHub SCM agent pulls Rego policies and evaluates request parameters."
      skill_refs       = concat(["sdlc-rego-policy-evaluation"], try(var.workflow_skill_refs["developer-request-intake::check-policy"], []))
    },
    # conditional_skip: Structured policy outcome from check-policy (see stage note).
    # When `policy_outcome: DENIED` is present, skip destructive work and close the tracking issue with the denial context.
    # Otherwise continue to process-request. Uses a whole-line sentinel to avoid accidental substring matches.
    {
      stage_id         = "policy-enforcement-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["check-policy"]
      action_config = {
        condition = "output_matches_regex"
        match     = "(?m)^\\s*policy_outcome:\\s*DENIED\\s*$"
        skip_to   = "close-tracking-issue"
        else_to   = "process-request"
        reason    = "Policy evaluation denied the request — skipping provisioning and closing with denial reason"
      }
    },
    {
      stage_id         = "process-request"
      agent_ref        = sg_agent.cloud_infra.name
      stage_depends_on = ["policy-enforcement-gate"]
      runbook_refs = compact([
        sg_runbook_sop.stackgen_mcp_iac.name,
        var.sre_runbook_names.deployment_rollback,
      ])
      note       = "Cloud-infra agent: StackGen MCP IaC runbook (stackgen-mcp_*) plus AWS integration; SRE rollback runbook if deployment rollback applies."
      skill_refs = concat(["sdlc-stackgen-mcp-iac"], try(var.workflow_skill_refs["developer-request-intake::process-request"], []))
    },
    # evidence_gate: Verifies that the process-request stage produced sufficient
    # evidence (MCP action logs, shell output, resource IDs) before the ticket
    # can be closed. Uses the attached evidence_checklist to score completeness.
    {
      stage_id         = "evidence-collection-gate"
      action_type      = "evidence_gate"
      stage_depends_on = ["process-request"]
    },
    {
      stage_id         = "close-tracking-issue"
      agent_ref        = sg_agent.linear_pm.name
      stage_depends_on = ["evidence-collection-gate"]
      note             = "Linear/PM agent updates Jira, attaches evidence, transitions to Done."
      skill_refs       = concat(["sdlc-jira-closeout"], try(var.workflow_skill_refs["developer-request-intake::close-tracking-issue"], []))
    },
  ]
}
