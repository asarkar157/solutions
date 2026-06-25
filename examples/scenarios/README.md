# Runnable scenarios

Pre-sales demo roots — one Terraform stack per prospect question. Each scenario is **< 80 lines of HCL** (typical) with a talk track in its README.

> **Keep in sync:** when adding a scenario, update this table and the prospect-question table in [`docs/se-playbook.md`](../../docs/se-playbook.md).

**Run any scenario from the repo root:**

```bash
make demo-doctor                    # check credentials first
make demo SCENARIO=<name>           # init + apply
make demo-reset SCENARIO=<name>     # clean up between calls
make demo-list                      # list available scenarios
```

**Adoption guide:** [Adopt the repo — Path 1](https://appcd-dev.github.io/solutions/adopt/#path-1--demo-aiden-today-pre-sales) · [SE Playbook](https://appcd-dev.github.io/solutions/se-playbook/)

---

| Scenario | One-line pitch | Command |
|----------|----------------|---------|
| [`aws-sre-demo`](aws-sre-demo/) | Triage and remediate an AWS incident end-to-end with policy-gated fixes. | `make demo SCENARIO=aws-sre-demo` |
| [`datadog-aws-rca`](datadog-aws-rca/) | Datadog monitor fires at 2am — investigate on AWS, write RCA back. | `make demo SCENARIO=datadog-aws-rca` |
| [`grafana-github-rca`](grafana-github-rca/) | Grafana alert → correlate with GitHub commits → RCA (no cloud creds). | `make demo SCENARIO=grafana-github-rca` |
| [`finops-weekly`](finops-weekly/) | Weekly FinOps summary to Slack with policy-gated cleanup proposals. | `make demo SCENARIO=finops-weekly` |
| [`pipeline-insights`](pipeline-insights/) | Read-only CI/deployment intelligence — lowest-friction first demo. | `make demo SCENARIO=pipeline-insights` |
| [`jenkins-sre-demo`](jenkins-sre-demo/) | Jenkins CI/CD integration with OPA safety gates for triggering production builds. | `make demo SCENARIO=jenkins-sre-demo` |
| [`incident-triage`](incident-triage/) | Grafana alert fatigue → filtered ingest, hypothesis RCA, Slack narrative. | `make demo SCENARIO=incident-triage` |
| [`repo-to-iac`](repo-to-iac/) | GitHub URL → inferred Terraform via StackGen MCP. | `make demo SCENARIO=repo-to-iac` |
| [`monorepo-services-split`](monorepo-services-split/) | Monorepo → DDD boundary map and optional service extract PR. | `make demo SCENARIO=monorepo-services-split` |
| [`pre-deploy-iam-gate`](pre-deploy-iam-gate/) | CCE PR delta → file:line IAM entitlement review comment. | `make demo SCENARIO=pre-deploy-iam-gate` |
| [`compliance-evidence-factory`](compliance-evidence-factory/) | Multi-repo CCE scan + regulatory digest for auditors. | `make demo SCENARIO=compliance-evidence-factory` |
| [`gitops-incident-scope`](gitops-incident-scope/) | CCE directory → Argo CD app correlation after rollback. | `make demo SCENARIO=gitops-incident-scope` |
| [`cve-reachability-fix`](cve-reachability-fix/) | Fix reachable CVEs only — CCE f-SBOM prioritization. | `make demo SCENARIO=cve-reachability-fix` |
| [`agentic-infra-entitlements`](agentic-infra-entitlements/) | CCE-gated repo-to-iac before developer-request execute. | `make demo SCENARIO=agentic-infra-entitlements` |
| [`bedrock-sonnet-demo`](bedrock-sonnet-demo/) | AWS SRE on Bedrock Claude Sonnet 4.6 — no Anthropic API key. | `make demo SCENARIO=bedrock-sonnet-demo` |
| [`cfn-author`](cfn-author/) | Plain-language intent → CFN PR + drift governance on Bedrock. | `make demo SCENARIO=cfn-author` |
| [`spec-symphony`](spec-symphony/) | Stage 5 SDD factory: webhooks → remote runner → spec → PR. | `make demo SCENARIO=spec-symphony` |
| [`sre-boost`](sre-boost/) | Add GitHub, AWS, remote runner to an **existing** SRE agent. | `make demo SCENARIO=sre-boost` |
| [`slo-weekly-review`](slo-weekly-review/) | OpenSLO from GitHub + Grafana Prometheus → weekly Slack digest. | `make demo SCENARIO=slo-weekly-review` |
| [`cdk-bot`](cdk-bot/) | GitHub issue → CDK change + quality checks → draft PR (plain-English README + runner scripts). | `make demo SCENARIO=cdk-bot` |
| [`clean-tenant-reset`](clean-tenant-reset/) | Utility: reset demo tenant to foundation + policies baseline. | `make demo SCENARIO=clean-tenant-reset` |

---

## Full stack fallback

If the prospect needs every integration wired, use [`examples/complete/`](../complete/) — but lead with a single scenario first.
