# AIOS Agent — SDLC (Software Development Lifecycle)

Complete SDLC domain module with 9 specialized agents and 2 multi-stage workflows covering the full release pipeline and developer self-service request intake.

## Agents

| Agent | Role | Budget |
|-------|------|--------|
| `cloud-infrastructure-engineer` | AWS CLI (`run_shell`) + optional StackGen Consumer MCP (`stackgen-mcp_*` tools), optional GCP + Slack Guild integrations | $20/day |
| `kubernetes-operator` | K8s cluster operations | $15/day |
| `github-scm-manager` | SCM + policy evaluation | $10/day |
| `qa-test-engineer` | Integration test orchestration | $10/day |
| `documentation-writer` | Auto-generated docs | $5/day |
| `ui-frontend-developer` | Frontend implementation | $10/day |
| `project-manager` | Linear/Jira PM coordination | $5/day |
| `datadog-alert-analyst` | Alert classification | $15/day |
| `pr-review-reminder` | Stale PR notifications | $5/day |

## Workflows

### `release-pipeline`
Full CI/CD: build → security scan ∥ integration tests → staging → smoke tests → canary → production (with parallel fan-out and cross-module SRE agent references).

### `developer-request-intake`
Multi-channel request processing (Jira/Slack/Web): analyze → create tracking issue → check governance policy → process request → close issue. The process stage follows **`stackgen-mcp-iac`** / **`stackgen-mcp-consumer-tool-catalog-sop`** (StackGen **user** MCP: AppStacks, env profiles, plans, snapshots, violations — not discovery-import / `download-iac` / git-push MCP unless a different integration adds them). Operators may attach **`stackgen-mcp-consumer-tool-catalog-sop`** from `aios-agent-repo-to-iac` as an extra skill on the workflow. Uses AWS integration where MCP does not cover live APIs; SRE **deployment_rollback** remains attached for rollback-style operations.

## Usage

```hcl
module "sdlc" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-sdlc"

  model_names = {
    gpt4o         = module.foundation.model_names.gpt4o
    claude_sonnet = module.foundation.model_names.claude_sonnet
  }

  policy_ids = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
  }

  sre_agent_names = {
    sre_risk_posture = module.sre.agent_names.sre_risk_posture
  }

  sre_runbook_names = {
    deployment_rollback = "argocd-rollback"
    ssl_cert_renewal    = "tls-certificate-renewal"
  }

  integration_names = {
    aws_production = module.aws_integration.integration_name
    # Optional Guild names (examples): stackgen-mcp, google-integration, slack-integration
    # stackgen_mcp    = "stackgen-mcp"
    # gcp_production  = "google-integration"
    # slack           = "slack-integration"
    # github_scm      = "github-integration" # default when omitted; set when your Guild name differs
  }

  linear_mcp_integration_name = "linear-integration" # optional; empty skips Linear on project-manager
}
```
