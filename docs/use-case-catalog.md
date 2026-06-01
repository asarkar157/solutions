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

## Bifrost LLM (PrivateSaaS SRE)

[`aios-agent-privatesaas-sre`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-privatesaas-sre) is designed for customers who route all model traffic through an **OpenAI-compatible Bifrost gateway** instead of public LLM APIs. In the consumer root, register Bifrost as an `sg_guild_model_provider` + `sg_guild_model`, then pass those model names via `model_names` / `bifrost_model_names`. See the module README for a full example block.

---

## Related docs

| Doc | Purpose |
|-----|---------|
| [Module Catalog]({% include doc_url.html path="module-catalog.md" %}) | Filter by tag (`aiden`, `use-case`, `webhook`, deployment profile, tool name) |
| [Architecture]({% include doc_url.html path="architecture.md" %}) | Layer diagram including new SRE / integration modules |
| [SE Playbook]({% include doc_url.html path="se-playbook.md" %}) | Runnable `examples/scenarios/` demos for pre-sales (not every use-case row has a scenario yet) |
