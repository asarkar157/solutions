# Agent and IDE Guide — AIOS Modules

This file helps **human developers** and **coding agents** (Cursor, Copilot, etc.) use this repository correctly when composing Terraform/OpenTofu for StackGen.

## What this repo is

- **Reusable modules** under `modules/` — each folder is an independent Terraform module (`aios-foundation`, `aios-policies`, `aios-integration-*`, `aios-agent-*`).
- **Runnable roots** under `examples/` — especially `examples/complete` for a full composition reference.
- **Human docs** under `docs/` — onboarding and architecture (Jekyll site).

Modules target the **StackGen** provider (`sg`). They do not implement application runtime code; they declare `sg_*` resources (agents, workflows, policies, integrations, secrets, models).

## Provider (required in the customer root)

Every consumer root must configure the provider, for example:

```hcl
terraform {
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      # Use >= 0.1.25 for current AIOS modules. Floors: 0.1.13 (evidence/remediation/remote runners),
      # 0.1.17 (integration env, adopt-on-conflict for bundles/models/workflows). 0.1.19 added
      # sg_agent.auto_approve_tools and data.sg_app / data.sg_apps; 0.1.20 syncs Guild OpenAPI
      # (integrations list, sg_webhook UpdateWebhook, agent state upgrade). 0.1.26 adds the sg_app
      # resource for deployment-catalog app install bindings (e.g. stackgen-sre-app).
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  # Optional: default org scope for Guild APIs that send orgId (agents, workflows, webhooks, schedules).
  # project_id = var.stackgen_project_id  # deprecated alias on provider: org_id
  # Optional: default true — some Guild resources adopt an existing object after Create returns 409/500.
  # adopt_on_conflict = false  # use for strict pipelines (fail + terraform import instead)
}
```

Use **OpenTofu** (`tofu`) or **Terraform** interchangeably for `fmt`, `init`, `validate`, `plan`, `apply`.

## Provider source documentation (keep current with upstream)

