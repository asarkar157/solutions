# AIOS Agent — ClickHouse Inspector

Dedicated ClickHouse inspection agent with deep system-table expertise for read-only diagnostics: cluster health, slow queries, parts/merge analysis, memory pressure, and ingestion throughput.

Uses a user-provided MCP server image (BYOI pattern) wrapping the official mcp-clickhouse server.

## Runbooks (5)

| Runbook | Purpose |
|---------|---------|
| `clickhouse-cluster-health-assessment` | Version, metrics, table sizes, running queries, server settings |
| `clickhouse-slow-query-analysis` | Slowest queries, resource-intensive queries, frequency analysis |
| `clickhouse-parts-merge-diagnostics` | Part count, merge backlog, TooManyParts risk assessment |
| `clickhouse-memory-pressure-triage` | Memory tracking, OOM risk, peak memory queries |
| `clickhouse-ingestion-health` | Insert throughput, failed inserts, mutation backlog |

## Usage

```hcl
module "clickhouse_inspector" {
  source = "github.com/appcd-dev/aios-modules//modules/aios-agent-clickhouse-inspector"

  model_names = {
    gpt4o         = module.foundation.model_names.gpt4o
    claude_sonnet = module.foundation.model_names.claude_sonnet
  }

  policy_ids = {
    dangerous_ops         = module.policies.policy_ids.dangerous_ops
    data_risk_pii         = module.policies.policy_ids.data_risk_pii
    azure_tool_governance = module.policies.policy_ids.azure_tool_governance
  }

  integration_names = {
    clickhouse = module.clickhouse_integration.integration_name
  }
}
```
