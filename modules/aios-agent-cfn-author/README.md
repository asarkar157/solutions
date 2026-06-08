# AIOS Agent — CloudFormation Author

Aiden for CloudFormation: **Intent to Infrastructure** (developer requests → catalog-aware templates → GitHub PR → change-set preview) and **Drift Management** (parallel drift detection, risk classification, optional reconcile PR). Designed for **Bedrock Claude Sonnet 4.6 only** (`us-east-1`).

## Use cases

### 1. Intent to Infrastructure

Integrates with the customer's AWS account, existing CloudFormation template catalog, and source control. Handles developer chat requests and converts them into templates that follow company best practices, then opens a PR and previews changes via change set (never executes).

### 2. Drift Management

On-demand or **scheduled** drift scans across stacks. When drift is detected, Aiden classifies each change:

- **FIX_DRIFT** — operational, compliance, or security risk (recommendation only in v1)
- **INCORPORATE_VIA_PR** — valid desired-state change → reconcile PR to the IaC repo
- **IGNORE** — low-risk cosmetic drift

## Usage

```hcl
module "foundation_bedrock" {
  source = "github.com/appcd-dev/solutions//modules/aios-foundation-bedrock?ref=main"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  aws_region     = "us-east-1"

  bedrock_auth = { use_iam_role = true }
}

module "cfn_author" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-cfn-author?ref=main"

  model_names = module.foundation_bedrock.model_names # Bedrock only — validated at plan time

  policy_ids = {
    dangerous_ops   = module.policies.policy_ids.dangerous_ops
    prod_write_gate = module.policies.policy_ids.prod_write_gate
  }

  target_repository_full_name = "org/infra-templates"
  cfn_template_catalog_path     = "cloudformation/catalog/"
  cfn_template_path_prefix      = "cloudformation/"

  github_secret_id = module.github_integration.secret_id
  aws_secret_id    = module.aws_integration.secret_id

  # AWS target role must allow cloudformation:CreateChangeSet for preview-changes.
  # Provision via modules/aios-cfn-preview-iam or pass an existing role through aios-integration-aws.

  enable_drift_schedule = true
  drift_schedule_cron   = "0 6 * * *"

  enable_intent_webhook    = true
  enable_drift_webhook     = true
  webhook_trigger_base_url = var.stackgen_url
  webhook_trigger_org_id   = var.stackgen_project_id

  workspace = {
    workspace_id         = "org/infra-templates"
    source_type          = "git"
    primary_iac          = "cloudformation"
    self_healing_allowed = false
  }
}
```

## Remote webhooks

Full JSON contracts: [`docs/WEBHOOKS.md`](docs/WEBHOOKS.md).

When `enable_intent_webhook = true` (default), the module creates `sg_webhook` **`cfn-intent-to-infrastructure`**. Remote systems POST JSON to StackGen:

```bash
curl -X POST "${INTENT_WEBHOOK_INGRESS_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "intent": "Create an S3 bucket with versioning in us-east-1",
    "stack_name": "staging-data",
    "environment": "staging",
    "workspace_id": "org/infra-templates",
    "correlation_id": "ci-12345"
  }'
```

When `enable_drift_webhook = true`, **`cfn-drift-management`** accepts batch drift payloads:

```json
{
  "correlation_id": "drift-scan-1",
  "drifted_stacks": [
    { "stack_name": "staging-vpc", "region": "us-east-1" }
  ]
}
```

Set `webhook_trigger_base_url` to your Guild URL; after `tofu apply`, use output **`intent_webhook_ingress_payload_url`** (includes `apiKey`) or `webhook_trigger_endpoint` with `Authorization: Bearer <token>`.

Optional **`webhook_allowed_cidrs`** restricts caller IP ranges.

## Governance pillars

The module nests [`aios-cfn-governance-runbooks`](../aios-cfn-governance-runbooks/) and wires five enterprise use cases into workflows:

