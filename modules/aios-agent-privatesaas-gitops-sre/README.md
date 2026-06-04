# AIOS Agent — PrivateSaaS GitOps SRE

**Aiden for SRE** on PrivateSaaS (or SaaS with `aios-remote-runner` for PoC): Slack intake for npm/deploy/pipeline failures, cross-signal investigation across **GitLab**, **Argo CD**, **AWS DynamoDB**, **SonarQube**, and optional **Docker/npm** via Ubuntu MCP.

## Agents

| Agent | Integrations |
|-------|----------------|
| `slack-sre-intake` | Slack, GitLab (read) |
| `gitops-sre-investigator` | GitLab, Argo CD, AWS, SonarQube, Ubuntu (optional), remote runner (optional) |
| `gitops-sre-remediator` | Same + Slack notify; bounded remediation |

## Workflows

1. **`gitops-sre-incident-response`** — Slack ingest → GitLab → Argo CD → DynamoDB → containers → SonarQube → RCA → safety gate → Slack notify
2. **`gitops-sre-quality-audit`** — Read-only GitLab branch scan, SonarQube metrics, DynamoDB capacity review

Optional `sg_webhook` **`slack-gitops-sre`** when `enable_slack_webhook = true`.

Optional `sg_evidence_checklist` **`gitops-sre-rca`** when `enable_evidence_checklist = true`.

## Remote runner (PoC)

```hcl
create_remote_runner          = true
remote_runner_name            = "gitops-sre-runner"
remote_runner_attach_to_agent = true
enable_ubuntu_cli             = true # also provisions Ubuntu MCP for docker/npm
```

Provider **>= 0.1.25** (remote runner). Run `aiden-runner` using `remote_runner_cli_start_command` / `remote_runner_helm_install_command` outputs before attaching agents.

## Usage

```hcl
module "gitops_sre" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-privatesaas-gitops-sre?ref=main"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops   = module.policies.policy_ids.dangerous_ops
    sre_remediation = module.policies.policy_ids.sre_remediation
    prod_write_gate = module.policies.policy_ids.prod_write_gate
  }

  gitlab_base_url      = "https://gitlab.internal.example.com"
  gitlab_private_token = var.gitlab_token
  argocd_server_url    = "https://argocd.internal.example.com"
  argocd_auth_token    = var.argocd_token
  sonarqube_server_url = "https://sonar.internal.example.com"
  sonarqube_token      = var.sonarqube_token
  aws_secret_id        = module.aws_integration.secret_id

  slack_bot_token         = var.slack_bot_token
  slack_channel_allowlist = ["#sre-gitops", "#deployments"]

  enable_ubuntu_cli = true
}
```

## Integration modules

This agent composes:

- `aios-integration-gitlab`
- `aios-integration-argocd`
- `aios-integration-sonarqube`
- `aios-integration-aws`
- `aios-integration-slack`
- `aios-integration-ubuntu` (when `enable_ubuntu_cli` or `create_remote_runner`)
- `aios-remote-runner` (optional)
