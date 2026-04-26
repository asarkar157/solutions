# AIOS Agent — Marketing Operations

AI-powered marketing agent for content operations, campaign analytics, social media monitoring, SEO auditing, and email marketing automation.

## Usage

```hcl
module "marketing" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-marketing"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
}
```

## What It Creates

- 4 marketing agents (content, PR, analytics, sales enablement) with budgets and `dangerous_ops` policy attachments
- Runbook SOPs and workflows for product-launch style go-to-market orchestration

## Use Cases

- **Content Pipeline**: Automate research → brief → SEO optimization → publishing
- **Campaign Analytics**: Track CTR, ROAS, CPA across channels with optimization recommendations
- **Social Media**: Monitor brand mentions, audit engagement, optimize posting schedule
- **Email Marketing**: Design sequences, A/B test subject lines, ensure compliance
