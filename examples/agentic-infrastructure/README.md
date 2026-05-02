# Agentic infrastructure example

This root shows how a **platform team** can declare [StackGen](https://stackgen.com/) agents and workflows so **application teams** get a **natural language** path to infrastructure work—**greenfield** generation (new environments, buckets, namespaces) and **brownfield** changes (upgrades, access, refactors)—without opening routine platform tickets.

## What gets provisioned

| Layer | Module | Role |
|-------|--------|------|
| 0 | `aios-foundation` | LLM models and API key vault wiring for agents |
| 0 | `aios-policies` | Org-wide Rego guardrails (e.g. dangerous-ops intervention) |
| 1 | `provider "aws"` + `aws_iam_role` | Creates an IAM role (trust principals from StackGen); outputs **`aws_role_arn`** into `aios-integration-aws` |
| 1 | `sg_secret` (**Other** / **mcp**) + `sg_guild_integration` | One Vault MCP secret (`transport = streamable_http`) plus Guild integration for Consumer URL `{stackgen_url}/api/mcp/user` ([StackGen MCP](https://docs.stackgen.com/docs/stackgen-mcp)) |
| 1 | `aios-integration-github` *(optional)* | Guild GitHub integration when **`github_token`** is non-empty |
| 2 | `aios-agent-sre` | Minimal SRE agents/runbooks referenced by the SDLC release graph |
| 2 | `aios-agent-sdlc` | **Developer request intake** workflow + **cloud infrastructure engineer** agent |
| 2 | `aios-agent-repo-to-iac` *(optional)* | **`repository-iac-architect`** plus **`repository-to-iac`** and **`repo-scan-appstack-github-export`** workflows (needs GitHub integration; same MCP wiring as this root when `create_stackgen_mcp_integrations` is true) |

The **`developer-request-intake`** workflow is documented in the SDLC module with example prompts such as new staging environments, encrypted S3 buckets, and namespace requests. Governance stages (analyze → track → **policy check** → execute → close) reflect posture the platform team encodes in policies and agent attachments.

## Natural language entry points

1. **StackGen product UI** — Teams sign in at [stackgen.com](https://stackgen.com/) and interact with the agents and workflows this Terraform registers in their project.
2. **IDE MCP (`streamable_http` + token)** — StackGen documents **two** hosted MCP URLs: `/api/mcp/admin` (Producer) and `/api/mcp/user` (Consumer). Point Cursor at both with `type: streamable_http` (see [StackGen MCP](https://docs.stackgen.com/docs/stackgen-mcp)); use the same [PAT](https://docs.stackgen.com/docs/setup/pat) as `provider "sg"`. Do **not** use `/api/mcp/sse` for IDE MCP — it is not documented and clients typically time out.

   Copy [`cursor-mcp.stackgen.example.json`](cursor-mcp.stackgen.example.json) into your MCP config, set the host to match `stackgen_url`, and replace the placeholder token.

3. **Guild (in-product agents)** — One Vault secret (**Other** / **mcp**): `transport = streamable_http`, `url` = your `stackgen_url` with path `/api/mcp/user`, and JSON `headers` with `Bearer <PAT>`. One `sg_guild_integration` references that secret. Set `create_stackgen_mcp_integrations = false` to skip creating them.

## Usage

```bash
cd examples/agentic-infrastructure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — stackgen_token, one LLM provider key, and AWS trust inputs (see below).

terraform init
terraform apply
```

You need **both**: credentials for `provider "sg"` (StackGen) and for `provider "aws"` (IAM role creation in your account). Set **`aws_stackgen_trust_arns`** to the IAM principal ARN(s) StackGen shows when you connect AWS, or set **`aws_integration_assume_role_policy_json`** to the full trust policy JSON.

After apply, use `terraform output` for **`aws_role_arn`**, workflow and agent names, plus **`stackgen_mcp_integration_name`** and **`stackgen_mcp_url`** when wiring Guild or IDE configs. With **`github_token`** set, outputs also include **`github_integration_name`**, **`repository_iac_architect_agent`**, **`repository_to_iac_workflow`**, and **`repo_scan_appstack_github_export_workflow`** for the repo → IaC paths (see [`modules/aios-agent-repo-to-iac`](../../modules/aios-agent-repo-to-iac)).

## Variables

See [`variables.tf`](variables.tf). Highlights: **`aws_stackgen_trust_arns`** or **`aws_integration_assume_role_policy_json`** (required together with AWS credentials); **`aws_integration_managed_policy_arns`** defaults to read-only. **`github_token`** is optional; when non-empty it registers **`aios-integration-github`** and **`aios-agent-repo-to-iac`** (GitHub SCM in intake workflows plus repository-to-iac and appStack export workflows). Leave it empty to skip those modules.

Optional **`linear_integration_name`**, **`gcp_integration_name`**, and **`slack_integration_name`** attach existing Guild integrations to SDLC agents when non-empty (typical names: **`linear-integration`**, **`google-integration`**, **`slack-integration`**). Defaults remain empty so you only wire integrations that already exist in the project. **`module.aws_integration`** defaults to **`aws-production`**; **`stackgen_mcp_integration_name`** defaults to **`stackgen-mcp`**; with **`github_token`** set, GitHub defaults to **`github-integration`**—matching a Guild list such as `aws-production`, `github-integration`, `google-integration`, `linear-integration`, `slack-integration`, `stackgen-mcp`.
