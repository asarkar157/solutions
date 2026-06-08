---
layout: page
title: Use-case catalog
permalink: use-case-catalog/
nav_order: 4
---

# Aiden use-case catalog

Maps **customer situations** to **Terraform modules** in this library. Each row links to the module `README` for variables, outputs, and wiring. For interactive discovery, tag filters, and copy-paste snippets, use the **[Module Catalog]({% include doc_url.html path="module-catalog.md" %})**.

**Deployment profiles** (tags in the catalog): `saas` (single-tenant cloud SaaS), `multitenant` (tenant-scoped RCA), `privatesaas` (customer VPC / on-prem control plane), `selfhosted` (customer-owned AWS with CloudFormation). Many agents also expose optional **`sg_webhook`** ingress and **`remote-runner`** (aiden-runner) for shell-heavy paths.

---

## By customer situation

| Customer situation | Primary agent module | Typical integrations | Profile / pattern |
|--------------------|----------------------|----------------------|-------------------|
| Single-tenant Azure SaaS: PagerDuty pages → investigate in Datadog + Azure → match Confluence runbook → remediate via Azure Automation | [`aios-agent-azure-saas-sre`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-azure-saas-sre) | Datadog, PagerDuty, Confluence, Azure | `saas`, `webhook`, `remediation` |
| ServiceNow tickets: ingest change/incident → Grafana/Prometheus + AWS investigation → bounded AWS fix → Slack notify | [`aios-agent-sre-ticket-resolution`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-sre-ticket-resolution) | ServiceNow, Grafana, AWS, Slack | `webhook`, `tickets`, `remediation` |
| Multi-tenant SaaS: Datadog alert per tenant → cross-signal RCA (Datadog, GCP Logging, AWS ECS/CloudTrail, GitHub) → Slack publish + thread collaboration | [`aios-agent-multitenant-sre-rca`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-multitenant-sre-rca) | Datadog, GCP, AWS, GitHub, Slack | `multitenant`, `saas`, `webhook`, `rca` |
| PrivateSaaS ops: Grafana alert → AWS + PAN-OS investigation → bounded AWS remediation + connectivity audit | [`aios-agent-privatesaas-devops-sre`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-privatesaas-devops-sre) | Grafana, AWS, Palo Alto | `privatesaas`, `webhook`, `remediation` |
| PrivateSaaS SRE (Aiden for SRE): FireHydrant + Grafana ingest → GCP + internal console → multi-source runbooks → RCA (document-only prod recommendations) | [`aios-agent-privatesaas-sre`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-privatesaas-sre) | FireHydrant, Grafana, GCP, internal REST API | `privatesaas`, `webhook`, `rca`, **Bifrost LLM** |
| PrivateSaaS GitOps: Slack `/aiden` for npm/deploy/pipeline failures → GitLab, Argo CD, DynamoDB, SonarQube → optional Ubuntu CLI / remote runner | [`aios-agent-privatesaas-gitops-sre`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-privatesaas-gitops-sre) | GitLab, Argo CD, SonarQube, AWS, Slack, Ubuntu (optional) | `privatesaas`, `gitops`, `webhook`, `remote-runner` |
| Self-hosted private AWS: CloudFormation stack failure ingest → read-only AWS/CFN investigation → HITL change-set recommendations, drift audit, pre-deploy review | [`aios-agent-selfhosted-infra`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-selfhosted-infra) | AWS, Ubuntu CLI (optional), remote runner (optional) | `selfhosted`, `infra`, `webhook`, `remote-runner` |
| Developer intent → company-standard CloudFormation (catalog reuse) → GitHub PR → change-set preview; Bedrock Sonnet 4.6 only | [`aios-agent-cfn-author`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-cfn-author) | AWS, GitHub, Ubuntu CLI, `aios-foundation-bedrock` | `cloudformation`, `bedrock`, `iac`, `selfhosted` |
| Periodic / on-demand CloudFormation drift: parallel detect, FIX_DRIFT (risk) vs INCORPORATE_VIA_PR (reconcile PR) | [`aios-agent-cfn-author`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-cfn-author) | AWS, GitHub, optional `aios-agent-schedules` cron | `cloudformation`, `drift`, `bedrock`, `selfhosted` |
| Application monolith → microservices: boundary scan + CCE (Go/Java/JS/TS), DDD guidance PR, optional `services/<name>/` scaffold + extract PR; optional aiden-runner for large repos | [`aios-agent-monorepo-services-splitter`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-monorepo-services-splitter) | GitHub, Ubuntu CLI, optional remote runner | `github`, `ubuntu`, `monorepo`, `microservices`, `ddd`, `cce`, `cce-enterprise` |
| Terraform/OpenTofu monolith state → logical groups + optional per-group roots / AppStacks; optional CCE on app repo | [`aios-agent-db-state-splitter`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-db-state-splitter) | GitHub, Ubuntu CLI, StackGen MCP (optional) | `terraform`, `iac`, `github`, `ubuntu`, `cce`, `modernization` |
| PR adds new cloud API calls → CCE entitlement delta comment before merge (`pre-deploy-iam-review`) | [`aios-agent-terraform-bot`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-terraform-bot) | GitHub, Ubuntu CLI | `cce`, `iam-gate`, `pre-deploy-iam`, `cce-enterprise` |
| Grafana alert storm → CCE incident-scoping on service repos → scoped RCA (not whole org) | [`aios-agent-alert-triage`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-alert-triage) | Grafana, GitHub, Ubuntu, Slack | `sre`, `cce`, `incident-scope`, `cce-enterprise` |
| Weekly SLO error budget + config drift digest from Git OpenSLO + Grafana | [`aios-agent-slo-health`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-slo-health) | GitHub, Grafana, Slack | `observability`, `slo`, `openslo`, `schedule` |
| Discover SLOs from Grafana dashboards → OpenSLO YAML → GitHub PR | [`aios-agent-slo-health`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-slo-health) | GitHub, Grafana, Ubuntu CLI | `observability`, `slo`, `openslo`, `webhook` |
| Reconcile OpenSLO Git drift with Grafana alert rules via PR | [`aios-agent-slo-health`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-slo-health) | GitHub, Grafana, Ubuntu CLI | `observability`, `slo`, `drift`, `webhook` |
| Quarterly multi-repo CCE audit evidence (PCI/HIPAA/SOC touchpoints) | [`aios-agent-compliance-auditor`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-compliance-auditor) | GitHub, Ubuntu, AWS | `compliance`, `cce`, `compliance-evidence`, `cce-enterprise` |
| GitOps deploy failure → CCE code scope → scoped Argo CD rollback (not cluster-wide) | [`aios-agent-privatesaas-gitops-sre`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-privatesaas-gitops-sre) | GitLab, Argo CD, SonarQube, AWS, Slack, Ubuntu | `gitops`, `cce`, `gitops-scope`, `cce-enterprise` |
| npm/Dependabot noise → CCE CVE reachability → fix PRs for reachable only | [`aios-agent-supply-chain-security`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-supply-chain-security) | GitHub, Ubuntu | `security`, `cce`, `cve-reachability`, `cce-enterprise` |
| Platform NL infra request → CCE entitlement guard on app repos → PoLP-sized IAM | [`examples/agentic-infrastructure`]({{ site.github.repository_url }}/tree/main/examples/agentic-infrastructure) + [`aios-agent-repo-to-iac`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-repo-to-iac) | AWS, GitHub, StackGen MCP | `platform`, `cce`, `entitlement-guard`, `cce-enterprise` |

