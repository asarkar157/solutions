---
layout: page
title: CCE enterprise workflows
permalink: cce-enterprise-workflows/
nav_order: 5
---

# CCE × Guild enterprise superpowers

Seven enterprise workflows combining **CCE (Code Context Engine)** file:line entitlement evidence with **Guild** multi-stage, policy-gated orchestration.

**Formula:** deterministic scope first → LLM reasoning second → governed action last.

See also [CCE × AIOS integration map]({% include doc_url.html path="cce-agent-integrations.md" %}) and the upstream [CCE use case catalog](https://github.com/appcd-dev/cce/blob/main/docs/use-cases/catalog.md).

---

## Workflow index

| # | Superpower | Module | CCE recipes / lenses | Demo scenario |
|---|------------|--------|----------------------|---------------|
| 1 | Monolith split with entitlement boundaries | [`aios-agent-monorepo-services-splitter`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-monorepo-services-splitter) + optional [`aios-agent-db-state-splitter`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-db-state-splitter) | `cloud-entitlements`, `microservice-decomposition`, `monorepo-intelligence` | `make demo SCENARIO=monorepo-services-split` |
| 2 | Block IAM at PR time | [`aios-agent-terraform-bot`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-terraform-bot) | `pre-deploy-iam-review`, `change-control` | `make demo SCENARIO=pre-deploy-iam-gate` |
| 3 | Scope incidents by code | [`aios-agent-alert-triage`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-alert-triage) | `incident-scoping`, `blast-radius-analysis` | `make demo SCENARIO=incident-triage` |
| 4 | Compliance evidence on schedule | [`aios-agent-compliance-auditor`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-compliance-auditor) | `audit-evidence`, `regulatory-scope`, `landing-zone-governance` | `make demo SCENARIO=compliance-evidence-factory` |
| 5 | GitOps rollback scope | [`aios-agent-privatesaas-gitops-sre`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-privatesaas-gitops-sre) | `incident-scoping`, `change-impact-analysis` | `make demo SCENARIO=gitops-incident-scope` |
| 6 | CVE reachability fixes | [`aios-agent-supply-chain-security`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-supply-chain-security) | `cve-reachability` | `make demo SCENARIO=cve-reachability-fix` |
| 7 | Entitlement-sized IAM (self-service) | [`examples/agentic-infrastructure`]({{ site.github.repository_url }}/tree/main/examples/agentic-infrastructure) + [`aios-agent-repo-to-iac`]({{ site.github.repository_url }}/tree/main/modules/aios-agent-repo-to-iac) | `cloud-entitlements`, `iac-alignment` | `make demo SCENARIO=agentic-infra-entitlements` |

---

## Enable flags (operator)

| Module | Variable | Default |
|--------|----------|---------|
| monorepo-services-splitter | `enable_cce_enhanced` | `true` |
| terraform-bot | `enable_cce`, `enable_iam_gate_workflow` | `true`, `false` |
| alert-triage | `enable_cce` | `true` |
| compliance-auditor | `enable_cce`, `enable_compliance_evidence_factory` | `true`, `false` |
| privatesaas-gitops-sre | `enable_cce` | `true` |
| supply-chain-security | `enable_cce`, `enable_cce_reachability` | `true`, `true` |
| agentic-infrastructure | `enable_entitlement_guard` | `true` |

Shared CCE scripts: [`modules/aios-cce-scripts/`]({{ site.github.repository_url }}/tree/main/modules/aios-cce-scripts/). Recycle Ubuntu sidecar after `tofu apply` when `CCE_PACK_B64` changes.

---

## SE talk tracks

| Prospect said… | Run |
|----------------|-----|
| "Split our monolith with real boundary data" | `monorepo-services-split` |
| "We find out about IAM gaps after merge" | `pre-deploy-iam-gate` |
| "We page 40 teams for every KMS alert" | `incident-triage` (with `github_default_repos`) |
| "Auditors want proof, not slides" | `compliance-evidence-factory` |
| "Don't rollback the whole cluster" | `gitops-incident-scope` |
| "Dependabot is noise" | `cve-reachability-fix` |
| "Self-service infra without shadow admin" | `agentic-infra-entitlements` |

Full prospect map: [SE Playbook]({% include doc_url.html path="se-playbook.md" %}).
