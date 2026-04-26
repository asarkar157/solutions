# AIOS Agent — SDLC (Software Development Lifecycle)

Complete SDLC domain module with 9 specialized agents and 2 multi-stage workflows covering the full release pipeline and developer self-service request intake.

## Agents

| Agent | Role | Budget |
|-------|------|--------|
| `cloud-infrastructure-engineer` | AWS infra with shell access | $20/day |
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
Multi-channel request processing (Jira/Slack/Web): analyze → create tracking issue → check governance policy → process request → close issue.

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
  }
}
```
