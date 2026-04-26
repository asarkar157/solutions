# AIOS Policies

Central library of reusable OPA/Rego guardrail policies for AIOS agent governance. Each policy can be individually enabled or disabled.

## Usage

```hcl
module "policies" {
  source = "github.com/appcd-dev/solutions//modules/aios-policies"

  # All policies enabled by default. Disable specific ones:
  create_policies = {
    azure_tool_governance  = false  # skip if no Azure agents
    google_tool_governance = false  # skip if no Google workspace
  }
}
```

## Policies Included

| Policy | Type | Description |
|--------|------|-------------|
| `dangerous-ops` | intervention | Blocks destructive operations (rm -rf, kubectl delete, terraform destroy) |
| `hitl-sre-remediation` | intervention | Auto-remediation and escalation require approval |
| `prod-write-gate` | intervention | Production writes require owner/on-call acknowledgement |
| `blast-radius-limit` | intervention | Actions must target ≤ 5 pods / ≤ 3 nodes / single region |
| `post-action-verification` | intervention | Broader rollout requires SLI health confirmation |
| `container-shell-hitl-policy` | intervention | Container execution requires HITL approval |
| `hitl-approval-evaluation` | logic | Evaluates approver authorization |
| `tier0-service-protection` | logic | Tier-0 services: read-only and diagnostics only |
| `freeze-window` | logic | Deny changes during freeze windows |
| `data-risk-pii` | logic | PII/PCI/PHI data requires redaction pipeline |
| `azure-tool-governance` | logic | Azure CLI read-only, blocks destructive ops |
| `google-tool-governance` | logic | Google workspace tools, blocks shell ops |

## Outputs

| Name | Description |
|------|-------------|
| `policy_ids` | Map of policy names to IDs (for `sg_agent_policy_attachment`) |
| `policy_names` | Map of policy names to registered names |
