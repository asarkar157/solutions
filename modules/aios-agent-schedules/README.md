# AIOS agent schedules (composable)

Creates one or more [`sg_agent_schedule`](https://appcd-dev.github.io/terraform-provider-stackgen/resources/agent_schedule/) resources for **any** agent defined elsewhere.

## Usage

Point `agent_name` at an output from your agent module (for example `module.aws_sre.aws_sre_agent_name`, `module.ubuntu_cli.agent_name`).

```hcl
module "my_agent_schedules" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-schedules"

  agent_name = module.aws_sre.aws_sre_agent_name

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
| `agent_name` | Target agent’s Guild name (must exist). |
| `schedules` | List of `{ name, expression, action, enabled? }`. Empty list creates no schedules. |

Cron is **five fields** (minute hour day-of-month month day-of-week), per the StackGen provider.

## Requirements

Same StackGen provider (`releases.stackgen.com/stackgen/stackgen`) and credentials as other AIOS modules.
