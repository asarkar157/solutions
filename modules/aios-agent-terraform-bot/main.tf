terraform {
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
    }
  }
}

# ============================================================================
# Terraform Module Bot Agent
# ============================================================================

resource "sg_agent" "terraform_module_manager" {
  name        = "terraform-module-manager"
  persona     = file("${path.module}/personas/terraform-module-manager.md")
  model_names = [var.model_names.gpt4o, var.model_names.claude_sonnet]

  integrations = compact([
    var.integration_names.github,
    var.integration_names.ubuntu_cli
  ])
}

resource "sg_agent_budget" "terraform_module_manager" {
  agent_name  = sg_agent.terraform_module_manager.name
  limit_usd   = 10
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "terraform_module_manager_dangerous_ops" {
  agent_name = sg_agent.terraform_module_manager.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# ============================================================================
# Terraform Module Compliance SOP
# ============================================================================

resource "sg_runbook_sop" "terraform_module_compliance" {
  name        = "terraform-module-compliance-sop"
  description = <<-EOT
    Executes a strict compliance and blast radius test loop for Terraform module updates.

    Steps:
    1) Clone the PR branch and its Terraform files using the GitHub integration.
    2) Run static analysis tools like `tfsec` or `checkov` in the Ubuntu CLI environment to identify hardcoded secrets, missing encryption, or open security groups.
    3) Run `terraform plan` and analyze the output to detect resource modifications or deletions. Evaluate these against organizational Rego policies (e.g., blast radius, dangerous ops).
    4) Query the StackGen Context Graph to identify downstream dependent services and verify this update won't introduce breaking changes.
    5) Auto-remediate issues by committing fixes back to the branch, or fail the test loop and report detailed findings.
  EOT
}

# ============================================================================
# StackGen Module Registration SOP
# ============================================================================

resource "sg_runbook_sop" "stackgen_module_registration" {
  name        = "stackgen-module-registration-sop"
  description = <<-EOT
    Provides instructions for installing the StackGen CLI and registering a Terraform module into the StackGen module catalog.

    Steps:
    1) Verify if the `stackgen` CLI is installed in the Ubuntu CLI environment (`which stackgen`).
    2) If not installed, install it using Homebrew since it is available at `stackgenhq/homebrew-stackgen`:
       `brew tap stackgenhq/stackgen`
       `brew install stackgen`
       (If Homebrew is unavailable, fallback to: `curl -fsSL https://docs.stackgen.com/install.sh | bash`)
    3) Ensure the `STACKGEN_TOKEN` environment variable is available for authentication.
    4) Use the `stackgen` CLI to register the module in the module's directory.
    5) Capture the output and report the registered module version in the final GitHub PR comment.
  EOT
}

# ============================================================================
# Terraform Module Update Workflow
# ============================================================================

resource "sg_workflow" "terraform_module_update" {
  name        = "terraform-module-update"
  domain      = "infrastructure-as-code"
  description = "Analyzes requested changes to existing Terraform modules (from PR or issue), checks deployed instances for security compliance and breaking changes, runs test loop, and either upgrades module or creates new module based on breaking change analysis. Finally registers it into StackGen core."

  triggers = [
    { field = "event_type", values = ["issue.created", "pull_request.opened"], type = "active", source = "github" }
  ]

  runbook_refs = [
    sg_runbook_sop.terraform_module_compliance.name,
    sg_runbook_sop.stackgen_module_registration.name
  ]

  required_inputs = ["repository_url", "issue_or_pr_number"]
  optional_inputs = ["requested_change"]

  example_queries = [
    "A developer opened an issue on the terraform repo asking to fix the RDS module to support encryption by default",
    "Analyze issue #45 for the networking module and implement the requested subnet changes if compliant"
  ]

  stages = [
    {
      stage_id    = "analyze-request"
      description = "Analyze the requested change on the existing module to determine intent and scope"
      note        = "Fetch issue or PR details. Understand what the dev/code assist is asking to fix or create."
      required    = true
    },
    {
      stage_id    = "impact-and-compliance-check"
      description = "Check deployed instances of the module across StackGen and assess security compliance and organizational impact"
      note        = "Analyze if the requested change is security-compliant. Evaluate whether it is a breaking change or unwanted change organizationally based on existing deployments."
      required    = true
    },
    {
      stage_id    = "test-loop-and-upgrade"
      description = "Test changes via PR pipeline or guild runner. Upgrade existing module if compliant and non-breaking, or create a new module for breaking changes."
      note        = "If compliant: iterate on test loop. If breaking: create a new major version or module. If non-breaking: push new version of existing module."
      required    = true
    },
    {
      stage_id    = "register-and-notify"
      description = "Register the new or updated module into StackGen core and comment on the GitHub PR"
      note        = "Once the module is updated and tests pass, register the module version into the StackGen module catalog. Finally, add a detailed comment to the original GitHub issue or PR explaining the changes made, the compliance status, and the new module version."
      required    = true
    }
  ]

  stage_bindings = [
    {
      stage_id  = "analyze-request"
      agent_ref = sg_agent.terraform_module_manager.name
      note      = "Manager analyzes the requested change."
    },
    {
      stage_id         = "impact-and-compliance-check"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["analyze-request"]
      note             = "Manager checks impact and compliance."
    },
    {
      stage_id         = "test-loop-and-upgrade"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["impact-and-compliance-check"]
      note             = "Manager performs test loop and implements module upgrades or creation."
    },
    {
      stage_id         = "register-and-notify"
      agent_ref        = sg_agent.terraform_module_manager.name
      stage_depends_on = ["test-loop-and-upgrade"]
      note             = "Manager registers the resulting module into StackGen core and posts a summary comment to the GitHub PR/issue."
    }
  ]
}

# ============================================================================
# Webhook Ingress for GitHub
# ============================================================================

resource "sg_webhook" "github_pr_issue" {
  name        = "github-terraform-bot-receiver"
  target_type = "workflow"
  target_name = sg_workflow.terraform_module_update.name
  action      = "A new GitHub issue or PR was created in the terraform module repository. Triage the payload, determine the requested change, and initiate the module update workflow."
  enabled     = true
}
