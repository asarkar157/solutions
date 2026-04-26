# AIOS Agent — Marketing Operations

AI-powered marketing agent for content operations, campaign analytics, social media monitoring, SEO auditing, and email marketing automation.

## Usage

```hcl
module "marketing" {
  source = "github.com/stackgen-demo/solutions//modules/aios-agent-marketing"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    slack  = module.slack_integration.integration_name
    google = "google-workspace"
    linear = "linear-integration"
  }
}
```

## What It Creates

- 1 Agent (marketing-ops)
- 5 Runbook SOPs (content brief, campaign report, social audit, SEO audit, email sequence)
- 2 Workflows (content-pipeline, campaign-analytics)

## Use Cases

- **Content Pipeline**: Automate research → brief → SEO optimization → publishing
- **Campaign Analytics**: Track CTR, ROAS, CPA across channels with optimization recommendations
- **Social Media**: Monitor brand mentions, audit engagement, optimize posting schedule
- **Email Marketing**: Design sequences, A/B test subject lines, ensure compliance
