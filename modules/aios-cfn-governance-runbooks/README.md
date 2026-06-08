# CFN Governance Runbooks

Reusable Guild runbook SOPs for the five CloudFormation governance pillars. Nest this module from [`aios-agent-cfn-author`](../aios-agent-cfn-author/) (or any CFN agent) and reference `runbook_names` in workflow `runbook_refs`.

## Pillars

| Runbook | Use case |
|---------|----------|
| `cfn-gov-remote-orchestration` | Headless API / CI/CD / external agent payload normalization |
| `cfn-gov-contextual-compliance` | FedRAMP + organisational baseline intent review |
| `cfn-gov-hardened-synthesis` | Secure IaC from knowledge base + catalog |
| `cfn-gov-governed-deployment` | Org PR and deployment mechanism adherence |
| `cfn-gov-continuous-governance` | Day-2 drift + compliance classification |

## Usage

```hcl
module "cfn_governance_runbooks" {
  source = "github.com/appcd-dev/solutions//modules/aios-cfn-governance-runbooks?ref=main"

  org_baseline_name         = "acme-fedramp-moderate-baseline"
  fedramp_profile           = "moderate"
  knowledge_base_path       = "cloudformation/knowledge-base/"
  cfn_template_catalog_path = "cloudformation/catalog/"
}

# In workflow stage_bindings:
# runbook_refs = [module.cfn_governance_runbooks.runbook_names.contextual_compliance]
```