| Pillar | Workflow / stages |
|--------|-------------------|
| **Remote orchestration** | Intent webhook + `normalize-remote-orchestration` stage; optional compliance webhook |
| **Contextual compliance** | Intent stages + standalone `cfn-contextual-compliance` (FedRAMP + org baseline) |
| **Hardened synthesis** | `generate-template` + `hardened-synthesis-review` (knowledge base + catalog) |
| **Governed deployments** | `governed-deployment-gate` + standalone `cfn-governed-deployment` |
| **Continuous governance** | `cloudformation-drift-management` + continuous governance runbook on classify/report |

Configure with `org_baseline_name`, `fedramp_profile`, `knowledge_base_path`, and `deployment_process_doc`. Security guardrails (Checkov + cfn-nag) run deterministically via embedded script pack before PR.

## What it creates

| Resource | Count | Description |
|----------|-------|-------------|
| Agents | 2 | `cfn-author`, `cfn-drift-manager` |
| Workflows | 2–4 | `intent-to-infrastructure`, `cloudformation-drift-management`, optional `cfn-contextual-compliance`, `cfn-governed-deployment` |
| Governance runbooks | 5 | From nested `aios-cfn-governance-runbooks` |
| Integrations | 3 | GitHub, AWS, Ubuntu CLI (optional remote runner) |
| Webhooks | 0–3 | Intent (default on); compliance when `enable_compliance_webhook = true`; drift when `enable_drift_webhook = true` |
| Schedules | 0–1 | Periodic drift workflow when `enable_drift_schedule = true` |

## Skills

Markdown sources live under [`skills/`](skills/). Sync to Guild via a skill source pointing at this directory (see `outputs.recommended_skill_names`).

| Skill | Workflow |
|-------|----------|
| `cfn-developer-intent-handler` | Intent — parse requirements |
| `cfn-company-best-practices` | Intent — generate / validate |
| `cfn-template-catalog-discovery` | Intent — catalog reuse |
| `cfn-architecture-fit-review` | Intent — post-synthesis NFR + architecture lint |
| `cfn-drift-scan-orchestration` | Drift — ingress / inventory / parallel detect |
| `cfn-drift-risk-classifier` | Drift — FIX vs INCORPORATE vs IGNORE |
| `cfn-drift-incorporate-pr` | Drift — reconcile PR |

## Workspace binding

Optional `workspace` object binds intent and drift workflows to a logical workspace (defaults inherit `target_repository_full_name` and branch/path):

```hcl
workspace = {
  workspace_id         = "org/infra-templates"
  source_type          = "git" # git | gitlab | s3
  primary_iac          = "cloudformation"
  self_healing_allowed = false
  force_new_workspace  = false
}
```

Resolved values are in output `workspace`.

## PoC scope vs full product

| In this module (PoC) | Not in this module |
|----------------------|-------------------|
| CFN intent + drift workflows, governance runbooks | Platform SSO / workspace ACL (appcd) |
| Webhook ingress (intent, compliance, drift) | Self-healing stack execution |
| Workspace object + structured compliance_report schema | StackGen Core MCP tool replacement (product) |
| Skills pack + Guild skill source sync | Per-request LLM header templates |
| Security guardrails gate (Checkov + cfn-nag JSON report) before PR | Snyk integration (hook documented; integration TBD) |
| Embedded script pack on Ubuntu (`CFN_AUTHOR_SCRIPT_PACK_TARBALL_B64`) | — |
| [`aios-agent-aiden-infra`](../aios-agent-aiden-infra/) composition entry | Dual CFN+TF unified orchestration beyond composition module |

For CFN stack **failure** ingest and pre-deploy review, use [`aios-agent-selfhosted-infra`](../aios-agent-selfhosted-infra/) — see [`docs/tr-deployment-profile.md`](../../docs/tr-deployment-profile.md).

## Workflow 1 — intent-to-infrastructure (17 stages)

