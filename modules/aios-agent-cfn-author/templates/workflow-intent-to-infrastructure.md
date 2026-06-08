Natural-language developer intent → FedRAMP/org baseline compliance → hardened CloudFormation synthesis → governed GitHub PR → validation and optional change-set preview.

Integrates with the customer's AWS account, existing CloudFormation template catalog under `${cfn_template_catalog_path}`, knowledge base at `${knowledge_base_path}`, and source control at `${target_repository_full_name}`.

**Governance pillars (via `aios-cfn-governance-runbooks`):**
- **Remote orchestration** — webhook/API/CI ingress normalization
- **Contextual compliance** — FedRAMP `${fedramp_profile}` + baseline `${org_baseline_name}`
- **Hardened synthesis** — KB-driven secure templates
- **Governed deployment** — ${deployment_process_doc}

**Triggers:**
- **Active:** HTTP webhook (`sg_webhook` `cfn-intent-to-infrastructure`) when `enable_intent_webhook = true` — POST to StackGen `/api/v1/webhooks/trigger` with the webhook token (see module outputs).
- **Passive:** Guild chat queries (cloudformation, generate template, intent to infra, cfn).

**Webhook JSON (example):**
```json
{
  "intent": "Create an S3 bucket with versioning in us-east-1",
  "stack_name": "staging-data",
  "environment": "staging",
  "workspace_id": "org/infra-templates",
  "correlation_id": "ci-12345",
  "ci_pipeline": "github-actions/deploy"
}
```

**Skills:** `cfn-developer-intent-handler`, `cfn-company-best-practices`, `cfn-template-catalog-discovery`, `cfn-architecture-fit-review`.
