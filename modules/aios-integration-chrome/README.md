# AIOS Integration — Chrome Browser

Headless Chrome browser automation integration for StackGen agents. Enables agents to navigate web pages, take screenshots, inspect console messages and network traffic, run performance traces, and evaluate JavaScript.

## Capabilities

| MCP Tool | Purpose |
|----------|---------|
| `navigate_page` | Navigate to a URL |
| `take_screenshot` | Capture page screenshot (PNG, base64) |
| `list_console_messages` | Get console logs, warnings, errors |
| `evaluate_script` | Execute JavaScript to extract page data |
| `list_network_requests` | Inspect HTTP traffic |
| `get_performance_metrics` | Collect Core Web Vitals |
| `emulate_network` | Throttle to 3G/4G/offline |
| `resize_page` | Set viewport dimensions |

## Usage

```hcl
module "chrome_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-chrome"
}
```

### With domain restrictions

```hcl
module "chrome_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-chrome"

  allowed_domains      = "mycompany.com,staging.mycompany.com"
  max_tabs             = 3
  enable_response_body = true
}
```

### Combined with other integrations

Chrome is most powerful when combined with other integrations for cross-signal analysis:

```hcl
# Chrome for UI/frontend inspection
module "chrome" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-chrome"
  allowed_domains = "app.mycompany.com"
}

# Grafana for backend metrics correlation
module "grafana" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-grafana"
  grafana_server = "https://grafana.mycompany.com"
  grafana_token  = var.grafana_api_token
}

# GitHub for source code context
module "github" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-github"
  github_token = var.github_token
}
```

## Security Guardrails

| Guardrail | Default |
|-----------|---------|
| URL scheme blocking | `chrome://`, `file://`, `javascript:`, `data:`, `blob://` always blocked |
| Internal IP blocking | `127.0.0.1`, `10.*`, `172.16-31.*`, `192.168.*`, `169.254.*` always blocked |
| Domain allowlist | All public domains (configure via `allowed_domains`) |
| Response bodies | Headers only (enable via `enable_response_body`) |
| Tab limit | 5 (configure via `max_tabs`) |
| Session timeout | 30 minutes (configure via `session_timeout`) |

## Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `integration_name` | `string` | `"chrome-browser"` | Guild integration name |
| `allowed_domains` | `string` | `""` | Comma-separated domain allowlist |
| `max_tabs` | `number` | `5` | Max concurrent tabs (1-20) |
| `session_timeout` | `string` | `"30m"` | Session duration limit |
| `enable_response_body` | `bool` | `false` | Expose network response bodies |
| `env_vars` | `map(string)` | `{}` | Extra container env vars |

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `integration_id` | Guild integration resource ID |
