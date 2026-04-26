---
layout: page
title: "1 — Orientation"
permalink: step-1/
nav_order: 10
parent: Onboarding
---

# Step 1 — Orientation

## What is this repository?

**AIOS Modules** is a collection of **Terraform modules** used to configure **AIOS** (AI operations) on the **StackGen** platform: agents, integrations, policies (Rego), and related resources. Modules are composed in layers (foundation → integrations → agents; see [Architecture]({% include doc_url.html path="architecture.md" %})).

## Two common paths

1. **I only want to use modules in my Terraform**  
   You will reference module `source` URLs (GitHub), provide variables (StackGen URL, API keys, etc.), and run **`tofu plan` / `tofu apply`** (or the same with **`terraform`**) in **your** environment. You do **not** have to clone this repo unless you want to read examples or contribute.

2. **I want to change modules or run the same checks as CI**  
   You will clone this repository, install Terraform (and OPA for policy work), and use the **`Makefile`** targets described in later steps.

## What you need in the real world (high level)

- A **StackGen / Guild** deployment you can reach, and credentials the modules expect (see each module’s README under `modules/<name>/`).
- **Terraform** `>= 1.5` (CI uses a recent 1.9.x).
- **LLM provider keys** as required by the modules you enable (see root README).

You do **not** need all of that on day one to finish [step 2]({% include doc_url.html path="onboarding/02-your-machine.md" %})—only Terraform (and Git) to clone.

---

**Next:** [Step 2 — Your machine]({% include doc_url.html path="onboarding/02-your-machine.md" %})  
**Back:** [Onboarding hub]({% include doc_url.html path="onboarding/index.md" %})
