# aios-sre-app-bindings

Binds Guild integrations to an installed **StackGen SRE Copilot** app (`sg_app` catalog slug `sre`).

## What it does

- Calls `PUT /api/v1/apps/sre` via the **`sg_app`** Terraform resource.
- Attaches Datadog, AWS, GitHub, Grafana, Slack, and other integration names the SRE app uses for discovery and investigation.
- **Optional (default on):** sets `config.setup_type = workspace` so the SRE app install is ready for onboarding. After apply, run **Discovery** once from the SRE app UI (same as finishing the connect-stack flow).

## Prerequisites

1. **stackgen-sre-app** must already be **installed** in the target Guild org (catalog install — not created by this module).
2. Provider **`sg` >= 0.1.27** (`sg_app` resource; `sg_sre_alert_webhook` for alert ingest).

## Usage

```hcl
module "sre_app_bindings" {
  source = "github.com/appcd-dev/solutions//modules/aios-sre-app-bindings?ref=main"

  merge_existing_app_integrations = true

  integration_names = compact([
    module.github_integration.integration_name,
    module.aws_integration.integration_name,
  ])

  alert_webhooks = [{
    source           = "datadog"
    integration      = "datadog" # existing integration from SRE app onboarding
    auto_investigate = false
  }]
}
```

Pass `alert_webhooks = []` (default) when Datadog ingest was configured during SRE app onboarding — no `sg_sre_alert_webhook` resources are created.

Set `merge_existing_app_integrations = false` to replace the full binding set (legacy behavior).

Set `enable_discovery_bootstrap = false` when the SRE app is already onboarded.

## Existing-install playbook

When the **stackgen-sre-app** is already installed (Datadog/Grafana from onboarding, discovery done):

```hcl
module "sre_app_bindings" {
  source = ".../aios-sre-app-bindings"

  merge_existing_app_integrations = true
  enable_discovery_bootstrap      = false
  integration_names               = [module.github_integration.integration_name]
  alert_webhooks                  = []

  remote_runner_name = var.create_remote_runner ? module.remote_runner.runner_name : ""

  investigator_policy_ids = var.enable_policies ? {
    dangerous_ops                = module.policies.policy_ids.dangerous_ops
    sre_remediation              = module.policies.policy_ids.sre_remediation
    prod_write_gate              = module.policies.policy_ids.prod_write_gate
    sre_investigation_write_gate = module.policies.policy_ids.sre_investigation_write_gate
    pagerduty_escalation_gate    = module.policies.policy_ids.pagerduty_escalation_gate
  } : null
  policy_create_flags = var.enable_policies ? module.policies.policy_create_flags : null
}
```

Import an existing `sg_app` binding before first apply when Terraform did not create it:

```bash
tofu import 'module.sre_app_bindings.sg_app.sre' sre
```

Attach the remote runner and investigator policies in the **same module** — no separate guardrail or runner modules.

## Variables

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `app_name` | no | `sre` | Catalog slug |
| `integration_names` | yes | — | Integrations to add or ensure (merged with existing when `merge_existing_app_integrations` is true) |
| `merge_existing_app_integrations` | no | `true` | Union with `data.sg_app` bindings instead of full replace |
| `config` | no | `null` | Install metadata; defaults to `setup_type = workspace` when `enable_discovery_bootstrap` is true |
| `enable_discovery_bootstrap` | no | `true` | Set workspace setup config; run discovery from the SRE app UI after apply |
| `alert_webhooks` | no | `[]` | SRE app alert ingest webhooks (`sg_sre_alert_webhook`) |
| `investigator_agent_name` | no | `stackgen-sre-investigator` | Catalog investigator agent for policy + runner attach |
| `investigator_policy_ids` | no | `null` | Policy IDs from `module.aios-policies`; null skips attachments |
| `policy_create_flags` | no | `null` | Gates optional policy attachments (from `module.aios-policies`) |
| `remote_runner_name` | no | `""` | Merge onto investigator via `sg_agent` adopt when non-empty |

## Outputs

| Name | Description |
|------|-------------|
| `configured` | Whether the install is configured |
| `integration_names` | Bound integration names after apply |
| `installation_id` | Server UUID |
| `discovery_bootstrap_enabled` | Whether workspace setup config was applied |
| `alert_webhook_trigger_urls` | Map of `source:integration` → absolute Guild trigger URL (sensitive) |
| `alert_webhook_ids` | Map of `source:integration` → Guild webhook UUID |
| `investigator_remote_runners` | Merged remote runners on investigator when `remote_runner_name` is set |
| `investigator_policies_attached` | Policy keys attached to the investigator |

## Destroy behavior

`terraform destroy` clears integration bindings on the app install (empty list). It does **not** uninstall the SRE app from the catalog. Discovery runs in the SRE app database are not deleted. Alert webhooks managed by `sg_sre_alert_webhook` are deregistered from Guild and removed from the SRE app config store.
