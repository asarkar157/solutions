# AI SOC Analyst Agent

The AI SOC Analyst Agent operates autonomously as a tier-1 Security Operations Center analyst. It integrates with your security tools and SIEM to ingest alerts, enrich them with threat intelligence, correlate them with infrastructure logs, and prioritize them for human analysts. 

This agent dramatically reduces alert fatigue, accelerates incident response, and proactively hunts for stealthy threats.

## Key Workflows

### 1. Alert Triage (`soc-alert-triage`)
Automates the first line of defense:
- Extracts Indicators of Compromise (IoCs).
- Enriches IoCs against Threat Intelligence databases.
- Correlates findings with CloudTrail, Kubernetes Audit Logs, or network flows.
- Dismisses false positives and provides structured summaries for true positives.

### 2. Threat Hunting (`soc-threat-hunt`)
Performs proactive security investigations:
- Formulates hunt hypotheses based on the latest CVEs or MITRE ATT&CK intelligence.
- Queries log aggregators (e.g., Splunk, Datadog) to uncover unauthorized access, lateral movement, or enumeration attempts.
- Generates detailed threat intelligence reports.

## Architecture & Integration

This module provisions an `sg_agent` alongside a strict `sg_agent_budget`. The agent uses the `soc-analyst` persona, granting it robust analytical capabilities with a "read-only" policy context unless overridden.

### Requirements

- Terraform >= 1.5
- StackGen Provider >= 0.1.10

### Variables

- `integration_names`: Map referencing tools like `aws`, `github`, `slack`, or `splunk`.
- `model_names`: Map defining the LLMs available (e.g., `gpt4o`).
- `agent_budget`: Maximum daily spending allowed (default: $25).
- `policy_ids`: Governance policies (e.g., attaching a `read_only` safety guardrail).

## Usage

```hcl
module "soc_analyst" {
  source = "./modules/aios-agent-soc-analyst"

  integration_names = {
    aws    = sg_integration_aws.main.name
    slack  = sg_integration_slack.main.name
    splunk = sg_integration_splunk.main.name
  }

  model_names = {
    gpt4o = sg_model_openai.gpt4o.name
  }
}
```
