---
layout: page
title: Architecture
permalink: architecture/
nav_order: 20
---

How **StackGen-facing modules** in this repository stack together—**foundation and policies** at the base, **integrations** and **agents** above, and **workflow** compositions on top. Many paths are **AIOS-oriented** (prefixed `aios-*`) for faster solution delivery; the same layering idea applies if you mix in your own roots. The **[Module Catalog]({% include doc_url.html path="module-catalog.md" %})** is the authoritative list of every shipped module (inputs, outputs, and copy-paste snippets). The **[Use-case catalog]({% include doc_url.html path="use-case-catalog.md" %})** maps customer deployment profiles (SaaS, PrivateSaaS, multi-tenant, self-hosted) to those modules. For formatting, validation, and CI for **this repository** (Makefile, GitHub Actions, registry token), see the root [README](https://github.com/appcd-dev/solutions/blob/main/README.md) — **Local verification** and **Continuous integration**. (If you use a fork or different repo name, adjust that link or open `README.md` at the repository root.)

## Layered dependency graph

```mermaid
graph TD
    subgraph "Layer 3 — Solutions"
        WF_IR["aios-workflow-incident-response"]
        WF_PS["aios-workflow-predictive-sre"]
        WF_FD["aios-workflow-feature-development"]
    end

    subgraph "Layer 2 — Agents"
        A_SRE["aios-agent-sre<br/>(5 agents, 2 workflows)"]
        A_AWS["aios-agent-aws-sre"]
        A_GCP["aios-agent-gcp-sre"]
        A_AZ["aios-agent-azure-devops"]
        A_GR["aios-agent-grafana-sre"]
        A_SE["aios-agent-software-engineering"]
        A_SC["aios-agent-supply-chain-security"]
        A_WA["aios-agent-workspace-assistant"]
        A_MK["aios-agent-marketing"]
        A_CO["aios-agent-compliance-auditor"]
        A_FO["aios-agent-cost-optimizer"]
        A_OB["aios-agent-onboarding"]
        A_PS["aios-agent-predictive-sre"]
        A_LFO["aios-agent-langfuse-observer"]
        A_SOC["aios-agent-soc-analyst"]
        A_TFB["aios-agent-terraform-bot"]
        A_DBS["aios-agent-db-state-splitter"]
        A_MON["aios-agent-monorepo-services-splitter"]
        A_AZS["aios-agent-azure-saas-sre"]
        A_STR["aios-agent-sre-ticket-resolution"]
        A_MTR["aios-agent-multitenant-sre-rca"]
        A_PSD["aios-agent-privatesaas-devops-sre"]
        A_PS["aios-agent-privatesaas-sre"]
        A_PSG["aios-agent-privatesaas-gitops-sre"]
        A_SHI["aios-agent-selfhosted-infra"]
    end

    subgraph "Layer 1 — Integrations"
        I_AWS["aios-integration-aws"]
        I_AZ["aios-integration-azure"]
        I_GCP["aios-integration-gcp"]
        I_GR["aios-integration-grafana"]
        I_LF["aios-integration-langfuse"]
        I_SL["aios-integration-slack"]
        I_GH["aios-integration-github"]
        I_UB["aios-integration-ubuntu"]
        I_CH["aios-integration-clickhouse"]
        I_DD["aios-integration-datadog"]
        I_PD["aios-integration-pagerduty"]
        I_SN["aios-integration-servicenow"]
        I_CF["aios-integration-confluence"]
        I_PA["aios-integration-paloalto"]
        I_FH["aios-integration-firehydrant"]
        I_IT["aios-integration-internal-tool"]
        I_GL["aios-integration-gitlab"]
        I_AC["aios-integration-argocd"]
        I_SQ["aios-integration-sonarqube"]
    end

    subgraph "Layer 0 — Foundation"
        F["aios-foundation<br/>(models, secrets)"]
        P["aios-policies<br/>(shared guardrails)"]
    end

    %% Layer 3 → Layer 2
    WF_IR --> A_SRE
    WF_PS --> A_PS
    WF_FD --> A_SE

    %% Layer 2 → Layer 1
    A_AWS --> I_AWS
    A_GCP --> I_GCP
    A_AZ --> I_AZ
    A_GR --> I_GR
    A_SE --> I_GH
    A_CO --> I_AWS
    A_CO --> I_GH
    A_FO --> I_AWS
    A_PS --> I_GH
    A_PS --> I_GR
    A_PS --> I_AWS
    A_LFO --> I_LF
    A_TFB --> I_GH
    A_DBS --> I_GH
    A_MON --> I_GH
    A_MON --> I_UB
    A_AZS --> I_AZ
    A_AZS --> I_DD
    A_AZS --> I_PD
    A_AZS --> I_CF
    A_STR --> I_SN
    A_STR --> I_GR
    A_STR --> I_AWS
    A_STR --> I_SL
    A_MTR --> I_DD
    A_MTR --> I_GCP
    A_MTR --> I_AWS
    A_MTR --> I_GH
    A_MTR --> I_SL
    A_PSD --> I_GR
    A_PSD --> I_AWS
    A_PSD --> I_PA
    A_PS --> I_GR
    A_PS --> I_GCP
    A_PS --> I_FH
    A_PS --> I_IT
    A_PSG --> I_GL
    A_PSG --> I_AC
    A_PSG --> I_SQ
    A_PSG --> I_AWS
    A_PSG --> I_SL
    A_SHI --> I_AWS

    %% Layer 2 → Layer 0
    A_SRE --> F
    A_SRE --> P
    A_AWS --> F
    A_AWS --> P
    A_GCP --> F
    A_GCP --> P
    A_LFO --> F
    A_LFO --> P
    A_SOC --> F
    A_SOC --> P
    A_TFB --> F
    A_TFB --> P
    A_DBS --> F
    A_DBS --> P
    A_MON --> F
    A_MON --> P
    A_AZS --> F
    A_AZS --> P
    A_STR --> F
    A_STR --> P
    A_MTR --> F
    A_MTR --> P
    A_PSD --> F
    A_PSD --> P
    A_PS --> F
    A_PS --> P
    A_PSG --> F
    A_PSG --> P
    A_SHI --> F
    A_SHI --> P

    %% Layer 1 → Layer 0
    I_AWS --> F
    I_AZ --> F
    I_GCP --> F
    I_GR --> F
    I_LF --> F
    I_SL --> F
    I_GH --> F
    I_UB --> F
```

## Resource Inventory by Module

The table below is a **snapshot** of several heavily used agent modules (agent / runbook / workflow counts are approximate). For **every** integration and agent module—including **Langfuse**, **StackGen MCP guardrails**, **SDLC**, **Repo to IaC**, **schedules**, **SOC Analyst**, **DB optimizer**, **drift detective**, **incident commander**, and others—use the **[Module Catalog]({% include doc_url.html path="module-catalog.md" %})** and the module `README.md` under `modules/`.

<details markdown="1">
<summary>Show inventory table</summary>

| Module | Agents | Runbooks | Workflows | Policies | Remediation Patterns |
|--------|--------|----------|-----------|----------|---------------------|
| aios-agent-sre | 5 | 9 | 2 | — | 8 |
| aios-agent-aws-sre | 1 | 4 | 2 | 1 | — |
| aios-agent-gcp-sre | 1 | 4 | 2 | 1 | — |
| aios-agent-azure-devops | 1 | 4 | 1 | — | 2 |
| aios-agent-grafana-sre | 1 | 8 | — | — | — |
| aios-agent-software-engineering | 2 | 3 | 1 | — | — |
| aios-agent-supply-chain-security | 1 | 3 | 1 | 3 | 2 |
| aios-agent-workspace-assistant | 1 | 1 | 1 | — | — |
| aios-agent-marketing | 1 | 5 | 2 | — | — |
| aios-agent-compliance-auditor | 1 | 4 | 1 | 1 | — |
| aios-agent-cost-optimizer | 1 | 4 | 1 | — | — |
| aios-agent-onboarding | 1 | 3 | 1 | — | — |
| aios-agent-predictive-sre | 1 | 2 | 1 | — | — |
| aios-agent-repo-to-iac | 1 | 6 | 2 | 1 | — |
| aios-agent-sdlc | 9 | 1 | 2 | 12+ | — |
| aios-agent-ubuntu-cli | 1 | 4 | — | 2 | — |
| aios-agent-clickhouse-inspector | 1 | 5 | — | 3 | — |
| aios-agent-langfuse-observer | 1 | 4 | 1 | 3 | — |
| aios-agent-soc-analyst | 1 | 2 | 2 | 1 | — |
| aios-agent-stackgen-mcp-policy | 1 | — | — | 1 | — |
| aios-agent-terraform-bot | 1 | — | 1 | 1 | — |
| aios-agent-db-state-splitter | 2+ | — | 2 | 1 | — |
| aios-agent-monorepo-services-splitter | 2–3 | — | 2 | 1 | — |
| aios-agent-db-optimizer | 1 | 1 | 1 | — | — |
| aios-agent-iac-drift-detective | 1 | 1 | 1 | — | — |
| aios-agent-sre-incident-commander | 1 | 1 | 1 | — | — |
| aios-agent-schedules | — | — | — | — | — |
| aios-agent-azure-saas-sre | 3 | 4 | 1 | — | 1 |
| aios-agent-sre-ticket-resolution | 3 | — | 1 | — | — |
| aios-agent-multitenant-sre-rca | 4 | — | 2 | — | — |
| aios-agent-privatesaas-devops-sre | 3 | — | 2 | — | — |
| aios-agent-privatesaas-sre | 3 | — | 2 | — | — |
| aios-agent-privatesaas-gitops-sre | 3 | — | 2 | — | — |
| aios-agent-selfhosted-infra | 3 | — | 3 | — | — |

</details>

## Design Principles

1. **Self-contained**: Each module has its own `versions.tf`, personas, policies, and README
2. **Opinionated defaults**: Sensible defaults for budgets, images, policies — zero-config works
3. **Override everything**: All defaults overridable via variables
4. **Composable**: Layer 2 agents take integration names as inputs, not create integrations
5. **Out-of-box policies**: Each agent auto-attaches relevant policies
6. **Multi-cloud SRE**: AWS, Azure, and GCP SRE modules with parallel structures
