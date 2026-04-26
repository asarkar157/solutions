---
layout: default
title: Home
nav_order: 1
---

# Welcome

This site walks you through **AIOS Modules** in small steps: what the repository is, what to install, how to run checks locally, and how to reference a module from your own **OpenTofu** or **Terraform** root (the CLIs are interchangeable; this repo prefers **OpenTofu**).

You do **not** need to finish everything at once. Use the steps in order, or jump ahead when you are ready.

[**Start onboarding →**]({% link onboarding/index.md %})

---

## Quick links

| Resource | Description |
|----------|-------------|
| [Onboarding]({% link onboarding/index.md %}) | Guided steps (start here if you are new). |
| [Architecture]({% link architecture.md %}) | Layer diagram and how modules relate. |
| [Repository README]({{ site.github.repository_url }}/blob/main/README.md) | Full reference: modules table, CI, `Makefile`, prerequisites. |
| [Runnable example]({{ site.github.repository_url }}/blob/main/examples/complete/) | Full stack under `examples/complete/`. |
| [Writing Rego policies]({% link rego-policies.md %}) | Plain-language guide to policy evaluation, sample AIOS `input` JSON, OPA Playground, and repo examples. |

If links or styles look wrong, edit **`baseurl`** and **`url`** in [`_config.yml`]({{ site.github.repository_url }}/blob/main/docs/_config.yml) so they match your org, site type, and repository name.
