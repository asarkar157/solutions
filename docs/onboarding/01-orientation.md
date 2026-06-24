---
layout: page
title: "1 — Orientation"
permalink: step-1/
nav_order: 10
parent: Onboarding
---

# Step 1 — Orientation

## What is this repository?

This monorepo is a **Terraform/OpenTofu module library for StackGen**: provider-backed resources such as **projects**, **roles**, **secrets**, **integrations**, **policies** (Rego), and **agents**. **AIOS**—StackGen’s AI operating system—is a **strong theme in the catalog** (foundation, integrations, and agent bundles) when you want opinionated, layered stacks; you can still adopt pieces à la carte. Modules compose in layers (foundation → integrations → agents; see [Architecture]({% include doc_url.html path="architecture.md" %})).

## Three common paths

1. **I want to demo Aiden in front of a prospect today** (most pre-sales SEs land here first)  
   You will clone this repo, set a few environment variables, and run `make demo SCENARIO=<name>` — a one-command wrapper over `tofu init && plan && apply` against a prebuilt scenario root under [`examples/scenarios/`]({{ site.github.repository_url }}/tree/main/examples/scenarios). See the [SE Playbook]({% include doc_url.html path="se-playbook.md" %}) for which scenario to pick for which prospect. The rest of the onboarding steps are optional for this path.

2. **I only want to use modules in my Terraform** (composing your own root)  
   You will reference module `source` URLs (GitHub), provide variables (StackGen URL, API keys, etc.), and run **`tofu plan` / `tofu apply`** (or the same with **`terraform`**) in **your** environment. You do **not** have to clone this repo unless you want to read examples or contribute. This is the path the rest of these onboarding pages walk you through.

3. **I want to change modules or run the same checks as CI**  
   You will clone this repository, install Terraform (and OPA for policy work), and use the **`Makefile`** targets described in later steps.

## What you need in the real world (high level)

See the full [Prerequisites]({% include doc_url.html path="prerequisites.md" %}) checklist. At minimum:

- A **StackGen / Guild** deployment you can reach, and a PAT for `stackgen_token`
- **OpenTofu or Terraform** `>= 1.5`
- **At least one LLM key** for stacks that register models (see prerequisites for Bedrock path)

You do **not** need all of that on day one to finish [step 2]({% include doc_url.html path="onboarding/02-your-machine.md" %})—only Terraform (and Git) to clone.

---

**Next:** [Step 2 — Your machine]({% include doc_url.html path="onboarding/02-your-machine.md" %})  
**Back:** [Onboarding hub]({% include doc_url.html path="onboarding/index.md" %})
