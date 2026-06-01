# AIOS Agent — Self-Hosted Infra

Aiden for Infra: CloudFormation-focused agents and workflows for self-hosted AWS environments (private account, no public SaaS assumptions). Stack failure ingestion, read-only investigation, change-set recommendations with HITL for prod, drift audit, and pre-deploy review.

## Usage

```hcl
module "selfhosted_infra" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-selfhosted-infra?ref=main"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops   = module.policies.policy_ids.dangerous_ops
    sre_remediation = module.policies.policy_ids.sre_remediation
    prod_write_gate = module.policies.policy_ids.prod_write_gate
  }

  self_hosted_environment_label = "prod-us-east-1-vpc"
  aws_secret_id                 = module.aws_integration.secret_id

  cloudformation_stack_prefix_allowlist = ["prod-", "staging-"]
  blocked_stack_names                   = ["test-sandbox"]
  default_aws_regions                   = ["us-east-1", "us-west-2"]
  stack_ingest_allowed_environment_tags = ["production", "staging"]

  enable_ubuntu_cli    = true
  create_remote_runner = true
  remote_runner_name   = "selfhosted-cfn-runner"

  webhook_trigger_base_url = var.stackgen_url
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

## What It Creates

- 3 Agents: `cfn-event-ingest`, `infra-investigator`, `infra-change-engineer`
- 11 Runbook SOPs (stack normalization, investigation, change-set recommendation, drift audit, pre-deploy review)
- 3 Workflows: `cloudformation-stack-incident`, `cloudformation-drift-audit`, `cloudformation-pre-deploy-review`
- Optional `sg_webhook` for CloudFormation failure ingress when `enable_stack_failure_webhook = true`
- Optional `sg_evidence_checklist` `selfhosted-infra-rca` when `enable_evidence_checklist = true`
- Internal AWS integration submodule (or attach existing integration)
- Optional Ubuntu CLI integration and remote runner for cfn-lint / VPC shell

## Workflow Stages — Stack Incident

| Stage | Type | Purpose |
|-------|------|---------|
| stack-ingest-filter | policy_check (templated Rego) | Filter by stack prefix, blocked names, environment tag |
| normalize-stack-event | agent | Parse stack failure payload |
| analyze-stack-events | agent | Failed resources and rollback reasons |
| correlate-aws-resources | agent | Underlying AWS resource errors |
| review-template | agent | Template body, parameters, policy issues |
| synthesize-infra-rca | agent | Cross-signal RCA synthesis |
| change-safety-gate | policy_check (inline Rego) | Block prod/production auto-changes |
| recommend-change-set | agent | Document change set; no prod execute without HITL |

## Workflow Stages — Drift Audit (read-only)

| Stage | Type | Purpose |
|-------|------|---------|
| inventory-stacks | agent | List stacks per region |
| detect-drift | agent | Drift detection per stack |
| report-drift | agent | Drift summary and recommendations |

## Workflow Stages — Pre-Deploy Review (read-only)

| Stage | Type | Purpose |
|-------|------|---------|
| validate-template-intent | agent | Template intent and deploy readiness |
| policy-sanity-check | agent | IAM, SG, encryption, exposure review |

## Outputs

| Name | Description |
|------|-------------|
| `agent_names` | Map of event-ingest / investigator / change-engineer agent names |
| `workflow_names` | Map of stack incident, drift audit, and pre-deploy review workflows |
| `aws_integration_name` | Resolved AWS integration name |
| `webhook_id` / `webhook_token` | CloudFormation failure ingress webhook credentials |
| `remote_runner_cli_start_command` | aiden-runner CLI command when remote runner is configured |

## Guardrails

The change engineer persona never executes `delete-stack` without explicit operator approval. Prod/production environments require HITL before mutating CloudFormation actions (enforced by change-safety-gate and `prod_write_gate` policy).
