---
layout: default
title: Home
nav_order: 1
---

# StackGen modules for solutions engineers

A **Terraform/OpenTofu module library** for StackGen (Aiden / Guild): projects, roles, secrets, integrations, policies, and agent resources you compose in your own roots. **AIOS** (StackGen's AI operating system) is the headlined accelerator — opinionated, layered bundles you can run end-to-end — but the same modules work à la carte.

This site is reorganized around **three jobs solutions engineers actually have**. Pick the row that matches what you are doing right now.

| You are… | Start here | What you get |
|----------|-----------|--------------|
| **Demoing Aiden to a prospect in the next 30 minutes** (pre-sales) | [SE playbook]({% include doc_url.html path="se-playbook.md" %}) and [`examples/scenarios/`]({{ site.github.repository_url }}/tree/main/examples/scenarios) | A one-command runnable demo per prospect question (AWS SRE, FinOps, pipeline insights, alert triage, repo → IaC). Each scenario ships with a talk track. |
| **Migrating a UI-clicked tenant into Terraform** (PoC → prod, multi-env, customer hand-off, DR) | [`tools/aios-export/`]({{ site.github.repository_url }}/tree/main/tools/aios-export) | Read-only export of every agent / workflow / integration in a Guild tenant — first as a JSON snapshot, then as HCL the customer can version-control. |
| **Composing your own root from individual modules** (advanced / customers extending the library) | [Onboarding]({% include doc_url.html path="onboarding/index.md" %}) → [Use a module]({% include doc_url.html path="onboarding/04-use-a-module.md" %}) | Step-by-step orientation, machine setup, local CI parity, and the patterns used in `examples/complete/`. |

> Work through whichever row applies in small steps. You do **not** need to finish everything at once. The CLIs are interchangeable — this repo prefers **OpenTofu** but `terraform` works the same way for `fmt`, `init`, `validate`, `plan`, `apply`.

[**Run your first scenario →**]({% include doc_url.html path="se-playbook.md" %})

---

## Quick links

| Resource | Description |
|----------|-------------|
| [SE Playbook]({% include doc_url.html path="se-playbook.md" %}) | Prospect-question → scenario map, demo runbook, office hours. **Start here if you are a solutions engineer.** |
| [Module Catalog]({% include doc_url.html path="module-catalog.md" %}) | Interactive module discovery with tag filtering and copy-paste snippets. |
| [Onboarding]({% include doc_url.html path="onboarding/index.md" %}) | Guided steps (start here if you are composing your own root). |
| [Architecture]({% include doc_url.html path="architecture.md" %}) | Layer diagram and how modules relate. |
| [Repository README]({{ site.github.repository_url }}/blob/main/README.md) | Full reference: modules table, CI, `Makefile`, prerequisites. |
| [Runnable scenarios]({{ site.github.repository_url }}/tree/main/examples/scenarios) | Small, single-purpose roots for pre-sales demos. |
| [Full-stack example]({{ site.github.repository_url }}/blob/main/examples/complete/) | Every layer wired together in one root (under `examples/complete/`). |
| [Writing Rego policies]({% include doc_url.html path="rego-policies.md" %}) | Plain-language guide to policy evaluation, sample evaluation `input` JSON, OPA Playground, and repo examples. |
| [SE feedback / office hours]({% include doc_url.html path="se-feedback.md" %}) | Slack channel, scenario-request issue template, weekly cadence — and the `scenario-author` bot that triages every request within minutes. |