---

## CCE × Guild enterprise workflows

Full index with demo scenarios: **[CCE enterprise workflows]({% include doc_url.html path="cce-enterprise-workflows.md" %})**.

---

## Monolith → microservices (application + IaC)

For customers splitting **both** application code and infrastructure state:

1. **[Monorepo services split]({% include doc_url.html path="monorepo-services-splitter.md" %})** — `monorepo-services-split-analysis` then `monorepo-services-split-extract` on the application repo.
2. **[DB state split]({{ site.github.repository_url }}/tree/main/modules/aios-agent-db-state-splitter)** — group Terraform/OpenTofu state and optional AppStack materialization.

Demo scenario: `make demo SCENARIO=monorepo-services-split`. Pair with **`db-state-splitter`** for full-stack modernization (`make demo` on both roots or compose in `examples/complete`).

Flagship CCE demo — three-tier pipeline documented in [monorepo-services-splitter]({% include doc_url.html path="monorepo-services-splitter.md" %}) and [CCE enterprise workflows]({% include doc_url.html path="cce-enterprise-workflows.md" %}).

---

## CloudFormation Author (Bedrock)

Intent → catalog-aligned CloudFormation → GitHub PR → change-set preview; optional FedRAMP/baseline compliance gate and drift reconcile PRs. Full trigger examples (chat, webhooks, schedule): **[CloudFormation Author]({% include doc_url.html path="cfn-author.md" %})**.

Demo: `make demo SCENARIO=cfn-author`. Sample webhook payloads: [`docs/samples/cfn-intent-webhook.json`]({{ site.github.repository_url }}/blob/main/docs/samples/cfn-intent-webhook.json), [`cfn-compliance-webhook.json`]({{ site.github.repository_url }}/blob/main/docs/samples/cfn-compliance-webhook.json), [`cfn-drift-webhook.json`]({{ site.github.repository_url }}/blob/main/docs/samples/cfn-drift-webhook.json).

