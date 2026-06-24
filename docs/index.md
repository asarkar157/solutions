---
layout: default
title: Home
nav_order: 1
---

# StackGen modules for solutions engineers

A **Terraform/OpenTofu module library** for StackGen (Aiden / Guild): projects, roles, secrets, integrations, policies, and agent resources you compose in your own roots. **AIOS** (StackGen's AI operating system) is the headlined accelerator — opinionated, layered bundles you can run end-to-end — but the same modules work à la carte.

This site is organized around **three jobs solutions engineers actually have**. Pick the row that matches what you are doing right now.

| You are… | Start here | What you get |
|----------|-----------|--------------|
| **Demoing Aiden to a prospect in the next 30 minutes** (pre-sales) | [SE playbook]({% include doc_url.html path="se-playbook.md" %}) and [`examples/scenarios/`]({{ site.github.repository_url }}/tree/main/examples/scenarios) | A one-command runnable demo per prospect question (AWS SRE, FinOps, pipeline insights, alert triage, repo → IaC, monorepo split, Bedrock Claude). Each scenario ships with a talk track. |
| **Migrating a UI-clicked tenant into Terraform** (PoC → prod, multi-env, customer hand-off, DR) | [aios-export]({% include doc_url.html path="aios-export.md" %}) | Read-only export of every agent / workflow / remote runner in a Guild tenant — first as a JSON snapshot, then as HCL the customer can version-control. Phase 1 does **not** capture integrations / policies / schedules / secrets / webhooks (no provider data sources yet — hand-merge those); Phase 2 will add manual capture for them. |
| **Composing your own root from individual modules** (advanced / customers extending the library) | [Adopt the repo]({% include doc_url.html path="adopt.md" %}) → [Use a module]({% include doc_url.html path="onboarding/04-use-a-module.md" %}) | Step-by-step orientation, machine setup, local CI parity, and the patterns used in `examples/complete/`. |

> Work through whichever row applies in small steps. You do **not** need to finish everything at once. The CLIs are interchangeable — this repo prefers **OpenTofu** but `terraform` works the same way for `fmt`, `init`, `validate`, `plan`, `apply`.

[**How do I adopt this repo? →**]({% include doc_url.html path="adopt.md" %}) &nbsp;·&nbsp; [**Run your first scenario →**]({% include doc_url.html path="se-playbook.md" %})

---

## Start adopting

| Resource | Description |
|----------|-------------|
| [Adopt the repo]({% include doc_url.html path="adopt.md" %}) | Single entry point: three paths, migration guide picker, production checklist. |
| [SE Playbook]({% include doc_url.html path="se-playbook.md" %}) | Prospect-question → scenario map and one-screen demo runbook. |
| [Prerequisites]({% include doc_url.html path="prerequisites.md" %}) | StackGen credentials, provider auth, LLM keys — one checklist. |
| [Glossary]({% include doc_url.html path="glossary.md" %}) | Plain-English definitions for StackGen, Guild, agents, workflows, and other terms on this site. |

## Find modules

| Resource | Description |
|----------|-------------|
| [Module Catalog]({% include doc_url.html path="module-catalog.md" %}) | Interactive module discovery with tag filtering and copy-paste snippets. |
| [Use-case catalog]({% include doc_url.html path="use-case-catalog.md" %}) | Customer situation → agent + integration modules (SaaS, PrivateSaaS, multi-tenant, self-hosted). |

## Deep dives

| Resource | Description |
|----------|-------------|
| [Topic guides]({% include doc_url.html path="guides/index.md" %}) | Architecture, migration, CFN Author, CCE workflows, Rego policies, and more. |
| [Repository README]({{ site.github.repository_url }}/blob/main/README.md) | Full reference: modules table, CI, `Makefile`, prerequisites. |
| [Runnable scenarios]({{ site.github.repository_url }}/tree/main/examples/scenarios) | Small, single-purpose roots for pre-sales demos. |
| [Full-stack example]({{ site.github.repository_url }}/blob/main/examples/complete/) | Every layer wired together in one root. |
