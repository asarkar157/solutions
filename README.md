# AIOS Modules — Reusable Terraform Modules for AI Operations

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-blue.svg)](https://www.terraform.io/)
[![Provider](https://img.shields.io/badge/Provider-StackGen-%23FF6B35.svg)](https://github.com/stackgen-demo/terraform-provider-stackgen)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![CI](https://github.com/stackgen-demo/solutions/actions/workflows/ci.yml/badge.svg)](https://github.com/stackgen-demo/solutions/actions/workflows/ci.yml)

Production-ready, composable Terraform modules for bootstrapping **AIOS (AI Operations)** solutions — autonomous SRE agents, incident response workflows, software engineering pipelines, and supply chain security scanners.

## Guided onboarding (GitHub Pages)

Step-by-step docs for **new users and contributors** live under [`docs/`](docs/) as a small [Jekyll](https://jekyllrb.com/) site (orientation → install tools → run checks → use a module → deeper links).

1. **Enable Pages:** GitHub **Settings → Pages →** build from the default branch, folder **`/docs`** ([publishing source docs](https://docs.github.com/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)).
2. **Open the site** after the first build (GitHub shows the URL; it is usually `https://<org>.github.io/<repo>/`).
3. **Start onboarding:** [`/onboarding/`](https://stackgen-demo.github.io/solutions/onboarding/) — if your repo name or org is different, use your Pages URL and update `baseurl` / `repository` in [`docs/_config.yml`](docs/_config.yml) so links stay correct.

Optional local preview: `cd docs && bundle install && bundle exec jekyll serve` (see [`docs/Gemfile`](docs/Gemfile)).

## What you will find here

| Path | Purpose |
|------|---------|
| [`modules/`](modules/) | One directory per Terraform module (foundation, integrations, agents, policies). Each module is intended to be used via a `module` block `source` pointing at this repo (see [Quick start](#quick-start)). |
| [`examples/`](examples/) | Runnable Terraform roots that compose modules for local experimentation and CI validation (`examples/complete`). Snippet-only quickstarts live next to them as READMEs. |
| [`docs/`](docs/) | **GitHub Pages** onboarding site ([`docs/onboarding/`](docs/onboarding/)), Jekyll [`_config.yml`](docs/_config.yml), and [architecture](docs/architecture.md) for the dependency graph. |
| [`scripts/`](scripts/) | Shell helpers invoked by the [`Makefile`](Makefile) and [GitHub Actions](.github/workflows/ci.yml). |

**Conventions:** Terraform `>= 1.5` in modules; Rego policies are shipped as separate `sg_policy` bodies (each `.rego` file is validated in isolation in CI). The StackGen provider is resolved from `releases.stackgen.com` (see [Local verification](#local-verification) for authentication).

## 🏗 Architecture

Modules are organized in **four composable layers**:

```
┌─────────────────────────────────────────────────────────┐
│  Layer 3 — Solutions (Composite Workflows)              │
│  incident-response • predictive-sre • feature-dev       │
├─────────────────────────────────────────────────────────┤
│  Layer 2 — Agents (Domain-Specific AI Agents)           │
│  sre • aws-sre • azure-devops • grafana-sre             │
│  software-engineering • supply-chain • workspace        │
├─────────────────────────────────────────────────────────┤
│  Layer 1 — Integrations (Cloud & Tool Connectors)       │
│  aws • azure • grafana • slack • github • clickhouse    │
├─────────────────────────────────────────────────────────┤
│  Layer 0 — Foundation (Models, Policies)               │
│  foundation • policies                                  │
└─────────────────────────────────────────────────────────┘
```

Each layer depends only on the layers below it. Pick exactly what you need.

## 🚀 Quick Start

### Minimal SRE Setup (~30 lines)

```hcl
module "foundation" {
  source = "github.com/stackgen-demo/solutions//modules/aios-foundation"

  stackgen_url   = "https://main.dev.stackgen.com"
  stackgen_token = var.stackgen_token
  llm_api_keys = {
    openai    = var.openai_key
    anthropic = var.anthropic_key
  }
}

module "policies" {
  source = "github.com/stackgen-demo/solutions//modules/aios-policies"
}

module "sre_agents" {
  source = "github.com/stackgen-demo/solutions//modules/aios-agent-sre"

  model_names = module.foundation.model_names
  policy_ids  = module.policies.policy_ids
}
```

In the same root module, configure the **`sg`** provider (values should match `stackgen_url` / `stackgen_token` passed into `module "foundation"`):

```hcl
provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
}
```

### Full-Stack SRE with AWS + Grafana

See [`examples/complete/`](examples/complete/) for a full reproduction of the AIOS stack.

## 📦 Available Modules

### Foundation (Layer 0)

| Module | Description |
|--------|-------------|
| [`aios-foundation`](modules/aios-foundation/) | LLM secrets, model providers, model instances (root module configures `sg`) |
| [`aios-policies`](modules/aios-policies/) | Reusable OPA/Rego guardrail policy library (12+ policies) |

### Integrations (Layer 1)

| Module | Description |
|--------|-------------|
| [`aios-integration-aws`](modules/aios-integration-aws/) | AWS integration with IAM role assumption via Vault |
| [`aios-integration-azure`](modules/aios-integration-azure/) | Azure integration with service principal + role assignments |
| [`aios-integration-grafana`](modules/aios-integration-grafana/) | Grafana observability integration |
| [`aios-integration-slack`](modules/aios-integration-slack/) | Slack ChatOps integration |
| [`aios-integration-github`](modules/aios-integration-github/) | GitHub SCM integration |
| [`aios-integration-clickhouse`](modules/aios-integration-clickhouse/) | ClickHouse BYOI analytics integration |

### Agents (Layer 2)

| Module | Description | Agents | Policies |
|--------|-------------|--------|----------|
| [`aios-agent-sre`](modules/aios-agent-sre/) | SRE incident response agents | 5 | 8 |
| [`aios-agent-aws-sre`](modules/aios-agent-aws-sre/) | AWS cloud operations SRE | 1 | 2 |
| [`aios-agent-azure-devops`](modules/aios-agent-azure-devops/) | Azure data pipeline SRE | 1 | 8 |
| [`aios-agent-grafana-sre`](modules/aios-agent-grafana-sre/) | Grafana observability SRE | 1 | 2 |
| [`aios-agent-software-engineering`](modules/aios-agent-software-engineering/) | Linear + Cursor dev pipeline | 2 | 3 |
| [`aios-agent-supply-chain-security`](modules/aios-agent-supply-chain-security/) | npm supply chain scanner | 1 | 5 |
| [`aios-agent-workspace-assistant`](modules/aios-agent-workspace-assistant/) | Google/Slack/Linear workspace | 1 | 2 |
| [`aios-agent-gcp-sre`](modules/aios-agent-gcp-sre/) | GCP operations SRE | 1 | 2 |
| [`aios-agent-compliance-auditor`](modules/aios-agent-compliance-auditor/) | Compliance and data-access governance | 1 | 2–3 |
| [`aios-agent-cost-optimizer`](modules/aios-agent-cost-optimizer/) | Cost optimization assistant | 1 | 1 |
| [`aios-agent-marketing`](modules/aios-agent-marketing/) | Marketing operations | 1 | 1 |
| [`aios-agent-onboarding`](modules/aios-agent-onboarding/) | Workspace onboarding | 1 | 1 |
| [`aios-agent-predictive-sre`](modules/aios-agent-predictive-sre/) | Predictive / cross-signal triage | 1 | 1 |

### Solutions (Layer 3)

The architecture diagram above includes composite **workflow** solutions (incident response, predictive SRE, feature development). **Those `aios-workflow-*` Terraform modules are not present under [`modules/`](modules/) in this repository yet**; they are described as the top layer in [`docs/architecture.md`](docs/architecture.md). Compose agents and integrations here today; follow the doc for the intended end-state graph.

## 📖 Examples

| Example | Description |
|---------|-------------|
| [`examples/complete/`](examples/complete/) | Runnable Terraform root: full AIOS stack (used for `terraform validate` in CI). |
| [`examples/sre-quickstart/`](examples/sre-quickstart/) | Minimal copy-paste HCL in the README only (no `.tf` root in this folder). |

## Local verification

Use the [`Makefile`](Makefile) from the repository root. Run `make help` for a short summary of targets.

**Tools (align with CI when possible):**

| Tool | Role |
|------|------|
| [Terraform](https://www.terraform.io/downloads) **1.9.x** (minimum **1.5** per modules) | Format and validate all module and example roots. CI pins **1.9.8** in [`.github/workflows/ci.yml`](.github/workflows/ci.yml). |
| [OPA](https://www.openpolicyagent.org/docs/latest/#running-opa) (CLI) | Rego formatting and `opa check` on each policy file. CI uses OPA **0.70.0**. |

**Typical commands:**

```bash
make fmt              # format all .tf
make fmt-check        # CI-style Terraform format check
make opa-fmt          # format all .rego
make opa-fmt-check    # CI-style Rego format check
make opa-check        # parse/typecheck each .rego with opa check --v1-compatible
make validate         # terraform init -backend=false && validate per directory under modules/ and examples/
make check            # fmt-check + opa-fmt-check + opa-check + validate
make clean            # remove .terraform caches under modules/ and examples/
```

**Registry authentication (required for `make validate` and the Terraform validate CI job):** modules download the StackGen provider from `releases.stackgen.com`. Set a token so Terraform can authenticate, for example:

- Environment variable: `export TF_TOKEN_releases_stackgen_com="<token>"` ([Terraform credential env convention](https://developer.hashicorp.com/terraform/cli/config/config-file#environment-variables)), or
- Credentials block in `~/.terraformrc` for hostname `releases.stackgen.com`.

Without a token, `terraform init` fails when resolving the `sg` provider.

## Continuous integration

Workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml) (runs on pull requests and pushes to `main`).

| Job | What it does |
|-----|----------------|
| **Terraform fmt** | `terraform fmt -check -recursive` |
| **OPA** | Install OPA; fail if any `.rego` needs `opa fmt`; run [`scripts/opa-check-all.sh`](scripts/opa-check-all.sh) (`opa check --v1-compatible` per file — policies are not one combined bundle). |
| **Terraform validate** | [`scripts/terraform-validate-all.sh`](scripts/terraform-validate-all.sh) in every Terraform root under `modules/` and `examples/`. |

**Repository secret (organization / upstream repo):** add **`STACKGEN_TERRAFORM_REGISTRY_TOKEN`** in GitHub → *Settings → Secrets and variables → Actions*. The workflow maps it to `TF_TOKEN_releases_stackgen_com` so `terraform init` can reach `releases.stackgen.com`. If the secret is missing (for example on a fork pull request), the validate step is **skipped** with a warning so format and OPA jobs can still pass.

## 🔧 Prerequisites

**When consuming these modules in your own stack:**

- **Terraform** >= 1.5 (see modules’ `required_version` / CI pin above)
- **StackGen** platform with Guild enabled, and **terraform-provider-stackgen** `>= 0.0.20` from `releases.stackgen.com`
- LLM API keys (OpenAI, Anthropic, and/or Gemini) as required by your chosen modules

## 📄 License

Apache 2.0 — see [LICENSE](LICENSE).
