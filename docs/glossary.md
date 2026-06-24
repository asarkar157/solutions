---
layout: page
title: Glossary
permalink: glossary/
nav_order: 6
---

# Glossary

Plain-English definitions for terms you will see in this repo, the docs site, and customer conversations. Use this page when a word shows up and you are not sure what it means in practice.

**Jump to:** [A](#aiden) · [C](#cce-code-context-engine) · [D](#demo-scenario) · [F](#foundation) · [G](#guild) · [H](#hcl-and-iac) · [I](#integration) · [L](#llm-and-model) · [M](#module-terraform--opentofu) · [P](#policy-and-guardrail) · [R](#rego) · [S](#scenario) · [T](#talk-track) · [W](#webhook)

---

## Aiden

**What it is:** The name for StackGen’s AI assistant experience — the “copilot” operators chat with during incidents, reviews, or automation tasks.

**Plain analogy:** Think of Aiden as the on-call engineer who never sleeps, but only acts within rules you define.

**See also:** [Agent](#agent), [Guild](#guild)

---

## Agent

**What it is:** A configured AI worker registered in Guild. It has a purpose (for example “AWS SRE”), a set of allowed tools, attached policies, and one or more language models.

**Plain analogy:** A specialist on your team with a job description and a list of systems they are allowed to touch.

**In this repo:** Agent modules (for example `aios-agent-aws-sre`) create and wire agents via Terraform.

**See also:** [Workflow](#workflow), [Integration](#integration), [Policy and guardrail](#policy-and-guardrail)

---

## AIOS

**What it is:** **AI Operations System** — StackGen’s bundled approach to running AI for ops work (incidents, cost, compliance, delivery). Modules prefixed `aios-*` in this repo are ready-made building blocks for that stack.

**Plain analogy:** A prefab kit for “AI that helps run production,” instead of assembling every piece from scratch.

**See also:** [Architecture]({% include doc_url.html path="architecture.md" %}), [Module](#module-terraform--opentofu)

---

## aios-export

**What it is:** A read-only tool under `tools/aios-export/` that snapshots what already exists in a Guild tenant and writes it out as Terraform files plus import commands.

**When to use it:** After someone configured agents in the UI during a proof of concept and the customer wants that setup in Git.

**Plain analogy:** Taking a photograph of a furnished room so you can rebuild the same layout elsewhere — you still need to wire plumbing and electricity (integrations, policies) by hand today.

**See also:** [aios-export guide]({% include doc_url.html path="aios-export.md" %}), [HCL and IaC](#hcl-and-iac)

---

## CCE (Code Context Engine)

**What it is:** A code-analysis layer that scans repositories and returns **file-and-line evidence** — for example “this PR adds a call to `s3:GetObject` here.” Agents use that evidence before they guess.

**Plain analogy:** A linter that explains *why* a change matters for security or architecture, not just that syntax is wrong.

**See also:** [CCE enterprise workflows]({% include doc_url.html path="cce-enterprise-workflows.md" %})

---

## Demo scenario

**What it is:** A small, runnable Terraform root under `examples/scenarios/` built for a single sales conversation — one prospect question, one `make demo SCENARIO=…` command, one talk track.

**Plain analogy:** A rehearsed five-minute demo in a box, not the full production installation.

**See also:** [Scenario](#scenario), [SE Playbook]({% include doc_url.html path="se-playbook.md" %}), [Scenario index]({{ site.github.repository_url }}/blob/main/examples/scenarios/README.md)

---

## Drift (infrastructure drift)

**What it is:** When live cloud resources no longer match what your templates or Terraform say they should be — because someone changed something manually, or a deploy partially failed.

**Why it shows up here:** Agents like CloudFormation Author can detect drift, classify risk, and open pull requests to reconcile.

**See also:** [CloudFormation Author]({% include doc_url.html path="cfn-author.md" %})

---

## Foundation

**What it is:** The bottom layer of every stack: language models, API keys stored as secrets, and basic platform setup. The `aios-foundation` module (or `aios-foundation-bedrock` for AWS Bedrock) must run before agents and integrations.

**Plain analogy:** Power and internet in a new office — nothing else works until this is on.

**See also:** [Architecture]({% include doc_url.html path="architecture.md" %}), [Prerequisites]({% include doc_url.html path="prerequisites.md" %})

---

## Guild

**What it is:** StackGen’s control plane for agents — where you register agents, run workflows, connect tools, and chat with Aiden. The web UI and APIs operators use day to day.

**Plain analogy:** The operations center where specialists (agents) are staffed, given keys to systems (integrations), and given rulebooks (policies).

**See also:** [StackGen](#stackgen), [Tenant](#tenant)

---

## HCL and IaC

**HCL** — the configuration language Terraform and OpenTofu use (the `.tf` files).

**IaC (Infrastructure as Code)** — describing servers, agents, integrations, and policies in files stored in Git instead of only clicking in a UI.

**Why it matters:** This entire repo helps you manage Guild resources as IaC so changes are reviewable, repeatable, and environment-specific.

**See also:** [OpenTofu / Terraform](#opentofu--terraform), [Adopt the repo]({% include doc_url.html path="adopt.md" %})

---

## Integration

**What it is:** A saved connection from Guild to an external system — AWS, GitHub, Grafana, Slack, and so on. Agents call integrations when they need to read or act in that system.

**Plain analogy:** A VPN badge that lets an agent into one vendor account, with credentials stored securely.

**In this repo:** Each `aios-integration-*` module creates one integration type.

**See also:** [Agent](#agent), [Module Catalog]({% include doc_url.html path="module-catalog.md" %})

---

## LLM and model

**LLM (large language model)** — the AI that reads prompts and writes responses (GPT, Claude, Gemini, etc.).

**Model (in Guild)** — a named model registration in your tenant that agents are allowed to use. Foundation modules register models from the API keys or cloud profiles you supply.

**Plain analogy:** Models are which “brains” an agent is allowed to think with; you can list several in priority order as fallbacks.

**See also:** [Foundation](#foundation), [Prerequisites]({% include doc_url.html path="prerequisites.md" %})

---

## MCP (Model Context Protocol)

**What it is:** A standard way for an agent to call external tools — for example StackGen’s own MCP for IaC, or GitHub, Linear, or Cursor MCP servers.

**Plain analogy:** USB ports on the agent: each MCP is a different plug for a different service.

**See also:** [Integration](#integration)

---

## Module (Terraform / OpenTofu)

**What it is:** A reusable package of Terraform configuration. Each folder under `modules/` in this repo is one module you reference with a `module { source = "…" }` block.

**Plain analogy:** A LEGO kit for one concern (Slack wiring, AWS SRE agent, shared policies) that you snap into your customer’s root project.

**See also:** [Onboarding step 4]({% include doc_url.html path="onboarding/04-use-a-module.md" %}), [Module Catalog]({% include doc_url.html path="module-catalog.md" %})

---

## Module catalog vs use-case catalog

| Catalog | Answers the question |
|---------|---------------------|
| **Module catalog** | “What modules exist, what do they take as input, and how do I copy-paste them?” |
| **Use-case catalog** | “This customer looks like PrivateSaaS / multi-tenant / self-hosted — which modules should I start with?” |

**See also:** [Module Catalog]({% include doc_url.html path="module-catalog.md" %}), [Use-case catalog]({% include doc_url.html path="use-case-catalog.md" %})

---

## OpenTofu / Terraform

**What they are:** Command-line tools that read `.tf` files and create or update cloud and platform resources. **OpenTofu** (`tofu`) and **HashiCorp Terraform** (`terraform`) work the same way for everything in this repo.

**Commands you will see:** `init` (download providers), `plan` (preview changes), `apply` (make changes), `validate` (syntax check).

**See also:** [Prerequisites]({% include doc_url.html path="prerequisites.md" %}), [HCL and IaC](#hcl-and-iac)

---

## PoC (proof of concept)

**What it is:** A time-boxed trial where a customer or prospect tries Aiden on a real (often limited) environment before buying or rolling out widely.

**In this repo:** Demos use **scenarios**; handoffs after UI setup use **aios-export**; production rollouts use pinned modules and separate `terraform.tfvars` per environment.

**See also:** [Adopt the repo]({% include doc_url.html path="adopt.md" %}), [Enterprise deployment profile]({% include doc_url.html path="enterprise-deployment-profile.md" %})

---

## Policy and guardrail

**What it is:** A rule that must pass before an agent is allowed to run a dangerous action — for example “no production writes without approval” or “block delete operations.”

**Plain analogy:** A manager who must sign off before certain tools run.

**In Guild:** Policies are written in **Rego** and attached to agents. The `aios-policies` module ships common guardrails.

**See also:** [Rego](#rego), [Writing Rego policies]({% include doc_url.html path="rego-policies.md" %})

---

## RCA (root cause analysis)

**What it is:** A structured write-up of **what broke, why, and what to do next** — often produced after an alert or incident.

**Why it shows up here:** Many demo scenarios end with Aiden investigating signals and publishing an RCA to Slack, Grafana, or Datadog.

**See also:** [SE Playbook]({% include doc_url.html path="se-playbook.md" %})

---

## Rego

**What it is:** A small policy language (used with Open Policy Agent) for writing allow/deny rules. You do not need to be a Rego expert to use this repo — modules ship policy bodies; the [Rego guide]({% include doc_url.html path="rego-policies.md" %}) explains how to read and test them.

**Plain analogy:** If-then rules on a checklist: “If the action is `delete_bucket` and environment is `prod`, deny.”

**See also:** [Policy and guardrail](#policy-and-guardrail)

---

## Remote runner

**What it is:** A worker process (often on a customer network or Kubernetes cluster) that runs shell commands, CLIs, or long jobs on behalf of Guild when cloud sandboxes are not enough.

**Plain analogy:** A jump box with hands — the agent thinks in Guild, the runner types in your VPC.

**In this repo:** `aios-remote-runner` registers runners and prints install commands for aiden-runner.

**See also:** [Enterprise deployment profile]({% include doc_url.html path="enterprise-deployment-profile.md" %})

---

## Scenario

**What it is:** A self-contained Terraform root under `examples/scenarios/<name>/` that provisions a minimal stack for one demo story.

**Not the same as:** `examples/complete/` (full production-style stack) or a customer’s own root module.

**See also:** [Demo scenario](#demo-scenario), [Scenario index]({{ site.github.repository_url }}/blob/main/examples/scenarios/README.md)

---

## Solutions engineer (SE)

**What it is:** The person who demos StackGen to prospects, wires modules for customers, and extends this repo. The docs on this site are written primarily for SEs, not end users of a finished product UI.

**See also:** [SE Playbook]({% include doc_url.html path="se-playbook.md" %}), [Adopt the repo]({% include doc_url.html path="adopt.md" %})

---

## Solutions repo (this repository)

**What it is:** The `appcd-dev/solutions` Git repository — Terraform modules, demo scenarios, docs site, and SE tools (like aios-export). It does **not** contain the Guild server itself; it configures resources **on** StackGen.

**See also:** [Architecture]({% include doc_url.html path="architecture.md" %}), [AGENTS.md]({{ site.github.repository_url }}/blob/main/AGENTS.md) (for IDE assistants)

---

## StackGen

**What it is:** The platform vendor stack — Guild (agents), integrations, policies, secrets, and the Terraform provider that this repo targets.

**Plain analogy:** The operating system; this repo ships applications (modules) that run on it.

**See also:** [Guild](#guild), [StackGen provider](#stackgen-provider-sg)

---

## StackGen provider (`sg`)

**What it is:** The Terraform/OpenTofu plugin that talks to StackGen’s APIs. Resource types look like `sg_agent`, `sg_workflow`, `sg_guild_integration`. You configure it once per root with `provider "sg" { stackgen_url = … stackgen_token = … }`.

**See also:** [Prerequisites]({% include doc_url.html path="prerequisites.md" %}), [Onboarding step 4]({% include doc_url.html path="onboarding/04-use-a-module.md" %})

---

## Talk track

**What it is:** A short script (usually five bullets) in each scenario README that tells you what to say and click during a live demo.

**Plain analogy:** Speaker notes for the prospect call.

**See also:** [SE Playbook]({% include doc_url.html path="se-playbook.md" %}), [Demo scenario](#demo-scenario)

---

## Tenant

**What it is:** One isolated StackGen / Guild environment — one customer’s agents, secrets, and integrations. Dev, staging, and prod are usually **separate tenants** (or separate config files pointing at different URLs/tokens).

**Optional scope:** `stackgen_project_id` (org/project UUID) when APIs need an explicit organization scope.

**See also:** [Prerequisites]({% include doc_url.html path="prerequisites.md" %}), [PoC](#poc-proof-of-concept)

---

## Webhook

**What it is:** An HTTPS URL that **starts** a workflow when an external system POSTs JSON — for example a CI pipeline, drift detector, GitHub event, or alert router.

**Plain analogy:** A doorbell that kicks off a playbook instead of ringing a chime.

**In this repo:** Many agent modules register `sg_webhook` resources; payloads are documented per module (for example CFN Author webhooks).

**See also:** [Workflow](#workflow), [CloudFormation Author]({% include doc_url.html path="cfn-author.md" %})

---

## Workflow

**What it is:** A multi-step automated playbook in Guild — clone repo, run checks, call an agent, open a PR, and so on. Workflows can be triggered by chat, schedules, or webhooks.

**Plain analogy:** A runbook where each step can be a human, a script, or an agent.

**Difference from an agent:** An **agent** is a conversational specialist; a **workflow** is the assembly line that orchestrates many steps.

**See also:** [Agent](#agent), [Webhook](#webhook)

---

## Adopt on conflict

**What it is:** A provider setting (`adopt_on_conflict`, default **true**) that tells Terraform to **attach to an existing Guild object** if create returns “already exists,” instead of failing.

**When to turn off:** Strict pipelines where duplicates must fail so you run `terraform import` explicitly.

**See also:** [StackGen provider](#stackgen-provider-sg), [aios-export](#aios-export)

---

## Still stuck?

- **Getting started:** [Adopt the repo]({% include doc_url.html path="adopt.md" %})
- **Credentials:** [Prerequisites]({% include doc_url.html path="prerequisites.md" %})
- **Pick a demo:** [SE Playbook]({% include doc_url.html path="se-playbook.md" %})
