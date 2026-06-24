---
layout: page
title: Prerequisites
permalink: prerequisites/
nav_order: 6
parent: Adopt the repo
---

# Prerequisites

One checklist before you run a scenario, export a tenant, or compose modules in your own root. Module-specific variables live in each `modules/<name>/README.md` — this page covers what every path needs.

---

## StackGen / Guild access

| Item | Required? | Notes |
|------|-----------|-------|
| **StackGen URL** | Yes | e.g. `https://main.dev.stackgen.com` — your Guild deployment base URL. |
| **StackGen token (PAT)** | Yes | Passed as `stackgen_token` or `TF_VAR_stackgen_token`. Used by the `sg` provider and `make demo`. |
| **Project ID** | Sometimes | Optional `stackgen_project_id` when your tenant requires explicit org scope on Guild APIs. |

**Sanity check:** from the repo root, run `make demo-doctor`. It reports missing StackGen credentials before you apply.

---

## OpenTofu or Terraform

| Item | Required? | Notes |
|------|-----------|-------|
| **OpenTofu 1.9.x** (preferred) or **Terraform >= 1.5** | Yes | CI pins OpenTofu via [`.opentofu-version`]({{ site.github.repository_url }}/blob/main/.opentofu-version). |
| **StackGen provider >= 0.1.25, < 0.2.0** | Yes | Resolved from `releases.stackgen.com` on `tofu init`. |

Configure the provider in **your root module** (modules do not configure it for you):

```hcl
provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
}
```

---

## Provider registry authentication

`make validate` and `tofu init` download the StackGen provider from `releases.stackgen.com`. Set **one** of:

- **Environment variable:** `export TF_TOKEN_releases_stackgen_com="<token>"` (works for both OpenTofu and Terraform)
- **Credentials block** in `~/.terraformrc` for hostname `releases.stackgen.com`

See [Local verification]({{ site.github.repository_url }}/blob/main/README.md#local-verification) in the repo README for `dev_overrides` behavior during validate.

---

## LLM keys

At least **one** LLM provider key is required for any stack that registers models (`aios-foundation` or `aios-foundation-bedrock`):

| Key | When |
|-----|------|
| `openai_api_key` | OpenAI models |
| `anthropic_api_key` | Direct Anthropic API |
| `gemini_api_key` | Google Gemini |
| **AWS Bedrock** (no Anthropic key) | Use [`aios-foundation-bedrock`]({{ site.github.repository_url }}/tree/main/modules/aios-foundation-bedrock) — see [`bedrock-sonnet-demo`]({{ site.github.repository_url }}/tree/main/examples/scenarios/bedrock-sonnet-demo) scenario |

Prefer `TF_VAR_openai_api_key` (etc.) over committing keys in `terraform.tfvars`.

---

## Integration secrets (by path)

Requirements depend on which scenario or modules you enable:

| Path | Typical integrations |
|------|---------------------|
| **Minimal demo** (`aws-sre-demo`) | AWS IAM role ARN + at least one LLM key |
| **Read-only demo** (`pipeline-insights`) | StackGen + LLM only — no cloud creds |
| **Full stack** (`examples/complete`) | AWS, GitHub, Slack; optional Grafana, Langfuse, Linear/Cursor MCP names |
| **Export only** (`aios-export`) | StackGen URL + token (read-only API calls) |

Each scenario's `terraform.tfvars.example` lists exactly what that root needs. Run `make demo-doctor SCENARIO=<name>` to check before apply.

---

## Git (contributors only)

Clone this repo only if you are:

- Running `make demo` or `make validate` from the repo root
- Changing modules and mirroring CI locally

Module consumers referencing GitHub `source` URLs do **not** need to clone the repo.

---

## Next steps

| Your goal | Go to |
|-----------|-------|
| Unfamiliar term | [Glossary]({% include doc_url.html path="glossary.md" %}) |
| Demo on a call | [Adopt — Path 1]({% include doc_url.html path="adopt.md" %}#path-1--demo-aiden-today-pre-sales) |
| Export UI tenant | [Adopt — Path 2]({% include doc_url.html path="adopt.md" %}#path-2--capture-a-ui-clicked-tenant-poc-handoff) |
| Compose modules | [Onboarding step 4]({% include doc_url.html path="onboarding/04-use-a-module.md" %}) |
