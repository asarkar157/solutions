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
      # Use >= 0.1.17 for current AIOS modules: integration `env` map (used by aios-integration-ubuntu and exposed
      # as an optional input on the other containerized integrations) plus adopt-on-conflict for sg_policy_bundle,
      # sg_guild_model_provider, sg_guild_model, and already-approved sg_workflow (re-applies after a Guild DB
      # re-seed stop failing 409/500). Pre-0.1.17 floors (evidence checklists, remediation approve, remote runner
      # attach from 0.1.13) are still required and implied by 0.1.17.
      version = ">= 0.1.17, < 0.2.0"
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

**Guild read-only data sources** (for lookups and automation without managing those objects in the same root): `sg_agent`, `sg_agents`, `sg_workflow`, `sg_workflows`, `sg_agent_diaries`, `sg_remote_runner`, `sg_remote_runners`. From provider **v0.1.12**, `sg_agent` accepts **`remote_runners`** (set of runner names/IDs) so Terraform can **attach** allowed runners to an agent; **v0.1.13** adds the evidence-checklist and remediation patterns this repo’s modules expect; **v0.1.17** adds an `env` map on `sg_guild_integration` (consumed by `aios-integration-ubuntu` and surfaced as an optional `env` input on the other containerized integrations) and extends adopt-on-conflict to `sg_policy_bundle`, `sg_guild_model_provider`, `sg_guild_model`, and already-approved `sg_workflow` so re-applies after a Guild DB re-seed no longer require manual `terraform import`. Modules such as `aios-agent-db-state-splitter`, `aios-agent-terraform-bot`, and `aios-agent-iac-drift-detective` expose optional `remote_runner_attach_to_agent` + `remote_runner_name` wiring that uses `data.sg_remote_runner` at plan time. **AppCD / Vault** examples: `sg_me`, `sg_roles`, `sg_users`, `sg_credential_provider`, etc. Prefer `project_id` on the provider when a data source is org-scoped.

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

- **`model_names`**: Almost always `module.foundation.model_names` (object with keys like `gpt4o`, `claude_sonnet`, `gemini_flash`).
- **`policy_ids`**: A **map** keyed by logical names; each agent module documents which keys it needs in its `variables.tf` / README. Source: `module.policies.policy_ids`.
- **Integrations**: Some modules take `integration_name` (string), others `integration_names` (map). Match the **exact** variable type of the module you are calling.
- **Secrets / tokens**: Prefer root-level sensitive variables and pass into modules; never commit credentials.

## Rego and policies

- Policy bodies live as `.rego` files inside modules (e.g. `aios-policies`, agent modules). CI validates them.
- When adding or changing policies, keep filenames and `sg_policy` resource names stable where possible to avoid unnecessary replacement in customer state.

## Conventions for generated HCL

1. **One concern per module block** — prefer adding another `module` block over forking a module’s internals from the consumer root.
2. **Pin `ref=`** on Git sources for anything beyond local experimentation.
3. **Run** `terraform fmt` / `tofu fmt` and `validate` after edits (or `pre-commit install` to mirror CI on every commit; see [README](README.md) and [`.pre-commit-config.yaml`](.pre-commit-config.yaml)).
4. **Do not** invent `sg_*` resource arguments; if unsure, open the StackGen provider schema or the module’s `main.tf` in this repo.

## Module inventory (folder → role)

| Path | Role |
|------|------|
| `modules/aios-foundation` | LLM providers, models, vault secrets for keys |
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
| `modules/aios-integration-cursor` | Cursor integration |
| `modules/aios-agent-sre` | SRE agents and incident workflows |
| `modules/aios-agent-aws-sre` | AWS-focused SRE |
| `modules/aios-agent-gcp-sre` | GCP-focused SRE |
| `modules/aios-agent-grafana-sre` | Grafana-focused SRE |
| `modules/aios-agent-predictive-sre` | Predictive triage workflow |
| `modules/aios-agent-software-engineering` | Feature development workflow |
| `modules/aios-agent-repo-to-iac` | GitHub repo URL → IaC via StackGen MCP (`repository-to-iac` workflow) |
| `modules/aios-agent-db-state-splitter` | Multi-cloud monorepo TF state → logical groups, optional StackGen AppStacks (MCP), registry mapping, orphan workflow (`db-monorepo-state-split-convergence`) |
| `modules/aios-agent-supply-chain-security` | Supply chain scan workflow and policies |
| `modules/aios-agent-compliance-auditor` | Compliance assessment workflow |
| `modules/aios-agent-cost-optimizer` | FinOps / cost workflow |
| `modules/aios-agent-sdlc` | SDLC agents and release/developer workflows |
| `modules/aios-agent-azure-devops` | Azure DevOps triage workflow |
| `modules/aios-agent-onboarding` | Onboarding |
| `modules/aios-agent-marketing` | Marketing / product launch workflow |
| `modules/aios-agent-workspace-assistant` | Workspace assistant workflow |
| `modules/aios-agent-ubuntu-cli` | Ubuntu CLI-oriented agent |
| `modules/aios-agent-clickhouse-inspector` | ClickHouse inspection |
| `modules/aios-agent-schedules` | Composable `sg_agent_schedule` resources for any agent or workflow |

## IDE tips (no agent file required)

- **terraform-ls**: Hover and completion use `description` on variables/outputs — keep module `variables.tf` / `outputs.tf` descriptions accurate when changing contracts.
- **Terraform/OpenTofu extension**: Set workspace root to the customer’s root where `provider "sg"` lives; use submodule opens only for reading source.

## When editing this repository

- Preserve **layering** (foundation/policies → integrations → agents).
- After changing interfaces, update **module README** and **examples** that exercise the change.
- Match existing naming: `aios-*` prefixes, `sg_*` resources.
