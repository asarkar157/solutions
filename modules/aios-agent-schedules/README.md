# AIOS agent schedules (composable)

Creates one or more [`sg_agent_schedule`](https://appcd-dev.github.io/terraform-provider-stackgen/resources/agent_schedule/) resources for **any** `sg_agent` or **`sg_workflow`** (same **`target_type`** / **`target_name`** pairing as **`sg_webhook`**).

## Usage

Point `target_name` at an output from your agent or workflow module. Use `target_type = "agent"` (default) or `"workflow"`.

```hcl
module "my_agent_schedules" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-schedules"

  target_name = module.aws_sre.aws_sre_agent_name
  # target_type = "agent" # default

  schedules = [
    {
      name       = "daily-cost-sanity"
      expression = "0 9 * * *" # 09:00 UTC daily
      action     = <<-EOT
        Read-only FinOps pass: summarize unattached EBS volumes and stopped EC2
        instances in the configured region; no destructive actions.
      EOT
      enabled = true
    },
  ]
}
```

## Inputs

| Name | Description |
|------|-------------|
| `target_type` | `agent` or `workflow` (default `agent`). |
| `target_name` | Guild name of the target agent or workflow (must exist). |
| `schedules` | List of `{ name, expression, action, enabled? }`. Empty list creates no schedules. |

Cron is **five fields** (minute hour day-of-month month day-of-week), per the StackGen provider.

**Migrating from older module versions:** replace the removed `agent_name` argument with `target_name` (and optionally `target_type = "agent"`).

## Requirements

Same StackGen provider (`releases.stackgen.com/stackgen/stackgen`) and credentials as other AIOS modules.
