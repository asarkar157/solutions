# AIOS Agent — Ubuntu CLI Inspector

Dedicated Linux OS diagnostic agent for read-only triage: network connectivity, process analysis, disk space, and log analysis.

## Runbooks (4)

| Runbook | Purpose |
|---------|---------|
| `ubuntu-network-diagnostics` | DNS, ping, port reachability, routing |
| `ubuntu-process-triage` | CPU/memory consumers, zombies, system load |
| `ubuntu-disk-triage` | Disk capacity, inode usage, file descriptor leaks |
| `ubuntu-log-analysis` | Syslog errors, dmesg OOM kills, application exceptions |

## Usage

```hcl
module "ubuntu_cli" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-ubuntu-cli"

  model_names = {
    gpt4o         = module.foundation.model_names.gpt4o
    claude_sonnet = module.foundation.model_names.claude_sonnet
  }

  policy_ids = {
    dangerous_ops        = module.policies.policy_ids.dangerous_ops
    container_shell_hitl = module.policies.policy_ids.container_shell_hitl
  }

  integration_names = {
    ubuntu_cli = module.ubuntu_integration.integration_name
  }
}
```