This repo consumes the **`sg`** provider from `releases.stackgen.com`; it does **not** vendor the provider code. When adding or changing `sg_*` usage, align with the upstream project **[appcd-dev/terraform-provider-stackgen](https://github.com/appcd-dev/terraform-provider-stackgen)**:

| Artifact | Purpose |
|----------|---------|
| [`docs/index.md`](https://github.com/appcd-dev/terraform-provider-stackgen/blob/main/docs/index.md) | Human-readable index of resources and data sources |
| [`AGENTS.md`](https://github.com/appcd-dev/terraform-provider-stackgen/blob/main/AGENTS.md) | Schema tag conventions (`sg:"..."`) and implementation patterns |
| `tofu providers schema -json` / `terraform providers schema -json` | Full machine-readable schema (key = your `required_providers.sg.source`) |

**Remote runners (on-prem):** `modules/aios-remote-runner` creates `sg_remote_runner` (provider **>= 0.1.25**) and outputs `cli_start_command` / `helm_install_command` for aiden-runner (outbound-only to mothership). Agent modules `aios-agent-terraform-bot`, `aios-agent-cdk-bot`, `aios-agent-db-state-splitter`, and `aios-agent-iac-drift-detective` accept `create_remote_runner` + `remote_runner_attach_to_agent`.

**Guild read-only data sources** (for lookups and automation without managing those objects in the same root): `sg_agent`, `sg_agents`, `sg_workflow`, `sg_workflows`, `sg_agent_diaries`, `sg_remote_runner`, `sg_remote_runners`, **`data.sg_app`**, **`data.sg_apps`** (deployment catalog, **v0.1.21+** minimum; catalog apps expose **`integrations`**, not the removed `integration_map`). **`resource.sg_app`** (provider **>= 0.1.26**) manages app install integration bindings — see `modules/aios-sre-app-bindings`. From **v0.1.12**, `sg_agent` accepts **`remote_runners`**; **v0.1.13** evidence/remediation patterns; **v0.1.17** `env` on `sg_guild_integration` and adopt-on-conflict for bundles/models/workflows; **v0.1.19** **`auto_approve_tools`** object blocks on `sg_agent` (MCP wildcards — used by `aios-agent-repo-to-iac`, `aios-agent-db-state-splitter`, `aios-agent-sdlc` cloud-infra). **`sg_webhook`** supports in-place updates of `action`, `endpoint_path`, and `allowed_cidrs` (provider **v0.1.21+**). Optional **`enable_stackgen_deployment_catalog`** on `aios-agent-release-tracker` loads `data.sg_apps` at plan time. Modules with `remote_runner_attach_to_agent` use `data.sg_remote_runner`. **AppCD / Vault** examples: `sg_me`, `sg_roles`, `sg_users`, `sg_credential_provider`, etc. Prefer `project_id` on the provider when a data source is org-scoped.

## Module source (how customers reference this repo)

Modules are addressed with a **double-slash** path to the subdirectory. The published examples in [`README.md`](README.md) use **`github.com/appcd-dev/solutions`** as the Git remote; pin `ref=` to a tag or commit for production.

**Git (version pinned):**

```hcl
module "foundation" {
  source = "github.com/appcd-dev/solutions//modules/aios-foundation?ref=main"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  llm_api_keys   = var.llm_api_keys
}
```

**Working inside this clone** (contributors / local examples): use a relative source such as `source = "../../modules/aios-foundation"` from under `examples/`.

**Registry-style** (if published): follow your registry’s module address format; the subdirectory is still `//modules/<name>` for Git-based module sources.

When generating snippets, **always** read the target module’s `variables.tf` and `outputs.tf` (and `README.md` if present) — contracts differ per module.

## Composition layers (dependency order)

Do not invert dependencies between layers.

| Layer | Modules | Purpose |
|-------|---------|---------|
| 0 | `aios-foundation` | Models, LLM secrets, provider-backed setup |
| 0 | `aios-foundation-bedrock` | Amazon Bedrock provider + Claude Sonnet 4.6 inference profile; IAM or static AWS keys |
| 0 | `aios-policies` | Shared `sg_policy` resources; exposes `policy_ids` map |
| 1 | `aios-integration-*` | Cloud/tool integrations; exposes `integration_name` or similar |
| 2 | `aios-agent-*` | Agents, workflows, attachments; consume `module.foundation.model_names`, `module.policies.policy_ids`, and integration outputs |
| 2 | `aios-agent-schedules` | Optional companion: `sg_agent_schedule` cron prompts; set `target_name` (and optional `target_type`) from agent or workflow module outputs — same pairing as `sg_webhook` |

**Typical wiring:**

1. Instantiate `aios-foundation` and `aios-policies` once per stack (or per env).
2. Instantiate only the **integrations** the customer uses (each module is optional).
3. Instantiate **agent** modules; pass `model_names`, the **subset** of `policy_ids` that module expects, and integration identifiers as required by that module’s variables.
4. Optionally instantiate **`aios-agent-schedules`** beside an agent or workflow to attach Guild cron schedules (`sg_agent_schedule` uses `target_type` / `target_name`); see `modules/aios-agent-schedules/README.md` and `examples/complete/main.tf`.

For a working full graph, start from `examples/complete/main.tf`.

## Variable and output contracts (agent modules)

- **`model_names`** is a **`list(string)`** of Guild-registered model names in priority order. Wire `module.foundation.model_names` directly (it is a `list(string)` output containing only configured models — empty entries are dropped). For hand-picking a single provider, use the companion `module.foundation.model_names_by_provider` map (e.g. `[module.foundation.model_names_by_provider.gpt54]`). Modules forward `model_names` straight to `sg_agent.model_names` after `compact()`; agents are no longer picky about which keys exist.
- **`policy_ids`**: A **map** keyed by logical names; each agent module documents which keys it needs in its `variables.tf` / README. Source: `module.policies.policy_ids`.
- **Integrations**: Some modules take `integration_name` (string), others `integration_names` (map). Match the **exact** variable type of the module you are calling.
- **Secrets / tokens**: Prefer root-level sensitive variables and pass into modules; never commit credentials.

## Rego and policies

- Policy bodies live as `.rego` files inside modules (e.g. `aios-policies`, agent modules). CI validates them.
- When adding or changing policies, keep filenames and `sg_policy` resource names stable where possible to avoid unnecessary replacement in customer state.

## Conventions for generated HCL

1. **One concern per module block** — prefer adding another `module` block over forking a module’s internals from the consumer root.
2. **Pin `ref=`** on Git sources for anything beyond local experimentation.
3. **Run** `terraform fmt` / `tofu fmt`, `make verify-workflow-stage-bindings`, and `validate` after workflow edits (or `pre-commit install` to mirror CI on every commit; see [README](README.md) and [`.pre-commit-config.yaml`](.pre-commit-config.yaml)).
4. **Do not** invent `sg_*` resource arguments; if unsure, open the StackGen provider schema or the module’s `main.tf` in this repo.

## Module inventory (folder → role)

| Path | Role |
|------|------|
| `modules/aios-foundation` | LLM providers, models, vault secrets for keys |
| `modules/aios-foundation-bedrock` | Bedrock model provider + Claude Sonnet 4.6 (`us.anthropic.claude-sonnet-4-6` style profile); output `model_names` for agents |
| `modules/aios-policies` | Org-wide policies; output `policy_ids` |
| `modules/aios-integration-aws` | AWS integration |
| `modules/aios-integration-azure` | Azure integration |
| `modules/aios-integration-gcp` | GCP integration |
| `modules/aios-integration-github` | GitHub integration |
| `modules/aios-integration-slack` | Slack integration |
| `modules/aios-integration-grafana` | Grafana integration |
| `modules/aios-integration-linear` | Linear integration |
| `modules/aios-integration-clickhouse` | ClickHouse integration |
| `modules/aios-integration-ubuntu` | Ubuntu / CLI integration |
| `modules/aios-cce-scripts` | Shared CCE bash pack (`CCE_PACK_B64`) + outputs for agent modules; see `docs/cce-agent-integrations.md` and **`docs/cce-enterprise-workflows.md`** (seven enterprise superpowers + demo scenarios) |
| `modules/aios-integration-cursor` | Cursor integration |
| `modules/aios-integration-datadog` | Datadog observability integration (official MCP) |
| `modules/aios-integration-pagerduty` | PagerDuty incident-management integration |
| `modules/aios-integration-firehydrant` | FireHydrant incident-management integration |
| `modules/aios-integration-internal-tool` | Internal operator console / service catalog (`restapi` Guild type) |
| `modules/aios-integration-servicenow` | ServiceNow ITSM integration |
| `modules/aios-integration-confluence` | Confluence runbook / knowledge-base integration |
| `modules/aios-integration-paloalto` | Palo Alto Networks PAN-OS firewall integration |
| `modules/aios-integration-gitlab` | GitLab SCM integration |
| `modules/aios-integration-argocd` | Argo CD GitOps integration |
| `modules/aios-integration-sonarqube` | SonarQube quality gate integration |
| `modules/aios-agent-sre` | SRE agents and incident workflows |
| `modules/aios-agent-alert-triage` | Grafana alert RCA — webhook ingest + Rego filter, prior-incident memory, PromQL query probe, ReAcTree hypothesis investigation, optional AWS/GitHub/k8s enrichment, Slack RCA publish |
| `modules/aios-agent-aws-sre` | AWS-focused SRE |
| `modules/aios-agent-gcp-sre` | GCP-focused SRE |
| `modules/aios-agent-grafana-sre` | Grafana-focused SRE |
| `modules/aios-agent-predictive-sre` | Predictive triage workflow |
| `modules/aios-agent-software-engineering` | Feature development workflow |
| `modules/aios-agent-repo-to-iac` | GitHub repo URL → IaC via StackGen MCP (`repository-to-iac` workflow) |
| `modules/aios-agent-db-state-splitter` | Multi-cloud monorepo TF state → logical groups, optional StackGen AppStacks (MCP), registry mapping, orphan workflow (`db-monorepo-state-split-convergence`) |
| `modules/aios-agent-monorepo-services-splitter` | Application monorepo (Go/JS/TS/Java) → boundary scan, DDD split guidance PR, optional service scaffold/extract + Cursor (`monorepo-services-split-analysis` / `monorepo-services-split-extract`) |
| `modules/aios-agent-supply-chain-security` | Supply chain scan workflow and policies |
| `modules/aios-agent-compliance-auditor` | Compliance assessment workflow |
| `modules/aios-agent-cost-optimizer` | FinOps / cost workflow |
| `modules/aios-agent-sdlc` | SDLC agents and release/developer workflows |
| `modules/aios-agent-azure-devops` | Azure DevOps triage workflow |
| `modules/aios-agent-azure-saas-sre` | Single-tenant Azure SaaS SRE — PagerDuty ingest + filter, Datadog/Azure investigation, Confluence runbook match, Azure Automation remediation |
| `modules/aios-agent-sre-ticket-resolution` | ServiceNow ticket resolution — webhook ingest + filter, Grafana/Prometheus + AWS investigation, bounded AWS remediation, Slack notify |
| `modules/aios-agent-multitenant-sre-rca` | Multi-tenant SaaS SRE RCA — Datadog alert ingest + filter, cross-signal investigation (Datadog/GCP/AWS/GitHub), Slack RCA publish, thread collaboration webhook |
| `modules/aios-agent-privatesaas-devops-sre` | PrivateSaaS DevOps/SRE — Grafana alert ingest + filter, Grafana/AWS/PAN-OS investigation, bounded AWS remediation, read-only connectivity audit |
| `modules/aios-agent-privatesaas-sre` | PrivateSaaS SRE (Aiden for SRE) — FireHydrant + Grafana ingest, GCP + internal tooling investigation, multi-source runbook coordinator, RCA; Bifrost LLM via foundation; optional Grafana/FireHydrant webhooks |
| `modules/aios-agent-privatesaas-gitops-sre` | PrivateSaaS GitOps SRE — Slack `/aiden` intake, GitLab/Argo CD/AWS DynamoDB/SonarQube investigation, optional Ubuntu docker/npm + remote runner, bounded remediation, quality audit workflow |
| `modules/aios-agent-selfhosted-infra` | Self-hosted infra (Aiden for Infra) — CloudFormation stack failure ingest + filter, AWS/CFN read-only investigation, HITL-gated change-set recommendations, drift audit, pre-deploy review; optional Ubuntu CLI + remote runner |
| `modules/aios-agent-cfn-author` | CloudFormation Author (Bedrock Sonnet 4.6) — five governance pillars via nested `aios-cfn-governance-runbooks`: remote orchestration, FedRAMP/baseline compliance, hardened synthesis, governed PR deployment, continuous drift governance; intent webhook + optional compliance webhook and drift cron |
| `modules/aios-cfn-governance-runbooks` | Reusable CFN governance runbook SOP pack (remote orchestration, contextual compliance, hardened synthesis, governed deployment, continuous governance) — nest from `aios-agent-cfn-author` or other CFN agents |
| `modules/aios-agent-onboarding` | Onboarding |
| `modules/aios-agent-marketing` | Marketing / product launch workflow |
| `modules/aios-agent-workspace-assistant` | Workspace assistant workflow |
| `modules/aios-agent-ubuntu-cli` | Ubuntu CLI-oriented agent |
| `modules/aios-agent-clickhouse-inspector` | ClickHouse inspection |
| `modules/aios-agent-resource-janitor` | Multi-cloud unused-resource detection (≥ 30 days inactive — Lambda invocations, S3 last-modified, idle compute / disks / IPs) plus HITL-gated tag-and-quarantine cleanup workflow |
| `modules/aios-agent-pipeline-insights` | Read-only GitHub pipeline & deployment intelligence — workflow runs, PR-merge metadata (who / when / mode / scope), deployment statuses with failure log excerpts |
| `modules/aios-agent-slo-health` | OpenSLO + Grafana SLO health — weekly error-budget review, config drift vs alerts/dashboards, bootstrap/drift-reconcile PRs from Grafana metrics |
| `modules/aios-agent-release-tracker` | Read-only microservice release tracker — latest GitHub tags / Releases, GHCR image versions, "what's deployed where" via deployments + optional manifest cross-check, release diffs |
| `modules/aios-agent-scenario-author` | Closes the SE feedback loop — triages `scenario-request` GitHub issues, matches existing scenarios, and delegates new `examples/scenarios/<slug>/` scaffolding (5 files + `scripts/demo.sh` entry + `docs/se-playbook.md` row + tofu validate + auto-PR via Cursor's GitHub App) to a Cursor Cloud Agent via `cursor_agents_run_task`, then comments back on the issue. Uses GitHub + Cursor integrations (no Ubuntu CLI shell scripting); strict repo + label gate |
| `modules/aios-agent-terraform-bot` | GitHub issue/PR → clone → validate → PR → **quality assess/iterate loop** (`conditional_skip` forward on PASS/GIVE_UP; `loop_stage` GO_BACK to merge when NEEDS_REVISION; `module_quality_max_iterations`) → register. **Discovery-modules profile** (`discovery_modules_repository_full_names`, default `stackgenhq/discovery-modules`): `aws|gcp|azurerm/<module>/` layout, `.stackgen/stackgen.yaml`, Template I scaffold, `stackgen upload custom-modules` |
| `modules/aios-agent-spec-symphony` | Stage 5 SDD factory — GitHub/Linear webhooks → remote runner (Spec Kit + OpenSpec CLIs) → clone → SDD Kit bootstrap → implement → validate + CI poll → PR → archive → tracker update. No Ubuntu/Cursor. |
| `modules/aios-agent-schedules` | Composable `sg_agent_schedule` resources for any agent or workflow |
| `modules/aios-sre-app-bindings` | Binds Guild integrations to an installed **stackgen-sre-app** install via **`sg_app`**; optional **`sg_sre_alert_webhook`** alert ingest registrations (provider **>= 0.1.27**) |
| `modules/aios-remote-runner` | Register or look up Guild remote runners; outputs aiden-runner CLI/Helm install commands (provider **>= 0.1.25**) |

## IDE tips (no agent file required)

- **terraform-ls**: Hover and completion use `description` on variables/outputs — keep module `variables.tf` / `outputs.tf` descriptions accurate when changing contracts.
- **Terraform/OpenTofu extension**: Set workspace root to the customer’s root where `provider "sg"` lives; use submodule opens only for reading source.

## When editing this repository

- Preserve **layering** (foundation/policies → integrations → agents).
- After changing interfaces, update **module README** and **examples** that exercise the change.
- Match existing naming: `aios-*` prefixes, `sg_*` resources.
