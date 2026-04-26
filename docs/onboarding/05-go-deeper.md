---
layout: page
title: "5 — Go deeper"
permalink: step-5/
nav_order: 14
parent: Onboarding
---

# Step 5 — Go deeper (when you need it)

Use this page as a **map**, not a checklist. Open links only when the topic applies to you.

## Repository and layout

- **[README]({{ site.github.repository_url }}/blob/main/README.md)** — module catalog, prerequisites, `Makefile`, CI, registry authentication for local runs.
- **[Architecture]({% include doc_url.html path="architecture.md" %})** — layer diagram (foundation, integrations, agents, future workflow layer).
- **[`examples/complete/`]({{ site.github.repository_url }}/blob/main/examples/complete/)** — large runnable composition; good reference, not the smallest first read.

## Continuous integration

- **[`.github/workflows/ci.yml`]({{ site.github.repository_url }}/blob/main/.github/workflows/ci.yml)** — OpenTofu **`tofu fmt`** / **`tofu validate`**, OPA; HashiCorp Terraform is interchangeable locally via `make TF=terraform`.

## This documentation site (GitHub Pages)

- **Source:** `/docs` on your default branch ([`_config.yml`]({{ site.github.repository_url }}/blob/main/docs/_config.yml)).
- **Forks / renames:** update `url`, `baseurl`, and `repository` in `_config.yml` so links and assets resolve (see [Home — Enable this site]({% include doc_url.html path="index.md" %}) for the Pages settings path).

## Policies (Rego)

- Policies live under `modules/*/policies` and `modules/aios-policies/policies/`.
- **`make opa-check`** validates each **file** in isolation (how `sg_policy` uses them), not as one merged bundle.
- For **sample evaluation payloads**, the **[OPA Rego Playground](https://play.openpolicyagent.org/)**, and links to the Rego language docs, see **[Writing Rego policies]({% include doc_url.html path="rego-policies.md" %})**.

---

**Previous:** [Step 4 — Use a module]({% include doc_url.html path="onboarding/04-use-a-module.md" %})  
**Back:** [Onboarding hub]({% include doc_url.html path="onboarding/index.md" %})
