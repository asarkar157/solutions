---
layout: page
title: Migration Guide
permalink: migration-guide/
nav_order: 30
---

# Migration guide: monolithic Terraform → modular StackGen library

This guide walks you through moving from a monolithic `terraform/guild/main.tf` to **composable StackGen modules** in this repository. Module folders use the **`aios-*`** naming where the library targets **AIOS-ready** bundles; the migration is about **structure and provider resources**, not AIOS-only deployments.

> **OpenTofu vs Terraform:** Prefer **`tofu`** ([OpenTofu](https://opentofu.org/)); commands below use `terraform` where that is the conventional spelling in docs—**`tofu plan`**, **`tofu import`**, etc. work the same.

## Before You Start

1. Ensure you have **OpenTofu or Terraform** `>= 1.5` installed (this repository pins OpenTofu in [`.opentofu-version`]({{ site.github.repository_url }}/blob/main/.opentofu-version) for CI)
2. Back up your existing Terraform state
3. Review the [architecture diagram]({% include doc_url.html path="architecture.md" %})

## Step 1: Configure the Provider (Root Module)

The `aios-foundation` module no longer configures the provider. Add this to your root module:

```hcl
terraform {
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  # project_id = var.stackgen_project_id  # optional; prefer over deprecated org_id
  # adopt_on_conflict = false            # optional; default true — disable for strict create semantics
}
```

## Step 2: Replace Inline Resources with Foundation Module

**Before (monolithic):**
```hcl
resource "sg_secret" "openai_vault" { ... }
resource "sg_guild_model_provider" "openai" { ... }
resource "sg_guild_model" "gpt4o" { ... }
```

**After (modular):**
```hcl
module "foundation" {
  source = "github.com/appcd-dev/solutions//modules/aios-foundation"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token

  llm_api_keys = {
    openai    = var.openai_api_key
    anthropic = var.anthropic_api_key
    gemini    = var.gemini_api_key
  }
}
```

**HTTP webhooks (Guild):** Newer StackGen provider versions support `sg_webhook` (incoming HTTP triggers) with in-place updates to `action`, `endpoint_path`, and `allowed_cidrs`. Set provider `project_id` / model `scope` on the provider and foundation resources when org-scoped; pin **>= 0.1.25** when you need those features.

**Deployment catalog (`data.sg_app` / `data.sg_apps`):** Catalog installations expose **`integrations`** (list). The older **`integration_map`** attribute was removed upstream.

**Remote runners (>= 0.1.25):** Resource `sg_remote_runner` registers aiden-runner and exposes computed `cli_start_command` / `helm_install_command` (mothership = provider `stackgen_url`). AIOS module [`modules/aios-remote-runner`](../modules/aios-remote-runner) wraps create/lookup; agent modules `aios-agent-terraform-bot`, `aios-agent-db-state-splitter`, and `aios-agent-iac-drift-detective` accept `create_remote_runner`.

**Read-only lookups:** The provider also ships Guild data sources such as `sg_agent`, `sg_agents`, `sg_workflow`, `sg_workflows`, and `sg_agent_diaries` (Insights), plus `sg_remote_runner` / `sg_remote_runners`. Use them in root modules for discovery, outputs, or tooling; set provider `project_id` when the API is org-scoped. See the provider repo [`docs/index.md`](https://github.com/appcd-dev/terraform-provider-stackgen/blob/main/docs/index.md) and `tofu providers schema -json` for the authoritative schema.

**`sg_agent_schedule`:** Current provider versions use `target_type` and `target_name` (agent or workflow), matching `sg_webhook`. The `aios-agent-schedules` module uses `target_name` and optional `target_type` instead of the legacy `agent_name` argument—update module callers accordingly.

## Step 3: Replace Inline Policies with Policies Module

**Before:**
```hcl
resource "sg_policy" "dangerous_ops" { ... }
resource "sg_policy" "sre_remediation" { ... }
# 10 more policies...
```

**After:**
```hcl
module "policies" {
  source = "github.com/appcd-dev/solutions//modules/aios-policies"

  # Disable policies you don't need
  create_policies = {
    azure_tool_governance  = false
    google_tool_governance = false
  }
}
```

## Step 4: Replace Inline Integrations with Integration Modules

**Before:**
```hcl
resource "sg_secret" "azure_vault" { ... }
resource "sg_guild_integration" "azure_production" { ... }
```

**After:**
```hcl
module "azure_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-azure"

  azure_subscription_id = var.azure_subscription_id
}
```

## Step 5: Replace Domain Modules

**Before:**
```hcl
module "sre" {
  source = "./modules/sre"
  model_names = {
    gpt4o         = sg_guild_model.gpt4o.name
    claude_sonnet = sg_guild_model.claude_sonnet.name
    gemini_flash  = sg_guild_model.gemini_flash.name
  }
  policy_ids = {
    dangerous_ops = sg_policy.dangerous_ops.id
    # ... 7 more
  }
  integration_names = {
    grafana = sg_guild_integration.grafana[0].name
    slack   = sg_guild_integration.slack[0].name
  }
}
```

**After:**
```hcl
module "sre" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-sre"

  model_names = module.foundation.model_names
  policy_ids  = module.policies.policy_ids

  integration_names = {
    grafana = module.grafana_integration.integration_name
    slack   = module.slack_integration.integration_name
  }
}
```

## Step 6: Import Existing State (Optional)

If you want to preserve existing resources without recreating them:

```bash
# Example: import existing SRE agent
terraform import 'module.sre.sg_agent.sre_triage' <agent-id>   # or: tofu import …
```

> **Warning**: Resource names must match exactly between old and new state. Run `terraform plan` (or `tofu plan`) first to see what the tool wants to recreate.

## Module Mapping

| Monolithic source | Module in this repo |
|------------------|-------------|
| `main.tf` (secrets, providers, models) | `aios-foundation` |
| `main.tf` (policies) | `aios-policies` |
| `main.tf` (integrations) | `aios-integration-*` (one per provider) |
| `modules/sre/` | `aios-agent-sre` |
| `modules/sdlc/` | `aios-agent-sdlc` |
| `modules/azure-devops/` | `aios-agent-azure-devops` |
| `modules/clickhouse-inspector/` | `aios-agent-clickhouse-inspector` |
| `modules/ubuntu-cli/` | `aios-agent-ubuntu-cli` |
| `modules/grafana-sre/` | `aios-agent-grafana-sre` |
| `modules/aws-sre/` | `aios-agent-aws-sre` |
| `modules/supply-chain-security/` | `aios-agent-supply-chain-security` |
| `modules/software-engineering/` | `aios-agent-software-engineering` |
| `modules/workspace-assistant/` | `aios-agent-workspace-assistant` |
| `modules/marketing/` | `aios-agent-marketing` |
| `modules/predictive-sre/` | `aios-agent-predictive-sre` |
