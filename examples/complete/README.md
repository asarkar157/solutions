# Complete AIOS Stack Example

This example deploys the full AIOS stack, mirroring the production deployment in `terraform/guild/main.tf`. It demonstrates how all module layers compose together.

**Adoption path:** this is the **compose-path reference** after you finish [Onboarding step 4](https://appcd-dev.github.io/solutions/onboarding/step-4/) or the [Adopt the repo — Path 3](https://appcd-dev.github.io/solutions/adopt/) guide. For pre-sales demos, start with a single scenario under [`examples/scenarios/`](../scenarios/) instead.

CI validates this root via `make validate` from the repository root.

## What this wires

```
Layer 0 — foundation, policies
Layer 1 — AWS, GitHub, Slack, Ubuntu CLI (+ optional Grafana)
Layer 2 — SRE, AWS SRE, software engineering, supply chain, workspace, and more
```

See [`main.tf`](main.tf) for the full module graph. Optional blocks (Grafana alert-triage, software-engineering with Linear/Cursor MCP) activate when you set the corresponding variables.

## Minimum vs full

| Tier | What you need |
|------|----------------|
| **Plan-only smoke test** | StackGen URL + token + provider registry auth (`TF_TOKEN_releases_stackgen_com`) |
| **Minimal apply** | Above + at least one LLM key + `aws_role_arn` + `github_token` + `slack_bot_token` |
| **Full stack** | All required vars in `terraform.tfvars.example`, plus optional Grafana and Langfuse |

For a smaller first apply, use a scenario such as [`aws-sre-demo`](../scenarios/aws-sre-demo/) or [`pipeline-insights`](../scenarios/pipeline-insights/) instead.

## Prerequisites

- StackGen platform with Guild enabled
- LLM API keys (OpenAI + Anthropic minimum for full stack; at least one for foundation)
- AWS IAM role for SRE operations
- GitHub token and Slack bot token
- Optional: Grafana instance with API token (enables alert-triage agent)

See the [Prerequisites checklist](https://appcd-dev.github.io/solutions/prerequisites/) for credential details.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (or use TF_VAR_* env vars)
tofu init
tofu plan
tofu apply
# Interchangeable: use `terraform` instead of `tofu` if you use HashiCorp Terraform.
```

Optional webhook wiring: see [`http-webhook.tf.example`](http-webhook.tf.example).

## Related

- [Adopt the repo](https://appcd-dev.github.io/solutions/adopt/) — pick demo, export, or compose path
- [Architecture](https://appcd-dev.github.io/solutions/architecture/) — layer dependency diagram
- [Use-case catalog](https://appcd-dev.github.io/solutions/use-case-catalog/) — pick a subset of modules for a customer profile
