---
layout: page
title: Topic guides
permalink: guides/
nav_order: 5
---

# Topic guides

Deep dives beyond the [adoption paths]({% include doc_url.html path="adopt.md" %}). Use these after you know **which job** you are doing (demo, export, or compose).

**New term?** Check the [Glossary]({% include doc_url.html path="glossary.md" %}) first.

---

## Reference

| Guide | When to read |
|-------|--------------|
| [Glossary]({% include doc_url.html path="glossary.md" %}) | Plain-English lookup for StackGen, Guild, agents, workflows, IaC, and other concepts on this site. |

---

## Deployment and rollout

| Guide | When to read |
|-------|--------------|
| [Architecture]({% include doc_url.html path="architecture.md" %}) | Layer diagram — foundation → integrations → agents — and how modules depend on each other. |
| [Enterprise deployment profile]({% include doc_url.html path="enterprise-deployment-profile.md" %}) | Post-PoC enterprise rollout: module choice, webhooks, skills sync, LLM egress, milestones. |
| [Migration guide]({% include doc_url.html path="migration-guide.md" %}) | Refactor monolithic `terraform/guild/main.tf` into `aios-*` modules. |
| [aios-export]({% include doc_url.html path="aios-export.md" %}) | Capture a UI-configured Guild tenant as HCL (PoC handoff). |

---

## Agent workflows

| Guide | When to read |
|-------|--------------|
| [CloudFormation Author]({% include doc_url.html path="cfn-author.md" %}) | Intent → CFN PR, compliance preflight, drift management. |
| [Monorepo services split]({% include doc_url.html path="monorepo-services-splitter.md" %}) | Monolith → microservices: analysis PR, optional extract. |
| [Spec-driven orchestration]({% include doc_url.html path="spec-driven-orchestration.md" %}) | Stage 5 SDD factory (`aios-agent-spec-symphony`). |
| [CCE enterprise workflows]({% include doc_url.html path="cce-enterprise-workflows.md" %}) | Seven enterprise superpowers with demo scenarios. |
| [CCE × AIOS integrations]({% include doc_url.html path="cce-agent-integrations.md" %}) | Code Context Engine usage mapped to agent modules. |
| [Omnichannel triage]({% include doc_url.html path="omnichannel-triage.md" %}) | Slack / Teams Event Subscription wiring for chat intake. |

---

## Governance and module selection

| Guide | When to read |
|-------|--------------|
| [Use-case catalog]({% include doc_url.html path="use-case-catalog.md" %}) | Customer situation → agent + integration modules. |
| [Writing Rego policies]({% include doc_url.html path="rego-policies.md" %}) | Policy evaluation, sample input JSON, OPA Playground. |

---

## Community

| Guide | When to read |
|-------|--------------|
| [SE feedback / office hours]({% include doc_url.html path="se-feedback.md" %}) | Slack channel, scenario-request issues, weekly cadence. |
| [Onboarding (compose deep dive)]({% include doc_url.html path="onboarding/index.md" %}) | Five-step path for module integration and local CI parity. |
