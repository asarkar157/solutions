terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.9, < 0.2.0" }
  }
}

# =============================================================================
# StackGen MCP Integration & Policy Module
# =============================================================================
# Vault Other/mcp pattern matches examples/agentic-infrastructure and repo-to-iac:
# transport, url, headers (Bearer) — MCPSecretResolver.

locals {
  stackgen_mcp_headers = jsonencode({
    authorization = "Bearer ${var.stackgen_api_token}"
  })
  # SSE URLs (…/mcp/sse) use transport "sse"; hosted Consumer-style paths use streamable_http.
  stackgen_mcp_transport = strcontains(var.stackgen_mcp_url, "/mcp/sse") ? "sse" : "streamable_http"
}

# 1. Define the Secret for MCP Auth
resource "sg_secret" "stackgen_mcp_auth" {
  name        = "stackgen-mcp-auth"
  description = "StackGen MCP — transport/url/headers (same pattern as agentic-infrastructure / repo-to-iac)."
  category    = "Other"
  subcategory = "mcp"
  metadata = {
    transport = local.stackgen_mcp_transport
    url       = var.stackgen_mcp_url
    headers   = local.stackgen_mcp_headers
  }
}

# 2. Define the MCP Integration pointing to <MOTHERSHIP>/api/mcp/sse
resource "sg_guild_integration" "stackgen_mcp" {
  name           = "stackgen-mothership-mcp"
  description    = "Connects to StackGen Mothership MCP SSE endpoint"
  type           = "mcp"
  scope          = "PROJECT"
  secret_ref_ids = [sg_secret.stackgen_mcp_auth.id]
  enabled        = true


}

# 3. Author the Guardrail Policy
# This Rego policy enforces read-only operations on StackGen, blocking mutations.
resource "sg_policy" "stackgen_guardrails" {
  name        = "stackgen-mcp-guardrails"
  description = "Ensures the agent can only read infrastructure state from StackGen, preventing unintended infrastructure modifications."
  type        = "logic"
  rego_source = file("${path.module}/policies/stackgen-guardrails.rego")
}

# 4. Provision the Agent
resource "sg_agent" "stackgen_expert" {
  name    = "stackgen-expert"
  persona = file("${path.module}/personas/stackgen-expert.md")
  model_names = compact([
    lookup(var.model_names, "gpt4o", ""),
    lookup(var.model_names, "claude_sonnet", ""),
    lookup(var.model_names, "gemini_flash", "")
  ])

  integrations = compact([
    sg_guild_integration.stackgen_mcp.name,
    lookup(var.integration_names, "stackgen_openapi", "")
  ])
}

# 5. Bind Policy to Agent
resource "sg_agent_policy_attachment" "stackgen_safety" {
  agent_name = sg_agent.stackgen_expert.name
  policy_id  = sg_policy.stackgen_guardrails.id
  enabled    = true
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  count      = lookup(var.policy_ids, "dangerous_ops", "") != "" ? 1 : 0
  agent_name = sg_agent.stackgen_expert.name
  policy_id  = lookup(var.policy_ids, "dangerous_ops", "")
  enabled    = true
}

# --- Workflows ---
resource "sg_runbook_sop" "stackgen_audit" {
  name        = "stackgen-audit"
  approve     = true
  description = "Audit the current application infrastructure using the StackGen MCP."
}

resource "sg_workflow" "infrastructure_audit" {
  name        = "stackgen-infrastructure-audit"
  domain      = "cloudops"
  description = "Uses StackGen MCP to pull current infrastructure state and audit it against best practices."
  approve     = true

  stages = [
    { stage_id = "fetch-state", description = "Call StackGen MCP to retrieve application graph.", required = true },
    { stage_id = "evaluate", description = "Evaluate the architecture for high availability and security.", required = true },
  ]

  stage_bindings = [
    { stage_id = "fetch-state", agent_ref = sg_agent.stackgen_expert.name, runbook_refs = [sg_runbook_sop.stackgen_audit.name], skill_refs = concat(["stackgen-mcp-app-graph"], try(var.workflow_skill_refs["stackgen-infrastructure-audit::fetch-state"], [])) },
    { stage_id = "evaluate", agent_ref = sg_agent.stackgen_expert.name, stage_depends_on = ["fetch-state"], skill_refs = concat(["stackgen-architecture-best-practices"], try(var.workflow_skill_refs["stackgen-infrastructure-audit::evaluate"], [])) },
  ]
}