| Stage | Type |
|-------|------|
| parse-intent | agent + runner (parse-requirements + catalog-discover scripts) |
| intent-blocked-gate | conditional_skip |
| compliance-check | agent + runner (deterministic compliance-check.sh) |
| compliance-blocked-gate | conditional_skip |
| synthesize-template | agent (catalog-aware generate; reads catalog_candidates.json) |
| quality-check | agent + runner (cfn-lint, parallel Checkov/cfn-nag, AWS validate) |
| quality-rework-loop | loop_stage |
| quality-blocked-gate | conditional_skip |
| architecture-fit-review | agent + runner (deterministic architecture-lint.sh) |
| architecture-blocked-gate | conditional_skip (FAIL → skip PR) |
| open-pr | agent + runner (governed-deployment-check + commit-and-pr.sh) |
| publish-blocked-gate | conditional_skip |
| preview-disabled-gate | conditional_skip (module enable_change_set_preview=false) |
| preview-skip-gate | conditional_skip (confirm_deploy not true) |
| preview-safety-gate | policy_check |
| preview-changes | agent + runner (change-set-preview.sh when enabled) |
| final-intent-summary | agent + runner |

### Standard profile tfvars (recommended)

```hcl
enable_change_set_preview       = false  # preview only when true AND confirm_deploy=true
enable_security_guardrails_gate = true
cfn_lint_max_iterations         = 1
max_template_lines              = 500
enable_contextual_compliance_workflow = true   # standalone CI workflow
enable_governed_deployment_workflow   = false  # disable if unused
```

Merged for cost/latency: script-first runners for parse, compliance, quality, architecture lint, PR, preview, and summary; guardrails scanners run in parallel on Ubuntu inside one spawn.

## Workflow 1b — cfn-contextual-compliance (optional)

CI/CD preflight: parse → normalize remote payload → compliance report (no synthesis/PR). Enable with `enable_contextual_compliance_workflow = true` (default). Webhook: `enable_compliance_webhook = true`.

## Workflow 1c — cfn-governed-deployment (optional)

Validated template → governed PR process only. Enable with `enable_governed_deployment_workflow = true` (default).

## Workflow 2 — cloudformation-drift-management

| Stage | Type |
|-------|------|
| normalize-drift-ingress | agent |
| parse-drift-scope | agent |
| scope-blocked-gate | conditional_skip |
| inventory-stacks | agent |
| inventory-empty-gate | conditional_skip |
| parallel-detect-drift | agent + parallel batch runners |
| parallel-fan-in-gate | conditional_skip |
| drift-retry-loop | loop_stage |
| synthesize-drift-report | agent |
| classify-drift-recommendation | agent |
| no-drift-skip-gate | conditional_skip |
| reconcile-template-diff | agent |
| reconcile-pr-skip-gate | conditional_skip |
| open-reconcile-pr | agent + runner |
| final-drift-summary | agent |

## Outputs

| Name | Description |
|------|-------------|
| `agent_names` | cfn-author, cfn-drift-manager |
| `workflow_names` | Up to four workflow names |
| `governance_runbook_names` | Five reusable governance SOP names |
| `recommended_skill_names` | Skills to register |
| `drift_schedule_names` | Cron schedules when enabled |
| `intent_webhook_id` / `intent_webhook_token` | Remote trigger credentials |
| `intent_webhook_ingress_payload_url` | Full trigger URL with apiKey |
| `compliance_webhook_ingress_payload_url` | Compliance preflight trigger URL with apiKey |
| `drift_webhook_*` | Drift webhook credentials when `enable_drift_webhook = true` |
| `workspace` | Resolved workspace binding |

Compliance JSON schema: [`docs/compliance-report-schema.json`](docs/compliance-report-schema.json).

## Requirements

- StackGen provider `>= 0.1.25`
- `model_names` must be exactly one Bedrock model (default `claude-sonnet-bedrock`)
- GitHub + AWS integrations (self-contained or shared)
