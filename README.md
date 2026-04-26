# AIOS Modules — Reusable Terraform Modules for AI Operations

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-blue.svg)](https://www.terraform.io/)
[![Provider](https://img.shields.io/badge/Provider-StackGen-%23FF6B35.svg)](https://github.com/appcd-dev/terraform-provider-stackgen)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

Production-ready, composable Terraform modules for bootstrapping **AIOS (AI Operations)** solutions — autonomous SRE agents, incident response workflows, software engineering pipelines, and supply chain security scanners.

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
│  Layer 0 — Foundation (Provider, Models, Policies)      │
│  foundation • policies                                  │
└─────────────────────────────────────────────────────────┘
```

Each layer depends only on the layers below it. Pick exactly what you need.

## 🚀 Quick Start

### Minimal SRE Setup (~30 lines)

```hcl
module "foundation" {
  source = "github.com/stackgen-demo/solutions//modules/aios-foundation"

  guild_url   = "https://guild.example.com"
  guild_token = var.guild_token
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

### Full-Stack SRE with AWS + Grafana

See [`examples/complete/`](examples/complete/) for a full reproduction of the AIOS stack.

## 📦 Available Modules

### Foundation (Layer 0)

| Module | Description |
|--------|-------------|
| [`aios-foundation`](modules/aios-foundation/) | StackGen provider, LLM secrets, model providers, model instances |
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

### Workflows (Layer 3)

| Module | Description | Stages |
|--------|-------------|--------|
| [`aios-workflow-incident-response`](modules/aios-workflow-incident-response/) | Full + quick triage incident response | 5 + 2 |
| [`aios-workflow-predictive-sre`](modules/aios-workflow-predictive-sre/) | Cross-domain predictive triage | 4 |
| [`aios-workflow-feature-development`](modules/aios-workflow-feature-development/) | Linear → Cursor → GitHub PR | 3 |

## 📖 Examples

| Example | Description |
|---------|-------------|
| [`complete`](examples/complete/) | Full AIOS stack — mirrors production deployment |
| [`sre-quickstart`](examples/sre-quickstart/) | Minimal SRE agents + incident response |
| [`aws-sre`](examples/aws-sre/) | AWS-focused SRE with audit workflows |
| [`software-engineering`](examples/software-engineering/) | Dev workflow pipeline |

## 🔧 Prerequisites

- **Terraform** >= 1.5
- **StackGen Platform** with Guild enabled
- **terraform-provider-stackgen** >= 0.0.20
- LLM API keys (OpenAI, Anthropic, and/or Gemini)

## 📄 License

Apache 2.0 — see [LICENSE](LICENSE).
