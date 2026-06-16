# AIOS Agent — Web Inspector

Cross-signal web application inspector that combines **Chrome browser automation** with **Grafana** observability, **GitHub** source context, and **Ubuntu CLI** OS diagnostics for comprehensive frontend-to-backend analysis.

## Integrations

| Integration | Required | Purpose |
|-------------|----------|---------|
| Chrome Browser | ✅ Yes | Navigate, screenshot, debug console, inspect network, performance |
| Ubuntu CLI | ✅ Yes | DNS, connectivity, OS-level diagnostics |
| Grafana | Optional | Backend metrics, latency, error rates |
| GitHub | Optional | Source code context, recent changes |

## Runbooks (3)

| Runbook | Purpose |
|---------|---------|
| `web-visual-smoke-test` | Navigate flows, screenshot, check console errors, verify APIs |
| `web-frontend-performance-audit` | Core Web Vitals, mobile emulation, network throttling |
| `web-cross-signal-triage` | Correlate frontend errors with backend metrics and source changes |

## Usage

### Minimal (Chrome + Ubuntu only)

```hcl
module "web_inspector" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-web-inspector"

  model_names = module.foundation.model_names

  policy_ids = {
    dangerous_ops        = module.policies.policy_ids.dangerous_ops
    container_shell_hitl = module.policies.policy_ids.container_shell_hitl
  }

  chrome_allowed_domains = "app.mycompany.com,staging.mycompany.com"
}
```

### Full (Chrome + Grafana + GitHub + Ubuntu)

```hcl
module "web_inspector" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-web-inspector"

  model_names = module.foundation.model_names

  policy_ids = {
    dangerous_ops        = module.policies.policy_ids.dangerous_ops
    container_shell_hitl = module.policies.policy_ids.container_shell_hitl
  }

  chrome_allowed_domains    = "app.mycompany.com"
  grafana_integration_name  = module.grafana_integration.integration_name
  github_integration_name   = module.github_integration.integration_name
  github_secret_id          = module.github_secret.secret_id
}
```

### Sharing existing integrations

```hcl
module "web_inspector" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-web-inspector"

  model_names = module.foundation.model_names

  policy_ids = {
    dangerous_ops        = module.policies.policy_ids.dangerous_ops
    container_shell_hitl = module.policies.policy_ids.container_shell_hitl
  }

  existing_chrome_integration_name = module.chrome.integration_name
  existing_ubuntu_integration_name = module.ubuntu.integration_name
  grafana_integration_name         = module.grafana.integration_name
}
```

## Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `model_names` | `list(string)` | — | LLM model names (required) |
| `policy_ids` | `object` | — | Policy IDs for dangerous_ops and container_shell_hitl |
| `chrome_allowed_domains` | `string` | `""` | Comma-separated domain allowlist |
| `chrome_max_tabs` | `number` | `3` | Max concurrent tabs |
| `grafana_integration_name` | `string` | `""` | Optional Grafana integration |
| `github_integration_name` | `string` | `""` | Optional GitHub integration |
| `github_secret_id` | `string` | `""` | Optional GitHub PAT secret ID |
| `name_suffix` | `string` | `""` | Suffix for resource names |

## Outputs

| Name | Description |
|------|-------------|
| `agent_name` | Name of the Web Inspector agent |
| `chrome_integration_name` | Resolved Chrome integration name |
| `ubuntu_integration_name` | Resolved Ubuntu integration name |
| `runbook_sop_names` | Map of SOP names |
