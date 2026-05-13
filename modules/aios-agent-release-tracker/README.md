# AIOS Agent — Microservice Release Tracker

Read-only conversational agent that fetches the **latest tag / release** of a microservice (or a list of services) and, when asked, correlates with the **container image** registry and the **currently deployed version** per environment. Useful for answering "is `payments-service` v2.5.0 in prod yet?".

## Usage

```hcl
module "release_tracker" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-release-tracker"

  # aios-foundation exposes model_names as list(string) — pass it through.
  # To hand-pick: model_names = [module.foundation.model_names_by_provider.claude_sonnet]
  model_names = module.foundation.model_names

  policy_ids = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    github = module.github_integration.integration_name
    slack  = module.slack_integration.integration_name
  }

  # Optional service catalog so operators can ask by service_name.
  service_catalog = {
    payments      = "appcd-dev/payments"
    checkout-api  = "appcd-dev/checkout"
    order-service = "appcd-dev/orders"
  }

  image_namespace_template = "ghcr.io/appcd-dev/{{service}}"
}
```

## What It Creates

- **1 agent**: `release-tracker` (GitHub + optional Slack)
- **4 runbook SOPs**: `latest-tags-and-releases`, `container-image-tag-discovery`, `deployed-version-correlation`, `release-diff`
- **1 workflow**: `microservice-release-tracking` (intent fan-out → composed Markdown answer)

## What it answers

- "What's the latest tag of `<service>`?"
- "List the last N releases of `<repo>` (with or without pre-releases)."
- "What version of `<service>` is currently deployed in `production`?"
- "What changed between `v2.4.0` and `v2.5.0` of `<service>`?"
- "Is the manifest in the platform repo pinned to the latest release?"

Always cites the source GitHub URL.

## Why this is read-only

- `hitl.always_allowed` lists only lookup-shaped tools.
- The `dangerous-ops` policy is attached so any attempt to publish a release, push an image, or modify a manifest requires HITL approval.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `model_names` | yes | — | `list(string)` of registered model names in priority order |
| `policy_ids` | yes | — | Must include `dangerous_ops` |
| `integration_names` | yes | — | Must include `github`; `slack` optional |
| `agent_budget` | no | `5` | Daily $ budget for the agent |
| `tag_limit` | no | `10` | Default per-repo tag / image limit |
| `release_limit` | no | `5` | Default per-repo Releases limit |
| `include_prereleases_default` | no | `false` | Default for the workflow's `include_prereleases` input |
| `image_namespace_template` | no | `ghcr.io/{{org}}/{{service}}` | Template used to derive an image ref from `service_name` |
| `service_catalog` | no | `{}` | Map of `service_name` → `owner/repo` to allow service-name lookups |
| `workflow_skill_refs` | no | `{}` | Optional `skill_refs` overrides per `<workflow>::<stage>` |

## Outputs

| Name | Description |
|------|-------------|
| `agent_name` | Guild name of the agent |
| `workflow_name` | Workflow name; pass to `aios-agent-schedules` for digests |
| `runbook_names` | All registered runbook SOP names |

## Schedule examples

Periodic release digest using `aios-agent-schedules`:

```hcl
module "release_tracker_schedules" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-schedules"

  target_type = "workflow"
  target_name = module.release_tracker.workflow_name

  schedules = [
    {
      name       = "monday-release-digest"
      expression = "0 12 * * 1" # Mondays 12:00 UTC
      action     = "Summarize new tags and releases across payments, checkout-api, and order-service since last Monday. Include the currently deployed production version of each."
    },
  ]
}
```
