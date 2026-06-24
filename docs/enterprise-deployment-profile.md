---
layout: page
title: Enterprise deployment profile
permalink: enterprise-deployment-profile/
nav_order: 7
parent: Topic guides
---

# Enterprise deployment profile

Maps the **post-PoC enterprise architecture** to **this repository** and **platform repos**. Use this when wiring a single-tenant Guild stack for CloudFormation governance + optional Terraform module quality.

**Related:** [CloudFormation Author]({% include doc_url.html path="cfn-author.md" %}), [`aios-agent-aiden-infra`](../modules/aios-agent-aiden-infra/), [`aios-agent-selfhosted-infra`](../modules/aios-agent-selfhosted-infra/).

---

## Who owns what

| Concern | Owner | This repo |
|---------|-------|-----------|
| Workflows, runbooks, webhooks | **solutions** | `aios-agent-cfn-author`, `aios-cfn-governance-runbooks` |
| Headless CI invoke | **Guild (existing)** | `POST /api/v1/webhooks/trigger` + `sg_webhook` |
| Shell / cfn-lint / gh | **Guild remote runner (existing)** | `aios-remote-runner` spawn contracts |
| Skills content | **solutions** + Guild skillsync | `modules/aios-agent-cfn-author/skills/` |
| SSO / workspace ACL | **appcd auth** | Not in solutions — pass `workspace_id` only |
| LLM proxy headers | **genie + trpc-agent-go** | `LLM_EXTRA_HTTP_HEADERS` env on runner |
| StackGen Core MCP | **StackGen product** | One `stackgen-mcp` per tenant; attach terraform-bot by secret |

---

## Module choice

| Need | Module | Do not |
|------|--------|--------|
| Intent → CFN PR, drift reconcile, FedRAMP preflight | [`aios-agent-cfn-author`](../modules/aios-agent-cfn-author/) | — |
| CFN stack **failure** ingest, read-only RCA, pre-deploy review | [`aios-agent-selfhosted-infra`](../modules/aios-agent-selfhosted-infra/) | Duplicate drift agents on same tenant |
| CFN + TF module quality in one `tofu apply` | [`aios-agent-aiden-infra`](../modules/aios-agent-aiden-infra/) | Second StackGen MCP integration |

**Rule:** Do not deploy **both** `cfn-author` drift management and `selfhosted-infra` drift audit for the same stack prefix without reading each README.

---

## Single apply entry (dual IaC)

```hcl
module "aiden_infra" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-aiden-infra?ref=main"

  model_names = module.foundation_bedrock.model_names
  policy_ids = {
    dangerous_ops   = module.policies.policy_ids.dangerous_ops
    prod_write_gate = module.policies.policy_ids.prod_write_gate
  }

  target_repository_full_name = "org/infra-templates"
  github_secret_id            = module.github_integration.secret_id
  aws_secret_id               = module.aws_integration.secret_id

  workspace = {
    workspace_id         = "org/infra-templates"
    primary_iac          = "cloudformation"
    self_healing_allowed = false
  }

  enable_intent_webhook     = true
  enable_compliance_webhook = true
  enable_drift_webhook      = true
  enable_security_guardrails_gate = true

  webhook_trigger_base_url = var.stackgen_url
  webhook_trigger_org_id   = var.stackgen_project_id

  enable_terraform_bot     = true
  stackgen_token_secret_id = var.stackgen_openapi_secret_id
}
```

---

## Webhook ingress (CI / drift Lambda)

| Webhook | Payload doc | Sample |
|---------|-------------|--------|
| Intent | [`WEBHOOKS.md`](../modules/aios-agent-cfn-author/docs/WEBHOOKS.md) | [`cfn-intent-webhook.json`](samples/cfn-intent-webhook.json) |
| Compliance preflight | same | [`cfn-compliance-webhook.json`](samples/cfn-compliance-webhook.json) |
| Drift batch | same | [`cfn-drift-webhook.json`](samples/cfn-drift-webhook.json) |

Required fields: `correlation_id`, optional `workspace_id`, optional `confirm_deploy: "false"` for PR-only mode.

---

## Skills sync (one-time per tenant)

1. Register Guild **skill source** → git path `modules/aios-agent-cfn-author/skills/` (branch pinned).
2. Run skillsync / wait for sync job.
3. Verify `recommended_skill_names` from `tofu output`.
4. After module upgrades, **recycle the cfn-author Ubuntu sidecar** so `CFN_AUTHOR_SCRIPT_PACK_TARBALL_B64` matches `script_pack_version` (required for validate / security-guardrails / open-pr runners).

---

## Troubleshooting: intent workflow did not open a PR

Check the execution summary for which gate skipped `open-pr`:

| Symptom in notes / summary | Cause | Fix |
|----------------------------|-------|-----|
| `security_guardrails_blocked` or `policy_scan_blocked` | Checkov/cfn-nag critical findings | Fix template; review `generated/security-guardrails-report.json` |
| `validate_blocked` / `cfn_lint_passed=false` | cfn-lint or missing `WORK_ROOT/generated/template.yaml` | Re-run generate-template; ensure agent writes template file |
| `compliance_blocked` / `compliance_summary:FAIL` | FedRAMP/baseline hard-fail | Adjust intent or baseline; use compliance webhook preflight first |
| `governed_deployment_blocked` | Org deployment process gate | Satisfy governed-deployment runbook or use `confirm_deploy: "false"` PR-only mode |
| `pr_blocker=missing_script_pack` / `clone_blocker=auth_or_network` | Script pack stale or GitHub PAT | `tofu apply` + recycle Ubuntu sidecar; PAT needs `repo` scope on target repo |
| `pr_blocker=missing_template_body` | Template not on disk before commit-pr | generate-template must persist YAML under `WORK_ROOT/generated/template.yaml` |
| Jump to `final-intent-summary` with no `pr_url` | Any conditional_skip gate above | Inspect stage timeline for first skip reason |

Runners use spawn-context **Commit PR command** with default `REPO_FULL_NAME=${target_repository_full_name}` — override only when `github_repo_override` is in notes.

---

## LLM egress (M5 — genie)

**Path A — managed Bedrock:** set on aiden-runner / Guild deployment:

```bash
export LLM_EXTRA_HTTP_HEADERS='{"X-Custom-Profile":"staging","X-Asset-Id":"infra-workspace-1"}'
```

**Path B — corporate proxy:** Guild `POST /api/v1/model-providers` with proxy `host`.

---

## Milestone checklist

| Milestone | Status | Notes |
|-----------|--------|-------|
| **M1** CFN governance PoC | Done | cfn-author + governance runbooks |
| **M2** Workspace, compliance JSON, drift webhook, skills, security guardrails + script pack | Done | This repo |
| **M3** Core MCP tools | Product | StackGen mothership |
| **M5** LLM egress env | Done in genie | OpenAPI headers TBD |