---

## Integration modules (wire standalone or via agents)

| Tool | Module | Used by (examples) |
|------|--------|-------------------|
| Datadog | [`aios-integration-datadog`]({{ site.github.repository_url }}/tree/main/modules/aios-integration-datadog) | Azure SaaS SRE, multi-tenant RCA |
| PagerDuty | [`aios-integration-pagerduty`]({{ site.github.repository_url }}/tree/main/modules/aios-integration-pagerduty) | Azure SaaS SRE |
| FireHydrant | [`aios-integration-firehydrant`]({{ site.github.repository_url }}/tree/main/modules/aios-integration-firehydrant) | PrivateSaaS SRE |
| ServiceNow | [`aios-integration-servicenow`]({{ site.github.repository_url }}/tree/main/modules/aios-integration-servicenow) | SRE ticket resolution |
| Confluence | [`aios-integration-confluence`]({{ site.github.repository_url }}/tree/main/modules/aios-integration-confluence) | Azure SaaS SRE (runbooks) |
| Palo Alto PAN-OS | [`aios-integration-paloalto`]({{ site.github.repository_url }}/tree/main/modules/aios-integration-paloalto) | PrivateSaaS DevOps/SRE |
| Internal operator console (REST) | [`aios-integration-internal-tool`]({{ site.github.repository_url }}/tree/main/modules/aios-integration-internal-tool) | PrivateSaaS SRE |
| GitLab | [`aios-integration-gitlab`]({{ site.github.repository_url }}/tree/main/modules/aios-integration-gitlab) | PrivateSaaS GitOps SRE |
| Argo CD | [`aios-integration-argocd`]({{ site.github.repository_url }}/tree/main/modules/aios-integration-argocd) | PrivateSaaS GitOps SRE |
| SonarQube | [`aios-integration-sonarqube`]({{ site.github.repository_url }}/tree/main/modules/aios-integration-sonarqube) | PrivateSaaS GitOps SRE |

---

## Bedrock LLM (AWS-native Claude)

[`aios-foundation-bedrock`]({{ site.github.repository_url }}/tree/main/modules/aios-foundation-bedrock) registers a Guild **Bedrock** model provider and **Claude Sonnet 4.6** via cross-region inference profile (`us.anthropic.claude-sonnet-4-6` style). Use when agents should call Anthropic through **AWS Bedrock** (IAM role or static keys) instead of direct API keys from `aios-foundation`.

```hcl
module "foundation_bedrock" {
  source = "github.com/appcd-dev/solutions//modules/aios-foundation-bedrock?ref=main"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  aws_region     = "us-east-1"
  bedrock_auth   = { use_iam_role = true }
}

module "aws_sre" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-aws-sre?ref=main"

  model_names = module.foundation_bedrock.model_names
  # ...
}
```

Demo scenario: [`examples/scenarios/bedrock-sonnet-demo/`]({{ site.github.repository_url }}/tree/main/examples/scenarios/bedrock-sonnet-demo/).

---

## Bifrost LLM (PrivateSaaS SRE)

[`aios-agent-privatesaas-sre`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-privatesaas-sre) is designed for customers who route all model traffic through an **OpenAI-compatible Bifrost gateway** instead of public LLM APIs. In the consumer root, register Bifrost as an `sg_guild_model_provider` + `sg_guild_model`, then pass those model names via `model_names` / `bifrost_model_names`. See the module README for a full example block.

---

## Related docs

| Doc | Purpose |
|-----|---------|
| [Module Catalog]({% include doc_url.html path="module-catalog.md" %}) | Filter by tag (`aiden`, `use-case`, `webhook`, deployment profile, tool name) |
| [Architecture]({% include doc_url.html path="architecture.md" %}) | Layer diagram including new SRE / integration modules |
| [SE Playbook]({% include doc_url.html path="se-playbook.md" %}) | Runnable `examples/scenarios/` demos for pre-sales (not every use-case row has a scenario yet) |
| [Monorepo services split]({% include doc_url.html path="monorepo-services-splitter.md" %}) | Analysis → guidance PR → extract workflow guide |
| [CCE × AIOS integration map]({% include doc_url.html path="cce-agent-integrations.md" %}) | Which agent modules run which CCE usage guides |
| [CCE enterprise workflows]({% include doc_url.html path="cce-enterprise-workflows.md" %}) | Seven enterprise superpowers with demo scenarios |
