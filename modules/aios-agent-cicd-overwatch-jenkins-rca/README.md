# AIOS Agent — CICD Overwatch Jenkins RCA

Investigation workflow that analyzes and attempts to solve Jenkins CI/CD issues reported by an inbound Linear ticket: claim the ticket, read its context, collect live Jenkins (and optional AWS/GitHub) evidence, diagnose the failure and recommend a fix, post an RCA back to Linear, and — only with explicit human approval — apply a safe remediation.

## Usage

```hcl
module "cicd_overwatch_jenkins_rca" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-cicd-overwatch-jenkins-rca?ref=main"

  model_names = module.foundation.model_names
  # policy_ids = { dangerous_ops = module.policies.policy_ids.dangerous_ops }  # optional

  # Reuse integrations already registered in the StackGen project (e.g. POC):
  existing_jenkins_integration_name = "jenkins"
  existing_linear_integration_name  = "devops-linear"

  # Optional — extend evidence collection into artifacts/deployments and source control.
  # existing_aws_integration_name    = "aws-production"
  # existing_github_integration_name = "github-integration"

  webhook_allowed_cidrs = []
}
```

## What It Creates

- 1 Agent: `cicd-overwatch-investigator` — single persona used across all six workflow stages
- 6 Guild skills (`sg_skill`) from `skills/*.md`, one per workflow stage
- 1 optional knowledge base (`sg_knowledge_base`) with 5 uploaded reference documents (`sg_knowledge_document`) from `knowledge/*.md`
- 6 Runbook SOPs (one per stage)
- 1 Workflow (`cicd-overwatch-jenkins-rca`) with exactly six stages
- Optional `sg_webhook` `cicd-overwatch-linear-ticket-receiver` when `enable_linear_webhook = true`
- Internal integration submodules for Jenkins, Linear, AWS, and GitHub (or attach existing integrations via `existing_*_integration_name`)

## Workflow Stages

| Stage | Purpose |
|-------|---------|
| claim-ticket-in-progress | Assign and move the Linear ticket to in-progress; acknowledge investigation has started. |
| read-ticket-context | Parse the ticket and extract concrete identifiers (job, build, commit, image, environment). |
| collect-live-evidence | Query Jenkins (and AWS/GitHub when attached) for build metadata, console output, and artifact/source evidence. |
| diagnose-and-recommend | Classify the failure class, rule out an alternative, recommend the smallest safe fix and verification steps. |
| post-linear-rca | Post a concise, structured RCA comment to the Linear ticket. |
| optional-approved-remediation | Only with explicit operator approval: execute the fix, then report action, verification, and result back to Linear. Not `required` — the workflow completes even if skipped. |

All six stages are bound to the same `cicd-overwatch-investigator` agent, matching the single-persona pattern used by `aios-agent-spec-symphony`.

## Knowledge Base

The five documents under `knowledge/` (copied from the CICD Overwatch demo reference material) are uploaded to a dedicated knowledge base via `sg_knowledge_document.source_url`, which fetches from `raw.githubusercontent.com/<knowledge_source_repo>/<knowledge_source_ref>/modules/aios-agent-cicd-overwatch-jenkins-rca/knowledge/<file>`. **Push this module to the configured ref before running `tofu apply`** so the raw URLs resolve:

- `incident-investigation-sop.md` — overall SOP and guardrails
- `jenkins-topology.md` — controller URL, job list, and investigation tips
- `aws-artifact-investigation.md` — artifact/registry/deployment investigation playbook
- `source-and-contract-investigation.md` — source-control and API contract investigation playbook
- `safe-remediation.md` — approval-gated remediation allow/deny list

Set `enable_knowledge_base = false` to skip uploading, or override `knowledge_source_repo` / `knowledge_source_ref` if you fork this module.

## HITL / Approval

The agent's `hitl.always_allowed` only covers read-only Linear comment/update and Jenkins read tools. Mutating tools (Jenkins reruns/restarts, AWS changes, GitHub changes) fall through to default human-in-the-loop approval, which is how `optional-approved-remediation` stays approval-gated without a separate policy stage.

## Outputs

| Name | Description |
|------|-------------|
| `agent_name` | Name of the investigator agent |
| `workflow_name` | Name of the `cicd-overwatch-jenkins-rca` workflow |
| `*_integration_name` | Resolved Jenkins, Linear, AWS, GitHub integration names |
| `knowledge_base_id` | ID of the knowledge base when enabled |
| `skill_names` | Names of the provisioned Guild skills |
| `webhook_id` / `webhook_token` | Linear ingress webhook credentials |
