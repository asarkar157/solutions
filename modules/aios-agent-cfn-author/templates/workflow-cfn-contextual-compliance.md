FedRAMP and organisational baseline preflight for infrastructure intent — without full template synthesis.

Use from CI/CD pipelines or external agents before merge or before triggering intent-to-infrastructure.

**Profile:** FedRAMP `${fedramp_profile}` against baseline **${org_baseline_name}**.

**Triggers:** Guild chat or optional HTTP webhook when `enable_compliance_webhook = true`.

**Skills:** `cfn-developer-intent-handler`, `cfn-template-catalog-discovery`.
