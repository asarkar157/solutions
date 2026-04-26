---
layout: default
title: Home
nav_order: 1
---

# StackGen modules for solution engineers

This documentation supports **solution engineers** shipping on **StackGen**: a **library of Terraform/OpenTofu modules** for projects, roles, secrets, integrations, policies, and agent resources you compose in your own roots. **AIOS** (StackGen’s AI operating system) shows up here as a **highlighted accelerator**—opinionated, layered bundles when you are standing up AI-assisted operations—not the only way to use the repo.

Work through it in small steps: what the repository contains, what to install, how to run checks locally, and how to reference a module from your **OpenTofu** or **Terraform** root (the CLIs are interchangeable; this repo prefers **OpenTofu**).

You do **not** need to finish everything at once. Use the steps in order, or jump ahead when you are ready.

[**Start onboarding →**]({% include doc_url.html path="onboarding/index.md" %})

---

## Quick links

| Resource | Description |
|----------|-------------|
| [Module Catalog]({% include doc_url.html path="module-catalog.md" %}) | Interactive module discovery with tag filtering and copy-paste snippets. |
| [Onboarding]({% include doc_url.html path="onboarding/index.md" %}) | Guided steps (start here if you are new). |
| [Architecture]({% include doc_url.html path="architecture.md" %}) | Layer diagram and how modules relate. |
| [Repository README]({{ site.github.repository_url }}/blob/main/README.md) | Full reference: modules table, CI, `Makefile`, prerequisites. |
| [Runnable example]({{ site.github.repository_url }}/blob/main/examples/complete/) | Full stack under `examples/complete/`. |
| [Writing Rego policies]({% include doc_url.html path="rego-policies.md" %}) | Plain-language guide to policy evaluation, sample evaluation `input` JSON, OPA Playground, and repo examples. |
