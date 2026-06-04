---
layout: page
title: SE playbook
permalink: se-playbook/
nav_order: 3
---

# Solutions engineer playbook

A short, prospect-driven map: what the prospect just asked → which scenario you should run. Every scenario in this playbook is **one runnable Terraform root** under [`examples/scenarios/`]({{ site.github.repository_url }}/tree/main/examples/scenarios) that finishes inside a single discovery call. If the prospect needs the **full** stack with every integration wired, the reference is still [`examples/complete/`]({{ site.github.repository_url }}/tree/main/examples/complete) — but lead with one of these first.

## When to reach for this repo at all

| Situation | Use this repo? | Why |
|-----------|----------------|-----|
| **Pre-sales demo:** you have 15–30 min on Zoom and need a working Aiden in front of a prospect. | **Yes — run a scenario** | One `make demo SCENARIO=…` gets you to "first agent reply" faster than clicking through the UI. |
| **PoC handoff:** you have configured a tenant in the UI and the customer wants it in code. | **Yes — capture it** | Use [`tools/aios-export/`]({{ site.github.repository_url }}/tree/main/tools/aios-export) to snapshot the tenant to HCL the customer can own. |
| **Multi-env rollout:** the customer wants dev / staging / prod tenants from the same baseline. | **Yes — clone the scenario** | Each scenario is parameterized by `STACKGEN_URL` / `STACKGEN_TOKEN`; same root, different `terraform.tfvars`. |
| **Discovery call, no Aiden yet:** the prospect wants to see what an "agent" even is. | **No — open Guild UI** | Modules add latency you do not need. Come back here once they nod at the concept. |
| **Internal eng explaining the platform to another eng team.** | **Maybe — link [architecture]({% include doc_url.html path="architecture.md" %})** | The diagram doc is faster than reading 15 module READMEs. |

## Prospect-question → scenario

Drop the prompts below in your talk track. Each one points at a single scenario; resist composing on the fly during the call.

| The prospect said… | Run | Why it lands |
|--------------------|-----|--------------|
| "Can your thing actually fix an AWS incident?" | **`aws-sre-demo`** | Connects AWS, registers the SRE agents, hands you a chat to type "EC2 i-… is unhealthy" into. ~5 min to first reply. |
| "We are drowning in cloud spend." | **`finops-weekly`** | Cost optimizer + resource janitor + weekly Slack summary. The pitch the team flagged as "comes way later" — now it is a 5-min demo. |
| "Our CI is a mess, what do you actually see?" | **`pipeline-insights`** | Read-only — no prod creds needed. Lowest-friction first demo; safe even mid-call when you do not have the prospect's AWS yet. |
| "We get 200 Grafana alerts a day." | **`incident-triage`** | Grafana ingest filter → prior-incident search → PromQL probe → ReAcTree hypothesis RCA → Slack narrative. Demonstrates the "alert fatigue → triaged narrative" pitch. |
| "We have a legacy repo. Can your platform take it from here?" | **`repo-to-iac`** | Paste a GitHub URL, get IaC. Already runnable today as [`examples/repo-to-iac/`]({{ site.github.repository_url }}/tree/main/examples/repo-to-iac). |
| "We have a monolith codebase — can you tell us how to split it?" | **`monorepo-services-split`** | Run **`monorepo-services-split-analysis`** first (guidance PR with `service-catalog.yaml`). Extract only after plan approval. Pairs with **`db-state-splitter`** for IaC + app code. [Module guide]({% include doc_url.html path="monorepo-services-splitter.md" %}). [CCE workflows]({% include doc_url.html path="cce-enterprise-workflows.md" %}). |
| "New AWS calls slip into prod without IAM review." | **`pre-deploy-iam-gate`** | CCE PR delta → GitHub comment with file:line entitlements. |
| "We page everyone when KMS fails." | **`incident-triage`** | Enable CCE + `github_default_repos` — scope RCA to repos that call the failing API. |
| "Auditors want continuous evidence." | **`compliance-evidence-factory`** | Multi-repo CCE pack scan + regulatory digest. |
| "Argo rollback took down unrelated apps." | **`gitops-incident-scope`** | CCE directory → Argo app correlation. |
| "Dependabot alert fatigue." | **`cve-reachability-fix`** | CCE f-SBOM prioritization + fix PRs. |
| "Teams want S3 buckets without `s3:*`." | **`agentic-infra-entitlements`** | CCE on repo-to-iac before developer-request execute. |
| "We want Claude on AWS Bedrock, not a separate Anthropic key." | **`bedrock-sonnet-demo`** | **`aios-foundation-bedrock`** + AWS SRE agent on `claude-sonnet-bedrock`. IAM role or static AWS keys. [Scenario README]({{ site.github.repository_url }}/tree/main/examples/scenarios/bedrock-sonnet-demo). |
| "I want to clean state between demos." | **`clean-tenant-reset`** | Minimal foundation + policies, used as a known baseline you can re-apply over a previous demo. |

## Demo runbook (one screen)

1. Sanity-check creds — `make demo-doctor` will tell you what is missing before the prospect sees a stack trace.
2. Pick the scenario from the table above. `make demo SCENARIO=<name>`.
3. Open the Guild URL printed in the outputs. The scenario README's **Talk track** section is the 5-bullet talk you walk through.
4. After the call, run `make demo-reset SCENARIO=<name>` so the next prospect lands on a clean slate.

If your prospect wants the export instead of a fresh demo — i.e. they already played with Aiden in the UI and want to keep it — point them at [`tools/aios-export/`]({{ site.github.repository_url }}/tree/main/tools/aios-export). Phase 1 emits raw `sg_*` HCL plus a JSON snapshot; phase 2 rewrites that HCL into module form.

## Office hours & feedback

This page is **edited by the solutions team — plus the bot**. Open a `scenario-request` issue ([template]({{ site.github.repository_url }}/issues/new?template=scenario-request.md)) when a prospect asks something we do not yet have a one-command answer for. The [`scenario-author` agent]({{ site.github.repository_url }}/tree/main/modules/aios-agent-scenario-author) triages every such issue within minutes: it either points you at the existing scenario that fits or scaffolds a draft PR (with this table updated as part of the PR's reviewer checklist). The owners for each scenario are listed in [`CONTRIBUTORS-SE.md`]({{ site.github.repository_url }}/blob/main/CONTRIBUTORS-SE.md); ping them directly when their scenario's PR needs review. Office-hour cadence and Slack channel are in [`docs/se-feedback.md`]({% include doc_url.html path="se-feedback.md" %}).
