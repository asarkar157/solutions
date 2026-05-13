---
layout: page
title: "4 — Use a module"
permalink: step-4/
nav_order: 13
parent: Onboarding
---

# Step 4 — Use a module in your Terraform

This step is about **your** root module (separate from cloning this repo)—where **solution engineers** typically integrate StackGen. You reference modules by **`source`** and pass **variables**.

## 1. Minimal pattern

Modules live under `modules/<name>` in this repository. Example `source` (replace **`ref`** with a tag or commit you trust for production). The URL below uses this site’s GitHub metadata so it tracks your fork after you set `repository` in `_config.yml`:

```hcl
module "foundation" {
  source = "git::{{ site.github.repository_url }}.git//modules/aios-foundation?ref=main"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  llm_api_keys = {
    openai    = var.openai_api_key
    anthropic = var.anthropic_api_key
  }
}
```

You can also use the **GitHub Terraform source** form shown in the root [README]({{ site.github.repository_url }}/blob/main/README.md#-quick-start) (`github.com/ORG/REPO//modules/...`).

## 2. Add policies and an agent (illustrative)

```hcl
module "policies" {
  source = "git::{{ site.github.repository_url }}.git//modules/aios-policies?ref=main"
}

module "sre" {
  source = "git::{{ site.github.repository_url }}.git//modules/aios-agent-sre?ref=main"

  model_names = module.foundation.model_names
  policy_ids  = module.policies.policy_ids
}
```

Exact variable names differ per module — open the matching **`modules/<name>/variables.tf`** and **`README.md`** in this repo.

## 3. Configure the StackGen provider

Your root module must configure the **`sg`** provider required by these modules (version constraints are in each module’s `terraform` block). Use **`stackgen_url`** and **`stackgen_token`** (or the `host` / `api_token` aliases; avoid deprecated `guild_url` / `guild_token`). For example:

```hcl
provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  # Optional default org scope for Guild (agents, workflows, webhooks, schedules, knowledge):
  # project_id = var.stackgen_project_id
  # Optional: default true — set false to disable create-time adoption on 409/500 for selected Guild resources.
  # adopt_on_conflict = false
}
```

Each module’s `required_providers` pins the StackGen provider at **`>= 0.1.13, < 0.2.0`** from `releases.stackgen.com` (patch upgrades within **v0.1.x** until **v0.2**).

**Read-only data sources** (e.g. `sg_workflow`, `sg_agents`, `sg_agent_diaries`) and the full resource list are documented in the provider repo: [`terraform-provider-stackgen` docs index](https://github.com/appcd-dev/terraform-provider-stackgen/blob/main/docs/index.md). For machine-readable attribute descriptions, run `tofu providers schema -json` after `init` and inspect `provider_schemas["releases.stackgen.com/stackgen/stackgen"]`.

## 4. Plan

```bash
tofu init
tofu plan
# Same with HashiCorp Terraform: terraform init && terraform plan
```

Fix any missing variables or provider configuration before apply.

## 5. Full stack reference

For a **large** composition (many integrations and agents), see the runnable example: [`examples/complete/`]({{ site.github.repository_url }}/blob/main/examples/complete/).

---

**Next:** [Step 5 — Go deeper]({% include doc_url.html path="onboarding/05-go-deeper.md" %})  
**Previous:** [Step 3 — Run checks]({% include doc_url.html path="onboarding/03-run-checks.md" %})
